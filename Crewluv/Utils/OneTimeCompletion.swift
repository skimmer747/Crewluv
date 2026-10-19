//
//  OneTimeCompletion.swift
//  CrewLuve
//
//  Ends a piece of work once, whoever ends it first
//

import Foundation

/// Ends a piece of work once, whichever end comes first, from any thread: say iOS's expiry
/// handler for a background task, or a deadline, and the end of the work itself.
nonisolated final class OneTimeCompletion<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var complete: ((Value) -> Void)?

    init(_ complete: @escaping (Value) -> Void) {
        self.complete = complete
    }

    /// Ends the work with `value`, unless it has ended already.
    func callAsFunction(_ value: Value) {
        let complete = lock.withLock {
            defer { self.complete = nil }
            return self.complete
        }
        complete?(value)
    }
}

nonisolated extension OneTimeCompletion where Value == Bool {
    /// Ends the work, unless it has ended already.
    func callAsFunction(success: Bool) {
        self(success)
    }
}
