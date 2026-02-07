//
//  PaywallView.swift
//  CrewLuv
//
//  One-time purchase paywall with Liquid Glass design
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(PurchaseManager.self) private var purchaseManager
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ScrollView {
            GlassEffectContainer(spacing: 20) {
                VStack(spacing: 32) {
                    // Hero Section
                    VStack(spacing: 16) {
                        Image(systemName: "heart.circle.fill")
                            .font(.system(size: 100))
                            .foregroundStyle(.red.gradient)
                        
                        Text("Welcome to CrewLuv")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Stay connected with your pilot, always know when they'll be home")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 32)
                    
                    // Features
                    VStack(spacing: 16) {
                        FeatureRow(
                            icon: "clock.fill",
                            title: "Real-Time Updates",
                            description: "Live countdown to homecoming or next departure"
                        )
                        
                        FeatureRow(
                            icon: "location.fill",
                            title: "Location Tracking",
                            description: "See their current city and local time"
                        )
                        
                        FeatureRow(
                            icon: "airplane",
                            title: "Flight Status",
                            description: "Know when they're flying, on duty, or at home"
                        )
                        
                        FeatureRow(
                            icon: "calendar",
                            title: "Trip Progress",
                            description: "Track trip days and upcoming destinations"
                        )
                        
                        FeatureRow(
                            icon: "lock.shield.fill",
                            title: "Private & Secure",
                            description: "CloudKit sharing keeps your data safe"
                        )
                    }
                    .padding(.horizontal, 24)
                    
                    // Pricing Card
                    if let product = purchaseManager.product {
                        VStack(spacing: 16) {
                            VStack(spacing: 8) {
                                Text("One-Time Purchase")
                                    .font(.headline)
                                
                                Text(product.displayPrice)
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                
                                Text("Pay once, use forever")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .glassEffect(.regular, in: .rect(cornerRadius: 20))
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    // Purchase Button
                    VStack(spacing: 12) {
                        Button(action: {
                            Task {
                                await handlePurchase()
                            }
                        }) {
                            if purchaseManager.isLoading {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Unlock CrewLuv")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(purchaseManager.isLoading || purchaseManager.product == nil)
                        
                        Button(action: {
                            Task {
                                await handleRestore()
                            }
                        }) {
                            Text("Restore Purchase")
                                .font(.subheadline)
                        }
                        .buttonStyle(.glass)
                        .disabled(purchaseManager.isLoading)
                        
                        #if DEBUG
                        Button(action: {
                            purchaseManager.simulateUnlock()
                        }) {
                            Text("🧪 Debug: Simulate Unlock")
                                .font(.caption)
                        }
                        .buttonStyle(.glass)
                        #endif
                    }
                    .padding(.horizontal, 24)
                    
                    // Legal
                    VStack(spacing: 8) {
                        Text("One-time payment. No subscriptions. No recurring charges.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        HStack(spacing: 16) {
                            Button("Privacy Policy") {
                                // Open privacy policy
                                if let url = URL(string: "https://toddanderson.com/crewluv/privacy") {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .font(.caption2)
                            
                            Text("•")
                                .foregroundColor(.secondary)
                            
                            Button("Terms of Use") {
                                // Open terms
                                if let url = URL(string: "https://toddanderson.com/crewluv/terms") {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .font(.caption2)
                        }
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
        }
        .alert("Purchase Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func handlePurchase() async {
        do {
            try await purchaseManager.purchase()
        } catch PurchaseError.userCancelled {
            // Don't show error for cancellation
            return
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func handleRestore() async {
        do {
            try await purchaseManager.restorePurchases()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var purchaseManager = PurchaseManager.shared
        
        var body: some View {
            PaywallView()
                .environment(purchaseManager)
        }
    }
    
    return PreviewWrapper()
}
