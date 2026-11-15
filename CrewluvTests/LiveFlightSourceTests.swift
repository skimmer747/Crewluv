//
//  LiveFlightSourceTests.swift
//  CrewluvTests
//
//  When the live plane is asked for, and what's kept of each answer (Stage 3 spec §11)
//

import Foundation
import Testing
@testable import Crewluv

@MainActor
final class LiveFlightSourceTests {
    private let door = StandInPartnerDoor()
    private let keys = InMemoryDeviceKeyStore()
    private let clock = HandClock()
    private var isOnCrewluCloud = true
    private var timesSharingEnded = 0
    /// This device's clock.
    private var now = Date(timeIntervalSince1970: 1_794_600_000)

    init() {
        keys.key = Make.key
    }

    private func source() -> LiveFlightSource {
        LiveFlightSource(
            door: door, keys: keys,
            isOnCrewluCloud: { self.isOnCrewluCloud },
            endSharing: { self.timesSharingEnded += 1 },
            timer: RepeatingRefresh(interval: LiveFlightSource.interval, sleep: clock.sleep),
            now: { self.now }
        )
    }

    /// A trail point `minutes` after the test's start.
    private func point(_ minutes: Double) -> LiveFlight.TrailPoint {
        LiveFlight.TrailPoint(time: now.addingTimeInterval(minutes * 60), latitude: 38 + minutes / 10, longitude: -85, altitudeFeet: 30_000)
    }

    /// One of an answer's flights, with trail points at `minutes`. `count` is what Crewlu Cloud says the flight has in
    /// all: as many as the answer brings, unless said.
    private func flight(
        _ legID: String, state: LiveFlight.State = .airborne, points minutes: [Double] = [], count: Int? = nil, seenAt: Date? = nil
    ) -> PartnerLiveAnswer.Flight {
        let fix = state == .waiting ? nil : LiveFlight.Fix(
            latitude: 39, longitude: -85, altitudeFeet: 30_000, groundSpeedKnots: 430, trackDegrees: 80,
            isOnGround: false, registration: nil, typeCode: nil, seenAt: seenAt ?? now
        )
        return PartnerLiveAnswer.Flight(legID: legID, callsign: "UPS207", state: state, fix: fix, landedAt: nil,
                                        trail: minutes.map(point), trailCount: count ?? minutes.count)
    }

    private func answer(
        cursor: Int, _ flights: [PartnerLiveAnswer.Flight] = [], now serverNow: Date? = nil
    ) -> Result<PartnerLiveAnswer, PartnerDoorError> {
        .success(PartnerLiveAnswer(now: serverNow ?? now, cursor: cursor, flights: flights))
    }

    /// The times of a flight's trail, in minutes after the test's start.
    private func minutes(of legID: String, in source: LiveFlightSource) -> [Double]? {
        source.flights[legID]?.trail.map { $0.time.timeIntervalSince(now) / 60 }
    }

    // MARK: - Asking

    @Test func test_screenCameToFront_asksOnce_withThisDevicesKey_andNoCursor() async {
        door.liveAnswers = [answer(cursor: 0)]
        let source = source()

        await source.screenCameToFront()

        #expect(door.lives.map(\.key) == [Make.key])
        #expect(door.lives.map(\.after) == [nil])
        source.screenLeftFront()
    }

    @Test func test_ask_keepsEachFlightByItsLegsID() async {
        door.liveAnswers = [answer(cursor: 7, [flight("leg-1", points: [0, 2]), flight("leg-2", state: .waiting)])]
        let source = source()

        await source.ask()

        #expect(Set(source.flights.keys) == ["leg-1", "leg-2"])
        #expect(source.flights["leg-1"]?.callsign == "UPS207")
        #expect(source.flights["leg-1"]?.state == .airborne)
        #expect(minutes(of: "leg-1", in: source) == [0, 2])
        #expect(source.flights["leg-2"]?.state == .waiting)
        #expect(source.flights["leg-2"]?.fix == nil)
    }

    @Test func test_ask_sendsTheLastCursorBack_andAddsTheNewPoints() async {
        door.liveAnswers = [
            answer(cursor: 7, [flight("leg-1", points: [0, 2])]),
            answer(cursor: 9, [flight("leg-1", points: [4], count: 3)]),
        ]
        let source = source()

        await source.ask()
        await source.ask()

        #expect(door.lives.map(\.after) == [nil, 7])
        #expect(minutes(of: "leg-1", in: source) == [0, 2, 4])
    }

    @Test func test_ask_aTrailThatDoesntAddUp_asksAgainForEveryPoint() async {
        door.liveAnswers = [
            answer(cursor: 7, [flight("leg-1", points: [0, 2])]),
            // Two points here and one new make three, and Crewlu Cloud says the flight has four.
            answer(cursor: 9, [flight("leg-1", points: [6], count: 4)]),
            answer(cursor: 9, [flight("leg-1", points: [0, 2, 4, 6])]),
        ]
        let source = source()

        await source.ask()
        await source.ask()

        #expect(door.lives.map(\.after) == [nil, 7, nil])
        #expect(minutes(of: "leg-1", in: source) == [0, 2, 4, 6])
    }

    @Test func test_ask_aFlightFirstAnsweredAfterTheCursor_asksAgainForEveryPoint() async {
        door.liveAnswers = [
            answer(cursor: 7),
            // Its points from before the cursor didn't come.
            answer(cursor: 9, [flight("leg-1", points: [4], count: 3)]),
            answer(cursor: 9, [flight("leg-1", points: [0, 2, 4])]),
        ]
        let source = source()

        await source.ask()
        await source.ask()

        #expect(door.lives.map(\.after) == [nil, 7, nil])
        #expect(minutes(of: "leg-1", in: source) == [0, 2, 4])
    }

    @Test func test_ask_aWholeAnswer_isTakenAsItComes() async {
        // Asked without a cursor, there's nothing to ask again for.
        door.liveAnswers = [answer(cursor: 7, [flight("leg-1", points: [0, 2], count: 5)])]
        let source = source()

        await source.ask()

        #expect(door.lives.count == 1)
        #expect(minutes(of: "leg-1", in: source) == [0, 2])
    }

    @Test func test_ask_aFlightNoLongerAnswered_isForgotten() async {
        door.liveAnswers = [
            answer(cursor: 7, [flight("leg-1", points: [0]), flight("leg-2", points: [2])]),
            answer(cursor: 7, [flight("leg-1", count: 1)]),
        ]
        let source = source()

        await source.ask()
        await source.ask()

        #expect(Set(source.flights.keys) == ["leg-1"])
        #expect(minutes(of: "leg-1", in: source) == [0])
    }

    @Test func test_ask_whenCrewluCloudCantBeReached_keepsWhatItHas() async {
        door.liveAnswers = [
            answer(cursor: 7, [flight("leg-1", points: [0, 2])]),
            .failure(.unavailable),
            .failure(.refused(.tryLater)),
            answer(cursor: 9, [flight("leg-1", points: [4], count: 3)]),
        ]
        let source = source()

        await source.ask()
        await source.ask()
        await source.ask()

        #expect(minutes(of: "leg-1", in: source) == [0, 2])
        #expect(timesSharingEnded == 0)

        await source.ask()

        #expect(door.lives.map(\.after) == [nil, 7, 7, 7])
        #expect(minutes(of: "leg-1", in: source) == [0, 2, 4])
    }

    @Test func test_ask_whileOneIsUnderWay_asksNothingMore() async {
        door.liveAnswers = [answer(cursor: 7, [flight("leg-1", points: [0])])]
        door.holdsLives = true
        let source = source()

        let asking = Task { await source.ask() }
        await eventually { door.lives.count == 1 }
        // In a task of its own: a second call that did go out would wait on the door, and must fail here, not hang.
        let again = Task { await source.ask() }
        for _ in 0..<100 {
            await Task.yield()
        }

        #expect(door.lives.count == 1)
        door.release()
        await asking.value
        await again.value
        #expect(minutes(of: "leg-1", in: source) == [0])
    }

    @Test func test_ask_whenTheCallForEveryPointFails_keepsWhatItHas_andItsCursor() async {
        door.liveAnswers = [
            answer(cursor: 7, [flight("leg-1", points: [0, 2])]),
            answer(cursor: 9, [flight("leg-1", points: [6], count: 4)]),
            .failure(.unavailable),
            answer(cursor: 9, [flight("leg-1", points: [4, 6], count: 4)]),
        ]
        let source = source()

        await source.ask()
        await source.ask()

        #expect(minutes(of: "leg-1", in: source) == [0, 2])

        await source.ask()

        #expect(door.lives.map(\.after) == [nil, 7, nil, 7])
        #expect(minutes(of: "leg-1", in: source) == [0, 2, 4, 6])
    }

    // MARK: - The Connection

    @Test func test_ask_sharingEnded_forgetsTheFlights_andTellsTheStatusSource() async {
        door.liveAnswers = [answer(cursor: 7, [flight("leg-1", points: [0])]), .failure(.refused(.sharingEnded))]
        let source = source()

        await source.ask()
        await source.ask()

        #expect(source.flights.isEmpty)
        #expect(timesSharingEnded == 1)
    }

    @Test func test_ask_sharingEnded_onTheCallForEveryPoint_endsSharingToo() async {
        door.liveAnswers = [
            answer(cursor: 7, [flight("leg-1", points: [0, 2])]),
            answer(cursor: 9, [flight("leg-1", points: [6], count: 4)]),
            .failure(.refused(.sharingEnded)),
        ]
        let source = source()

        await source.ask()
        await source.ask()

        #expect(source.flights.isEmpty)
        #expect(timesSharingEnded == 1)
    }

    @Test func test_ask_sharingEnded_forAKeySinceReplaced_endsNothing() async {
        door.liveAnswers = [.failure(.refused(.sharingEnded))]
        door.holdsLives = true
        let source = source()

        let asking = Task { await source.ask() }
        await eventually { door.lives.count == 1 }
        keys.key = String(repeating: "7a", count: 32)
        door.release()
        await asking.value

        #expect(timesSharingEnded == 0)
    }

    @Test func test_ask_anAnswerForAKeySinceReplaced_isLeftOut() async {
        door.liveAnswers = [answer(cursor: 7, [flight("leg-1", points: [0])])]
        door.holdsLives = true
        let source = source()

        let asking = Task { await source.ask() }
        await eventually { door.lives.count == 1 }
        keys.key = String(repeating: "7a", count: 32)
        door.release()
        await asking.value

        #expect(source.flights.isEmpty)
    }

    @Test func test_ask_withAnotherKey_startsAgainFromNothing() async {
        door.liveAnswers = [answer(cursor: 7, [flight("leg-1", points: [0])]), answer(cursor: 3, [flight("leg-9", points: [2])])]
        let source = source()
        let other = String(repeating: "7a", count: 32)

        await source.ask()
        keys.key = other
        await source.ask()

        #expect(door.lives.map(\.key) == [Make.key, other])
        #expect(door.lives.map(\.after) == [nil, nil])
        #expect(Set(source.flights.keys) == ["leg-9"])
    }

    @Test func test_ask_withAnotherKey_forgetsTheLastKeysFlights_evenWhenCrewluCloudCantBeReached() async {
        door.liveAnswers = [answer(cursor: 7, [flight("leg-1", points: [0])]), .failure(.unavailable)]
        let source = source()

        await source.ask()
        keys.key = String(repeating: "7a", count: 32)
        await source.ask()

        #expect(source.flights.isEmpty)
    }

    @Test func test_ask_withNoKey_asksNothing() async {
        keys.key = nil
        let source = source()

        await source.ask()

        #expect(door.lives.isEmpty)
        #expect(timesSharingEnded == 0)
    }

    @Test func test_ask_onICloud_asksNothing_andForgetsTheFlights() async {
        door.liveAnswers = [answer(cursor: 7, [flight("leg-1", points: [0])])]
        let source = source()

        await source.ask()
        isOnCrewluCloud = false
        await source.ask()

        #expect(door.lives.count == 1)
        #expect(source.flights.isEmpty)
    }

    @Test func test_ask_withAKeyThatCantBeRead_asksNothing_andKeepsWhatItHas() async {
        door.liveAnswers = [answer(cursor: 7, [flight("leg-1", points: [0])])]
        let source = source()

        await source.ask()
        keys.readFails = true
        await source.ask()

        #expect(door.lives.count == 1)
        #expect(minutes(of: "leg-1", in: source) == [0])
    }

    // MARK: - Crewlu Cloud's Clock

    @Test func test_serverTime_followsCrewluCloudsClock() async {
        door.liveAnswers = [answer(cursor: 0, now: now.addingTimeInterval(90))]
        let source = source()

        #expect(source.serverTime(at: now) == now)
        await source.ask()

        #expect(source.clockOffset == 90)
        #expect(source.serverTime(at: now.addingTimeInterval(10)) == now.addingTimeInterval(100))
    }

    @Test func test_serverTime_afterASlowCall_measuresFromTheCallsMiddle() async {
        // The call takes 20 s by this device's clock, and Crewlu Cloud read its own clock somewhere inside it.
        let asked = now
        door.liveAnswers = [answer(cursor: 0, now: asked.addingTimeInterval(110))]
        door.holdsLives = true
        let source = source()

        let asking = Task { await source.ask() }
        await eventually { door.lives.count == 1 }
        now = asked.addingTimeInterval(20)
        door.release()
        await asking.value

        #expect(source.clockOffset == 100)
    }

    // MARK: - The 30-Second Check

    @Test func test_check_withAWindowOpen_asksEvery30Seconds() async {
        door.liveAnswers = [answer(cursor: 0), answer(cursor: 0), answer(cursor: 0)]
        let source = source()
        source.watch([LiveFlightSource.Leg(id: "leg-1", departure: now.addingTimeInterval(-3600), arrival: now.addingTimeInterval(3600))])

        await source.screenCameToFront()
        await eventually { clock.waitingCount == 1 }
        #expect(clock.sleeps == [.seconds(30)])
        clock.tick()
        await eventually { door.lives.count == 2 }
        await eventually { clock.waitingCount == 1 }
        clock.tick()
        await eventually { door.lives.count == 3 }

        source.screenLeftFront()
    }

    @Test func test_check_withNoWindowOpen_asksNothing() async {
        door.liveAnswers = [answer(cursor: 0), answer(cursor: 0)]
        let source = source()
        source.watch([LiveFlightSource.Leg(id: "leg-1", departure: now.addingTimeInterval(2 * 3600), arrival: now.addingTimeInterval(4 * 3600))])

        await source.screenCameToFront()
        await eventually { clock.waitingCount == 1 }
        clock.tick()
        // The check has run and gone back to sleep.
        await eventually { clock.sleeps.count == 2 }

        #expect(door.lives.count == 1)
        source.screenLeftFront()
    }

    @Test func test_check_pastTheWindow_whileTheFlightIsStillSeenInTheAir_keepsAsking() async {
        let seenAt = now.addingTimeInterval(-5 * 60)
        door.liveAnswers = [answer(cursor: 0, [flight("leg-1", seenAt: seenAt)]), answer(cursor: 0, [flight("leg-1", seenAt: seenAt)])]
        let source = source()
        source.watch([LiveFlightSource.Leg(id: "leg-1", departure: now.addingTimeInterval(-11 * 3600), arrival: now.addingTimeInterval(-3 * 3600))])

        await source.screenCameToFront()
        await eventually { clock.waitingCount == 1 }
        clock.tick()
        await eventually { door.lives.count == 2 }

        source.screenLeftFront()
    }

    @Test func test_check_measuresTheWindowByCrewluCloudsClock() async {
        // This device's clock is two hours slow: by it, the flight's window hasn't opened.
        door.liveAnswers = [answer(cursor: 0, now: now.addingTimeInterval(2 * 3600)), answer(cursor: 0, now: now.addingTimeInterval(2 * 3600))]
        let source = source()
        source.watch([LiveFlightSource.Leg(id: "leg-1", departure: now.addingTimeInterval(3600), arrival: now.addingTimeInterval(5 * 3600))])

        await source.screenCameToFront()
        await eventually { clock.waitingCount == 1 }
        clock.tick()
        await eventually { door.lives.count == 2 }

        source.screenLeftFront()
    }

    @Test func test_screenCameToFront_twice_leavesOneCheckRunning() async {
        door.liveAnswers = [answer(cursor: 0), answer(cursor: 0)]
        let source = source()

        await source.screenCameToFront()
        await eventually { clock.waitingCount == 1 }
        await source.screenCameToFront()
        await eventually { clock.sleeps.count == 2 }
        await eventually { clock.waitingCount == 1 }

        #expect(door.lives.count == 2)
        source.screenLeftFront()
    }

    @Test func test_aSourceLetGo_takesItsCheckWithIt() async {
        door.liveAnswers = [answer(cursor: 0)]
        var source: LiveFlightSource? = source()

        await source?.screenCameToFront()
        await eventually { clock.waitingCount == 1 }
        source = nil
        await eventually { clock.waitingCount == 0 }

        #expect(clock.sleeps.count == 1)
    }

    @Test func test_screenLeftFront_stopsTheCheck() async {
        door.liveAnswers = [answer(cursor: 0)]
        let source = source()
        source.watch([LiveFlightSource.Leg(id: "leg-1", departure: now.addingTimeInterval(-3600), arrival: now.addingTimeInterval(3600))])

        await source.screenCameToFront()
        await eventually { clock.waitingCount == 1 }
        source.screenLeftFront()
        await eventually { clock.waitingCount == 0 }

        #expect(door.lives.count == 1)
    }
}
