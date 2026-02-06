//
//  DebugLog.swift
//  CrewLuv
//
//  Debug-only logging utility
//

import Foundation

// MARK: - Debug Logging

/// Debug-only logging wrapper that silences console output in production builds.
///
/// This function replaces print() throughout the codebase to ensure:
/// - Development builds show all debug output normally
/// - Production/App Store builds have zero console logging
/// - No performance impact in release builds (code is compiled out)
///
/// Usage:
/// ```swift
/// debugLog("Loading pilot status...")
/// debugLog("Found", status, "records")
/// debugLog("✅ Status loaded")
/// ```
///
/// - Parameters:
///   - items: Zero or more items to print (same as print())
///   - separator: String to print between items (default: space)
///   - terminator: String to print after all items (default: newline)
func debugLog(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    #if DEBUG
    let output = items.map { String(describing: $0) }.joined(separator: separator)
    print(output, terminator: terminator)
    #endif
}
