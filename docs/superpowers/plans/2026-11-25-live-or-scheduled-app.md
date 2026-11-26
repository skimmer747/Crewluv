# Live or Scheduled, Said Everywhere: the App's Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every word on the app's trip map, the map card and the status sentence says whether a flight is tracked live or shown by the schedule, and a plane on the ground at its departure airport never reads as flying, in the website's words.

**Architecture:** As the website's (merged in crewluve-web PR #6, commit `ea13c4d`): one rule on `MapLeg`, `tracking(at:)` (`FlightTracking`: live, best guess, not tracked, waiting) and `atDeparture(at:)` (`AtDeparture`: due, at the gate, still at the gate, returned), read by the pill, the card's bar, the VoiceOver sentences, the timeline's line, the facts and the list. The status sentence reads one value, `NarrativeFlight`, worked out in `LiveLegs` from the same `MapFlight` phases, in place of the three Booleans it has today. `LiveFlightSource.hasAnswered` gives the wait for the first answer.

**Tech Stack:** Swift 6 language mode features, SwiftUI, Observation, XCTest and Swift Testing. The app builds with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`: logic types are `nonisolated`, and an extension of one is `nonisolated extension`.

**Spec:** `docs/superpowers/specs/2026-11-25-crewluve-live-or-scheduled-design.md` (§ numbers below are its). The website's code is the reference for every word: `../Crewluve Website/src/map/flightTracking.ts`, `src/copy/tripMap.ts`, `src/facts/tripFacts.ts`, `src/facts/tripFactsRows.ts`, `src/copy/narrative.ts`.

**Rules for whoever builds this (Todd's standing rules):**
- **No `xcodebuild`** builds or test runs. Todd runs the tests in Xcode. One type-check of the whole app target with `swiftc` is allowed at the end (Task 9), as `memory/reference_typecheck_outside_xcode.md` describes.
- **No commits, staging or branch switches** until Todd says. Task 0 makes the branch.
- None of the files below is one of the alerts helper's 16 (`CrewluveAlerts` target): keep it so.
- One primary type per file; new files go in the folders named (the project uses synchronized folders, so a new `.swift` file joins the target by itself).

---

## File map

| File | What changes |
|---|---|
| `Crewluv/Services/TripMap/FlightProgress.swift` | `scheduledTakeoff(departure:arrival:)` |
| `Crewluv/Services/TripMap/Live/MapFlight.swift` | `seenAtDeparture(at:)`, `isNotLive(at:)`; `isAtDeparture(at:)` built on it |
| `Crewluv/Services/TripMap/FlightTracking.swift` (new) | `FlightTracking` |
| `Crewluv/Services/TripMap/AtDeparture.swift` (new) | `AtDeparture` |
| `Crewluv/Services/TripMap/MapLeg.swift` | `isAwaitingLive`; `isStillOnGround(at:)` and `hasReturned(at:)` go (Task 6) |
| `Crewluv/Services/TripMap/MapLeg+Tracking.swift` (new) | `scheduledTakeoff`, `tracking(at:)`, `atDeparture(at:)` |
| `Crewluv/Services/TripMap/TripMap.swift`, `TripMap+Status.swift` | `isAwaitingLive` passed through |
| `Crewluv/Services/TripMap/Live/LiveFlightSource.swift` | `hasAnswered` |
| `Crewluv/Services/PartnerStatusReceiver.swift` | `isAwaitingLive`; `narrativeFlight` in place of `isStillOnGround`, `hasReturned`, `isLandedBeforeGate` |
| `Crewluv/Services/TripMap/TripMapWording.swift` | the words: constants, `flightStatus`, `topPill`, `liveSummary`, `spokenSource`, `spokenDueClause`, `cardSummary`, the timeline's words |
| `Crewluv/Services/TripMap/FlightOnGround.swift` → `FlightNow.swift` | renamed, with `dueTo` and `shouldBeFlyingTo` |
| `Crewluv/Services/TripMap/TripMap+Activity.swift` | `flightNow(at:)` in place of `flightOnGround(at:)` and `stillOnGroundAirport(at:)` |
| `Crewluv/Services/TripMap/Facts/FactsWording.swift`, `FactRow.swift` | `onTheGround(in:)`, `scheduledTakeoff(at:)`, `notTrackedLines`; the `source` kind |
| `Crewluv/Services/TripMap/Facts/TripFacts.swift`, `TripFacts+Rows.swift` | the facts and the list, by the new rule |
| `Crewluv/Services/TripMap/PlanePopupWords.swift` | shares `TripMapWording.mayBeAtGate` |
| `Crewluv/Services/TripMap/Live/LiveLegs.swift` | `narrativeFlight(in:flights:at:isAwaitingLive:)` in place of `stillOnGroundFlight` and `landedFlight` |
| `Crewluv/Services/TripMap/Live/NarrativeFlight.swift` (new) | `NarrativeFlight` |
| `Crewluv/Views/Status/NarrativeCardView.swift`, `PilotStatusView.swift`, `Crewluv/Views/Welcome/ContentView.swift` | `narrativeFlight`, `isAwaitingLive` |
| `Crewluv/Views/TripMap/TripMapInFlightBar.swift`, `TripTimelineControl.swift`, `FactsPanel.swift`, `FactsSheet.swift` | an empty status shows nothing; `flight:` in place of `onGround:` |
| Tests (new) | `CrewluvTests/FlightTrackingTests.swift`, `LiveOrScheduledWordsTests.swift`, `LiveOrScheduledFactsTests.swift`, `NarrativeFlightTests.swift`; additions to `LiveFlightSourceTests.swift` |
| Tests (changed, Task 8) | `AirReturnTests`, `AirReturnWordsTests`, `FactsWordingTests`, `LandedBeforeGateFactsTests`, `LandedBeforeGateTests`, `LiveTripFactsTests`, `LiveWordingTests`, `StillOnGroundFactsTests`, `StillOnGroundTests`, `TripFactsTests`, `TripMapWordingTests`, and any other the type-check or Todd's run turns up |

The tests use the shared live cases (`TripMapFixtures.liveCases()`), whose flights all leave Louisville at 12:00 UTC on 13 Nov 2026 for Philadelphia at 13:45, so the schedule's (and the plan's) takeoff is 12:15. `cases.mapLeg(_:at:)` gives a leg whose airports have no city, so they read by code: "SDF", "PHL". The moments used:

| Case | Moment | State |
|---|---|---|
| `on the ground before the plan's takeoff` | `13T12:10:00` | live, at the gate |
| same | `13T12:13:00` | not tracked (ground fix 3.5 min old), due |
| `still on the ground twenty minutes after` | `13T12:35:00` | live, still at the gate |
| `an air return, back on the ground` | `13T12:41:00` | live, returned |
| same | `13T12:43:01` | not tracked, after takeoff |
| `ahead, in the air` | `13T12:41:50` | live in the air, "14 min ahead" |
| same | `13T12:45:00` | best guess, "About 14 min ahead" |
| `landed, seen all the way` | `13T13:30:00` | live, landed |
| `on the ground somewhere else` | `13T13:21:00` | live, no label |
| `no live data` | `13T12:30:00` | not tracked, after takeoff (and `leg.start + 5 min` for due) |

---

### Task 0: Branch

- [ ] **Step 1:** `cd /Users/toddanderson/Dev/Crewluv && git checkout main && git pull --ff-only && git checkout -b fix/live-or-scheduled`. The uncommitted spec, this plan and `.claude/launch.json` come along untouched.

---

### Task 1: How a flight is known, and on the ground at departure (§2, §3)

**Files:** `FlightProgress.swift`, `Live/MapFlight.swift`, new `FlightTracking.swift`, `AtDeparture.swift`, `MapLeg+Tracking.swift`, `MapLeg.swift`, `TripMap.swift`, `TripMap+Status.swift`; test `CrewluvTests/FlightTrackingTests.swift`.

- [ ] **Step 1: Write the failing tests.** Create `CrewluvTests/FlightTrackingTests.swift`:

```swift
//
//  FlightTrackingTests.swift
//  CrewluvTests
//
//  How the flight between its gates is known now, and whether it's on the ground at its departure airport (live or
//  scheduled design §2, §3), held to the shared live cases.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class FlightTrackingTests: XCTestCase {

    /// A shared case's flight at its moment `time`, as a leg of the map, and that moment.
    private func leg(_ name: String, at time: String) throws -> (leg: MapLeg, at: Date) {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: name)
        let moment = try cases.moment(time, of: flightCase)
        return (try cases.mapLeg(flightCase, at: moment), moment.at)
    }

    /// `leg` while Crewlu Cloud's first answer is on its way.
    private func awaiting(_ leg: MapLeg) -> MapLeg {
        MapLeg(id: leg.id, kind: leg.kind, origin: leg.origin, destination: leg.destination, start: leg.start, end: leg.end,
               flightNumber: leg.flightNumber, flight: leg.flight, isAwaitingLive: true)
    }

    // MARK: - How it's known (§2)

    func test_tracking_isLive_whileCrewluCloudSawThePlaneInTheLastThreeMinutes() throws {
        for (name, time) in [("on the ground before the plan's takeoff", "13T12:10:00"), ("ahead, in the air", "13T12:41:50"),
                             ("still on the ground twenty minutes after", "13T12:35:00"),
                             ("an air return, back on the ground", "13T12:41:00"), ("landed, seen all the way", "13T13:30:00"),
                             ("on the ground somewhere else", "13T13:21:00")] {
            let (leg, at) = try leg(name, at: time)
            XCTAssertEqual(leg.tracking(at: at), .live, name)
        }
    }

    func test_tracking_isABestGuess_onceAPlaneLastSeenInTheAirHasntBeenForOverThreeMinutes() throws {
        let (leg, at) = try leg("ahead, in the air", at: "13T12:45:00")
        XCTAssertEqual(leg.tracking(at: at), .bestGuess)
    }

    func test_tracking_isNotTracked_withNoLiveData_orAGroundFixOverThreeMinutesOld() throws {
        for (name, time) in [("no live data", "13T12:30:00"), ("on the ground before the plan's takeoff", "13T12:13:00"),
                             ("an air return, back on the ground", "13T12:43:01")] {
            let (leg, at) = try leg(name, at: time)
            XCTAssertEqual(leg.tracking(at: at), .notTracked, name)
        }
    }

    func test_tracking_isWaiting_whileTheFirstAnswerIsOnItsWay_andEitherIsByTheSchedule() throws {
        let (leg, at) = try leg("no live data", at: "13T12:30:00")
        XCTAssertEqual(awaiting(leg).tracking(at: at), .waiting)
        XCTAssertTrue(FlightTracking.waiting.isBySchedule)
        XCTAssertTrue(FlightTracking.notTracked.isBySchedule)
        XCTAssertFalse(FlightTracking.live.isBySchedule)
        XCTAssertFalse(FlightTracking.bestGuess.isBySchedule)
    }

    func test_make_marksOnlyAFlightCrewluCloudHasntAnsweredFor_asWaiting() throws {
        let cases = try TripMapFixtures.liveCases()
        let noLive = try cases.flight(named: "no live data")
        let ahead = try cases.flight(named: "ahead, in the air")
        let at = try cases.moment("13T12:30:00", of: noLive).at
        func map(flights: [String: MapFlight]) -> TripMap? {
            TripMap.make(tripLegs: [cases.tripLeg(noLive)], isNextTrip: false, homeAirportCode: "SDF", legacyDelayMinutes: nil,
                         flights: flights, isAwaitingLive: true, at: at, coordinate: cases.coordinateOrNil)
        }
        XCTAssertEqual(map(flights: [:])?.legs.first?.isAwaitingLive, true)
        XCTAssertEqual(map(flights: ["f1": try cases.mapFlight(ahead)])?.legs.first?.isAwaitingLive, false)
    }

    // MARK: - On the ground at departure (§3)

    func test_atDeparture_isDue_byTheScheduleAlone_untilTheSchedulesTakeoff() throws {
        let (leg, _) = try leg("no live data", at: "13T12:30:00")
        XCTAssertEqual(leg.scheduledTakeoff, leg.start.addingTimeInterval(15 * 60))
        XCTAssertEqual(leg.atDeparture(at: leg.start.addingTimeInterval(5 * 60)), .due)
        XCTAssertEqual(awaiting(leg).atDeparture(at: leg.start.addingTimeInterval(14 * 60)), .due)
        XCTAssertNil(leg.atDeparture(at: leg.scheduledTakeoff))
        // A fix on the ground gone stale is the schedule's again.
        let stale = try self.leg("on the ground before the plan's takeoff", at: "13T12:13:00")
        XCTAssertEqual(stale.leg.atDeparture(at: stale.at), .due)
    }

    func test_atDeparture_isTheRealPlaneAtItsGate_stillThere_orBackAfterAnAirReturn() throws {
        let atGate = try leg("on the ground before the plan's takeoff", at: "13T12:10:00")
        XCTAssertEqual(atGate.leg.atDeparture(at: atGate.at), .atGate)
        let late = try leg("still on the ground twenty minutes after", at: "13T12:35:00")
        XCTAssertEqual(late.leg.atDeparture(at: late.at), .stillAtGate)
        let back = try leg("an air return, back on the ground", at: "13T12:41:00")
        XCTAssertEqual(back.leg.atDeparture(at: back.at), .returned)
        XCTAssertTrue(AtDeparture.atGate.isSeen)
        XCTAssertTrue(AtDeparture.stillAtGate.isSeen)
        XCTAssertTrue(AtDeparture.returned.isSeen)
        XCTAssertFalse(AtDeparture.due.isSeen)
    }

    func test_atDeparture_isNil_inTheAir_outOfSight_landed_orByTheScheduleAfterItsTakeoff() throws {
        for (name, time) in [("ahead, in the air", "13T12:41:50"), ("ahead, in the air", "13T12:45:00"),
                             ("landed, seen all the way", "13T13:30:00"), ("no live data", "13T12:30:00"),
                             ("an air return, back on the ground", "13T12:43:01")] {
            let (leg, at) = try leg(name, at: time)
            XCTAssertNil(leg.atDeparture(at: at), "\(name) at \(time)")
        }
        let (leg, _) = try leg("no live data", at: "13T12:30:00")
        XCTAssertNil(leg.atDeparture(at: leg.start.addingTimeInterval(-60)), "before its gate time")
    }

    func test_atDeparture_aBlockTooShortForTheTaxiAllowances_takesOffAtTheGate() throws {
        let (long, _) = try leg("no live data", at: "13T12:30:00")
        let short = MapLeg(id: long.id, kind: .flight, origin: long.origin, destination: long.destination, start: long.start,
                           end: long.start.addingTimeInterval(20 * 60), flightNumber: long.flightNumber)
        XCTAssertEqual(short.scheduledTakeoff, short.start)
        XCTAssertNil(short.atDeparture(at: short.start.addingTimeInterval(5 * 60)))
    }

    func test_seenAtDeparture_agreesWithIsAtDeparture_andHasReturned() throws {
        for (name, time) in [("on the ground before the plan's takeoff", "13T12:10:00"),
                             ("still on the ground twenty minutes after", "13T12:35:00"),
                             ("an air return, back on the ground", "13T12:41:00"), ("ahead, in the air", "13T12:41:50")] {
            let (leg, at) = try leg(name, at: time)
            let flight = try XCTUnwrap(leg.flight)
            let seen = flight.seenAtDeparture(at: at)
            XCTAssertEqual(flight.isAtDeparture(at: at), seen == .stillAtGate || seen == .returned, name)
            XCTAssertEqual(flight.hasReturned(at: at), seen == .returned, name)
        }
    }
}
```

Todd runs it later; for now the type-check in Task 9 shows it compiles. (No `xcodebuild` here.)

- [ ] **Step 2: The schedule's takeoff.** In `FlightProgress.swift`, after `airborneWindow`:

```swift
    /// When the schedule's plane takes off for a flight that leaves the gate at `departure` and reaches it at
    /// `arrival` (both moved by any delay): the start of its time in the air, or the gate departure for a flight with
    /// none (live or scheduled design §3).
    static func scheduledTakeoff(departure: Date, arrival: Date) -> Date {
        airborneWindow(departure: departure, arrival: arrival)?.start ?? departure
    }
```

- [ ] **Step 3: The two enums.** Create `Crewluv/Services/TripMap/AtDeparture.swift`:

```swift
//
//  AtDeparture.swift
//  CrewLuve
//
//  How a flight on the ground at its departure airport is told (live or scheduled design §3, §4.2).
//

nonisolated enum AtDeparture: Equatable, Sendable {
    /// Known by the schedule alone, before the schedule's takeoff: "Scheduled to take off about 3:14 PM L".
    case due
    /// Its real plane seen there before the plan's takeoff: "On the ground in Louisville".
    case atGate
    /// Seen there after it: "Still on the ground in Louisville" (which plane design §4).
    case stillAtGate
    /// Back there after an air return: "Returned to Rockford" (air return design §3).
    case returned

    /// Whether it's the real plane seen at its departure airport, not the schedule's: the list leaves it out until it
    /// takes off.
    var isSeen: Bool { self != .due }
}
```

and `Crewluv/Services/TripMap/FlightTracking.swift`:

```swift
//
//  FlightTracking.swift
//  CrewLuve
//
//  How the flight between its gates is known now (live or scheduled design §2), as the website's FlightTracking.
//

nonisolated enum FlightTracking: Equatable, Sendable {
    /// Crewlu Cloud saw the plane in the last 3 minutes: at its gate, in the air, landed or down somewhere else.
    case live
    /// Last seen in the air over 3 minutes ago: the faded plane.
    case bestGuess
    /// No live data, never seen, or seen on the ground over 3 minutes ago: the schedule's plane alone.
    case notTracked
    /// No live data yet: Crewlu Cloud hasn't answered since the status screen came up. It reads as `notTracked`, but
    /// the pill, the card's bar and the facts say nothing of where it comes from, so nothing flips from "Not tracked
    /// live" to "Live" in the first second. Hedged words ("Should be flying", "By the schedule", "about") still show:
    /// they're true either way.
    case waiting

    /// Whether the flight is known by the schedule alone: not tracked live, or waiting to hear.
    var isBySchedule: Bool { self == .notTracked || self == .waiting }
}
```

- [ ] **Step 4: One place reads the phase at departure.** In `Live/MapFlight.swift`, replace `isAtDeparture(at:)` with these three, and add `isNotLive(at:)` after `hasReturned(at:)`:

```swift
    /// Where the real plane is on the ground at its departure airport, when this device's clock says `now` (live or
    /// scheduled design §3): at its gate before the plan's takeoff, `atGate`; still there after it, `stillAtGate`; or
    /// back there after an air return, `returned`. Nil anywhere else, and when it isn't live.
    func seenAtDeparture(at now: Date) -> AtDeparture? {
        let progress = self.progress(at: now)
        switch progress.phase {
        case .returned: return .returned
        case .onGround:
            if case .stillOnGround = progress.label { return .stillAtGate }
            return .atGate
        default: return nil
        }
    }

    /// Whether the real plane is still on the ground at its departure airport after the plan's takeoff time, or back
    /// there after an air return, when this device's clock says `now` (which plane design §4, air return design §3).
    func isAtDeparture(at now: Date) -> Bool {
        let seen = seenAtDeparture(at: now)
        return seen == .stillAtGate || seen == .returned
    }
```

```swift
    /// Whether Crewlu Cloud's answer says nothing of the plane now, when this device's clock says `now`: never seen,
    /// or seen on the ground over 3 minutes ago (Stage 3 spec §5.1's `notLive`). The flight is then known by the
    /// schedule alone (live or scheduled design §2).
    func isNotLive(at now: Date) -> Bool {
        progress(at: now).phase == .notLive
    }
```

- [ ] **Step 5: A leg can wait for the first answer.** In `MapLeg.swift`, add after `flight`:

```swift
    /// The flight has no live data yet because Crewlu Cloud hasn't answered since the status screen came up (live or
    /// scheduled design §2). Set only on a flight with no answer of its own.
    let isAwaitingLive: Bool
```

add `isAwaitingLive: Bool = false` as the init's last parameter, and `self.isAwaitingLive = isAwaitingLive`.

- [ ] **Step 6: The rule.** Create `Crewluv/Services/TripMap/MapLeg+Tracking.swift`:

```swift
//
//  MapLeg+Tracking.swift
//  CrewLuve
//
//  How the flight between its gates is known now, and whether it's on the ground at its departure airport (live or
//  scheduled design §2, §3), as the website's flightTracking.ts. Every word that says where a flight comes from reads
//  these. Now only: a replay's moment shows the plane the map draws.
//

import Foundation

nonisolated extension MapLeg {

    /// When the schedule's plane takes off: the gate departure plus the taxi allowance (`FlightProgress`).
    var scheduledTakeoff: Date {
        FlightProgress.scheduledTakeoff(departure: start, arrival: end)
    }

    /// How the flight is known at `date` (live or scheduled design §2).
    func tracking(at date: Date) -> FlightTracking {
        guard let flight, flight.live != nil else { return isAwaitingLive ? .waiting : .notTracked }
        switch flight.progress(at: date).phase {
        case .notLive: return .notTracked
        case .estimated: return .bestGuess
        case .onGround, .returned, .inAir, .landed, .elsewhere: return .live
        }
    }

    /// Whether the flight, between its gates at `date`, is on the ground at its departure airport, and how that's
    /// told (live or scheduled design §3). Nil in the air, out of sight, down, outside its gate times, and for a drive.
    /// A plane on the ground at departure never reads "Over …", "In the air now" or "Flying into the night", and has
    /// passed nothing yet.
    func atDeparture(at date: Date) -> AtDeparture? {
        guard kind == .flight, isMoving(at: date) else { return nil }
        let isDue = date < scheduledTakeoff
        guard let flight, !flight.isNotLive(at: date) else { return isDue ? .due : nil }
        return flight.seenAtDeparture(at: date)
    }
}
```

List `LiveProgress.Phase`'s cases in `tracking(at:)` exactly as they're declared: if one is named differently, use its name; don't add a `default`.

- [ ] **Step 7: Pass the wait through the map.** In `TripMap.swift`, add `isAwaitingLive: Bool = false` to `make(...)` right after `flights:`, with a line in its doc list (`` - `isAwaitingLive`: Crewlu Cloud hasn't answered since the screen came up (live or scheduled design §2). ``), pass it to `mapLeg(for:…)`, and there:

```swift
        // A flight with no live data has the schedule's plan and the great circle, and waits for the first answer.
        let answered = kind == .flight ? flights[leg.id] : nil
        let flight = kind == .flight
            ? answered ?? MapFlight(departure: start, arrival: end, from: originCoordinate, to: destinationCoordinate)
            : nil
```

and `isAwaitingLive: kind == .flight && answered == nil && isAwaitingLive` in the `MapLeg(…)` call. In `TripMap+Status.swift`, `init?(status:flights:isAwaitingLive: Bool = false, at:)`, passing it to `make`.

---

### Task 2: The first answer (§2)

**Files:** `Live/LiveFlightSource.swift`, `PartnerStatusReceiver.swift`, `Views/Status/PilotStatusView.swift`, `Views/Welcome/ContentView.swift`; test `CrewluvTests/LiveFlightSourceTests.swift`.

- [ ] **Step 1: The failing tests.** Add to `LiveFlightSourceTests` (Swift Testing, `@MainActor`):

```swift
    // MARK: - The first answer (live or scheduled design §2)

    @Test func test_hasAnswered_isFalseUntilTheFirstCallSettles_thenTrue_evenWithNoFlights() async {
        door.liveAnswers = [answer(cursor: 0)]
        let source = source()
        #expect(!source.hasAnswered)

        await source.ask()

        #expect(source.hasAnswered)
        #expect(source.flights.isEmpty)
    }

    @Test func test_hasAnswered_isTrue_afterACallThatFails() async {
        door.liveAnswers = [.failure(.unavailable)]
        let source = source()

        await source.ask()

        #expect(source.hasAnswered)
    }

    @Test func test_hasAnswered_isTrue_offCrewluCloud_withNothingAsked() async {
        isOnCrewluCloud = false
        let source = source()

        await source.ask()

        #expect(source.hasAnswered)
        #expect(door.lives.isEmpty)
    }
```

- [ ] **Step 2: Keep it.** In `LiveFlightSource.swift`, after `flights`:

```swift
    /// Crewlu Cloud has answered since the source was made, a call to it failed, or this device isn't on Crewlu Cloud
    /// (live or scheduled design §2). Until then a flight with no live data may yet have some, and the screen says
    /// nothing of where it comes from. Once true it stays true, a new connection's included.
    private(set) var hasAnswered = false
```

and in `ask()`, the call's task becomes:

```swift
        let call = Task { [weak self] in
            await self?.askCrewluCloud()
            self?.asking = nil
            // The first answer is told even when it brings no flights: the screen waits for it.
            if self?.hasAnswered == false { self?.hasAnswered = true }
        }
```

- [ ] **Step 3: The screen's model says when it's waiting.** In `PartnerStatusReceiver.swift`, after `isLandedBeforeGate`:

```swift
    /// Crewlu Cloud hasn't answered since this screen came up: nothing yet says where a flight comes from (live or
    /// scheduled design §2). Never on iCloud, which has no live plane, nor in the demo.
    var isAwaitingLive: Bool {
        statusSource.isOnCrewluCloud && !isInDemoMode && !liveSource.hasAnswered
    }
```

and in `followLiveFlights()`, read both: `_ = liveSource.flights` and `_ = liveSource.hasAnswered`, so the first answer resolves again even when it brings nothing.

- [ ] **Step 4: Hand it to the map.** `PilotStatusView` gains `var isAwaitingLive = false` (doc: "Crewlu Cloud hasn't answered since the screen came up, from the screen's model (live or scheduled design §2)"), and its trip map line becomes `TripMap(status: status, flights: flights, isAwaitingLive: isAwaitingLive, at: Date())`. Both `PilotStatusView(…)` calls in `ContentView.swift` pass `isAwaitingLive: receiver.isAwaitingLive` after `estimatedArrival:`.

---

### Task 3: The pill and the card's bar (§4.1, §4.2, §6)

**Files:** `TripMapWording.swift`, `Views/TripMap/TripMapInFlightBar.swift`; test `CrewluvTests/LiveOrScheduledWordsTests.swift` (new).

- [ ] **Step 1: The failing tests.** Create `CrewluvTests/LiveOrScheduledWordsTests.swift`:

```swift
//
//  LiveOrScheduledWordsTests.swift
//  CrewluvTests
//
//  The pill, the card's bar, the VoiceOver sentences and the line under the timeline say whether a flight is tracked
//  live or shown by the schedule (live or scheduled design §4, §6, §7), in US English for a family in Louisville.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class LiveOrScheduledWordsTests: XCTestCase {

    private let locale = Locale(identifier: "en_US")
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private func plain(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{202F}", with: " ")
    }

    private func leg(_ name: String, at time: String) throws -> (leg: MapLeg, at: Date) {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: name)
        let moment = try cases.moment(time, of: flightCase)
        return (try cases.mapLeg(flightCase, at: moment), moment.at)
    }

    /// `leg` while Crewlu Cloud's first answer is on its way, with another flight number if it's given.
    private func awaiting(_ leg: MapLeg, flightNumber: String?? = .none) -> MapLeg {
        MapLeg(id: leg.id, kind: leg.kind, origin: leg.origin, destination: leg.destination, start: leg.start, end: leg.end,
               flightNumber: flightNumber ?? leg.flightNumber, flight: leg.flight, isAwaitingLive: true)
    }

    private func map(of leg: MapLeg) -> TripMap {
        TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: leg.origin,
                span: DateInterval(start: leg.start, end: leg.end), tripDays: nil)
    }

    // MARK: - The bar and the pill (§4.1, §6)

    func test_flightStatus_seenLive_saysLiveBeforeTheLabel_orLiveAlone() throws {
        let ahead = try leg("ahead, in the air", at: "13T12:41:50")
        XCTAssertEqual(TripMapWording.flightStatus(for: ahead.leg, at: ahead.at), "Live · 14 min ahead")
        let late = try leg("still on the ground twenty minutes after", at: "13T12:35:00")
        XCTAssertEqual(TripMapWording.flightStatus(for: late.leg, at: late.at), "Live · Still on the ground · 20 min behind")
        let back = try leg("an air return, back on the ground", at: "13T12:41:00")
        XCTAssertEqual(TripMapWording.flightStatus(for: back.leg, at: back.at), "Live · Returned to SDF")
        let elsewhere = try leg("on the ground somewhere else", at: "13T13:21:00")
        XCTAssertEqual(TripMapWording.flightStatus(for: elsewhere.leg, at: elsewhere.at), "Live")
        let atGate = try leg("on the ground before the plan's takeoff", at: "13T12:10:00")
        XCTAssertEqual(TripMapWording.flightStatus(for: atGate.leg, at: atGate.at), "Live")
    }

    func test_flightStatus_aBestGuess_isItsLabelAlone() throws {
        let (leg, at) = try leg("ahead, in the air", at: "13T12:45:00")
        XCTAssertEqual(TripMapWording.flightStatus(for: leg, at: at), "About 14 min ahead")
    }

    func test_flightStatus_byTheScheduleAlone_isNotTrackedLive_andNothingWhileWaiting() throws {
        let (leg, at) = try leg("no live data", at: "13T12:30:00")
        XCTAssertEqual(TripMapWording.flightStatus(for: leg, at: at), "Not tracked live")
        XCTAssertEqual(TripMapWording.flightStatus(for: awaiting(leg), at: at), "")
    }

    func test_flightStatus_inAReplay_isInFlightWithARealPath_elseByTheSchedule() throws {
        let ahead = try leg("ahead, in the air", at: "13T12:41:50")
        XCTAssertEqual(TripMapWording.flightStatus(for: ahead.leg, at: ahead.at, isReplay: true), "In flight")
        let noLive = try leg("no live data", at: "13T12:30:00")
        XCTAssertEqual(TripMapWording.flightStatus(for: noLive.leg, at: noLive.at, isReplay: true), "By the schedule")
    }

    func test_topPill_putsTheWordsAfterTheFlightNumber_orTheFlightAloneWhileWaiting() throws {
        let ahead = try leg("ahead, in the air", at: "13T12:41:50")
        XCTAssertEqual(TripMapWording.topPill(for: map(of: ahead.leg), at: ahead.at, dayNumber: 1, totalDays: 2),
                       "UPS207 · Live · 14 min ahead")
        let (noLive, at) = try leg("no live data", at: "13T12:30:00")
        XCTAssertEqual(TripMapWording.topPill(for: map(of: noLive), at: at, dayNumber: 1, totalDays: 2), "UPS207 · Not tracked live")
        XCTAssertEqual(TripMapWording.topPill(for: map(of: noLive), at: at, dayNumber: 1, totalDays: 2, isReplay: true),
                       "UPS207 · By the schedule")
        XCTAssertEqual(TripMapWording.topPill(for: map(of: awaiting(noLive)), at: at, dayNumber: 1, totalDays: 2), "UPS207")
        XCTAssertEqual(TripMapWording.topPill(for: map(of: awaiting(noLive, flightNumber: .some(nil))), at: at, dayNumber: 1,
                                              totalDays: 2), "Flight to PHL")
    }
}
```

- [ ] **Step 2: The words.** In `TripMapWording.swift`, add a section before `// MARK: - The real plane`:

```swift
    // MARK: - Live or scheduled (live or scheduled design §4.1)

    /// A flight known by the schedule alone: the pill, the card's bar and the facts' first row.
    static let notTrackedLive = "Not tracked live"
    /// The facts' first row for a flight Crewlu Cloud sees now.
    static let trackedLive = "Tracked live"
    /// The list's tag for a flight known by the schedule alone, and a replay's pill for one with no real path (§6).
    static let byTheSchedule = "By the schedule"
    /// Why the schedule's plane may not be where it's drawn, in the facts' first row and the schedule plane's popup
    /// (which plane design §3).
    static let mayBeAtGate = "If it's running late, it may still be at the gate"
```

Replace `flightStatus(for:at:isReplay:)` and its doc:

```swift
    /// What the card's bar and the full-screen pill say of a flight between its gates (Stage 3 spec §9, live or
    /// scheduled design §4.1): how it's known, then the real plane's label.
    /// - Seen now, "Live · 12 min ahead", or "Live" alone with no label; back at its departure airport after an air
    ///   return, "Live · Returned to Rockford" (air return design §3).
    /// - A best guess, its label alone, "About 12 min ahead", or "In flight" with no label.
    /// - By the schedule alone, "Not tracked live", and nothing while Crewlu Cloud's first answer is on its way.
    /// - A moment of the replay is "In flight" for a flight with a real path, and "By the schedule" for one without (§6).
    /// - Parameter now: the moment, by this device's clock.
    static func flightStatus(for leg: MapLeg, at now: Date, isReplay: Bool = false) -> String {
        if isReplay { return leg.flight?.path.isReal == true ? "In flight" : byTheSchedule }
        let words = leg.flight?.progress(at: now).label.map { $0 == .returned ? FactsWording.returned(to: leg.origin) : liveLabel($0) }
        switch leg.tracking(at: now) {
        case .live: return words.map { "Live · \($0)" } ?? "Live"
        case .bestGuess: return words ?? "In flight"
        case .notTracked: return notTrackedLive
        case .waiting: return ""
        }
    }
```

In `topPill`, the flight case:

```swift
            case .flight:
                // While Crewlu Cloud's first answer is on its way the status is empty: the flight number alone, or
                // where it's going.
                let words = [leg.flightNumber, flightStatus(for: leg, at: date, isReplay: isReplay)]
                    .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
                return words.isEmpty ? "Flight to \(leg.destination.name)" : words
```

and its doc's examples: `"UPS207 · Live · 12 min ahead", "UPS207 · Not tracked live"`, `- Parameter isReplay: … a flight is "In flight" with a real path, else "By the schedule"`.

- [ ] **Step 3: The bar shows nothing while waiting.** In `TripMapInFlightBar.swift`, the `status` doc becomes `/// "Live · 12 min ahead", "Not tracked live", or empty while the first answer is on its way (\`TripMapWording.flightStatus\`).` and the `Text(status)` is shown only `if !status.isEmpty`.

---

### Task 4: The VoiceOver sentences (§7)

**Files:** `TripMapWording.swift`, `Facts/TripFacts.swift`; test `LiveOrScheduledWordsTests.swift`.

- [ ] **Step 1: The failing tests.** Add to `LiveOrScheduledWordsTests`:

```swift
    // MARK: - The card's VoiceOver sentence (§7)

    func test_cardSummary_withARealPlane_endsTrackedLive() throws {
        let (leg, at) = try leg("ahead, in the air", at: "13T12:41:50")
        let sentence = plain(TripMapWording.cardSummary(for: map(of: leg), now: at, pilotName: "Alex", calendar: calendar, locale: locale))
        XCTAssertTrue(sentence.hasPrefix("UPS207 to PHL, 14 minutes ahead of schedule. Lands about "), sentence)
        XCTAssertTrue(sentence.hasSuffix(" your time. Tracked live."), sentence)
    }

    func test_cardSummary_byTheScheduleAlone_saysSo_andNothingWhileWaiting() throws {
        let (leg, at) = try leg("no live data", at: "13T12:30:00")
        XCTAssertEqual(plain(TripMapWording.cardSummary(for: map(of: leg), now: at, pilotName: "Alex", calendar: calendar, locale: locale)),
                       "UPS207 to PHL, landing at 8:45 AM your time. Not tracked live, so it's shown where the schedule has it.")
        XCTAssertEqual(plain(TripMapWording.cardSummary(for: map(of: awaiting(leg)), now: at, pilotName: "Alex", calendar: calendar,
                                                        locale: locale)),
                       "UPS207 to PHL, landing at 8:45 AM your time.")
    }

    func test_cardSummary_byTheScheduleAlone_beforeItsTakeoff_saysWhenItsScheduledToTakeOff() throws {
        let (leg, _) = try leg("no live data", at: "13T12:30:00")
        let at = leg.start.addingTimeInterval(5 * 60)
        XCTAssertEqual(plain(TripMapWording.cardSummary(for: map(of: leg), now: at, pilotName: "Alex", calendar: calendar, locale: locale)),
                       "UPS207 to PHL, scheduled to take off about 7:15 AM your time, landing at 8:45 AM your time. " +
                       "Not tracked live, so it's shown where the schedule has it.")
    }

    func test_liveSummary_aRealPlaneAtItsGateBeforeThePlansTakeoff_isOnTheGround() throws {
        let (leg, at) = try leg("on the ground before the plan's takeoff", at: "13T12:10:00")
        XCTAssertEqual(plain(TripMapWording.liveSummary(for: leg, now: at, calendar: calendar, locale: locale) ?? ""),
                       "UPS207 to PHL, on the ground in SDF. Lands at 8:45 AM your time.")
    }
```

- [ ] **Step 2: The sentence's pieces.** In `TripMapWording.swift`'s live-or-scheduled section, add:

```swift
    /// "Not tracked live, so it's shown where the schedule has it.": the card's VoiceOver sentence for a flight by the
    /// schedule alone (live or scheduled design §7).
    static let spokenNotTracked = "\(notTrackedLive), so it's shown where the schedule has it."

    /// What the card's VoiceOver sentence says of where the flight comes from (§7): "Tracked live." while Crewlu Cloud
    /// sees it, "Not tracked live, so …" by the schedule alone, and nothing for a best guess, whose sentence says
    /// where it was last tracked, or while the first answer is on its way.
    static func spokenSource(for leg: MapLeg, at now: Date) -> String? {
        switch leg.tracking(at: now) {
        case .live: "\(trackedLive)."
        case .notTracked: spokenNotTracked
        case .bestGuess, .waiting: nil
        }
    }

    /// ", scheduled to take off about 3:14 PM your time": a flight by the schedule alone, before its takeoff (§7).
    /// Empty otherwise.
    static func spokenDueClause(for leg: MapLeg, at now: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        guard leg.atDeparture(at: now) == .due else { return "" }
        return ", scheduled to take off about \(clockTime(leg.scheduledTakeoff, in: calendar.timeZone, locale: locale)) your time"
    }
```

- [ ] **Step 3: A real plane at its gate is on the ground.** Replace `liveSummary`'s body (its doc gains: "Seen at its gate before the plan's takeoff, with no label yet: "UPS70 to Honolulu, on the ground in Louisville. Lands at 12:11 AM your time." (live or scheduled design §7). Nil when the plane has no label and isn't seen at its gate, and the schedule's sentence stands."):

```swift
        let label = leg.flight?.progress(at: now).label
        let spoken: String
        switch label {
        // A plane back at its departure airport after an air return names it (air return design §3).
        case .returned?: spoken = "returned to \(leg.origin.name)"
        case let label?: spoken = spokenLiveLabel(label)
        case nil:
            guard leg.atDeparture(at: now) == .atGate else { return nil }
            spoken = "on the ground in \(leg.origin.name)"
        }
        let lead = leg.flightNumber.map { "\($0) to" } ?? "Flying to"
        // What's below and where it was last seen are said only of a plane in the air: not of one on the ground at its
        // gate, nor of one that's down (which plane design §4).
        let isFlying = switch label {
        case .onSchedule?, .ahead?, .behind?: true
        default: false
        }
        let isDown = switch label {
        case .landedOnTime?, .landedEarly?, .landedLate?: true
        default: false
        }
        let over = isFlying ? (place.map { ", over \($0)" } ?? "") + (lastSeen.map { ", last tracked \($0)" } ?? "") : ""
        let time = clockTime(leg.end, in: calendar.timeZone, locale: locale)
        // It's down and on its way in: "landed 8 minutes early. Lands at 3:18 PM" would say so twice.
        let arrival = isDown ? "Reaches the gate at \(time) your time." : "Lands \(leg.isArrivalEstimated ? "about" : "at") \(time) your time."
        return "\(lead) \(leg.destination.name), \(spoken)\(over). \(arrival)"
```

- [ ] **Step 4: The card's sentence without the facts.** In `cardSummary(for:now:pilotName:…)`, the `.inFlight` case:

```swift
        case .inFlight:
            guard let leg = tripMap.currentLeg else { return "Trip map" }
            let source = spokenSource(for: leg, at: now)
            if let live = liveSummary(for: leg, now: now, calendar: calendar, locale: locale) {
                return [live, source].compactMap { $0 }.joined(separator: " ")
            }
            let lead = leg.flightNumber.map { "\($0) to" } ?? "Flying to"
            let due = spokenDueClause(for: leg, at: now, calendar: calendar, locale: locale)
            let landing = clockTime(leg.end, in: calendar.timeZone, locale: locale)
            return ["\(lead) \(leg.destination.name)\(due), landing at \(landing) your time.", source].compactMap { $0 }.joined(separator: " ")
```

- [ ] **Step 5: With the facts.** In `TripFacts.flightSummary(of:now:)`, from `if let live = …` to the end:

```swift
        let source = TripMapWording.spokenSource(for: leg, at: now)
        if let live = TripMapWording.liveSummary(for: leg, over: isOverWhereLastTracked ? nil : below, lastSeen: lastSeen,
                                                 now: now, calendar: calendar, locale: locale) {
            return [live, source].compactMap { $0 }.joined(separator: " ")
        }
        // By the schedule alone (live or scheduled design §7): when it's due to take off, else what's below, then the
        // source.
        let lead = leg.flightNumber.map { "\($0) to" } ?? "Flying to"
        let due = TripMapWording.spokenDueClause(for: leg, at: now, calendar: calendar, locale: locale)
        let over = due.isEmpty ? (below.map { ", over \($0)" } ?? "") : ""
        let landing = TripMapWording.clockTime(leg.end, in: calendar.timeZone, locale: locale)
        return ["\(lead) \(leg.destination.name)\(due)\(over). Lands at \(landing) your time.", source].compactMap { $0 }.joined(separator: " ")
```

---

### Task 5: The line under the timeline (§4.1, §4.2)

**Files:** `FlightOnGround.swift` → `FlightNow.swift`, `TripMap+Activity.swift`, `Facts/TripFacts.swift`, `TripMapWording.swift`, `Views/TripMap/TripTimelineControl.swift`, `FactsPanel.swift`, `FactsSheet.swift`; test `LiveOrScheduledWordsTests.swift`.

- [ ] **Step 1: The failing tests.** Add to `LiveOrScheduledWordsTests`:

```swift
    // MARK: - Under the timeline (§4.1, §4.2)

    func test_timelineLine_byTheScheduleAlone_isScheduledToFly_thenShouldBeFlying() {
        let honolulu = AirportMark(code: "HNL", city: "Honolulu", coordinate: CLLocationCoordinate2D(latitude: 21.3, longitude: -157.9),
                                   timeZone: TimeZone(identifier: "Pacific/Honolulu"))
        let date = FactsTestData.date("2026-11-25T20:12:00Z")
        XCTAssertEqual(plain(TripMapWording.timelineLine(date, activity: nil, flight: .dueTo(honolulu), calendar: calendar, locale: locale)),
                       "Wed 3:12 PM L · Scheduled to fly to Honolulu")
        XCTAssertEqual(plain(TripMapWording.timelineLine(date, activity: nil, flight: .shouldBeFlyingTo(honolulu), calendar: calendar,
                                                         locale: locale)),
                       "Wed 3:12 PM L · Should be flying to Honolulu")
    }

    func test_flightNow_isTheRealPlaneOnTheGroundFirst_elseTheFlightByTheScheduleAlone() throws {
        let (noLive, _) = try leg("no live data", at: "13T12:30:00")
        let due = noLive.start.addingTimeInterval(5 * 60)
        guard case .dueTo(let to)? = map(of: noLive).flightNow(at: due) else { return XCTFail("due") }
        XCTAssertEqual(to.code, "PHL")
        guard case .shouldBeFlyingTo(let flyingTo)? = map(of: noLive).flightNow(at: due.addingTimeInterval(25 * 60)) else {
            return XCTFail("should be flying")
        }
        XCTAssertEqual(flyingTo.code, "PHL")
        let atGate = try leg("on the ground before the plan's takeoff", at: "13T12:10:00")
        guard case .stillIn(let gate)? = map(of: atGate.leg).flightNow(at: atGate.at) else { return XCTFail("at the gate") }
        XCTAssertEqual(gate.code, "SDF")
        let back = try leg("an air return, back on the ground", at: "13T12:41:00")
        guard case .returnedTo? = map(of: back.leg).flightNow(at: back.at) else { return XCTFail("returned") }
        let ahead = try leg("ahead, in the air", at: "13T12:41:50")
        XCTAssertNil(map(of: ahead.leg).flightNow(at: ahead.at))
    }
```

- [ ] **Step 2: Rename and widen the type.** `git mv Crewluv/Services/TripMap/FlightOnGround.swift Crewluv/Services/TripMap/FlightNow.swift`, and make it:

```swift
//
//  FlightNow.swift
//  CrewLuve
//
//  What the line under the timeline names of the flight between its gates now, in place of the activity's words
//  (which plane design §4, landed before the gate design §3, air return design §3, live or scheduled design §4).
//

nonisolated enum FlightNow {
    /// Its real plane at its departure airport, before or after the plan's takeoff time: "On the ground in Rockford".
    case stillIn(AirportMark)
    /// Back at its departure airport after an air return: "Returned to Rockford".
    case returnedTo(AirportMark)
    /// Down at its arrival airport, before the gate: "Landed in Anchorage".
    case landedIn(AirportMark)
    /// By the schedule alone, before the schedule's takeoff: "Scheduled to fly to Honolulu".
    case dueTo(AirportMark)
    /// By the schedule alone, after it: "Should be flying to Honolulu".
    case shouldBeFlyingTo(AirportMark)

    /// The airport it names.
    var airport: AirportMark {
        switch self {
        case .stillIn(let airport), .returnedTo(let airport), .landedIn(let airport), .dueTo(let airport),
             .shouldBeFlyingTo(let airport): airport
        }
    }
}
```

- [ ] **Step 3: Work it out.** In `TripMap+Activity.swift`, delete `stillOnGroundAirport(at:)`, and replace `flightOnGround(at:)` with:

```swift
    /// What the line under the timeline names of the flight between its gates at `date`, in place of "Flying to"
    /// (live or scheduled design §4): the real plane on the ground (at its departure airport, back there after an air
    /// return, or down at its arrival airport before the gate), else the flight known by the schedule alone, due to
    /// take off or flying by the schedule. Nil otherwise. Now only: the facts ask it only of now.
    func flightNow(at date: Date) -> FlightNow? {
        if let arrival = landedAirport(at: date) { return .landedIn(arrival) }
        guard let flight = flightInMotion(at: date) else { return nil }
        switch flight.atDeparture(at: date) {
        case .returned: return .returnedTo(flight.origin)
        case .atGate, .stillAtGate: return .stillIn(flight.origin)
        case .due: return .dueTo(flight.destination)
        case nil: return flight.tracking(at: date).isBySchedule ? .shouldBeFlyingTo(flight.destination) : nil
        }
    }
```

In `TripFacts.swift`, `flightOnGround(at:)` becomes `func flightNow(at date: Date) -> FlightNow? { isReplay ? nil : tripMap.flightNow(at: date) }` (doc updated to name the schedule's words too).

- [ ] **Step 4: The words.** In `TripMapWording.swift`, `timelineLine` and `timelineSpokenValue` take `flight: FlightNow? = nil` in place of `onGround: FlightOnGround? = nil`, and `timelineWords`:

```swift
    private static func timelineWords(_ activity: TripActivity?, flight: FlightNow?) -> String? {
        switch flight {
        case .stillIn(let airport): "On the ground in \(airport.name)"
        case .returnedTo(let airport): FactsWording.returned(to: airport)
        case .landedIn(let airport): FactsWording.landed(in: airport)
        case .dueTo(let airport): "Scheduled to fly to \(airport.name)"
        case .shouldBeFlyingTo(let airport): "Should be flying to \(airport.name)"
        case nil: activity?.words
        }
    }
```

Update the three docs to add: "By the schedule alone, "Scheduled to fly to Honolulu" before its takeoff and "Should be flying to Honolulu" after (live or scheduled design §4)."

- [ ] **Step 5: The views.** In `TripTimelineControl.swift`, the `onGround: FlightOnGround?` property becomes `flight: FlightNow?`, passed as `flight:`. In `FactsPanel.swift` and `FactsSheet.swift`, `onGround: facts.flightOnGround(at: time)` becomes `flight: facts.flightNow(at: time)`.

---

### Task 6: The facts and the list (§3, §4, §5, §6)

**Files:** `Facts/FactsWording.swift`, `Facts/FactRow.swift`, `PlanePopupWords.swift`, `Facts/TripFacts.swift`, `Facts/TripFacts+Rows.swift`, `MapLeg.swift`; test `CrewluvTests/LiveOrScheduledFactsTests.swift` (new).

- [ ] **Step 1: The failing tests.** Create `CrewluvTests/LiveOrScheduledFactsTests.swift`:

```swift
//
//  LiveOrScheduledFactsTests.swift
//  CrewluvTests
//
//  The facts and the list say how the flight between its gates is known (live or scheduled design §4, §5, §6), in US
//  English for a family in Louisville. The equator flight (FactsTestData) leaves its gate at 10:00 UTC (6:00 AM in
//  Louisville), takes off at 10:15, crosses into Bravo at 11:00, is halfway at 11:45 and reaches its gate at 13:22.
//

import XCTest
@testable import Crewluv

final class LiveOrScheduledFactsTests: XCTestCase {

    private let locale = Locale(identifier: "en_US")
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private func at(_ time: String) -> Date { FactsTestData.date("2026-03-20T\(time):00Z") }

    private func plain(_ text: String?) -> String? {
        text?.replacingOccurrences(of: "\u{202F}", with: " ")
    }

    private let home = FactsTestData.mark("HOME", latitude: 0.5, longitude: 14)

    /// The facts of a map of `legs`, the last of them in the air.
    private func facts(_ legs: [MapLeg], isReplay: Bool = false) -> TripFacts {
        let map = TripMap(mode: .inFlight(legID: legs[legs.count - 1].id), legs: legs, home: home,
                          span: DateInterval(start: legs[0].start, end: legs[legs.count - 1].end), tripDays: nil)
        var stories: [String: LegStory] = [:]
        var sunEvents: [String: [SkyFacts.SunEvent]] = [:]
        for leg in legs {
            stories[leg.id] = LegStory(leg: leg, geography: FactsTestData.equator, home: home)
            sunEvents[leg.id] = SkyFacts.sunEvents(on: leg)
        }
        var facts = TripFacts(tripMap: map, geography: FactsTestData.equator, comparisons: nil, stories: stories,
                              sunEvents: sunEvents, dayNumber: 1, totalDays: 1, calendar: calendar, locale: locale)
        facts.isReplay = isReplay
        return facts
    }

    /// The equator flight by the schedule alone, with a plan of its own and no live data, or waiting for it.
    private func bySchedule(isAwaitingLive: Bool = false) -> MapLeg {
        let leg = FactsTestData.equatorFlight(from: 0, to: 20)
        let flight = MapFlight(departure: leg.start, arrival: leg.end, from: leg.origin.coordinate, to: leg.destination.coordinate)
        return MapLeg(id: leg.id, kind: leg.kind, origin: leg.origin, destination: leg.destination, start: leg.start, end: leg.end,
                      flightNumber: leg.flightNumber, flight: flight, isAwaitingLive: isAwaitingLive)
    }

    // MARK: - By the schedule, before its takeoff (§4.2)

    func test_headline_beforeTheSchedulesTakeoff_saysWhenItsScheduledToTakeOff() {
        XCTAssertEqual(plain(facts([bySchedule()]).headline(at: at("10:05"))), "Scheduled to take off about 6:15 AM L")
    }

    func test_rows_beforeTheSchedulesTakeoff_leadWithTheSource_thenTheTakeoff_theMilesToGo_andTheLanding() throws {
        let rows = facts([bySchedule()]).rows(at: at("10:05"), now: at("10:05"))
        XCTAssertEqual(rows.map(\.kind), [.source, .below, .distance, .headed])
        XCTAssertEqual(rows[0].symbolName, "calendar")
        XCTAssertEqual(rows[0].title, "Not tracked live")
        XCTAssertEqual(rows[0].detail, "Shown where the schedule has it · If it's running late, it may still be at the gate")
        XCTAssertEqual(rows[1].symbolName, "airplane.departure")
        XCTAssertEqual(plain(rows[1].title), "Scheduled to take off about 6:15 AM L")
        XCTAssertEqual(rows[2].title, "1,382 mi to go")
        XCTAssertTrue(plain(rows[2].detail)?.contains("Halfway at about 7:45 AM L") == true, rows[2].detail ?? "")
    }

    func test_beforeTheSchedulesTakeoff_thereIsNoLatestEvent_andTheListTagsTheFlightByTheSchedule() {
        let facts = facts([bySchedule()])
        XCTAssertNil(facts.latestEvent(at: at("10:05")))
        let soFar = facts.tripSoFar(at: at("10:05"))
        XCTAssertEqual(soFar.flights.map(\.tag), ["By the schedule"])
        XCTAssertEqual(soFar.flights.first?.events.count, 0)
    }

    func test_cardSummary_beforeTheSchedulesTakeoff_saysWhenItsScheduledToTakeOff_andThatItsNotTracked() {
        XCTAssertEqual(plain(facts([bySchedule()]).cardSummary(now: at("10:05"), pilotName: "Alex")),
                       "TST1 to E20, scheduled to take off about 6:15 AM your time. Lands at 9:22 AM your time. " +
                       "Not tracked live, so it's shown where the schedule has it.")
    }

    func test_waitingForTheFirstAnswer_beforeItsTakeoff_saysWhenItsScheduledToTakeOff_withNoSourceRow() {
        let facts = facts([bySchedule(isAwaitingLive: true)])
        XCTAssertEqual(plain(facts.headline(at: at("10:05"))), "Scheduled to take off about 6:15 AM L")
        XCTAssertEqual(facts.rows(at: at("10:05"), now: at("10:05")).map(\.kind), [.below, .distance, .headed])
    }

    // MARK: - By the schedule, in the air (§4.1, §5)

    func test_inTheAir_theHeadlineIsWhatsBelow_underTheSourceRow() {
        let facts = facts([bySchedule()])
        XCTAssertEqual(facts.headline(at: at("11:10")), "Over Bravo, near Testville")
        XCTAssertEqual(facts.rows(at: at("11:10"), now: at("11:10")).first?.title, "Not tracked live")
    }

    func test_inTheAir_itsEventsHalfwayAndClosestPointReadAbout() throws {
        let facts = facts([bySchedule()])
        XCTAssertEqual(facts.latestEvent(at: at("11:10"))?.when, "About 10 min ago")
        let soFar = facts.tripSoFar(at: at("11:10"))
        XCTAssertEqual(soFar.flights.first?.tag, "By the schedule")
        let events = try XCTUnwrap(soFar.flights.first?.events)
        XCTAssertFalse(events.isEmpty)
        XCTAssertTrue(events.allSatisfy(\.isEstimate))
        let distance = try XCTUnwrap(facts.rows(at: at("11:10"), now: at("11:10")).first { $0.kind == .distance })
        XCTAssertTrue(plain(distance.detail)?.contains("Halfway at about 7:45 AM L") == true, distance.detail ?? "")
    }

    func test_whileWaitingForTheFirstAnswer_thereIsNoSourceRow_andTheListStillSaysByTheSchedule() {
        let facts = facts([bySchedule(isAwaitingLive: true)])
        XCTAssertFalse(facts.rows(at: at("11:10"), now: at("11:10")).contains { $0.kind == .source })
        XCTAssertEqual(facts.tripSoFar(at: at("11:10")).flights.first?.tag, "By the schedule")
    }

    func test_aReplay_readsAsBefore_withNoSourceRow_itsEventsNotGuesses_andByTheScheduleWithNoRealPath() throws {
        let facts = facts([bySchedule()], isReplay: true)
        XCTAssertFalse(facts.rows(at: at("11:10"), now: at("11:10")).contains { $0.kind == .source })
        XCTAssertFalse(facts.latestEvent(at: at("11:10"))?.when.hasPrefix("About") ?? true)
        let soFar = facts.tripSoFar(at: at("11:10"))
        XCTAssertEqual(soFar.flights.first?.tag, "By the schedule")
        XCTAssertTrue(try XCTUnwrap(soFar.flights.first?.events).allSatisfy { !$0.isEstimate })
    }

    func test_anEarlierFlightsEvents_readAsBefore() throws {
        let first = bySchedule()
        let later = FactsTestData.equatorFlight(from: 20, to: 40, departure: first.start.addingTimeInterval(5 * 3600), id: "eq2")
        let soFar = facts([first, later]).tripSoFar(at: first.start.addingTimeInterval(6 * 3600))
        let earlier = try XCTUnwrap(soFar.flights.first { $0.id == "eq" })
        XCTAssertFalse(earlier.events.isEmpty)
        XCTAssertTrue(earlier.events.allSatisfy { !$0.isEstimate })
    }

    // MARK: - Tracked live (§4.1, §4.2)

    func test_aPlaneSeenInTheAir_leadsWithTrackedLive() throws {
        let leg = try FactsTestData.equatorLiveLeg(FactsTestData.equatorLive(seenUntil: at("10:55")), at: at("10:55"))
        let row = try XCTUnwrap(facts([leg]).rows(at: at("10:55"), now: at("10:55")).first)
        XCTAssertEqual(row.kind, .source)
        XCTAssertEqual(row.symbolName, "dot.radiowaves.left.and.right")
        XCTAssertEqual(row.title, "Tracked live")
        XCTAssertNil(row.detail)
    }

    func test_aBestGuess_hasNoSourceRow() throws {
        let leg = try FactsTestData.equatorLiveLeg(FactsTestData.equatorLive(seenUntil: at("10:55")), at: at("11:05"))
        XCTAssertEqual(leg.tracking(at: at("11:05")), .bestGuess)
        XCTAssertFalse(facts([leg]).rows(at: at("11:05"), now: at("11:05")).contains { $0.kind == .source })
    }

    func test_aRealPlaneAtItsGateBeforeThePlansTakeoff_isOnTheGround_withNoSky_nothingListed_andNoLatestEvent() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "on the ground before the plan's takeoff")
        let moment = try cases.moment("13T12:10:00", of: flightCase)
        let leg = try cases.mapLeg(flightCase, at: moment)
        let map = TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: leg.origin,
                          span: DateInterval(start: leg.start, end: leg.end), tripDays: nil)
        let facts = TripFacts(tripMap: map, geography: nil, comparisons: nil, stories: [:], sunEvents: [:],
                              calendar: calendar, locale: locale)
        XCTAssertEqual(facts.headline(at: moment.at), "On the ground in SDF")
        let rows = facts.rows(at: moment.at, now: moment.at)
        XCTAssertEqual(rows.first?.title, "Tracked live")
        XCTAssertEqual(rows.first { $0.kind == .below }?.title, "On the ground in SDF")
        XCTAssertFalse(rows.contains { $0.kind == .sky })
        XCTAssertTrue(rows.first { $0.kind == .distance }?.title.hasSuffix("mi to go") == true)
        XCTAssertTrue(facts.tripSoFar(at: moment.at).flights.isEmpty)
        XCTAssertNil(facts.latestEvent(at: moment.at))
        XCTAssertEqual(plain(facts.cardSummary(now: moment.at, pilotName: "Alex")),
                       "UPS207 to PHL, on the ground in SDF. Lands at 8:45 AM your time. Tracked live.")
    }
}
```

If an expectation here disagrees with what the code says (a number, a city, the order of a row's parts), check it against the website's own test (`../Crewluve Website/tests/facts/liveOrScheduledFacts.test.ts`) and the spec before changing either: the two platforms must say the same.

- [ ] **Step 2: The facts' words.** In `FactsWording.swift`, after `stillOnGround(in:)`:

```swift
    /// In place of what's below, a real plane seen at its gate before the plan's takeoff: "On the ground in
    /// Louisville" (live or scheduled design §4.2).
    static func onTheGround(in airport: AirportMark) -> String {
        "On the ground in \(airport.name)"
    }

    /// In place of what's below, a flight by the schedule alone before its takeoff: "Scheduled to take off about 3:14
    /// PM L" (§4.2). The time is the gate's plus the map's own taxi allowance, so "about".
    static func scheduledTakeoff(at time: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        "Scheduled to take off about \(ClockLabel.yours(time, calendar: calendar, locale: locale))"
    }

    /// The second line of the facts' first row for a flight by the schedule alone, as the schedule's plane's popup
    /// says it (§4.1).
    static let notTrackedLines = ["Shown where the schedule has it", TripMapWording.mayBeAtGate]
```

and in `stillOnGround(in:)`'s doc, "after the plan's takeoff time" stays. `inTheAir(isReplay:)` is unchanged.

In `PlanePopupWords.swift`, the schedule plane's second line becomes `TripMapWording.mayBeAtGate`.

In `FactRow.swift`, the in-flight kinds become `case source, below, plane, sky, distance, takeoff, headed`, with the comment above saying the first is how the flight is known now (live or scheduled design §4.1).

- [ ] **Step 3: The facts' rule.** In `TripFacts.swift`, replace `isStillOnGround(_:at:)` and `atDepartureWords(on:at:)` with:

```swift
    /// Whether `leg`, the leg between its gates at `date`, is on the ground at its departure airport, and how that's
    /// told (live or scheduled design §3): by the schedule before its takeoff, or its real plane seen there. The facts
    /// then say so in place of what's below, count nothing as flown, and pass nothing. Now only: a replay reads where
    /// the map has the plane.
    func atDeparture(of leg: MapLeg, at date: Date) -> AtDeparture? {
        isReplay ? nil : leg.atDeparture(at: date)
    }

    /// What the facts say in place of what's below while `atDeparture` holds (§4.2): "Scheduled to take off about
    /// 3:14 PM L", "On the ground in Louisville", "Still on the ground in Louisville" (which plane design §4), or
    /// "Returned to Rockford" (air return design §3).
    func atDepartureWords(_ atDeparture: AtDeparture, on leg: MapLeg) -> String {
        switch atDeparture {
        case .due: FactsWording.scheduledTakeoff(at: leg.scheduledTakeoff, calendar: calendar, locale: locale)
        case .atGate: FactsWording.onTheGround(in: leg.origin)
        case .stillAtGate: FactsWording.stillOnGround(in: leg.origin)
        case .returned: FactsWording.returned(to: leg.origin)
        }
    }

    /// Whether `leg`'s guessed times at `date` are the schedule's alone (§5): it's between its gates now and known by
    /// the schedule. Its events, halfway and closest point to home then read "about", as an unseen stretch's do. Now
    /// only, and only the flight between its gates: earlier flights, the recap and a replay read as before.
    func isGuessedFromSchedule(_ leg: MapLeg, at date: Date) -> Bool {
        !isReplay && leg.isMoving(at: date) && leg.tracking(at: date).isBySchedule
    }
```

Then:
- `milestones(on:at:)`: after `let all = milestones(on: leg)`, add
  ```swift
          // Nobody saw a flight by the schedule alone: each of its events is the schedule's guess (live or scheduled
          // design §5).
          if isGuessedFromSchedule(leg, at: date) {
              return all.map { Milestone(kind: $0.kind, time: $0.time, isEstimate: true) }
          }
  ```
- `headline(at:includesEvents:)`: `if isStillOnGround(leg, at: date) { return atDepartureWords(on: leg, at: date) }` becomes `if let atDeparture = atDeparture(of: leg, at: date) { return atDepartureWords(atDeparture, on: leg) }`, and its doc names the new words.
- `latestEvent(at:)`: `!isStillOnGround(leg, at: date)` becomes `atDeparture(of: leg, at: date) == nil`.
- `tripSoFar(at:)`: the `started` filter's `!isStillOnGround($0, at: date)` becomes `!(atDeparture(of: $0, at: date)?.isSeen ?? false)` (a real plane seen at its departure airport is left out until it takes off; one due by the schedule is listed), and the tag's `FactsWording.inTheAir(isReplay: isReplay)` becomes `flightTag(leg, at: date)`, with:
  ```swift
      /// The tag on the flight between its gates (live or scheduled design §4.1, §6): "By the schedule" for one known
      /// by the schedule alone now, or with no real path in a replay, whose events aren't marked as guesses there
      /// ("about" is now only); else "In the air now", or "In the air" in a replay.
      private func flightTag(_ leg: MapLeg, at date: Date) -> String {
          let isBySchedule = isReplay ? leg.flight?.path.isReal != true : leg.tracking(at: date).isBySchedule
          return isBySchedule ? TripMapWording.byTheSchedule : FactsWording.inTheAir(isReplay: isReplay)
      }
  ```
  and `tripSoFar`'s doc: a real plane seen at its departure airport, before or after the plan's takeoff time, is left out; a flight by the schedule alone is tagged "By the schedule".

- [ ] **Step 4: The rows.** In `TripFacts+Rows.swift`:

```swift
    private func flightRows(on leg: MapLeg, at date: Date, now: Date) -> [FactRow] {
        let plane = leg.plane(at: date, isReplay: isReplay)
        return [sourceRow(on: leg, at: date), belowRow(on: leg, at: date), planeRow(on: leg, plane: plane),
                skyRow(on: leg, at: date), distanceRow(on: leg, plane: plane, at: date), takeoffRow(on: leg, at: date),
                headedRow(on: leg, at: date, now: now)]
            .compactMap { $0 }
    }

    /// How the flight is known now (live or scheduled design §4.1): "Tracked live" while Crewlu Cloud sees it, "Not
    /// tracked live" with why the plane may not be where it's drawn, by the schedule alone. None for a best guess,
    /// whose place has "Last tracked near …" under it, while the first answer is on its way, and in a replay.
    private func sourceRow(on leg: MapLeg, at date: Date) -> FactRow? {
        guard !isReplay else { return nil }
        switch leg.tracking(at: date) {
        case .live:
            return FactRow(.source, symbol: "dot.radiowaves.left.and.right", title: TripMapWording.trackedLive)
        case .notTracked:
            return FactRow(.source, symbol: "calendar", title: TripMapWording.notTrackedLive, details: FactsWording.notTrackedLines)
        case .bestGuess, .waiting:
            return nil
        }
    }
```

(If `details:` won't take `[String]` for `[String?]`, pass `FactsWording.notTrackedLines.map(Optional.some)`.)

- `belowRow`: `let place = isStillOnGround(…) ? atDepartureWords(on: leg, at: date) : belowText(…)` becomes
  ```swift
          let atDeparture = atDeparture(of: leg, at: date)
          let place = atDeparture.map { atDepartureWords($0, on: leg) } ?? belowText(on: leg, at: date)
  ```
  and the returned row's symbol is `atDeparture == .due ? "airplane.departure" : "mappin.and.ellipse"` (due to take off by the schedule, the row is the takeoff's, live or scheduled design §4.2).
- `closestToHomeLine`: `let isOnGround = atDeparture(of: leg, at: date) != nil`, and `isEstimate: isOnGround || isGuessedFromSchedule(leg, at: date) || !leg.isSeen(atDistance: distance)`.
- `skyRow`: `guard atDeparture(of: leg, at: date) == nil, !isLandedBeforeGate(leg, at: date) else { return nil }`.
- `distanceRow`: `let isOnGround = atDeparture(of: leg, at: date) != nil`, and halfway's `isEstimate: isOnGround || isGuessedFromSchedule(leg, at: date) || !leg.isSeen(atDistance: leg.pathLength / 2)`.
- `takeoffRow`: `guard atDeparture(of: leg, at: date) == nil, let takeoff = …`.
- Each changed function's doc: "a real plane still at its departure airport" becomes "a plane on the ground at its departure airport (live or scheduled design §3)".

- [ ] **Step 5: The old rule goes.** In `MapLeg.swift`, delete `isStillOnGround(at:)` and `hasReturned(at:)`. `grep -rn "isStillOnGround(at\|hasReturned(at\|flightOnGround\|stillOnGroundAirport\|FlightOnGround" Crewluv` must show only `MapFlight.hasReturned(at:)` and its callers.

---

### Task 7: The status sentence (§4)

**Files:** new `Live/NarrativeFlight.swift`, `Live/LiveLegs.swift`, `PartnerStatusReceiver.swift`, `Views/Status/NarrativeCardView.swift`, `PilotStatusView.swift`, `Views/Welcome/ContentView.swift`; test `CrewluvTests/NarrativeFlightTests.swift` (new).

- [ ] **Step 1: The failing tests.** Create `CrewluvTests/NarrativeFlightTests.swift`:

```swift
//
//  NarrativeFlightTests.swift
//  CrewluvTests
//
//  How the status sentence tells the flight under way (live or scheduled design §4; which plane design §4; landed
//  before the gate design §3; air return design §3), held to the shared live cases.
//

import XCTest
@testable import Crewluv

final class NarrativeFlightTests: XCTestCase {

    /// The sentence's flight for a case at `time`: with its live data as the screen's model hands it on, or with none.
    private func narrative(_ name: String, at time: String, isLive: Bool = true, isAwaitingLive: Bool = false) throws -> NarrativeFlight {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: name)
        let now = try cases.moment(time, of: flightCase).at
        return try narrative(flightCase, cases: cases, at: now, isLive: isLive, isAwaitingLive: isAwaitingLive)
    }

    private func narrative(
        _ flightCase: TripMapFixtures.LiveCases.Flight, cases: TripMapFixtures.LiveCases, at now: Date, isLive: Bool = true,
        isAwaitingLive: Bool = false
    ) throws -> NarrativeFlight {
        let flights = isLive && cases.live(flightCase) != nil ? ["f1": try cases.mapFlight(flightCase)] : [:]
        let legs = LiveLegs.replacingTimes(in: [cases.tripLeg(flightCase)], with: flights, at: now)
        return LiveLegs.narrativeFlight(in: legs, flights: flights, at: now, isAwaitingLive: isAwaitingLive)
    }

    func test_narrativeFlight_seenInTheAir_orABestGuess_isFlying() throws {
        XCTAssertEqual(try narrative("ahead, in the air", at: "13T12:41:50"), .flying)
        XCTAssertEqual(try narrative("ahead, in the air", at: "13T12:45:00"), .flying)
    }

    func test_narrativeFlight_theRealPlaneOnTheGround_saysWhere() throws {
        XCTAssertEqual(try narrative("on the ground before the plan's takeoff", at: "13T12:10:00"), .atGate)
        XCTAssertEqual(try narrative("still on the ground twenty minutes after", at: "13T12:35:00"), .stillAtGate)
        XCTAssertEqual(try narrative("an air return, back on the ground", at: "13T12:41:00"), .returned)
        // Down at 13:14:51 and at the gate at 13:21:51: a minute before the gate it's still between its gates.
        let cases = try TripMapFixtures.liveCases()
        let landed = try cases.flight(named: "landed, seen all the way")
        let gate = try cases.moment("13T13:30:00", of: landed).end
        XCTAssertEqual(try narrative(landed, cases: cases, at: gate.addingTimeInterval(-60)), .landed)
    }

    func test_narrativeFlight_byTheScheduleAlone_isDueToTakeOff_thenShouldBeFlying() throws {
        let cases = try TripMapFixtures.liveCases()
        let noLive = try cases.flight(named: "no live data")
        XCTAssertEqual(try narrative(noLive, cases: cases, at: noLive.departure.addingTimeInterval(5 * 60)), .dueToTakeOff)
        XCTAssertEqual(try narrative("no live data", at: "13T12:30:00"), .shouldBeFlying(saysNotTracked: true))
        XCTAssertEqual(try narrative("on the ground before the plan's takeoff", at: "13T12:13:00"), .dueToTakeOff)
        XCTAssertEqual(try narrative("an air return, back on the ground", at: "13T12:43:01"), .shouldBeFlying(saysNotTracked: true))
    }

    func test_narrativeFlight_whileWaitingForTheFirstAnswer_shouldBeFlying_withoutSayingNotTracked() throws {
        XCTAssertEqual(try narrative("no live data", at: "13T12:30:00", isAwaitingLive: true), .shouldBeFlying(saysNotTracked: false))
    }

    func test_narrativeFlight_withNoFlightBetweenItsGates_isNil() throws {
        let cases = try TripMapFixtures.liveCases()
        let noLive = try cases.flight(named: "no live data")
        XCTAssertNil(LiveLegs.narrativeFlight(in: [cases.tripLeg(noLive)], flights: [:], at: noLive.departure.addingTimeInterval(-60),
                                              isAwaitingLive: false))
        XCTAssertNil(LiveLegs.narrativeFlight(in: [cases.tripLeg(noLive)], flights: [:], at: noLive.arrival, isAwaitingLive: false))
    }
}
```

- [ ] **Step 2: The value.** Create `Crewluv/Services/TripMap/Live/NarrativeFlight.swift`:

```swift
//
//  NarrativeFlight.swift
//  CrewLuve
//
//  How the status sentence tells the flight under way (live or scheduled design §4), in place of three Booleans: by
//  its real plane where Crewlu Cloud sees it, else by the schedule, saying so.
//

nonisolated enum NarrativeFlight: Equatable, Sendable {
    /// In the air, seen or a best guess: "Alex is flying to Honolulu …", as before.
    case flying
    /// Its real plane at its gate before the plan's takeoff: "Alex is on the ground in Louisville …" (§4.2).
    case atGate
    /// Still there after it: "Alex is still on the ground in Louisville …" (which plane design §4).
    case stillAtGate
    /// Back there after an air return: "Alex has returned to Rockford …" (air return design §3).
    case returned
    /// Down at the arrival airport, before the gate: "Alex has landed in Anchorage …" (landed before the gate design §3).
    case landed
    /// By the schedule alone, before the schedule's takeoff: "Alex is due to take off from Louisville …" (§4.2).
    case dueToTakeOff
    /// By the schedule alone, after it: "Alex should be flying to Honolulu … — not tracked live — …", without "not
    /// tracked live" while Crewlu Cloud's first answer is on its way (§2, §4.1).
    case shouldBeFlying(saysNotTracked: Bool)
}
```

- [ ] **Step 3: Work it out.** In `LiveLegs.swift`, replace `stillOnGroundFlight(in:flights:at:)` and `landedFlight(in:flights:at:)` with:

```swift
    /// How the status sentence tells the flight between its gates at `now` (live or scheduled design §4), from its live
    /// data where Crewlu Cloud sees it, else by the schedule. Nil with no flight between its gates.
    /// - Parameter isAwaitingLive: Crewlu Cloud hasn't answered since the screen came up: "not tracked live" isn't
    ///   said yet (§2).
    static func narrativeFlight(in legs: [TripLeg], flights: [String: MapFlight], at now: Date, isAwaitingLive: Bool) -> NarrativeFlight? {
        guard let leg = legs.first(where: { $0.type == .flight && $0.effectiveStart <= now && now < $0.effectiveEnd }) else { return nil }
        guard let flight = flights[leg.id], !flight.isNotLive(at: now) else {
            let takeoff = FlightProgress.scheduledTakeoff(departure: leg.effectiveStart, arrival: leg.effectiveEnd)
            return now < takeoff ? .dueToTakeOff : .shouldBeFlying(saysNotTracked: !isAwaitingLive)
        }
        if flight.hasLanded(at: now) { return .landed }
        switch flight.seenAtDeparture(at: now) {
        case .atGate: return .atGate
        case .stillAtGate: return .stillAtGate
        case .returned: return .returned
        case .due, nil: return .flying
        }
    }
```

`MapFlight.isAtDeparture(at:)` then has no caller but its test: delete it and its doc, and drop it from `FlightTrackingTests.test_seenAtDeparture_agreesWithIsAtDeparture_andHasReturned` (keep the `hasReturned` check, and rename the test `test_seenAtDeparture_agreesWithHasReturned`).

- [ ] **Step 4: The model hands it on.** In `PartnerStatusReceiver.swift`, replace `isStillOnGround`, `hasReturned` and `isLandedBeforeGate` with:

```swift
    /// How the status sentence tells the flight under way: by its real plane where Crewlu Cloud sees it, else by the
    /// schedule, saying so (live or scheduled design §4). Nil with no flight between its gates.
    private(set) var narrativeFlight: NarrativeFlight?
```

In `resolveAndSchedule()`, replace the four lines from `let atDeparture = …` to `isLandedBeforeGate = …` with
`narrativeFlight = LiveLegs.narrativeFlight(in: legs, flights: flights, at: now, isAwaitingLive: isAwaitingLive)`,
and in `clearLiveFlights()` the three resets become `narrativeFlight = nil`. (With no trip legs the sentence reads as before.)

- [ ] **Step 5: The sentence.** In `NarrativeCardView.swift`, replace the three properties `isStillOnGround`, `hasReturned`, `isLandedBeforeGate` with:

```swift
    /// How the flight under way is told, from the screen's model: by its real plane, else by the schedule, saying so
    /// (live or scheduled design §4). Nil reads as before: flying.
    var narrativeFlight: NarrativeFlight? = nil
```

and in `inFlightNarrative`:
- `isLandedBeforeGate` reads `narrativeFlight == .landed`.
- `isStillOnGround` reads `narrativeFlight == .stillAtGate || narrativeFlight == .returned`, and `atDeparturePhrase` reads `narrativeFlight == .returned`.
- A new branch, after "still on the ground", for `narrativeFlight == .atGate`, with no delay and with one:
  `Text("\(name) is on the ground in \(Text(dep).bold())\(fltStr.isEmpty ? " on the flight" : fltStr) to \(Text(dest).bold()) — landing in \(countdownText(to: …)) which is \(about)\(timeText(arrTimeStr).bold()).")`, with the delayed branch's `countdownColor` and `shiftedArr` as "still on the ground" has them.
- A new branch for `narrativeFlight == .dueToTakeOff`:
  - delayed: `Text("\(name) \(pastPhrase) in \(Text(dep).bold()) and is due to take off\(fltStr.isEmpty ? " on the flight" : fltStr) to \(Text(dest).bold()) — landing in \(countdownText(to: shiftedArr, color: countdownColor)) which is \(about)\(timeText(arrTimeStr).bold()).")`
  - not delayed: `Text("\(name) is due to take off from \(Text(dep).bold())\(fltStr.isEmpty ? " on the flight" : fltStr) to \(Text(dest).bold()) — landing in \(countdownText(to: arrTime)) which is \(about)\(timeText(arrTimeStr).bold()).")`
- The flying sentences, delayed and not, read "\(being)" in place of "is \(verb)" and add `\(untracked)` before " — landing in", with
  ```swift
          // By the schedule alone: "should be flying … — not tracked live —", without "not tracked live" while Crewlu
          // Cloud's first answer is on its way (live or scheduled design §2, §4.1).
          let being: String = if case .shouldBeFlying = narrativeFlight { "should be \(verb)" } else { "is \(verb)" }
          let untracked = narrativeFlight == .shouldBeFlying(saysNotTracked: true) ? " — not tracked live" : ""
  ```
  e.g. `Text("\(name) \(being) to \(Text(dest).bold())\(fltStr) from \(Text(dep).bold())\(untracked) — landing in …")` and `Text("\(name) \(pastPhrase) in \(Text(dep).bold()) and \(being) to \(Text(dest).bold())\(fltStr)\(untracked) — landing in …")`.

Order of the branches, delayed and not: landed, still on the ground (or returned), at the gate, due to take off, then flying (by the real plane or by the schedule). The sentences match the website's `src/copy/narrative.ts` word for word.

- [ ] **Step 6: Pass it through.** `PilotStatusView`: replace its three properties with `var narrativeFlight: NarrativeFlight? = nil` (doc as above), and pass `narrativeFlight: narrativeFlight` to `NarrativeCardView`. Both `PilotStatusView(…)` calls in `ContentView.swift`: replace the three arguments with `narrativeFlight: receiver.narrativeFlight`. Fix any `#Preview` that set the old flags.

- [ ] **Step 7: Their old tests.** In `StillOnGroundTests.swift` and `LandedBeforeGateTests.swift`, the tests of `LiveLegs.stillOnGroundFlight` / `landedFlight` become tests of `narrativeFlight` at the same moments: `"f1"` → `.stillAtGate` (or `.landed`), and `nil` → whatever `narrativeFlight` says at that moment (`.atGate` before the plan's takeoff, `.flying` in the air, `.shouldBeFlying(saysNotTracked: true)` with no live data after the takeoff, and `.dueToTakeOff` or `nil` as the moment has it). Don't drop a case.

---

### Task 8: The old expectations the spec changes

**Files:** the tests named in the file map, and any other the type-check or Todd's run turns up.

No test is run here: read each test that pins one of the changed words or APIs, and change it the way the spec says. The changes (spec section in brackets):
- **No live data, now:** "In flight" → "Not tracked live"; "UPS207 · In flight" → "UPS207 · Not tracked live" [§4.1]. "In the air now" → "By the schedule" [§4.1]. In-flight rows gain a leading `.source` row [§4.1]. Its events, halfway and closest point read "about" ("12 min ago" → "About 12 min ago", "Just now" → "About now", "12 minutes ago" → "about 12 minutes ago") [§5]. The card's "Estimated from the schedule." → "Not tracked live, so it's shown where the schedule has it." [§7]. Under the timeline "Flying to X" → "Should be flying to X", or "Scheduled to fly to X" before the schedule's takeoff [§4].
- **Before the schedule's takeoff, no live data:** "Scheduled to take off about H:MM AM L", "N mi to go", no sky row, no latest event [§4.2].
- **Seen live:** labels gain "Live · " ("Live · 14 min ahead", "Live · Returned to …", "Live · Landed 13 min early", "Live" alone with no label); rows gain a leading "Tracked live" `.source` row; the card's sentence ends "… your time. Tracked live." before any "Latest: …" [§4.1, §7].
- **A real plane at its gate before the plan's takeoff:** "On the ground in {city}"; no sky row; "N mi to go"; halfway and closest "about"; left out of the list; no latest event [§3, §4.2].
- **A replay with no real path:** "By the schedule" in place of "In flight" and "In the air" [§6].
- **APIs:** `MapLeg.isStillOnGround(at:)` → `atDeparture(at:) == .stillAtGate` (or `?.isSeen`); `MapLeg.hasReturned(at:)` → `atDeparture(at:) == .returned`; `TripMap.flightOnGround(at:)` / `TripFacts.flightOnGround(at:)` → `flightNow(at:)`; `FlightOnGround` → `FlightNow`; `stillOnGroundAirport(at:)` is gone; `timelineLine(…, onGround:)` → `flight:`; `TripFacts.isStillOnGround(_:at:)` → `atDeparture(of:at:) != nil`; `atDepartureWords(on:at:)` → `atDepartureWords(_:on:)`.

Rename a test whose name says something now false ("…AsBefore" for a behavior that changed). Where a test can't be explained by one of the changes above, stop and report it: it's a bug in Tasks 1 to 7, not an old expectation. The shared fixtures in `CrewluvTests/Fixtures/TripMap/` don't change.

- [ ] **Step 1:** `grep -rln -e '"In flight"' -e 'In the air now' -e 'Estimated from the schedule' -e 'isStillOnGround' -e 'hasReturned(at' -e 'flightOnGround' -e 'FlightOnGround' -e 'stillOnGroundFlight' -e 'landedFlight(' -e 'onGround:' CrewluvTests` and work through each file.
- [ ] **Step 2:** For every test that reads facts, words or the list of a flight with no live data "now", check whether its expectation now gains "about", a `.source` row, or "By the schedule", and change it.

---

### Task 9: Type-check the app target

- [ ] **Step 1:** Type-check the whole app target once with `swiftc`, as `memory/reference_typecheck_outside_xcode.md` says (copy `Crewluv/**/*.swift` to a scratch folder, list them in `files.txt`, run its `xcrun --sdk iphonesimulator swiftc -typecheck …` command). Expected: no errors, no warnings. Fix any error, then run it once more.
- [ ] **Step 2:** `grep -rn "isStillOnGround\|isLandedBeforeGate\|stillOnGroundFlight\|landedFlight(\|FlightOnGround\|flightOnGround\|stillOnGroundAirport" Crewluv CrewluvTests` shows nothing but `MapLeg.isLandedBeforeGate(at:)`, `TripFacts.isLandedBeforeGate(_:at:)` and their callers.

---

### Task 10: Hand off to Todd

- [ ] **Step 1:** Report what changed, and that the app target type-checks (the test target wasn't compiled).
- [ ] **Step 2:** Ask Todd to run the tests in Xcode (⌘U), or the live-or-scheduled ones alone:

```bash
xcodebuild test -project Crewluv.xcodeproj -scheme Crewluv -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:CrewluvTests/FlightTrackingTests -only-testing:CrewluvTests/LiveOrScheduledWordsTests -only-testing:CrewluvTests/LiveOrScheduledFactsTests -only-testing:CrewluvTests/NarrativeFlightTests -only-testing:CrewluvTests/LiveFlightSourceTests
```

and to look at the map in the simulator on a flight with no live data (the demo's in-flight scene), at the largest text size for the card's bar. Fix what his run turns up, one failure at a time.
- [ ] **Step 3:** Commit nothing until Todd says. When he does, the spec (`docs/superpowers/specs/2026-11-25-crewluve-live-or-scheduled-design.md`) and this plan go in the same branch, and a release note goes to the "Crewluve revisions" Apple Note (`memory/feedback_release_notes.md`).
