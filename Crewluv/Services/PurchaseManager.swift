//
//  PurchaseManager.swift
//  CrewLuve
//
//  Manages in-app purchase for CrewLuve one-time unlock
//

import StoreKit
import SwiftUI

@MainActor
@Observable
class PurchaseManager {
    static let shared = PurchaseManager()
    
    // Product ID - must match App Store Connect
    private let productID = "com.toddanderson.crewluv.unlock"
    
    // Purchase state
    var hasUnlockedApp = false
    var isLoading = false
    var product: Product?
    
    private var updateListenerTask: Task<Void, Never>?

    #if DEBUG
    private var debugUnlocked = false
    #endif

    /// Whether this build is a TestFlight (sandbox) distribution.
    /// Uses StoreKit 2’s `AppTransaction` instead of deprecated `Bundle.appStoreReceiptURL`.
    private func isTestFlightBuild() async -> Bool {
        #if DEBUG
        // Xcode debug builds are never treated as TestFlight; use debug tools to test IAP.
        return false
        #else
        guard case .verified(let appTransaction) = try? await AppTransaction.shared else {
            return false
        }
        // TestFlight installs report `.sandbox` for the app’s purchase environment.
        return appTransaction.environment == .sandbox
        #endif
    }

    private init() {
        // Start listening for transaction updates in a detached task
        let task = Task.detached { @MainActor [weak self] in
            guard let self else { return }
            self.updateListenerTask = self.listenForTransactions()
            if await self.isTestFlightBuild() {
                self.hasUnlockedApp = true
            }
            await self.loadProduct()
            await self.checkPurchaseStatus()
        }
        _ = task
    }
    
    // MARK: - Load Product
    
    func loadProduct() async {
        do {
            let products = try await Product.products(for: [productID])
            product = products.first
            debugLog("[PurchaseManager] Loaded product: \(product?.displayName ?? "none")")
        } catch {
            debugLog("[PurchaseManager] ❌ Failed to load product: \(error)")
        }
    }
    
    // MARK: - Check Purchase Status
    
    func checkPurchaseStatus() async {
        // Check for existing entitlements
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == productID {
                    hasUnlockedApp = true
                    debugLog("[PurchaseManager] ✅ App already unlocked")
                    return
                }
            }
        }
        
        #if DEBUG
        if debugUnlocked { return }
        #endif

        if await isTestFlightBuild() {
            hasUnlockedApp = true
            debugLog("[PurchaseManager] TestFlight build detected, bypassing paywall")
            return
        }

        hasUnlockedApp = false
        debugLog("[PurchaseManager] 🔒 App locked, purchase required")
    }
    
    // MARK: - Purchase
    
    func purchase() async throws {
        guard let product = product else {
            throw PurchaseError.productNotFound
        }
        
        isLoading = true
        defer { isLoading = false }
        
        debugLog("[PurchaseManager] Starting purchase...")
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            // Check verification
            switch verification {
            case .verified(let transaction):
                // Transaction is verified, grant access
                hasUnlockedApp = true
                await transaction.finish()
                debugLog("[PurchaseManager] ✅ Purchase successful!")
                
            case .unverified(_, let error):
                // Transaction failed verification
                debugLog("[PurchaseManager] ❌ Purchase unverified: \(error)")
                throw PurchaseError.failedVerification
            }
            
        case .userCancelled:
            debugLog("[PurchaseManager] Purchase cancelled by user")
            throw PurchaseError.userCancelled
            
        case .pending:
            debugLog("[PurchaseManager] Purchase pending")
            throw PurchaseError.pending
            
        @unknown default:
            throw PurchaseError.unknown
        }
    }
    
    // MARK: - Restore Purchases

    func restorePurchases() async throws {
        isLoading = true
        defer { isLoading = false }

        try await AppStore.sync()
        await checkPurchaseStatus()
        debugLog("[PurchaseManager] Restore complete")
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached {
            for await result in Transaction.updates {
                switch result {
                case .verified(let transaction):
                    await transaction.finish()
                    await self.checkPurchaseStatus()

                case .unverified(_, let error):
                    await MainActor.run {
                        debugLog("[PurchaseManager] ❌ Unverified transaction: \(error)")
                    }
                }
            }
        }
    }
    
    // MARK: - Debug Helper
    
    #if DEBUG
    func simulateUnlock() {
        hasUnlockedApp = true
        debugUnlocked = true
        debugLog("[PurchaseManager] 🧪 DEBUG: Simulated unlock")
    }
    
    func resetPurchase() {
        hasUnlockedApp = false
        debugLog("[PurchaseManager] 🧪 DEBUG: Reset purchase")
    }
    #endif
}

// MARK: - Purchase Errors

enum PurchaseError: LocalizedError {
    case productNotFound
    case failedVerification
    case userCancelled
    case pending
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Product not found"
        case .failedVerification:
            return "Purchase verification failed"
        case .userCancelled:
            return "Purchase cancelled"
        case .pending:
            return "Purchase pending approval"
        case .unknown:
            return "Unknown error occurred"
        }
    }
}
