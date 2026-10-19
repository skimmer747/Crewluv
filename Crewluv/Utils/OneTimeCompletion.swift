//
//  OneTimeCompletion.swift
//  CrewLuve
//
//  Ends a piece of work once, whoever ends it first
//

import Foundation

/// Ends a piece of work once, whichever end comes first, from any thread: say iOS's expiry
/// handler for a background task, and the end of the task's own work.
nonisolated final class OneTimeCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var complete: ((Bool) -> Void)?

    init(_ complete: @escaping (Bool) -> Void) {
        self.complete = complete
    }

    /// Ends the work with `success`, unless it has ended already.
    func callAsFunction(success: Bool) {
        let complete = lock.withLock {
            defer { self.complete = nil }
            return self.complete
        }
        complete?(success)
    }
}
