//
//  OneTimeCompletionTests.swift
//  CrewluvTests
//
//  The background refresh's task ends once, whoever ends it first
//

import Foundation
import Testing
@testable import Crewluv

struct OneTimeCompletionTests {

    @Test func test_onlyTheFirstEndCounts() {
        let ends = Ends()
        let completion = OneTimeCompletion { ends.add($0) }

        completion(success: false)
        completion(success: true)

        #expect(ends.all == [false])
    }

    @Test func test_endsOnce_whenEndedFromManyThreadsAtOnce() async {
        let ends = Ends()
        let completion = OneTimeCompletion { ends.add($0) }

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<200 {
                group.addTask { completion(success: true) }
            }
        }

        #expect(ends.all == [true])
    }
}

/// The ends a completion saw, added to from any thread.
private nonisolated final class Ends: @unchecked Sendable {
    private let lock = NSLock()
    private var ends: [Bool] = []

    func add(_ success: Bool) {
        lock.withLock { ends.append(success) }
    }

    var all: [Bool] {
        lock.withLock { ends }
    }
}
