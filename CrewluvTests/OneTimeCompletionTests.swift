//
//  OneTimeCompletionTests.swift
//  CrewluvTests
//
//  The background refresh's task and a push's read end once, whoever ends them first
//

import Foundation
import Testing
@testable import Crewluv

struct OneTimeCompletionTests {

    @Test func test_onlyTheFirstEndCounts() {
        let ends = Ends<Bool>()
        let completion = OneTimeCompletion { ends.add($0) }

        completion(success: false)
        completion(success: true)

        #expect(ends.all == [false])
    }

    @Test func test_endsWithTheFirstEndsValue() {
        let ends = Ends<String>()
        let completion = OneTimeCompletion { ends.add($0) }

        completion("read")
        completion("deadline")

        #expect(ends.all == ["read"])
    }

    @Test func test_endsOnce_whenEndedFromManyThreadsAtOnce() async {
        let ends = Ends<Bool>()
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
private nonisolated final class Ends<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var ends: [Value] = []

    func add(_ value: Value) {
        lock.withLock { ends.append(value) }
    }

    var all: [Value] {
        lock.withLock { ends }
    }
}
