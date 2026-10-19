//
//  RepeatingRefreshTests.swift
//  CrewluvTests
//
//  The 60-second check's timer (partner links piece 4 spec §5.5)
//

import Foundation
import Testing
@testable import Crewluv

@MainActor
struct RepeatingRefreshTests {

    @Test func test_start_runsTheActionAfterEachInterval() async {
        let clock = HandClock()
        let runs = Counter()
        let check = RepeatingRefresh(sleep: clock.sleep)

        check.start { runs.count += 1 }
        await eventually { clock.sleeps.count == 1 }
        #expect(runs.count == 0)
        clock.tick()
        await eventually { runs.count == 1 }
        clock.tick()
        await eventually { runs.count == 2 }

        #expect(clock.sleeps.allSatisfy { $0 == .seconds(60) })
        #expect(check.isRunning)
        check.stop()
    }

    @Test func test_stop_endsTheChecks() async {
        let clock = HandClock()
        let runs = Counter()
        let check = RepeatingRefresh(sleep: clock.sleep)

        check.start { runs.count += 1 }
        await eventually { clock.sleeps.count == 1 }
        check.stop()
        clock.tick()
        for _ in 0..<100 {
            await Task.yield()
        }

        #expect(runs.count == 0)
        #expect(!check.isRunning)
    }

    @Test func test_startAgain_replacesTheChecks() async {
        let clock = HandClock()
        let first = Counter()
        let second = Counter()
        let check = RepeatingRefresh(sleep: clock.sleep)

        check.start { first.count += 1 }
        await eventually { clock.sleeps.count == 1 }
        check.start { second.count += 1 }
        await eventually { clock.sleeps.count == 2 && clock.waitingCount == 1 }
        clock.tick()
        await eventually { second.count == 1 }
        for _ in 0..<100 {
            await Task.yield()
        }

        #expect(first.count == 0)
        check.stop()
    }
}
