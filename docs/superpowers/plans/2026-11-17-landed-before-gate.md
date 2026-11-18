# Landed, Not Yet at the Gate (Crewluve App) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** For the few minutes between touchdown and the gate, a flight with live data reads "Landed in Anchorage" in the app, now only, as it does on the website: in the facts, the list's tag, the line under the timeline, the card's bar ("At the gate 8:47 AM") and the status sentence.

**Architecture:**
- **The moment,** as "Still on the ground in Rockford" has its own (which plane design §4): `MapFlight.hasLanded` (Crewlu Cloud's state "landed"), `MapLeg.isLandedBeforeGate` (and the leg is between its gates, before `end`, the real plane's gate arrival), `TripMap.landedAirport` for the line under the timeline, and `LiveLegs.landedFlight` for the status sentence.
- **The facts:** `TripFacts.isLandedBeforeGate` (and the facts aren't a replay's) leads the headline, makes the first row "Landed in Anchorage" alone, leaves out the sky row, says "2,788 mi flown" and "Reaches the gate at …" (`TripMapWording.gateLine`), and tags the list's flight "Landed".
- **The rest:** the line under the timeline (`landedIn`, through `FactsSheet`, `FactsPanel`, `FactsHeader` and `TripTimelineControl`), the card's bar (`TripMapWording.barArrival`, handed to `TripMapInFlightBar`), and the status sentence (`PartnerStatusReceiver.isLandedBeforeGate`, through `ContentView` and `PilotStatusView` to `NarrativeCardView`). Two previews show it.

**Tech Stack:** Swift 5 language mode, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, iOS 26, SwiftUI, XCTest.

**Sources:**
- **The design** (Todd, 17 Nov 2026, "A: 'Landed in Anchorage'", and his two answers: "at", not "about", and the bar's "At the gate 8:47 AM"): the website's `docs/superpowers/specs/2026-11-17-landed-before-gate-design.md` (Crewluve Website repo, `329ce7a`), copied into this repo by Task 5 with §6 for where its words go in the app.
- **The website's plan** for the same words, `docs/superpowers/plans/2026-11-17-website-landed-before-gate.md` there, live on crewluve.crewlu.net since 17 Nov 2026.
- **The model:** the app's "still on the ground" (which plane plan, `docs/superpowers/plans/2026-11-16-which-plane-and-the-gate.md`), the other end of the flight. This plan's names and tests follow its.

**How this plan was checked.**
- **A scratch Swift package** with the app target's settings, made from the repo at `4186f60`: 596 XCTest and 71 Swift Testing tests before, 611 and 71 with this plan, all passing, no warnings.
- **Task by task:** the package was run as it stood after each of Tasks 2 to 4, all passing: 602 XCTest tests after Task 2, 609 after Task 3 and 611 after Task 4.
- **24 deliberate breaks** were made in the new code, one at a time, and every one fails at least one test: any live phase called landed, or a diversion; landed after the gate; landed in the departure airport; the status's flight after its gate, or the one still at its gate; landed in a replay, or the timeline's airport in one; the headline keeping what's below or naming the departure; the list keeping "In the air now"; the first row keeping what's below or closest to home; the sky row kept; "0 to go" kept, in the row or the words; the landing row keeping "Lands"; "Landed at"; the tag "Landed now"; the gate always "about", or without the city's time; the timeline keeping "Flying to"; and the bar keeping "Lands", or saying "At the gate" after the gate.
- **The whole app was type-checked for iOS** with `swiftc` outside Xcode after each task, and compiled for the iOS simulator with the whole plan in: no errors and no warnings. The views, the status sentence and the previews are checked that way only.
- **The plan was followed by a script** on the repo at `4186f60`: all 25 files came out the same as the tested ones.
- **Reviewed** by `superpowers:code-reviewer` (sonnet) before the plan was put together: nothing critical. From its points: a plane last seen on the ground away from its arrival airport isn't "Landed in Anchorage" (`MapFlight.hasLanded`, with a test), since it landed somewhere else; the status sentence is one function, `landedSentence`, used by both its branches; and the design's copy says its card-heading row is the website's only. Left, with reasons: the line under the timeline takes a second airport beside "still on the ground"'s, as the website's does, where one enum would be neater, for a later tidy; and the window, only minutes wide, goes by this device's clock against Crewlu Cloud's gate time, as every live label does.
- **Not checked:** nothing ran on a simulator or a device, and no view was seen.

**Where this plan settles details.**
- **"at", not "about",** as Todd chose for the website: "Reaches the gate at 3:52 PM · 7:52 PM your time", and "— at the gate in 8m which is 7:52pm EST." `gateLine` keeps "about" where the time is the real plane's estimate, as the popup does, which once down it never is.
- **"Landed in Anchorage" leads the headline,** ahead of a crossing in the last five minutes or a sun countdown, as "Still on the ground in Rockford" does. The latest event's banner still shows the crossing until the gate.
- **The first row is "Landed in Anchorage" alone:** nothing of what's below, where the plane was last tracked or the closest point to home.
- **The distance row keeps its comparison line;** its halfway line has gone by then.
- **The card's bottom chip** is the facts' headline, so it says "Landed in Anchorage" with no change of its own.
- **The card has no heading of its own,** unlike the website's: its VoiceOver label is the card's sentence, which the design leaves as it is.
- **The status sentence** keeps a delayed or early flight's red or green countdown, as "still on the ground" does, and says "on the flight" with no flight number.
- **The line under the timeline** reads "Landed in Anchorage" where it read "Flying to Anchorage", and its spoken value "…, landed in Anchorage". It's handed in beside "still on the ground"'s airport, as the website's `landedIn` is.
- **Two previews,** "Real plane, landed, not yet at the gate" on the card and full screen, in place of the website's demo scene: down in Cologne 2 minutes before the preview opens, at the gate 5 minutes after.

---

## Ground rules

1. **Don't run `xcodebuild` build or test loops.** Todd runs the tests (Task 6).
2. **Never commit without Todd's go-ahead,** and then only this plan's files, by path. **Never push** without a fresh yes.
3. **Copy the code as written.** A replacement is exact: if its text isn't in the file once, stop.
4. **Work on `feature/trip-map-live`.** Never stash, reset or switch branches.

## File map

| File | Task | What changes |
|---|---|---|
| `Crewluv/Services/TripMap/Live/MapFlight.swift`, `Crewluv/Services/TripMap/MapLeg.swift`, `TripMap+Activity.swift`, `Crewluv/Services/TripMap/Live/LiveLegs.swift` | 2 | when it is |
| `Crewluv/Services/TripMap/Facts/FactsWording.swift`, `TripFacts.swift`, `TripFacts+Rows.swift`, `TripSoFar.swift`, `Crewluv/Services/TripMap/TripMapWording.swift` | 3 | the facts and the list |
| `Crewluv/Services/TripMap/TripMapWording.swift`, `Crewluv/Views/TripMap/TripTimelineControl.swift`, `FactsHeader.swift`, `FactsPanel.swift`, `FactsSheet.swift`, `TripMapInFlightBar.swift`, `TripMapCard.swift`, `TripMapPreviews.swift`, `Crewluv/Services/PartnerStatusReceiver.swift`, `Crewluv/Views/Welcome/ContentView.swift`, `Crewluv/Views/Status/PilotStatusView.swift`, `NarrativeCardView.swift` | 4 | the timeline, the card's bar, the status sentence and the previews |
| `CrewluvTests/LandedBeforeGateTests.swift`, `LandedBeforeGateFactsTests.swift`, `LandedBeforeGateWordsTests.swift` (new) | 2, 3, 4 | the tests |
| `CLAUDE.md`, `docs/superpowers/specs/2026-11-17-landed-before-gate-design.md` (new) | 5 | the docs |

---

### Task 1: Before starting

- [x] **Step 1:** The branch is `feature/trip-map-live`, at `4186f60` or later, and none of this plan's files has changed since.

```bash
git -C /Users/toddanderson/Dev/Crewluv status --short && git -C /Users/toddanderson/Dev/Crewluv branch --show-current && git -C /Users/toddanderson/Dev/Crewluv log --oneline -1
```

---

### Task 2: When it is (design §2)

- [x] **Step 1: The tests.**

Create `CrewluvTests/LandedBeforeGateTests.swift`:

```swift
//
//  LandedBeforeGateTests.swift
//  CrewluvTests
//
//  When a real plane is down at its arrival airport and not yet at the gate (landed before the gate design §2). The
//  flight is `FactsTestData`'s equator flight, from E0 to E20: its real plane is seen down at E20 at 12:55 UTC and
//  reaches the gate at 13:02, the plan's 7 minutes of taxi in later.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class LandedBeforeGateTests: XCTestCase {

    private func at(_ time: String) -> Date { FactsTestData.date("2026-03-20T\(time):00Z") }

    /// The equator flight with its real plane down at E20 since 12:55, as the status screen's model hands it on at `now`.
    private func landed(at now: String) throws -> MapLeg {
        let live = FactsTestData.equatorLive(seenUntil: at("12:53"), landedAt: FactsTestData.liveTime(atLongitude: 20))
        return try FactsTestData.equatorLiveLeg(live, at: at(now))
    }

    private func map(of leg: MapLeg) -> TripMap {
        TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: leg.origin,
                span: DateInterval(start: leg.start, end: leg.end), tripDays: nil)
    }

    // MARK: - When it is

    func test_isLandedBeforeGate_fromTouchdownUntilTheGate() throws {
        XCTAssertTrue(try landed(at: "12:56").isLandedBeforeGate(at: at("12:56")))
        XCTAssertTrue(try landed(at: "13:01").isLandedBeforeGate(at: at("13:01")))
        XCTAssertFalse(try landed(at: "13:02").isLandedBeforeGate(at: at("13:02")), "at the gate")
    }

    func test_isLandedBeforeGate_isNeverAPlaneInTheAir_aFlightWithNoLiveData_norADrive() throws {
        let flying = try FactsTestData.equatorLiveLeg(FactsTestData.equatorLive(seenUntil: at("12:30")), at: at("12:30"))
        XCTAssertFalse(flying.isLandedBeforeGate(at: at("12:30")))
        XCTAssertFalse(try FactsTestData.equatorLiveLeg(nil, at: at("12:58")).isLandedBeforeGate(at: at("12:58")))
        let leg = try landed(at: "12:58")
        let drive = MapLeg(id: "d1", kind: .drive, origin: leg.origin, destination: leg.destination, start: leg.start, end: leg.end,
                           flightNumber: nil)
        XCTAssertFalse(drive.isLandedBeforeGate(at: at("12:58")))
    }

    func test_hasLanded_isCrewluCloudsLanded() throws {
        let flight = try XCTUnwrap(try landed(at: "12:58").flight)
        XCTAssertTrue(flight.hasLanded(at: at("12:58")))
        XCTAssertTrue(flight.hasLanded(at: at("13:30")), "after the gate too: the leg's gates bound the words")
        let flying = try XCTUnwrap(try FactsTestData.equatorLiveLeg(FactsTestData.equatorLive(seenUntil: at("12:30")), at: at("12:30")).flight)
        XCTAssertFalse(flying.hasLanded(at: at("12:30")))
    }

    func test_hasLanded_isFalse_forAPlaneSeenOnTheGroundAwayFromItsArrivalAirport() throws {
        // Down at 18° E, 120 nm short of E20: it landed somewhere else, which nothing names.
        let fix = LiveFlight.Fix(latitude: 0, longitude: 18, altitudeFeet: nil, groundSpeedKnots: 20, trackDegrees: nil,
                                 isOnGround: true, registration: "N370UP", typeCode: "B763", seenAt: at("12:55"))
        let elsewhere = LiveFlight(legID: "eq", callsign: "TST1", state: .landed, fix: fix, landedAt: at("12:55"),
                                   trail: FactsTestData.equatorLive(seenUntil: at("12:39")).trail)
        let leg = try FactsTestData.equatorLiveLeg(elsewhere, at: at("12:58"))
        XCTAssertFalse(try XCTUnwrap(leg.flight).hasLanded(at: at("12:58")))
        XCTAssertFalse(leg.isLandedBeforeGate(at: at("12:58")))
    }

    func test_landedAirport_isTheFlightsArrivalAirport_untilTheGate() throws {
        let leg = try landed(at: "12:58")
        XCTAssertEqual(map(of: leg).landedAirport(at: at("12:58"))?.code, "E20")
        XCTAssertNil(map(of: leg).landedAirport(at: at("13:02")), "at the gate")
        let flying = try FactsTestData.equatorLiveLeg(FactsTestData.equatorLive(seenUntil: at("12:30")), at: at("12:30"))
        XCTAssertNil(map(of: flying).landedAirport(at: at("12:30")))
    }

    func test_landedFlight_isTheFlightBetweenItsGatesWhoseRealPlaneIsDown_byItsID() throws {
        let cases = try TripMapFixtures.liveCases()
        let landed = try cases.flight(named: "landed, seen all the way")
        let flights = ["f1": try cases.mapFlight(landed)]
        let gate = try XCTUnwrap(flights["f1"]?.progress(at: try cases.moment("13T13:30:00", of: landed).at).liveArrival)
        func flight(at now: Date) -> String? {
            let legs = LiveLegs.replacingTimes(in: [cases.tripLeg(landed)], with: flights, at: now)
            return LiveLegs.landedFlight(in: legs, flights: flights, at: now)
        }
        XCTAssertEqual(flight(at: gate.addingTimeInterval(-60)), "f1")
        XCTAssertNil(flight(at: gate), "at the gate")
        XCTAssertNil(LiveLegs.landedFlight(in: [cases.tripLeg(landed)], flights: [:], at: gate.addingTimeInterval(-60)))

        let flying = try cases.flight(named: "ahead, in the air")
        let now = try cases.moment("13T12:41:50", of: flying).at
        let flyingFlights = ["f1": try cases.mapFlight(flying)]
        let legs = LiveLegs.replacingTimes(in: [cases.tripLeg(flying)], with: flyingFlights, at: now)
        XCTAssertNil(LiveLegs.landedFlight(in: legs, flights: flyingFlights, at: now))
    }
}
```

- [x] **Step 2: The real plane is down.**

In `Crewluv/Services/TripMap/Live/MapFlight.swift`:

Replace:

```swift
        guard progress.phase == .onGround, case .stillOnGround = progress.label else { return false }
        return true
    }
```

with:

```swift
        guard progress.phase == .onGround, case .stillOnGround = progress.label else { return false }
        return true
    }

    /// Whether the real plane is down at its arrival airport, by Crewlu Cloud's state, when this device's clock says
    /// `now` (spec §5.1's `landed`). Until the gate, the facts and the status say "Landed in Anchorage" (landed before
    /// the gate design §2). A plane last seen on the ground away from it landed somewhere else, which nothing names.
    func hasLanded(at now: Date) -> Bool {
        guard progress(at: now).phase == .landed else { return false }
        guard let fix = live?.fix, fix.isOnGround else { return true }
        return GreatCircle.distance(from: fix.coordinate, to: path.destination) <= LiveProgress.airportRadius
    }
```

In `Crewluv/Services/TripMap/MapLeg.swift`:

Replace:

```swift
    func isStillOnGround(at date: Date) -> Bool {
        isMoving(at: date) && (flight?.isAtDeparture(at: date) ?? false)
    }
```

with:

```swift
    func isStillOnGround(at date: Date) -> Bool {
        isMoving(at: date) && (flight?.isAtDeparture(at: date) ?? false)
    }

    /// Whether the flight is between its gates at `date` with its real plane already down (`MapFlight.hasLanded`):
    /// landed, and not yet at the gate (landed before the gate design §2).
    func isLandedBeforeGate(at date: Date) -> Bool {
        isMoving(at: date) && (flight?.hasLanded(at: date) ?? false)
    }
```

- [x] **Step 3: Where, for the timeline, and which flight, for the status sentence.**

In `Crewluv/Services/TripMap/TripMap+Activity.swift`:

Replace:

```swift
        guard let flight = flightInMotion(at: date), flight.isStillOnGround(at: date) else { return nil }
        return flight.origin
    }
```

with:

```swift
        guard let flight = flightInMotion(at: date), flight.isStillOnGround(at: date) else { return nil }
        return flight.origin
    }

    /// The arrival airport of the flight between its gates at `date` whose real plane has landed there, before the
    /// gate: the line under the timeline says "Landed in" it in place of "Flying to" (landed before the gate design §3).
    /// Nil otherwise. A replay's moment is where the map has the plane, so the facts ask this only of now.
    func landedAirport(at date: Date) -> AirportMark? {
        guard let flight = flightInMotion(at: date), flight.isLandedBeforeGate(at: date) else { return nil }
        return flight.destination
    }
```

In `Crewluv/Services/TripMap/Live/LiveLegs.swift`:

Replace:

```swift
                && (flights[leg.id]?.isAtDeparture(at: now) ?? false)
        }?.id
    }
```

with:

```swift
                && (flights[leg.id]?.isAtDeparture(at: now) ?? false)
        }?.id
    }

    /// The flight between its gates at `now` whose real plane has landed, by its leg's id: the status sentence says so
    /// (landed before the gate design §3). Nil with no such flight.
    static func landedFlight(in legs: [TripLeg], flights: [String: MapFlight], at now: Date) -> String? {
        guard !flights.isEmpty else { return nil }
        return legs.first { leg in
            leg.type == .flight && leg.effectiveStart <= now && now < leg.effectiveEnd
                && (flights[leg.id]?.hasLanded(at: now) ?? false)
        }?.id
    }
```

---

### Task 3: The facts and the list (design §3)

- [x] **Step 1: The tests.**

Create `CrewluvTests/LandedBeforeGateFactsTests.swift`:

```swift
//
//  LandedBeforeGateFactsTests.swift
//  CrewluvTests
//
//  The facts and the list of a flight whose real plane is down at its arrival airport and not yet at the gate
//  (landed before the gate design §3), in US English for a family in Louisville. The flight is `FactsTestData`'s
//  equator flight, from E0 to E20, 1,382 mi: its real plane is seen down at E20 at 12:55 UTC and reaches the gate at
//  13:02, which is 9:02 AM in Louisville.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class LandedBeforeGateFactsTests: XCTestCase {

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

    /// The facts of a map of the one flight, its real plane down at E20 since 12:55, made at `now`. A cockpit sunset
    /// at 13:20 stands in for the sky, so its row would show if it weren't left out.
    private func facts(landedAt now: String, isReplay: Bool = false) throws -> TripFacts {
        let live = FactsTestData.equatorLive(seenUntil: at("12:53"), landedAt: FactsTestData.liveTime(atLongitude: 20))
        let leg = try FactsTestData.equatorLiveLeg(live, at: at(now))
        let home = FactsTestData.homeByTheEquator
        let map = TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: home,
                          span: DateInterval(start: leg.start, end: leg.end), tripDays: nil)
        return TripFacts(tripMap: map, geography: FactsTestData.equator, comparisons: try FactsTestData.appComparisons(),
                         stories: [leg.id: LegStory(leg: leg, geography: FactsTestData.equator, home: home)],
                         sunEvents: [leg.id: [SkyFacts.SunEvent(kind: .sunset, time: at("13:20"), peopleBelowGap: nil)]],
                         dayNumber: 1, totalDays: 1,
                         calendar: calendar, locale: locale, isReplay: isReplay)
    }

    private func row(_ kind: FactRow.Kind, in rows: [FactRow]) throws -> FactRow {
        try XCTUnwrap(rows.first { $0.kind == kind }, "no \(kind) row")
    }

    // MARK: - The headline and the rows

    func test_headline_saysWhereItLanded() throws {
        XCTAssertEqual(try facts(landedAt: "12:58").headline(at: at("12:58")), "Landed in E20")
        XCTAssertEqual(try facts(landedAt: "12:58").sheetHeadline(at: at("12:58")), "Landed in E20")
    }

    func test_rows_sayItLanded_howFarItFlew_andWhenItReachesTheGate_withNoSky() throws {
        let rows = try facts(landedAt: "12:58").rows(at: at("12:58"), now: at("12:58"))
        XCTAssertEqual(rows.map(\.kind), [.below, .plane, .distance, .headed])
        let below = try row(.below, in: rows)
        XCTAssertEqual(below.title, "Landed in E20")
        XCTAssertNil(below.detail, "nothing of what's below, or of home")
        XCTAssertEqual(try row(.distance, in: rows).title, "1,382 mi flown")
        XCTAssertEqual(plain(try row(.headed, in: rows).title), "Reaches the gate at 9:02 AM")
        XCTAssertEqual(try row(.plane, in: rows).title, "Boeing 767-300 · N370UP")
        XCTAssertNil(try row(.plane, in: rows).detail, "no height or speed on the ground")
    }

    func test_inAReplay_theFactsReadWhereTheMapHasThePlane_asBefore() throws {
        let replay = try facts(landedAt: "12:58", isReplay: true)
        let rows = replay.rows(at: at("12:58"), now: at("12:58"))
        XCTAssertTrue(rows.contains { $0.kind == .sky }, "the sky row, as before")
        XCTAssertEqual(try row(.distance, in: rows).title, "1,382 mi flown · 0 to go")
        XCTAssertTrue(try XCTUnwrap(plain(try row(.headed, in: rows).title)).hasPrefix("Lands E20"))
        XCTAssertNil(replay.landedAirport(at: at("12:58")))
    }

    // MARK: - The list

    func test_tripSoFar_tagsTheFlight_landed_untilTheGate() throws {
        XCTAssertEqual(try facts(landedAt: "12:58").tripSoFar(at: at("12:58")).flights.map(\.tag), ["Landed"])
        XCTAssertEqual(try facts(landedAt: "12:58", isReplay: true).tripSoFar(at: at("12:58")).flights.map(\.tag), ["In the air"])
        XCTAssertEqual(try facts(landedAt: "13:03").tripSoFar(at: at("13:03")).flights.map(\.tag), [nil], "at the gate")
    }

    func test_landedAirport_isTheArrivalAirport_now() throws {
        XCTAssertEqual(try facts(landedAt: "12:58").landedAirport(at: at("12:58"))?.code, "E20")
    }

    // MARK: - The words

    func test_factsWords_sayItLanded_andHowFarItFlew() {
        let anchorage = AirportMark(code: "ANC", city: "Anchorage", coordinate: CLLocationCoordinate2D(latitude: 61.2, longitude: -150.0),
                                    timeZone: TimeZone(identifier: "America/Anchorage"))
        XCTAssertEqual(FactsWording.landed(in: anchorage), "Landed in Anchorage")
        XCTAssertEqual(FactsWording.flown(miles: 2_788, locale: locale), "2,788 mi flown")
        XCTAssertEqual(FactsWording.landedTag, "Landed")
    }

    func test_gateLine_saysAt_inTheCitysTimeAndTheFamilys() {
        let louisville = AirportMark(code: "SDF", city: "Louisville", coordinate: CLLocationCoordinate2D(latitude: 38.2, longitude: -85.7),
                                     timeZone: TimeZone(identifier: "America/New_York"))
        let anchorage = AirportMark(code: "ANC", city: "Anchorage", coordinate: CLLocationCoordinate2D(latitude: 61.2, longitude: -150.0),
                                    timeZone: TimeZone(identifier: "America/Anchorage"))
        // At the gate at 00:52 UTC: 3:52 PM in Anchorage, 7:52 PM in Louisville.
        let end = FactsTestData.date("2026-11-14T00:52:00Z")
        let toAnchorage = MapLeg(id: "f1", kind: .flight, origin: louisville, destination: anchorage,
                                 start: end.addingTimeInterval(-6 * 3600), end: end, flightNumber: "UPS2963")
        XCTAssertEqual(plain(TripMapWording.gateLine(for: toAnchorage, calendar: calendar, locale: locale)),
                       "Reaches the gate at 3:52 PM · 7:52 PM your time")
        let home = MapLeg(id: "f2", kind: .flight, origin: anchorage, destination: louisville,
                          start: end.addingTimeInterval(-6 * 3600), end: end, flightNumber: "UPS2964")
        XCTAssertEqual(plain(TripMapWording.gateLine(for: home, calendar: calendar, locale: locale)), "Reaches the gate at 7:52 PM")
    }
}
```

- [x] **Step 2: The words.**

In `Crewluv/Services/TripMap/Facts/FactsWording.swift`:

Replace:

```swift
    static func stillOnGround(in airport: AirportMark) -> String {
        "Still on the ground in \(airport.name)"
    }
```

with:

```swift
    static func stillOnGround(in airport: AirportMark) -> String {
        "Still on the ground in \(airport.name)"
    }

    /// "Landed in Anchorage": the real plane is down, and not yet at the gate (landed before the gate design §3).
    static func landed(in airport: AirportMark) -> String {
        "Landed in \(airport.name)"
    }

    /// The list's tag on the flight between its gates once its real plane is down.
    static let landedTag = "Landed"
```

Replace:

```swift
    static func toGo(miles: Int, locale: Locale = .current) -> String {
        "\(number(miles, locale: locale)) mi to go"
    }
```

with:

```swift
    static func toGo(miles: Int, locale: Locale = .current) -> String {
        "\(number(miles, locale: locale)) mi to go"
    }

    /// "2,788 mi flown": the whole of it, once the real plane is down (landed before the gate design §3).
    static func flown(miles: Int, locale: Locale = .current) -> String {
        "\(number(miles, locale: locale)) mi flown"
    }
```

In `Crewluv/Services/TripMap/TripMapWording.swift`:

Replace:

```swift
    /// "Lands 3:30 PM", for the card's bar. With the real plane's estimate, "Lands about 3:18 PM".
```

with:

```swift
    /// "Reaches the gate at 3:52 PM · 7:52 PM your time", or one time where the destination keeps the family's: the
    /// facts' landing row once the real plane is down (landed before the gate design §3). "at", as the card's sentence
    /// and the plane's popup say it, unless the time is the real plane's estimate.
    static func gateLine(for leg: MapLeg, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let when = about(leg).isEmpty ? "at " : about(leg)
        let yours = clockTime(leg.end, in: calendar.timeZone, locale: locale)
        guard let there = arrivalLocalClock(for: leg, calendar: calendar, locale: locale) else {
            return "Reaches the gate \(when)\(yours)"
        }
        return "Reaches the gate \(when)\(there) · \(yours) your time"
    }

    /// "Lands 3:30 PM", for the card's bar. With the real plane's estimate, "Lands about 3:18 PM".
```

- [x] **Step 3: The headline and the list.**

In `Crewluv/Services/TripMap/Facts/TripFacts.swift`:

Replace:

```swift
    /// in Rockford", ahead of all of them: it has crossed nothing yet, whatever the schedule's times say (which plane
    /// design §4).
```

with:

```swift
    /// in Rockford", ahead of all of them: it has crossed nothing yet, whatever the schedule's times say (which plane
    /// design §4). Once it's down at the arrival airport, before the gate, "Landed in Anchorage" leads in the same way
    /// (landed before the gate design §3).
```

Replace:

```swift
        if isStillOnGround(leg, at: date) {
            return FactsWording.stillOnGround(in: leg.origin)
        }
```

with:

```swift
        if isStillOnGround(leg, at: date) {
            return FactsWording.stillOnGround(in: leg.origin)
        }
        if isLandedBeforeGate(leg, at: date) {
            return FactsWording.landed(in: leg.destination)
        }
```

Replace:

```swift
    func stillOnGroundAirport(at date: Date) -> AirportMark? {
        isReplay ? nil : tripMap.stillOnGroundAirport(at: date)
    }
```

with:

```swift
    func stillOnGroundAirport(at date: Date) -> AirportMark? {
        isReplay ? nil : tripMap.stillOnGroundAirport(at: date)
    }

    /// Whether the real plane of `leg`, the leg between its gates at `date`, has landed and isn't at the gate yet
    /// (landed before the gate design §2). The facts then say "Landed in Anchorage" in place of what's below, and the
    /// list's tag says "Landed". Now only: a replay reads where the map has the plane.
    func isLandedBeforeGate(_ leg: MapLeg, at date: Date) -> Bool {
        !isReplay && leg.isLandedBeforeGate(at: date)
    }

    /// The arrival airport where the flight between its gates at `date` has landed, before the gate: the line under
    /// the timeline names it (landed before the gate design §3). Nil in a replay.
    func landedAirport(at date: Date) -> AirportMark? {
        isReplay ? nil : tripMap.landedAirport(at: date)
    }
```

Replace:

```swift
            let tag = leg.isMoving(at: date) ? FactsWording.inTheAir(isReplay: isReplay) : nil
```

with:

```swift
            let tag = leg.isMoving(at: date)
                ? (isLandedBeforeGate(leg, at: date) ? FactsWording.landedTag : FactsWording.inTheAir(isReplay: isReplay))
                : nil
```

In `Crewluv/Services/TripMap/Facts/TripSoFar.swift`:

Replace:

```swift
        /// "In the air now" for the flight between its gates, which the list sets apart. Nil for any other.
```

with:

```swift
        /// "In the air now" for the flight between its gates, which the list sets apart, or "Landed" once its real
        /// plane is down (landed before the gate design §3). Nil for any other.
```

- [x] **Step 4: The rows.**

In `Crewluv/Services/TripMap/Facts/TripFacts+Rows.swift`:

Replace:

```swift
        return [belowRow(on: leg, at: date), planeRow(on: leg, plane: plane), skyRow(on: leg, at: date),
                distanceRow(on: leg, plane: plane, at: date), headedRow(on: leg, now: now)]
```

with:

```swift
        return [belowRow(on: leg, at: date), planeRow(on: leg, plane: plane), skyRow(on: leg, at: date),
                distanceRow(on: leg, plane: plane, at: date), headedRow(on: leg, at: date, now: now)]
```

Replace:

```swift
    /// what's below (which plane design §4).
    private func belowRow(on leg: MapLeg, at date: Date) -> FactRow? {
```

with:

```swift
    /// what's below (which plane design §4). A real plane down at the arrival airport before the gate says that alone
    /// (landed before the gate design §3).
    private func belowRow(on leg: MapLeg, at date: Date) -> FactRow? {
        if isLandedBeforeGate(leg, at: date) {
            return FactRow(.below, symbol: "mappin.and.ellipse", title: FactsWording.landed(in: leg.destination))
        }
```

Replace:

```swift
    /// be the schedule's, for a plane that hasn't left (which plane design §4).
    private func skyRow(on leg: MapLeg, at date: Date) -> FactRow? {
        guard !isStillOnGround(leg, at: date) else { return nil }
```

with:

```swift
    /// be the schedule's, for a plane that hasn't left (which plane design §4). Left out too once the real plane is
    /// down, before the gate (landed before the gate design §3).
    private func skyRow(on leg: MapLeg, at date: Date) -> FactRow? {
        guard !isStillOnGround(leg, at: date), !isLandedBeforeGate(leg, at: date) else { return nil }
```

Replace:

```swift
    /// takeoff that hasn't happened, "about" (which plane design §4).
```

with:

```swift
    /// takeoff that hasn't happened, "about" (which plane design §4). Once it's down, before the gate, "2,788 mi
    /// flown", with nothing to go (landed before the gate design §3).
```

Replace:

```swift
        let title = isOnGround
            ? FactsWording.toGo(miles: Int(totalMiles.rounded()), locale: locale)
            : FactsWording.distance(flownMiles: flown, toGoMiles: Int(totalMiles.rounded()) - flown, locale: locale)
```

with:

```swift
        let title = if isOnGround {
            FactsWording.toGo(miles: Int(totalMiles.rounded()), locale: locale)
        } else if isLandedBeforeGate(leg, at: date) {
            FactsWording.flown(miles: flown, locale: locale)
        } else {
            FactsWording.distance(flownMiles: flown, toGoMiles: Int(totalMiles.rounded()) - flown, locale: locale)
        }
```

Replace:

```swift
    private func headedRow(on leg: MapLeg, now: Date) -> FactRow {
        let landingWeather = forecast(for: leg, now: now)
        return FactRow(.headed, symbol: "airplane.arrival",
                       title: TripMapWording.landingLine(for: leg, calendar: calendar, locale: locale),
```

with:

```swift
    /// "Lands Cologne 9:30 PM · 3:30 PM your time", or once the real plane is down, before the gate, "Reaches the gate
    /// at 9:30 PM · 3:30 PM your time" (landed before the gate design §3).
    private func headedRow(on leg: MapLeg, at date: Date, now: Date) -> FactRow {
        let landingWeather = forecast(for: leg, now: now)
        let title = isLandedBeforeGate(leg, at: date)
            ? TripMapWording.gateLine(for: leg, calendar: calendar, locale: locale)
            : TripMapWording.landingLine(for: leg, calendar: calendar, locale: locale)
        return FactRow(.headed, symbol: "airplane.arrival",
                       title: title,
```

---

### Task 4: The timeline, the card's bar and the status sentence (design §3)

- [x] **Step 1: The tests.**

Create `CrewluvTests/LandedBeforeGateWordsTests.swift`:

```swift
//
//  LandedBeforeGateWordsTests.swift
//  CrewluvTests
//
//  The line under the timeline and the card's bar once a real plane is down at its arrival airport, before the gate
//  (landed before the gate design §3), in US English for a family in Louisville.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class LandedBeforeGateWordsTests: XCTestCase {

    private let locale = Locale(identifier: "en_US")
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private func at(_ time: String) -> Date { FactsTestData.date("2026-03-20T\(time):00Z") }

    private func plain(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{202F}", with: " ")
    }

    private let anchorage = AirportMark(code: "ANC", city: "Anchorage", coordinate: CLLocationCoordinate2D(latitude: 61.2, longitude: -150.0),
                                        timeZone: TimeZone(identifier: "America/Anchorage"))

    func test_timeline_saysWhereTheRealPlaneLanded_inPlaceOfFlying() {
        // 12:45 AM UTC on the 14th is 7:45 PM on the 13th in Louisville.
        let date = FactsTestData.date("2026-11-14T00:45:00Z")
        let flying = TripActivity(kind: .flying, place: anchorage)
        XCTAssertEqual(plain(TripMapWording.timelineLine(date, activity: flying, landedIn: anchorage, calendar: calendar, locale: locale)),
                       "Fri 7:45 PM · Landed in Anchorage")
        XCTAssertEqual(plain(TripMapWording.timelineSpokenValue(date, activity: flying, landedIn: anchorage, calendar: calendar, locale: locale)),
                       "Friday 7:45 PM, landed in Anchorage")
        XCTAssertEqual(plain(TripMapWording.timelineLine(date, activity: flying, calendar: calendar, locale: locale)),
                       "Fri 7:45 PM · Flying to Anchorage", "without it, flying, as before")
    }

    func test_barArrival_saysAtTheGate_onceTheRealPlaneIsDown_untilTheGate() throws {
        // Down at E20 at 12:55 UTC; at the gate at 13:02, 9:02 AM in Louisville.
        let live = FactsTestData.equatorLive(seenUntil: at("12:53"), landedAt: FactsTestData.liveTime(atLongitude: 20))
        let landed = try FactsTestData.equatorLiveLeg(live, at: at("12:58"))
        XCTAssertEqual(plain(TripMapWording.barArrival(for: landed, at: at("12:58"), calendar: calendar, locale: locale)), "At the gate 9:02 AM")
        XCTAssertEqual(plain(TripMapWording.barArrival(for: landed, at: at("13:02"), calendar: calendar, locale: locale)), "Lands 9:02 AM",
                       "at the gate, as before")
        let flying = try FactsTestData.equatorLiveLeg(FactsTestData.equatorLive(seenUntil: at("12:30")), at: at("12:30"))
        XCTAssertEqual(TripMapWording.barArrival(for: flying, at: at("12:30"), calendar: calendar, locale: locale),
                       TripMapWording.landsAt(for: flying, calendar: calendar, locale: locale))
    }
}
```

- [x] **Step 2: The words.**

In `Crewluv/Services/TripMap/TripMapWording.swift`:

Replace:

```swift
    /// While the flight's real plane is still on the ground at its departure airport, `stillOnGroundIn`: "Mon 12:21 PM
    /// · On the ground in Rockford".
    static func timelineLine(_ date: Date, activity: TripActivity?, stillOnGroundIn airport: AirportMark? = nil,
                             calendar: Calendar = .current, locale: Locale = .current) -> String {
        let time = timelineTime(date, calendar: calendar, locale: locale)
        guard let words = timelineWords(activity, stillOnGroundIn: airport) else { return time }
```

with:

```swift
    /// While the flight's real plane is still on the ground at its departure airport, `stillOnGroundIn`: "Mon 12:21 PM
    /// · On the ground in Rockford". Once it's down at the arrival airport, before the gate, `landedIn`: "Mon 7:45 PM ·
    /// Landed in Anchorage".
    static func timelineLine(_ date: Date, activity: TripActivity?, stillOnGroundIn airport: AirportMark? = nil,
                             landedIn arrival: AirportMark? = nil,
                             calendar: Calendar = .current, locale: Locale = .current) -> String {
        let time = timelineTime(date, calendar: calendar, locale: locale)
        guard let words = timelineWords(activity, stillOnGroundIn: airport, landedIn: arrival) else { return time }
```

Replace:

```swift
    static func timelineSpokenValue(_ date: Date, activity: TripActivity?, stillOnGroundIn airport: AirportMark? = nil,
                                    calendar: Calendar = .current, locale: Locale = .current) -> String {
        let time = date.formatted(style(calendar: calendar, locale: locale).weekday(.wide).hour().minute())
        guard let words = timelineWords(activity, stillOnGroundIn: airport) else { return time }
```

with:

```swift
    static func timelineSpokenValue(_ date: Date, activity: TripActivity?, stillOnGroundIn airport: AirportMark? = nil,
                                    landedIn arrival: AirportMark? = nil,
                                    calendar: Calendar = .current, locale: Locale = .current) -> String {
        let time = date.formatted(style(calendar: calendar, locale: locale).weekday(.wide).hour().minute())
        guard let words = timelineWords(activity, stillOnGroundIn: airport, landedIn: arrival) else { return time }
```

Replace:

```swift
    /// What the pilot is doing, or "On the ground in Rockford" where the flight's real plane is still on the ground at
    /// its departure airport (which plane design §4).
    private static func timelineWords(_ activity: TripActivity?, stillOnGroundIn airport: AirportMark?) -> String? {
        if let airport { return "On the ground in \(airport.name)" }
        return activity?.words
    }
```

with:

```swift
    /// What the pilot is doing, or "On the ground in Rockford" where the flight's real plane is still on the ground at
    /// its departure airport (which plane design §4), or "Landed in Anchorage" where it's down at the arrival airport,
    /// before the gate (landed before the gate design §3).
    private static func timelineWords(_ activity: TripActivity?, stillOnGroundIn airport: AirportMark?,
                                      landedIn arrival: AirportMark?) -> String? {
        if let airport { return "On the ground in \(airport.name)" }
        if let arrival { return FactsWording.landed(in: arrival) }
        return activity?.words
    }
```

Replace:

```swift
    /// "9:30 PM in Cologne", or nil when the destination keeps the family's time.
```

with:

```swift
    /// The card's bar's landing time at `now`: "Lands 3:30 PM", or once the real plane is down, before the gate, "At
    /// the gate 3:30 PM" (landed before the gate design §3).
    static func barArrival(for leg: MapLeg, at now: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        guard leg.isLandedBeforeGate(at: now) else { return landsAt(for: leg, calendar: calendar, locale: locale) }
        return "At the gate \(clockTime(leg.end, in: calendar.timeZone, locale: locale))"
    }

    /// "9:30 PM in Cologne", or nil when the destination keeps the family's time.
```

- [x] **Step 3: The line under the timeline.** No tests: SwiftUI.

In `Crewluv/Views/TripMap/TripTimelineControl.swift`:

Replace:

```swift
    let stillOnGroundIn: AirportMark?
    /// The trip time on screen.
```

with:

```swift
    let stillOnGroundIn: AirportMark?
    /// Where the flight's real plane is down at the arrival airport, before the gate, now: the line under the bar says
    /// "Landed in" it (landed before the gate design §3).
    let landedIn: AirportMark?
    /// The trip time on screen.
```

Replace:

```swift
                                spokenValue: TripMapWording.timelineSpokenValue(time, activity: activity, stillOnGroundIn: stillOnGroundIn),
```

with:

```swift
                                spokenValue: TripMapWording.timelineSpokenValue(time, activity: activity, stillOnGroundIn: stillOnGroundIn,
                                                                                landedIn: landedIn),
```

Replace:

```swift
            Text(TripMapWording.timelineLine(time, activity: activity, stillOnGroundIn: stillOnGroundIn))
```

with:

```swift
            Text(TripMapWording.timelineLine(time, activity: activity, stillOnGroundIn: stillOnGroundIn, landedIn: landedIn))
```

In `Crewluv/Views/TripMap/FactsHeader.swift`:

Replace:

```swift
    let stillOnGroundIn: AirportMark?
```

with:

```swift
    let stillOnGroundIn: AirportMark?
    /// Where the flight's real plane is down at the arrival airport, before the gate, now.
    let landedIn: AirportMark?
```

Replace:

```swift
                                activity: activity, stillOnGroundIn: stillOnGroundIn, time: time, now: now)
```

with:

```swift
                                activity: activity, stillOnGroundIn: stillOnGroundIn, landedIn: landedIn, time: time, now: now)
```

In `Crewluv/Views/TripMap/FactsPanel.swift`:

Replace:

```swift
                            activity: facts.tripMap.activity(at: time), stillOnGroundIn: facts.stillOnGroundAirport(at: time),
                            time: time, now: now)
```

with:

```swift
                            activity: facts.tripMap.activity(at: time), stillOnGroundIn: facts.stillOnGroundAirport(at: time),
                            landedIn: facts.landedAirport(at: time), time: time, now: now)
```

In `Crewluv/Views/TripMap/FactsSheet.swift`:

Replace:

```swift
                                activity: facts.tripMap.activity(at: time), stillOnGroundIn: facts.stillOnGroundAirport(at: time),
                                clock: $clock,
```

with:

```swift
                                activity: facts.tripMap.activity(at: time), stillOnGroundIn: facts.stillOnGroundAirport(at: time),
                                landedIn: facts.landedAirport(at: time), clock: $clock,
```

- [x] **Step 4: The card's bar.** No tests: SwiftUI.

In `Crewluv/Views/TripMap/TripMapInFlightBar.swift`:

Replace:

```swift
    /// "In flight", or the real plane against the schedule: "12 min ahead" (`TripMapWording.flightStatus`).
    let status: String
```

with:

```swift
    /// "In flight", or the real plane against the schedule: "12 min ahead" (`TripMapWording.flightStatus`).
    let status: String
    /// "Lands 3:30 PM", or "At the gate 3:30 PM" once the real plane is down (`TripMapWording.barArrival`).
    let arrival: String
```

Replace:

```swift
            Text(TripMapWording.landsAt(for: leg))
```

with:

```swift
            Text(arrival)
```

In `Crewluv/Views/TripMap/TripMapCard.swift`:

Replace:

```swift
            TripMapInFlightBar(leg: leg, status: TripMapWording.flightStatus(for: leg, at: date))
```

with:

```swift
            TripMapInFlightBar(leg: leg, status: TripMapWording.flightStatus(for: leg, at: date),
                               arrival: TripMapWording.barArrival(for: leg, at: date))
```

- [x] **Step 5: The status sentence.** No tests: SwiftUI.

In `Crewluv/Services/PartnerStatusReceiver.swift`:

Replace:

```swift
    private(set) var isStillOnGround = false
```

with:

```swift
    private(set) var isStillOnGround = false
    /// Whether the flight between its gates has its real plane down at the arrival airport, before the gate: the
    /// narrative says so (landed before the gate design §3).
    private(set) var isLandedBeforeGate = false
```

Replace:

```swift
        isStillOnGround = LiveLegs.stillOnGroundFlight(in: legs, flights: flights, at: now) != nil
```

with:

```swift
        isStillOnGround = LiveLegs.stillOnGroundFlight(in: legs, flights: flights, at: now) != nil
        isLandedBeforeGate = LiveLegs.landedFlight(in: legs, flights: flights, at: now) != nil
```

Replace:

```swift
        isStillOnGround = false
    }
```

with:

```swift
        isStillOnGround = false
        isLandedBeforeGate = false
    }
```

In `Crewluv/Views/Welcome/ContentView.swift`:

Replace:

```swift
                                isStillOnGround: receiver.isStillOnGround,
```

with:

```swift
                                isStillOnGround: receiver.isStillOnGround,
                                isLandedBeforeGate: receiver.isLandedBeforeGate,
```

Replace:

```swift
                    isStillOnGround: receiver.isStillOnGround,
                    onExitDemo: { receiver.exitDemoMode() },
```

with:

```swift
                    isStillOnGround: receiver.isStillOnGround,
                    isLandedBeforeGate: receiver.isLandedBeforeGate,
                    onExitDemo: { receiver.exitDemoMode() },
```

In `Crewluv/Views/Status/PilotStatusView.swift`:

Replace:

```swift
    var isStillOnGround = false
    var onExitDemo: (() -> Void)? = nil
```

with:

```swift
    var isStillOnGround = false
    /// Whether the flight in the air's real plane is down at the arrival airport, before the gate, from the screen's
    /// model: the narrative says so (landed before the gate design §3).
    var isLandedBeforeGate = false
    var onExitDemo: (() -> Void)? = nil
```

Replace:

```swift
                                      isStillOnGround: isStillOnGround)
```

with:

```swift
                                      isStillOnGround: isStillOnGround, isLandedBeforeGate: isLandedBeforeGate)
```

In `Crewluv/Views/Status/NarrativeCardView.swift`:

Replace:

```swift
    var isStillOnGround = false

    @Environment(\.colorScheme) private var colorScheme
```

with:

```swift
    var isStillOnGround = false
    /// The flight in the air's real plane is down at the arrival airport, before the gate: "Alex has landed in
    /// Anchorage on UPS flight 2963 — at the gate in 8m which is 7:52pm EST", delayed or not (landed before the gate
    /// design §3).
    var isLandedBeforeGate = false

    @Environment(\.colorScheme) private var colorScheme
```

Replace:

```swift
                    if isStillOnGround, let dep, let dest {
```

with:

```swift
                    if isLandedBeforeGate, let dest {
                        landedSentence(in: dest, flight: fltStr, gate: shiftedArr, color: countdownColor)
                    } else if isStillOnGround, let dep, let dest {
```

Replace:

```swift
            if isStillOnGround, let dep {
```

with:

```swift
            if isLandedBeforeGate {
                landedSentence(in: dest, flight: fltStr, gate: arrTime)
            } else if isStillOnGround, let dep {
```

Replace:

```swift
    @ViewBuilder
    private var turnNarrative: some View {
```

with:

```swift
    /// "Alex has landed in Anchorage on UPS flight 2963 — at the gate in 8m which is 7:52pm EST.", with the gate's
    /// countdown in `color`, else the status's (landed before the gate design §3).
    private func landedSentence(in dest: String, flight fltStr: String, gate: Date, color: Color? = nil) -> Text {
        Text("\(name) has landed in \(Text(dest).bold())\(fltStr.isEmpty ? " on the flight" : fltStr) — at the gate in \(countdownText(to: gate, color: color)) which is \(Text(formattedLocalTime(gate)).bold()).")
    }

    @ViewBuilder
    private var turnNarrative: some View {
```

- [x] **Step 6: The previews.**

In `Crewluv/Views/TripMap/TripMapPreviews.swift`:

Replace:

```swift
    /// A store with Quick layovers set, so each full-screen preview shows its pace whatever the canvas remembered.
```

with:

```swift
    /// The Europe trip with its first flight's real plane down in Cologne `minutesAgo` minutes ago, and not yet at the
    /// gate, the plan's 7 minutes of taxi in after its touchdown (landed before the gate design §3). It was seen all
    /// the way, at 560 kt.
    static func europeLanded(minutesAgo: Double) -> TripMap? {
        let now = Date()
        guard let origin = coordinate("SDF"), let destination = coordinate("CGN") else { return nil }
        let waypoint = CLLocationCoordinate2D(latitude: 58, longitude: -45)
        let length = GreatCircle.distance(from: origin, to: waypoint) + GreatCircle.distance(from: waypoint, to: destination)
        let landedAt = now.addingTimeInterval(-minutesAgo * 60)
        let takeoff = landedAt.addingTimeInterval(-length / (560 * GreatCircle.metersPerNauticalMile / 3600))
        let legs = europeLegs(from: takeoff.addingTimeInterval(-FlightProgress.taxiOutAllowance))
        let flown = liveFlight(legID: "UPS207", from: origin, via: waypoint, to: destination, takeoff: takeoff,
                               lastSeen: landedAt.addingTimeInterval(-120))
        let fix = LiveFlight.Fix(latitude: destination.latitude, longitude: destination.longitude, altitudeFeet: nil,
                                 groundSpeedKnots: 20, trackDegrees: nil, isOnGround: true, registration: "N605UP",
                                 typeCode: "B748", seenAt: landedAt)
        let live = LiveFlight(legID: "UPS207", callsign: "UPS207", state: .landed, fix: fix, landedAt: landedAt, trail: flown.trail)
        let flights = LiveLegs.flights(for: legs, legacyDelayMinutes: nil, answered: ["UPS207": live], clockOffset: 0,
                                       coordinate: { coordinate($0) })
        return TripMap.make(tripLegs: LiveLegs.replacingTimes(in: legs, with: flights, at: now), isNextTrip: false,
                            homeAirportCode: "SDF", legacyDelayMinutes: nil, flights: flights, at: now,
                            coordinate: { coordinate($0) })
    }

    /// A store with Quick layovers set, so each full-screen preview shows its pace whatever the canvas remembered.
```

Replace:

```swift
#Preview("Full screen, real plane still at the gate") {
```

with:

```swift
#Preview("Real plane, landed, not yet at the gate") {
    if let map = TripMapPreviewData.europeLanded(minutesAgo: 2) {
        TripMapCard(tripMap: map, status: .demo, storyStore: LegStoryStore()).padding()
    }
}

#Preview("Full screen, real plane landed, not yet at the gate") {
    if let map = TripMapPreviewData.europeLanded(minutesAgo: 2) {
        TripMapScreen(tripMap: map, storyStore: LegStoryStore(), dayNumber: 1, totalDays: 4)
            .defaultAppStorage(TripMapPreviewData.storage(quickLayovers: true))
    }
}

#Preview("Full screen, real plane still at the gate") {
```

---

### Task 5: The docs

- [x] **Step 1: The design, copied from the website's, with §6 for the app.**

Create `docs/superpowers/specs/2026-11-17-landed-before-gate-design.md`:

```swift
# Crewluve Trip Map: Landed, Not Yet at the Gate

Status: approved by Todd on 17 Nov 2026, from a sketch of three wordings ("A: 'Landed in Anchorage'"), for the website and the
app. This is the app's copy of the website's design (Crewluve Website repo, the same path, at `329ce7a`), with §6 for where
the words go in the app. Todd settled two details on 17 Nov 2026, from the website's plan: "at", not "about", once the plane
is down, as the card's sentence and the popup say it; and the bar's right side, "At the gate 8:47 AM".

## 1. Why

For the few minutes between touchdown and the gate, the flight's bar, the card's sentence and the plane's popup already say
the plane is down ("Landed 8 min early", "…, landed 8 minutes early. Reaches the gate at 7:52 PM your time."). Everything
else still talks as if it were flying: "Over Alaska", "2,788 mi flown · 0 to go", "Lands Anchorage about 3:52 PM", the
list's "In the air now", "Flying to Anchorage" under the timeline, and "Alex is flying to Anchorage … — landing in 8m". A
family reading two of them at once gets two stories.

## 2. When

- **The real plane has landed:** Crewlu Cloud's state for the flight is "landed" (the engine's `landed` phase), and
- **it isn't at the gate yet:** the moment is before the leg's gate arrival (`leg.end`, the real plane's estimate where
  there is one, as every card has it).
- **Now only,** as "Still on the ground" is: a replay reads the map's plane, as before.
- A flight with no live data never knows its touchdown, so it reads as it always has.

## 3. The words

| Where | Today | In that window |
|---|---|---|
| The facts' headline, their first row, and the card's bottom chip | "Over Alaska" | **Landed in Anchorage** |
| The distance row | "2,788 mi flown · 0 to go" | **2,788 mi flown** (its comparison line as before) |
| The sky row | shown | **left out**, as at the gate |
| The landing row | "Lands Anchorage about 3:52 PM · 7:52 PM your time" | **Reaches the gate at 3:52 PM · 7:52 PM your time** ("at", as the card's sentence and the popup say it once the plane is down); the weather line under it as before |
| The card's bar, its right side | "Lands 8:47 AM" | **At the gate 8:47 AM** (the city's own time under it as before) |
| The list's tag on the flight | "In the air now" | **Landed** (its border kept) |
| The line under the timeline (and the slider's spoken value) | "Flying to Anchorage" | **Landed in Anchorage** |
| The status page's sentence | "Alex is flying to Anchorage on UPS flight 2963 from Rockford — landing in 8m which is about 7:52pm EST." | **Alex has landed in Anchorage on UPS flight 2963 — at the gate in 8m which is 7:52pm EST.** (with no flight number, "on the flight") |
| The card's heading for screen readers | "In flight" | **Landed** |

"Anchorage" is the arrival airport's city, as everywhere else. The first row's other lines (where the plane was last
tracked, the closest point to home) are left out with what's below, as "Still on the ground" does.

## 4. Unchanged

- The flight's bar's left side ("Landed 8 min early", "Landed on time", "Landed 8 min late").
- The card's sentence for screen readers ("…, landed 8 minutes early. Reaches the gate at 7:52 PM your time.").
- The plane's popup ("Reaches the gate at …").
- The latest event's banner, which the latest event design keeps until the gate.
- The plane's own row: the aircraft's name, with no height or speed (the plane isn't in the air).

## 5. Not in this design

- A plane that lands somewhere other than its arrival airport (a diversion): the engine's phases don't tell it apart today.
- An air return (back down at the departure airport): left for later in plan 3C-3.
- The app's words: its own plan, `docs/superpowers/plans/2026-11-17-landed-before-gate.md`, from this design.

## 6. In the app

- **The rule:** `MapFlight.hasLanded` (Crewlu Cloud's state "landed"), `MapLeg.isLandedBeforeGate` (and the leg is between its gates), `TripFacts.isLandedBeforeGate` (and the facts aren't a replay's), `TripMap.landedAirport` for the line under the timeline, and `LiveLegs.landedFlight` for the status sentence.
- **The card's bottom chip** is the facts' headline, so it says "Landed in Anchorage" with them.
- **The card's bar** is `TripMapInFlightBar`: its right side reads "At the gate 8:47 AM" (`TripMapWording.barArrival`), with the city's own time under it as before.
- **The card has no heading of its own,** so §3's row for it is the website's only: the app's VoiceOver label is the card's sentence, which §4 leaves as it is.
- **A diversion the app can tell:** a plane last seen on the ground away from its arrival airport isn't "Landed in Anchorage", and reads as before (`MapFlight.hasLanded`). One with no such fix can't be told apart, as §5 says.
- **The status sentence** is `NarrativeCardView`'s, delayed or not, with its red or green countdown kept.
- **Previews:** "Real plane, landed, not yet at the gate", on the card and full screen, in place of the website's demo scene.
```

- [x] **Step 2:**

In `CLAUDE.md`:

Replace:

```swift
- The list puts each flight's newest event first and sets the flight between its gates apart, "In the air now" (`TripSoFarList`). The latest event (design `docs/superpowers/specs/2026-11-15-crewluve-latest-event-design.md`, `TripFacts.latestEvent(at:)`) shows large until the next, in the card's top corner and under the full-screen map's pill (`LatestEventBanner`). Beside it the headline leaves events out (`includesEvents: false`); the shared cases read it with them. The key to the real plane and its ghost (which plane design `docs/superpowers/specs/2026-11-16-crewluve-which-plane-design.md`, `PlaneKey`) shares that corner (`TripMapCorner`): beside the banner where the two fit, else just under it, going by the widest "when" the banner can show (`TripMapCornerPlacement`). Neither takes a tap. On the full-screen map a tap on the real plane or the ghost opens its popup (`PlanePopupWords`, `TripMapPopupController`): only those two markers' views are enabled, and a selected one keeps its place in the stack. A real plane still at its gate after the plan's takeoff time (`MapFlight.isAtDeparture`) is told as on the ground, now only: in the facts, under the timeline, and in the status sentence (`LiveLegs.stillOnGroundFlight`, worked out by `PartnerStatusReceiver`)
```

with:

```swift
- The list puts each flight's newest event first and sets the flight between its gates apart, "In the air now" (`TripSoFarList`). The latest event (design `docs/superpowers/specs/2026-11-15-crewluve-latest-event-design.md`, `TripFacts.latestEvent(at:)`) shows large until the next, in the card's top corner and under the full-screen map's pill (`LatestEventBanner`). Beside it the headline leaves events out (`includesEvents: false`); the shared cases read it with them. The key to the real plane and its ghost (which plane design `docs/superpowers/specs/2026-11-16-crewluve-which-plane-design.md`, `PlaneKey`) shares that corner (`TripMapCorner`): beside the banner where the two fit, else just under it, going by the widest "when" the banner can show (`TripMapCornerPlacement`). Neither takes a tap. On the full-screen map a tap on the real plane or the ghost opens its popup (`PlanePopupWords`, `TripMapPopupController`): only those two markers' views are enabled, and a selected one keeps its place in the stack. A real plane still at its gate after the plan's takeoff time (`MapFlight.isAtDeparture`) is told as on the ground, now only: in the facts, under the timeline, and in the status sentence (`LiveLegs.stillOnGroundFlight`, worked out by `PartnerStatusReceiver`). A real plane down at its arrival airport before the gate (`MapFlight.hasLanded`, `MapLeg.isLandedBeforeGate`) reads "Landed in Anchorage", now only, in the same places: the facts, with "2,788 mi flown" and "Reaches the gate at …" and no sky row, the list's tag "Landed", under the timeline, on the card's bar ("At the gate 8:47 AM", `TripMapWording.barArrival`) and in the status sentence (`LiveLegs.landedFlight`) (landed before the gate design `docs/superpowers/specs/2026-11-17-landed-before-gate-design.md`)
```

---

### Task 6: Todd's run, the commits, and a look

- [x] **Step 1: Todd runs every test of the app once:**

```bash
xcodebuild test -project Crewluv.xcodeproj -scheme Crewluv -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' 2>&1 | grep -E "error:|TEST (SUCCEEDED|FAILED)"
```

Expected: `** TEST SUCCEEDED **`, with 1,172 tests in the result bundle (1,157 before).

Todd's run, 17 Nov 2026: `** TEST SUCCEEDED **`, 1,172 passed, none failed or skipped.

- [ ] **Step 2: Ask to commit:** one commit for each of Tasks 2, 3 and 4, then Task 5 with this plan. Then ask whether to add a line to the 1.4 (49) release note: "Between landing and the gate, Crewluve says \"Landed in Anchorage\", with when they'll reach the gate, in place of still flying."

- [ ] **Step 3: Todd looks** at the previews "Real plane, landed, not yet at the gate" and "Full screen, real plane landed, not yet at the gate", within 5 minutes of opening them: "Landed in Cologne" in the chip, the sheet's first row, the list's tag "Landed" and under the timeline; the distance flown with nothing to go; "Reaches the gate at …"; no sky row; "At the gate …" on the card's bar.

## Left for later

- **A diversion,** down somewhere other than its arrival airport: the engine's phases don't tell it apart today, as the design says.
- **An air return,** back down at the departure airport.
