# Which Plane Is Which, and a Plane Still at Its Gate (Crewluve App) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The app matches the website: a key to the real plane and its ghost on the card and the full-screen map, a popup on each plane when it's tapped on the full-screen map, and a plane still at its gate after its takeoff time told as on the ground everywhere.

**Architecture:**
- **The rules, each said once:** `MapFlight.isAtDeparture(at:)` (on the ground at its departure airport, and its bar says "Still on the ground"), `MapLeg.isStillOnGround(at:)`, `TripMap.flightInMotion(at:)` and `stillOnGroundAirport(at:)`, `LiveLegs.stillOnGroundFlight(in:flights:at:)` for the status screen's model, and `TripMapDrawing.showsPlaneKey` for the key.
- **The words:** `PlanePopupWords` writes each popup. `FactsWording` and `TripMapWording` gain "Still on the ground in Rockford", "2,788 mi to go" and "On the ground in Rockford".
- **The facts** (`TripFacts`, `TripFacts+Rows`) read a plane at its gate as on the ground, now only.
- **The key** (`PlaneKey`) sits with the latest event's banner in `TripMapCorner`, whose `TripMapCornerLayout` puts it beside the banner or under it by `TripMapCornerPlacement`.
- **The popup** (`PlanePopup`) is shown by `TripMapPopupController`, over the map in its container, when MapKit selects the real plane or its ghost, and placed by `PlanePopupPlacement`.

**Tech Stack:** Swift 5 language mode, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, iOS 26, SwiftUI, MapKit, XCTest.

**Design:** `docs/superpowers/specs/2026-11-16-crewluve-which-plane-design.md` (written with this plan): the app's half of the website's which plane design (Crewluve Website repo, `docs/superpowers/specs/2026-11-16-trip-map-which-plane-design.md`), with the website's plan 3C-3's words for a plane at its gate and plan 3C-4's place for the key beside the banner. Todd's choices (16 Nov 2026): the app gets these "with the key and popup"; "Yes, these words"; "A: key just under the banner"; "Leave it out until it takes off". The website's code at `b3e3c15` is the reference for every word and rule.

**How this plan was checked.**
- **A scratch Swift package** with the app target's settings, made from the repo at `9f06e71`: 525 XCTest and 71 Swift Testing tests before, 577 and 71 with this plan, all passing, no warnings.
- **Task by task:** the package was kept as it stood after each of Tasks 2 to 6 and run each time, all passing: 551 XCTest tests after Task 2, 563 after Tasks 3 and 4, 572 after Task 5 and 577 after Task 6.
- **56 deliberate breaks** were made in the new code, one at a time, and 54 fail at least one test. The first run caught 51: the three it missed (the clock offset, a drive taken for the flight in motion, and the sky at the gate) each led to a sharper test. Two can't be caught by any test, each for its reason: leaving out the on-ground check beside the "still on the ground" label, which only ever comes with it, and leaving out the flight's start in `LiveLegs.stillOnGroundFlight`, since before it the plan's takeoff time hasn't come. Both are kept, as the website has them.
- **The whole app was type-checked for iOS** with `swiftc` outside Xcode after each task, and compiled for the iOS simulator with the whole plan in: no errors and no warnings.
- **The plan was followed by a script** on the repo at `9f06e71`: all 40 files came out the same as the tested ones.
- **Reviewed** by `superpowers:code-reviewer` (sonnet) before the plan was put together: nothing critical. Of its five important points, four were mended: the key and the banner take no taps, so a tap on them goes on to the map; a popup stays below the top bar even with no banner or key; a popup closes when the next flight's planes take its plane's place; and the planes take a tap on their marks alone, since a wider area let the real plane's cover the ghost's. The fifth, that SwiftUI doesn't mirror a custom layout right to left, was tried on the Mac and found wrong: it does. Also mended from its minor points: the popup is measured only when its words, its width or the text size change, and the tests it found weak say exactly what they hold. What it left is in "Left for later".
- **Not checked:** nothing ran on a simulator or a device, and no view was seen. Not by any test: the views and their layout, MapKit's taps on the planes (the popup's opening, closing and moving), and the camera's framing with the key.

**Where this plan settles details, or differs from the website.** The design's §5:
- **No card heading.** The website's card has a heading for screen readers, "On the ground". The app's card is one VoiceOver element, whose sentence says "still on the ground" already, and now leaves out "over …" at the gate.
- **The popup opens on a tap only,** on iPad too, and it's the app's own glass, not MapKit's callout. It stays below the top bar, the banner and the key, and closes when the next flight's planes take its plane's place.
- **The key and the banner take no taps,** so a tap on them goes on to the map.
- **A plane takes a tap on its mark,** 26 points across: a wider area would let the real plane's cover the ghost's where the two are close.
- **The key counts in the card's top clearance even with no banner,** as the top chip always has.
- **No camera slide for the planes,** which the website's map needed: MapKit fits the leg in flight inside the map's margins.
- **The receiver works out the status sentence's "still on the ground"** when it resolves, as it does "about": on each of Crewlu Cloud's answers, every 30 seconds while the flight's window is open.
- **Not here:** the Schedule page's "about" (website plan 3C-3), and the website's slide.

**Questions for Todd:** none. His answers for the website stand for the app.

---

## Ground rules

1. **Don't run `xcodebuild` build or test loops.** Todd runs the tests (Task 7).
2. **Never commit without Todd's go-ahead,** and then only this plan's files, by path. **Never push** without a fresh yes.
3. **Copy the code as written.** A replacement is exact: if its text isn't in the file once, stop.
4. **Reviewers:** `superpowers:code-reviewer` with `model: "sonnet"`.
5. **Work on `feature/trip-map-live`.** Never stash, reset or switch branches.
6. **The shared cases are the judge:** `CrewluvTests/Fixtures/TripMap/live-cases.json` isn't edited.

## File map

| File | Task | What changes |
|---|---|---|
| `Crewluv/Services/TripMap/Live/MapFlight.swift`, `Crewluv/Services/TripMap/MapLeg.swift`, `TripMap.swift`, `TripMap+Activity.swift`, `Crewluv/Services/TripMap/Live/LiveLegs.swift` | 2 | a plane still at its gate, and the flight between its gates |
| `Crewluv/Services/TripMap/TripMapDrawing.swift` | 2 | when the key shows |
| `Crewluv/Services/TripMap/PlanePopupWords.swift` | 2 | new: the popup's words |
| `Crewluv/Services/TripMap/TripMapWording.swift`, `Crewluv/Services/TripMap/Facts/FactsWording.swift` | 2, 5 | the words at the gate, "over" only in flight, and the widest "when" |
| `Crewluv/Services/TripMap/Facts/TripFacts.swift`, `TripFacts+Rows.swift` | 3 | the facts at the gate |
| `Crewluv/Services/PartnerStatusReceiver.swift`, `Crewluv/Views/Welcome/ContentView.swift`, `Crewluv/Views/Status/PilotStatusView.swift`, `NarrativeCardView.swift` | 4 | the status sentence |
| `Crewluv/Views/TripMap/TripTimelineControl.swift`, `FactsHeader.swift`, `FactsSheet.swift`, `FactsPanel.swift` | 4 | the line under the timeline |
| `Crewluv/Services/TripMap/TripMapCornerPlacement.swift`, `Crewluv/Views/TripMap/TripMapCornerLayout.swift`, `TripMapCorner.swift`, `PlaneKey.swift` | 5 | new: the key, beside the banner or under it |
| `Crewluv/Views/TripMap/TripMapCard.swift`, `TripMapScreen.swift`, `TripMapPreviews.swift` | 5, 6 | the key on the card and the full-screen map, and previews at the gate |
| `Crewluv/Services/TripMap/PlanePopupPlacement.swift`, `Crewluv/Views/TripMap/PlanePopup.swift`, `TripMapPopupController.swift` | 6 | new: the popup |
| `Crewluv/Views/TripMap/TripMapMarker.swift`, `TripMapAnnotationView.swift`, `TripMapCoordinator.swift`, `TripMapView.swift`, `TripMapScreen.swift` | 6 | the planes take a tap, and the map shows their popup below its controls |
| `CrewluvTests/PlanePopupWordsTests.swift`, `StillOnGroundTests.swift`, `PlaneKeyTests.swift`, `StillOnGroundFactsTests.swift`, `TripMapCornerPlacementTests.swift`, `PlanePopupPlacementTests.swift` | 2, 3, 5, 6 | new: the tests |
| `CrewluvTests/LiveWordingTests.swift` | 2 | "over" only in flight |

---

### Task 1: Before starting

- [x] **Step 1:** The branch is `feature/trip-map-live`, at `9f06e71` or later, and none of this plan's files has changed since.

```bash
git -C /Users/toddanderson/Dev/Crewluv status --short && git -C /Users/toddanderson/Dev/Crewluv branch --show-current && git -C /Users/toddanderson/Dev/Crewluv log --oneline -1
```

---

### Task 2: The rules and the words

- [x] **Step 1: The tests.**

Create `CrewluvTests/PlanePopupWordsTests.swift`:

```swift
//
//  PlanePopupWordsTests.swift
//  CrewluvTests
//
//  What a plane's popup on the full-screen map says (which plane design §3), in US English for a family in
//  Louisville, on the shared cases' flights.
//

import XCTest
@testable import Crewluv

final class PlanePopupWordsTests: XCTestCase {

    private let locale = Locale(identifier: "en_US")
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    /// iOS writes a narrow no-break space before AM and PM; the tests read it as a plain space.
    private func plain(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{202F}", with: " ")
    }

    /// A shared case's flight at one of its moments, as a leg of the map.
    private func leg(of name: String, moment index: Int = 0) throws -> (leg: MapLeg, at: Date) {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: name)
        let moment = flightCase.moments[index]
        return (try cases.mapLeg(flightCase, at: moment), moment.at)
    }

    private func words(on leg: MapLeg, _ plane: PlaneKind = .realPlane, at date: Date, isReplay: Bool = false,
                       calendar: Calendar? = nil, locale: Locale? = nil) -> PlanePopupWords {
        let words = PlanePopupWords(leg: leg, plane: plane, at: date, isReplay: isReplay, calendar: calendar ?? self.calendar,
                                    locale: locale ?? self.locale)
        return PlanePopupWords(title: plain(words.title), lines: words.lines.map(plain))
    }

    /// The real plane's popup in a shared case's moment, now.
    private func realPlane(_ name: String, moment index: Int = 0) throws -> PlanePopupWords {
        let (leg, at) = try leg(of: name, moment: index)
        return words(on: leg, at: at)
    }

    // MARK: - Each plane

    func test_ghost_isOnSchedule_whereTheFlightWasScheduledToBe() throws {
        let (leg, at) = try leg(of: "ahead, in the air")
        XCTAssertEqual(words(on: leg, .ghost, at: at), PlanePopupWords(title: "On schedule", lines: ["Where UPS207 was scheduled to be"]))
    }

    func test_realPlaneInTheAir_saysTheBarsWords_andWhenItLands() throws {
        XCTAssertEqual(try realPlane("ahead, in the air"),
                       PlanePopupWords(title: "UPS207 · real plane", lines: ["14 min ahead", "Lands about 8:30 AM"]))
    }

    func test_realPlaneStillAtTheGate_afterItsTakeoffTime_saysSo() throws {
        XCTAssertEqual(try realPlane("still on the ground twenty minutes after"),
                       PlanePopupWords(title: "UPS207 · real plane", lines: ["Still on the ground · 20 min behind", "Lands about 9:05 AM"]))
    }

    func test_realPlaneWithNoLabel_beforeItsTakeoffTime_landsOnTheSchedulesTime_withNoAbout() throws {
        XCTAssertEqual(try realPlane("on the ground before the plan's takeoff"),
                       PlanePopupWords(title: "UPS207 · real plane", lines: ["Lands 8:45 AM"]))
    }

    func test_fadedPlane_isABestGuess_saysWhenItWasLastSeen_andLandsAbout() throws {
        // Last seen at 12:41:40 UTC, 7:41 AM in Louisville.
        XCTAssertEqual(try realPlane("ahead, in the air", moment: 2),
                       PlanePopupWords(title: "UPS207 · best guess",
                                       lines: ["Not seen since 7:41 AM, so it's drawn where it should be by now",
                                               "About 14 min ahead · lands about 8:30 AM"]))
    }

    func test_landedPlane_saysWhenItReachesTheGate() throws {
        XCTAssertEqual(try realPlane("landed, seen all the way"),
                       PlanePopupWords(title: "UPS207 · real plane", lines: ["Landed 23 min early", "Reaches the gate at 8:21 AM"]))
    }

    func test_planeDownSomewhereElse_saysOnlyWhichPlaneItIs() throws {
        XCTAssertEqual(try realPlane("on the ground somewhere else"), PlanePopupWords(title: "UPS207 · real plane", lines: []))
    }

    func test_flightWithNoLiveData_saysOnlyWhichPlaneItIs() throws {
        XCTAssertEqual(try realPlane("no live data"), PlanePopupWords(title: "UPS207 · real plane", lines: []))
        let (leg, at) = try leg(of: "ahead, in the air")
        let scheduleOnly = MapLeg(id: leg.id, kind: .flight, origin: leg.origin, destination: leg.destination,
                                  start: leg.start, end: leg.end, flightNumber: leg.flightNumber)
        XCTAssertEqual(words(on: scheduleOnly, at: at), PlanePopupWords(title: "UPS207 · real plane", lines: []))
    }

    func test_replay_saysWhereTheRealPlaneWasAtTheMoment() throws {
        let (leg, at) = try leg(of: "ahead, in the air")
        XCTAssertEqual(words(on: leg, at: at, isReplay: true),
                       PlanePopupWords(title: "UPS207 · real plane", lines: ["Where it was at 7:41 AM"]))
    }

    // MARK: - Names and clocks

    func test_flightWithNoNumber_isTheFlight() throws {
        let (leg, at) = try leg(of: "ahead, in the air")
        let unnamed = MapLeg(id: leg.id, kind: .flight, origin: leg.origin, destination: leg.destination,
                             start: leg.start, end: leg.end, flightNumber: nil, flight: leg.flight)
        XCTAssertEqual(words(on: unnamed, .ghost, at: at).lines, ["Where the flight was scheduled to be"])
        XCTAssertEqual(words(on: unnamed, at: at).title, "The flight · real plane")
    }

    func test_timesFollowThisDevicesTimeZoneAndClock() throws {
        let (leg, at) = try leg(of: "ahead, in the air")
        var cologne = Calendar(identifier: .gregorian)
        cologne.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Berlin"))
        // 12:41:50 UTC is 1:41 PM in Cologne, on a 24-hour clock there.
        XCTAssertEqual(words(on: leg, at: at, isReplay: true, calendar: cologne, locale: Locale(identifier: "de_DE")).lines,
                       ["Where it was at 13:41"])
        XCTAssertEqual(words(on: leg, at: at, calendar: cologne, locale: Locale(identifier: "de_DE")).lines,
                       ["14 min ahead", "Lands about 14:30"])
    }

    // MARK: - The shared cases

    func test_everySharedMomentTheRealPlaneShows_saysTheCardsBarsWords() throws {
        let cases = try TripMapFixtures.liveCases()
        var checked = 0
        for flightCase in cases.flights where flightCase.flight != nil {
            for (index, moment) in flightCase.moments.enumerated() {
                guard let label = moment.label, moment.phase != "notLive" else { continue }
                let words = try realPlane(flightCase.name, moment: index)
                XCTAssertTrue(words.lines.joined(separator: " · ").contains(label), "\(flightCase.name), moment \(index): \(words.lines)")
                checked += 1
            }
        }
        XCTAssertGreaterThan(checked, 20)
    }
}
```

Create `CrewluvTests/StillOnGroundTests.swift`:

```swift
//
//  StillOnGroundTests.swift
//  CrewluvTests
//
//  A real plane still on the ground at its departure airport after the plan's takeoff time (which plane design §4):
//  when it is, and the words that say so under the timeline and in the facts, in US English for a family in
//  Louisville.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class StillOnGroundTests: XCTestCase {

    private let locale = Locale(identifier: "en_US")
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private func plain(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{202F}", with: " ")
    }

    /// A shared case's flight at its moment `time`, as a leg of the map.
    private func leg(of name: String, at time: String) throws -> (leg: MapLeg, at: Date) {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: name)
        let moment = try cases.moment(time, of: flightCase)
        return (try cases.mapLeg(flightCase, at: moment), moment.at)
    }

    private func map(of leg: MapLeg) -> TripMap {
        TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: leg.origin,
                span: DateInterval(start: leg.start, end: leg.end), tripDays: nil)
    }

    private let rockford = AirportMark(code: "RFD", city: "Rockford", coordinate: CLLocationCoordinate2D(latitude: 42.2, longitude: -89.1),
                                       timeZone: TimeZone(identifier: "America/Chicago"))
    private let anchorage = AirportMark(code: "ANC", city: "Anchorage", coordinate: CLLocationCoordinate2D(latitude: 61.2, longitude: -150.0),
                                        timeZone: TimeZone(identifier: "America/Anchorage"))

    // MARK: - When it is

    func test_isStillOnGround_onlyAfterThePlansTakeoffTime_whileItsRealPlaneIsAtItsDepartureAirport() throws {
        for (name, time) in [("still on the ground just after the plan's takeoff", "13T12:18:00"),
                             ("still on the ground twenty minutes after", "13T12:35:00")] {
            let (leg, at) = try leg(of: name, at: time)
            XCTAssertTrue(leg.isStillOnGround(at: at), name)
        }
        for (name, time) in [("on the ground before the plan's takeoff", "13T12:10:00"), ("ahead, in the air", "13T12:41:50"),
                             ("landed, seen all the way", "13T13:30:00"), ("on the ground somewhere else", "13T13:21:00"),
                             ("no live data", "13T12:30:00")] {
            let (leg, at) = try leg(of: name, at: time)
            XCTAssertFalse(leg.isStillOnGround(at: at), name)
        }
    }

    func test_isStillOnGround_atEverySharedMoment_isTheBarsStillOnTheGround() throws {
        let cases = try TripMapFixtures.liveCases()
        var atTheGate = 0
        for flightCase in cases.flights {
            for moment in flightCase.moments {
                let leg = try cases.mapLeg(flightCase, at: moment)
                let expected = moment.phase == "onGround" && (moment.label?.hasPrefix("Still on the ground") ?? false)
                XCTAssertEqual(leg.isStillOnGround(at: moment.at), expected, "\(flightCase.name) at \(moment.at)")
                XCTAssertEqual(try cases.mapFlight(flightCase).isAtDeparture(at: moment.at), expected, "\(flightCase.name) at \(moment.at)")
                if expected { atTheGate += 1 }
            }
        }
        XCTAssertGreaterThanOrEqual(atTheGate, 2)
    }

    func test_isAtDeparture_goesByCrewluCloudsClock() throws {
        // Crewlu Cloud's clock is 6 minutes ahead of this device's: at 12:12 here it's 12:18 there, after the plan's
        // takeoff time at 12:15.
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "still on the ground just after the plan's takeoff")
        let moment = try cases.moment("13T12:18:00", of: flightCase)
        XCTAssertTrue(try cases.mapFlight(flightCase, clockOffset: 360).isAtDeparture(at: moment.at.addingTimeInterval(-360)))
        XCTAssertFalse(try cases.mapFlight(flightCase).isAtDeparture(at: moment.at.addingTimeInterval(-360)))
    }

    func test_flightInMotion_isTheFlightBetweenItsGates_neverADrive() throws {
        let (flight, _) = try leg(of: "ahead, in the air", at: "13T12:41:50")
        let drive = MapLeg(id: "d1", kind: .drive, origin: flight.destination, destination: flight.origin,
                           start: flight.end, end: flight.end.addingTimeInterval(3600), flightNumber: nil)
        let map = TripMap(mode: .onTrip, legs: [flight, drive], home: flight.origin,
                          span: DateInterval(start: flight.start, end: drive.end), tripDays: nil)
        XCTAssertEqual(map.flightInMotion(at: flight.start.addingTimeInterval(600))?.id, flight.id)
        XCTAssertNil(map.flightInMotion(at: drive.start.addingTimeInterval(600)))
        XCTAssertNil(map.flightInMotion(at: flight.start.addingTimeInterval(-60)))
    }

    func test_isStillOnGround_isNeverADrive_norAFlightOutsideItsGates() throws {
        let (leg, at) = try leg(of: "still on the ground twenty minutes after", at: "13T12:35:00")
        let drive = MapLeg(id: "d1", kind: .drive, origin: leg.origin, destination: leg.destination, start: leg.start, end: leg.end,
                           flightNumber: nil)
        XCTAssertFalse(drive.isStillOnGround(at: at))
        let over = MapLeg(id: leg.id, kind: .flight, origin: leg.origin, destination: leg.destination, start: leg.start,
                          end: at, flightNumber: leg.flightNumber, flight: leg.flight)
        XCTAssertFalse(over.isStillOnGround(at: at))
    }

    func test_stillOnGroundAirport_isTheFlightsDepartureAirport_whileItsRealPlaneWaitsThere() throws {
        let (atTheGate, gateTime) = try leg(of: "still on the ground twenty minutes after", at: "13T12:35:00")
        XCTAssertEqual(map(of: atTheGate).stillOnGroundAirport(at: gateTime)?.code, "SDF")
        let (flying, flyingTime) = try leg(of: "ahead, in the air", at: "13T12:41:50")
        XCTAssertNil(map(of: flying).stillOnGroundAirport(at: flyingTime))
    }

    func test_stillOnGroundFlight_isTheFlightBetweenItsGatesWhoseRealPlaneHasntLeft_byItsID() throws {
        let cases = try TripMapFixtures.liveCases()
        func flight(_ name: String, at time: String) throws -> String? {
            let flightCase = try cases.flight(named: name)
            let now = try cases.moment(time, of: flightCase).at
            let flights = ["f1": try cases.mapFlight(flightCase)]
            let legs = LiveLegs.replacingTimes(in: [cases.tripLeg(flightCase)], with: flights, at: now)
            return LiveLegs.stillOnGroundFlight(in: legs, flights: flights, at: now)
        }
        XCTAssertEqual(try flight("still on the ground twenty minutes after", at: "13T12:35:00"), "f1")
        XCTAssertEqual(try flight("still on the ground just after the plan's takeoff", at: "13T12:18:00"), "f1")
        XCTAssertNil(try flight("on the ground before the plan's takeoff", at: "13T12:10:00"))
        XCTAssertNil(try flight("ahead, in the air", at: "13T12:41:50"))
        XCTAssertNil(try flight("no live data", at: "13T12:30:00"))
        let atTheGate = try cases.flight(named: "still on the ground twenty minutes after")
        XCTAssertNil(LiveLegs.stillOnGroundFlight(in: [cases.tripLeg(atTheGate)], flights: [:], at: try cases.moment("13T12:35:00", of: atTheGate).at))
    }

    // MARK: - The words

    func test_timeline_saysWhereTheRealPlaneIsStillOnTheGround_inPlaceOfFlying() {
        // 5:21 PM UTC is 12:21 PM in Louisville.
        let date = FactsTestData.date("2026-11-13T17:21:00Z")
        let flying = TripActivity(kind: .flying, place: anchorage)
        XCTAssertEqual(plain(TripMapWording.timelineLine(date, activity: flying, stillOnGroundIn: rockford, calendar: calendar, locale: locale)),
                       "Fri 12:21 PM · On the ground in Rockford")
        XCTAssertEqual(plain(TripMapWording.timelineSpokenValue(date, activity: flying, stillOnGroundIn: rockford, calendar: calendar, locale: locale)),
                       "Friday 12:21 PM, on the ground in Rockford")
        // Without it, flying, as before.
        XCTAssertEqual(plain(TripMapWording.timelineLine(date, activity: flying, calendar: calendar, locale: locale)),
                       "Fri 12:21 PM · Flying to Anchorage")
        XCTAssertEqual(plain(TripMapWording.timelineSpokenValue(date, activity: flying, calendar: calendar, locale: locale)),
                       "Friday 12:21 PM, flying to Anchorage")
    }

    func test_factsWords_sayItsStillOnTheGround_andHowFarItHasToGo() {
        XCTAssertEqual(FactsWording.stillOnGround(in: rockford), "Still on the ground in Rockford")
        XCTAssertEqual(FactsWording.toGo(miles: 2_788, locale: locale), "2,788 mi to go")
    }
}
```

Create `CrewluvTests/PlaneKeyTests.swift`:

```swift
//
//  PlaneKeyTests.swift
//  CrewluvTests
//
//  When the map shows the key to its two planes (which plane design §2): while it draws a real plane and its ghost,
//  now only, on the shared cases' flights.
//

import XCTest
@testable import Crewluv

final class PlaneKeyTests: XCTestCase {

    /// A shared case's flight at one of its moments, as the map of that one flight.
    private func map(of name: String, at time: String) throws -> (map: TripMap, at: Date) {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: name)
        let moment = try cases.moment(time, of: flightCase)
        let leg = try cases.mapLeg(flightCase, at: moment)
        return (TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: leg.origin,
                        span: DateInterval(start: leg.start, end: leg.end), tripDays: nil), moment.at)
    }

    func test_showsPlaneKey_whileTheRealPlaneAndItsGhostShow() throws {
        for (name, time) in [("ahead, in the air", "13T12:41:50"), ("ahead, in the air", "13T12:45:00"),
                             ("still on the ground twenty minutes after", "13T12:35:00")] {
            let (map, at) = try map(of: name, at: time)
            XCTAssertTrue(TripMapDrawing(tripMap: map, at: at).showsPlaneKey, "\(name) at \(time)")
        }
    }

    func test_showsPlaneKey_notForAPlaneWithNoGhost_norInAReplay() throws {
        for (name, time) in [("landed, seen all the way", "13T13:30:00"), ("on the ground somewhere else", "13T13:21:00"),
                             ("no live data", "13T12:30:00"), ("waiting to be seen", "13T12:30:00")] {
            let (map, at) = try map(of: name, at: time)
            XCTAssertFalse(TripMapDrawing(tripMap: map, at: at).showsPlaneKey, "\(name) at \(time)")
        }
        let (map, at) = try map(of: "ahead, in the air", at: "13T12:41:50")
        XCTAssertFalse(TripMapDrawing(tripMap: map, at: at, isReplay: true).showsPlaneKey)
        XCTAssertFalse(TripMapDrawing.showsPlaneKey(on: map, at: at, isReplay: true))
    }

    func test_showsPlaneKey_atEverySharedMoment_isWhetherTheCaseHasBothPlanes_withoutDrawingTheRest() throws {
        let cases = try TripMapFixtures.liveCases()
        var shown = 0
        for flightCase in cases.flights {
            for moment in flightCase.moments {
                let leg = try cases.mapLeg(flightCase, at: moment)
                let map = TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: leg.origin,
                                  span: DateInterval(start: leg.start, end: leg.end), tripDays: nil)
                // The map draws a flight's planes between its gates.
                let expected = moment.plane != nil && moment.ghost != nil && leg.isMoving(at: moment.at)
                XCTAssertEqual(TripMapDrawing(tripMap: map, at: moment.at).showsPlaneKey, expected, "\(flightCase.name) at \(moment.at)")
                XCTAssertEqual(TripMapDrawing.showsPlaneKey(on: map, at: moment.at, isReplay: false), expected,
                               "\(flightCase.name) at \(moment.at)")
                if expected { shown += 1 }
            }
        }
        XCTAssertGreaterThan(shown, 20)
    }

    func test_showsPlaneKey_notOnTheGround_beforeOrAfterTheFlight() throws {
        let (map, _) = try map(of: "ahead, in the air", at: "13T12:41:50")
        let leg = try XCTUnwrap(map.legs.first)
        for date in [leg.start.addingTimeInterval(-60), leg.end] {
            XCTAssertFalse(TripMapDrawing(tripMap: map, at: date).showsPlaneKey)
            XCTAssertFalse(TripMapDrawing.showsPlaneKey(on: map, at: date, isReplay: false))
        }
    }
}
```

In `CrewluvTests/LiveWordingTests.swift`:

Replace:

```swift
    func test_liveSummary_withNoLabel_isNil() throws {
```

with:

```swift
    func test_liveSummary_saysWhatsBelowAndWhereItWasLastSeen_onlyWhileItFlies() throws {
        let (atTheGate, gateTime) = try leg(of: "still on the ground twenty minutes after", at: "13T12:35:00")
        XCTAssertEqual(plain(try XCTUnwrap(TripMapWording.liveSummary(for: atTheGate, over: "Kentucky", lastSeen: "near Louisville",
                                                                      now: gateTime, calendar: calendar, locale: locale))),
                       "UPS207 to Philadelphia, still on the ground, 20 minutes behind schedule. Lands about 9:05 AM your time.")
        let (landed, landedTime) = try leg(of: "landed, seen all the way", at: "13T13:30:00")
        XCTAssertEqual(plain(try XCTUnwrap(TripMapWording.liveSummary(for: landed, over: "Pennsylvania", lastSeen: "near Philadelphia",
                                                                      now: landedTime, calendar: calendar, locale: locale))),
                       "UPS207 to Philadelphia, landed 23 minutes early. Reaches the gate at 8:21 AM your time.")
    }

    func test_liveSummary_withNoLabel_isNil() throws {
```

- [x] **Step 2: A plane still at its gate, and the flight between its gates.**

In `Crewluv/Services/TripMap/Live/MapFlight.swift`:

Replace:

```swift
    func isEstimate(_ arrival: Date) -> Bool {
        live?.state != .landed && abs(arrival.timeIntervalSince(plan.arrival)) >= 1
    }
```

with:

```swift
    func isEstimate(_ arrival: Date) -> Bool {
        live?.state != .landed && abs(arrival.timeIntervalSince(plan.arrival)) >= 1
    }

    /// Whether the real plane is still on the ground at its departure airport after the plan's takeoff time, when
    /// this device's clock says `now`: seen there lately, not yet in the air (spec §5.1's `onGround`), and late
    /// leaving, as its bar says "Still on the ground". Before the plan's takeoff it's taxiing as the schedule has it,
    /// and nothing says so (which plane design §4).
    func isAtDeparture(at now: Date) -> Bool {
        let progress = self.progress(at: now)
        guard progress.phase == .onGround, case .stillOnGround = progress.label else { return false }
        return true
    }
```

In `Crewluv/Services/TripMap/MapLeg.swift`:

Replace:

```swift
    /// True from leaving the gate until reaching the other one.
    func isMoving(at date: Date) -> Bool { start <= date && date < end }
```

with:

```swift
    /// True from leaving the gate until reaching the other one.
    func isMoving(at date: Date) -> Bool { start <= date && date < end }

    /// Whether the flight is between its gates at `date` while its real plane is still on the ground at its departure
    /// airport after the plan's takeoff time (`MapFlight.isAtDeparture`, which plane design §4).
    func isStillOnGround(at date: Date) -> Bool {
        isMoving(at: date) && (flight?.isAtDeparture(at: date) ?? false)
    }
```

In `Crewluv/Services/TripMap/TripMap.swift`:

Replace:

```swift
    func legInMotion(at date: Date) -> MapLeg? {
        legs.first { $0.isMoving(at: date) }
    }
```

with:

```swift
    func legInMotion(at date: Date) -> MapLeg? {
        legs.first { $0.isMoving(at: date) }
    }

    /// The flight between its gates at `date`: the one the map draws its planes for.
    func flightInMotion(at date: Date) -> MapLeg? {
        legs.first { $0.kind == .flight && $0.isMoving(at: date) }
    }
```

In `Crewluv/Services/TripMap/TripMap+Activity.swift`:

Replace:

```swift
        guard let place = pilotLocation(at: date) else { return nil }
        return TripActivity(kind: groundKind(at: date, place: place), place: place)
    }
```

with:

```swift
        guard let place = pilotLocation(at: date) else { return nil }
        return TripActivity(kind: groundKind(at: date, place: place), place: place)
    }

    /// Where the pilot's flight waits at `date`, while it's between its gates and its real plane is still on the
    /// ground at its departure airport after the plan's takeoff time: that airport, which the line under the timeline
    /// names in place of "Flying to" (which plane design §4). Nil otherwise. A replay's moment is flying, as the map
    /// has the plane, so the facts ask this only of now.
    func stillOnGroundAirport(at date: Date) -> AirportMark? {
        guard let flight = flightInMotion(at: date), flight.isStillOnGround(at: date) else { return nil }
        return flight.origin
    }
```

In `Crewluv/Services/TripMap/Live/LiveLegs.swift`:

Replace:

```swift
    /// `legs`, as `replacingTimes` gives them, for the schedule's list, which shows each leg's written times as they
```

with:

```swift
    /// The flight between its gates at `now` whose real plane is still on the ground at its departure airport after
    /// the plan's takeoff time, by its leg's id: the status sentence says so (which plane design §4). Nil with no
    /// such flight.
    static func stillOnGroundFlight(in legs: [TripLeg], flights: [String: MapFlight], at now: Date) -> String? {
        guard !flights.isEmpty else { return nil }
        return legs.first { leg in
            leg.type == .flight && leg.effectiveStart <= now && now < leg.effectiveEnd
                && (flights[leg.id]?.isAtDeparture(at: now) ?? false)
        }?.id
    }

    /// `legs`, as `replacingTimes` gives them, for the schedule's list, which shows each leg's written times as they
```

- [x] **Step 3: When the key shows.**

In `Crewluv/Services/TripMap/TripMapDrawing.swift`:

Replace:

```swift
        self.ghost = ghost
        self.pilot = tripMap.activity(at: date).flatMap { $0.kind.isMoving ? nil : $0 }
    }
}
```

with:

```swift
        self.ghost = ghost
        self.pilot = tripMap.activity(at: date).flatMap { $0.kind.isMoving ? nil : $0 }
    }

    /// Whether the map shows the key to its two planes: while it draws a real plane and its ghost (which plane
    /// design §2). That's now, never in a replay, for a flight Crewlu Cloud has seen at its departure airport, in the
    /// air, or not for a while.
    var showsPlaneKey: Bool {
        realPlane != nil && ghost != nil
    }

    /// `showsPlaneKey` for `tripMap` at `date`, worked out without drawing the rest, for the views that place the key.
    /// As `FlightDrawing` has it: the flight between its gates draws the real plane where its progress has one, and
    /// the ghost where its progress has that.
    static func showsPlaneKey(on tripMap: TripMap, at date: Date, isReplay: Bool) -> Bool {
        guard !isReplay, let flight = tripMap.flightInMotion(at: date)?.flight else { return false }
        let progress = flight.progress(at: date)
        return progress.plane != nil && progress.ghostDistance != nil
    }
}
```

- [x] **Step 4: The words.**

Create `Crewluv/Services/TripMap/PlanePopupWords.swift`:

```swift
//
//  PlanePopupWords.swift
//  CrewLuve
//
//  What a plane's popup on the full-screen map says (which plane design §3): which plane it is, then what the card's
//  bar says of it, with when it lands, in this device's time zone and clock. Nothing else writes them.
//

import Foundation

/// Which of a flight's two planes: the real one, or the ghost where an on-schedule plane would be.
nonisolated enum PlaneKind: Equatable, Sendable {
    case realPlane
    case ghost
}

nonisolated struct PlanePopupWords: Equatable, Sendable {
    let title: String
    /// A line or two under the title. None for a real plane down somewhere else, which has no label and no landing
    /// time to give.
    let lines: [String]

    init(title: String, lines: [String]) {
        self.title = title
        self.lines = lines
    }

    /// The popup on one of `leg`'s planes at `date`: now, or a moment of the replay when `isReplay`.
    init(leg: MapLeg, plane: PlaneKind, at date: Date, isReplay: Bool,
         calendar: Calendar = .current, locale: Locale = .current) {
        let name = leg.flightNumber ?? "the flight"
        func time(_ date: Date) -> String { TripMapWording.clockTime(date, in: calendar.timeZone, locale: locale) }
        guard plane == .realPlane else {
            self.init(title: "On schedule", lines: ["Where \(name) was scheduled to be"])
            return
        }
        let title = "\(Self.capitalized(name)) · real plane"
        if isReplay {
            self.init(title: title, lines: ["Where it was at \(time(date))"])
            return
        }
        guard let flight = leg.flight else {
            self.init(title: title, lines: [])
            return
        }
        let progress = flight.progress(at: date)
        let label = progress.label.map(TripMapWording.liveLabel)
        let about = TripMapWording.about(leg)
        switch progress.phase {
        case .estimated:
            let seen = flight.live?.fix.map { "Not seen since \(time($0.seenAt)), so it's drawn where it should be by now" }
            let lands = "lands \(about)\(time(leg.end))"
            self.init(title: "\(Self.capitalized(name)) · best guess",
                      lines: [seen, label.map { "\($0) · \(lands)" } ?? Self.capitalized(lands)].compactMap { $0 })
        case .onGround, .inAir:
            self.init(title: title, lines: [label, TripMapWording.landsAt(for: leg, calendar: calendar, locale: locale)].compactMap { $0 })
        case .landed:
            // "at" the gate, as the card's sentence says once the plane is down, or "about" while that's still an estimate.
            self.init(title: title, lines: [label, "Reaches the gate \(about.isEmpty ? "at " : about)\(time(leg.end))"].compactMap { $0 })
        case .notLive, .elsewhere:
            // Down somewhere else: it has no label, and no landing time to give.
            self.init(title: title, lines: [])
        }
    }

    /// "the flight" → "The flight".
    private static func capitalized(_ text: String) -> String {
        text.prefix(1).uppercased() + text.dropFirst()
    }
}
```

In `Crewluv/Services/TripMap/TripMapWording.swift`:

Replace:

```swift
        guard let label = leg.flight?.progress(at: now).label else { return nil }
        let lead = leg.flightNumber.map { "\($0) to" } ?? "Flying to"
        let over = (place.map { ", over \($0)" } ?? "") + (lastSeen.map { ", last seen \($0)" } ?? "")
```

with:

```swift
        guard let label = leg.flight?.progress(at: now).label else { return nil }
        let lead = leg.flightNumber.map { "\($0) to" } ?? "Flying to"
        // What's below and where it was last seen are said only of a plane in the air: not of one still at its gate,
        // nor of one that's down (which plane design §4).
        let isFlying = switch label {
        case .onSchedule, .ahead, .behind: true
        case .stillOnGround, .landedOnTime, .landedEarly, .landedLate: false
        }
        let over = isFlying ? (place.map { ", over \($0)" } ?? "") + (lastSeen.map { ", last seen \($0)" } ?? "") : ""
```

Replace:

```swift
    /// "Sat 1:40 PM · Layover in Denver": the line under the timeline, when and what (activity markers design §4.2).
    static func timelineLine(_ date: Date, activity: TripActivity?, calendar: Calendar = .current,
                             locale: Locale = .current) -> String {
        let time = timelineTime(date, calendar: calendar, locale: locale)
        guard let activity else { return time }
        return "\(time) · \(activity.words)"
    }

    /// "Saturday 1:40 PM, layover in Denver": the timeline's VoiceOver value (activity markers design §4.3).
    static func timelineSpokenValue(_ date: Date, activity: TripActivity?, calendar: Calendar = .current,
                                    locale: Locale = .current) -> String {
        let time = date.formatted(style(calendar: calendar, locale: locale).weekday(.wide).hour().minute())
        guard let activity else { return time }
        let words = activity.words
        return "\(time), \(words.prefix(1).lowercased() + words.dropFirst())"
    }
```

with:

```swift
    /// "Sat 1:40 PM · Layover in Denver": the line under the timeline, when and what (activity markers design §4.2).
    /// While the flight's real plane is still on the ground at its departure airport, `stillOnGroundIn`: "Mon 12:21 PM
    /// · On the ground in Rockford".
    static func timelineLine(_ date: Date, activity: TripActivity?, stillOnGroundIn airport: AirportMark? = nil,
                             calendar: Calendar = .current, locale: Locale = .current) -> String {
        let time = timelineTime(date, calendar: calendar, locale: locale)
        guard let words = timelineWords(activity, stillOnGroundIn: airport) else { return time }
        return "\(time) · \(words)"
    }

    /// "Saturday 1:40 PM, layover in Denver": the timeline's VoiceOver value (activity markers design §4.3), as the
    /// line under it says.
    static func timelineSpokenValue(_ date: Date, activity: TripActivity?, stillOnGroundIn airport: AirportMark? = nil,
                                    calendar: Calendar = .current, locale: Locale = .current) -> String {
        let time = date.formatted(style(calendar: calendar, locale: locale).weekday(.wide).hour().minute())
        guard let words = timelineWords(activity, stillOnGroundIn: airport) else { return time }
        return "\(time), \(words.prefix(1).lowercased() + words.dropFirst())"
    }

    /// What the pilot is doing, or "On the ground in Rockford" where the flight's real plane is still on the ground at
    /// its departure airport (which plane design §4).
    private static func timelineWords(_ activity: TripActivity?, stillOnGroundIn airport: AirportMark?) -> String? {
        if let airport { return "On the ground in \(airport.name)" }
        return activity?.words
    }
```

In `Crewluv/Services/TripMap/Facts/FactsWording.swift`:

Replace:

```swift
    // MARK: - The real plane (Stage 3 spec §8)
```

with:

```swift
    /// In place of what's below, a real plane still on the ground at its departure airport after the plan's takeoff
    /// time: "Still on the ground in Rockford" (which plane design §4).
    static func stillOnGround(in airport: AirportMark) -> String {
        "Still on the ground in \(airport.name)"
    }

    // MARK: - The real plane (Stage 3 spec §8)
```

Replace:

```swift
    /// "2,140 mi flown · 1,960 to go".
    static func distance(flownMiles: Int, toGoMiles: Int, locale: Locale = .current) -> String {
        "\(number(flownMiles, locale: locale)) mi flown · \(number(toGoMiles, locale: locale)) to go"
    }
```

with:

```swift
    /// "2,140 mi flown · 1,960 to go".
    static func distance(flownMiles: Int, toGoMiles: Int, locale: Locale = .current) -> String {
        "\(number(flownMiles, locale: locale)) mi flown · \(number(toGoMiles, locale: locale)) to go"
    }

    /// "2,788 mi to go": a real plane still at its departure airport has flown nothing yet (which plane design §4).
    static func toGo(miles: Int, locale: Locale = .current) -> String {
        "\(number(miles, locale: locale)) mi to go"
    }
```

---

### Task 3: The facts of a plane still at its gate

- [x] **Step 1: The tests.**

Create `CrewluvTests/StillOnGroundFactsTests.swift`:

```swift
//
//  StillOnGroundFactsTests.swift
//  CrewluvTests
//
//  The facts of a flight whose real plane is still on the ground at its departure airport after the plan's takeoff
//  time (which plane design §4), in US English for a family in Louisville. The flight is `FactsTestData`'s equator
//  flight, from E0 to E20: its gates at 10:00 and 13:22 UTC, its plan in the air from 10:15. Here its real plane
//  hasn't left the gate.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class StillOnGroundFactsTests: XCTestCase {

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

    /// The real plane at the gate in E0, last seen there half a minute before `now`.
    private func atTheGate(_ now: String) -> LiveFlight {
        let fix = LiveFlight.Fix(latitude: 0, longitude: 0, altitudeFeet: nil, groundSpeedKnots: 0, trackDegrees: nil,
                                 isOnGround: true, registration: "N370UP", typeCode: "B763", seenAt: at(now).addingTimeInterval(-30))
        return LiveFlight(legID: "eq", callsign: "TST1", state: .ground, fix: fix, landedAt: nil, trail: [])
    }

    /// The facts of a map of the one flight, its real plane at the gate, as the status screen's model hands it on at `now`.
    private func facts(atTheGate now: String, isReplay: Bool = false) throws -> TripFacts {
        try facts(of: try FactsTestData.equatorLiveLeg(atTheGate(now), at: at(now)), isReplay: isReplay)
    }

    private func facts(of leg: MapLeg, isReplay: Bool = false) throws -> TripFacts {
        let home = FactsTestData.homeByTheEquator
        let map = TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: home,
                          span: DateInterval(start: leg.start, end: leg.end), tripDays: nil)
        return TripFacts(tripMap: map, geography: FactsTestData.equator, comparisons: try FactsTestData.appComparisons(),
                         stories: [leg.id: LegStory(leg: leg, geography: FactsTestData.equator, home: home)],
                         sunEvents: [leg.id: SkyFacts.sunEvents(on: leg)], dayNumber: 1, totalDays: 1,
                         calendar: calendar, locale: locale, isReplay: isReplay)
    }

    private func row(_ kind: FactRow.Kind, in rows: [FactRow]) throws -> FactRow {
        try XCTUnwrap(rows.first { $0.kind == kind }, "no \(kind) row")
    }

    // MARK: - The headline

    func test_headline_atTheGateAfterThePlansTakeoff_isStillOnTheGround_aheadOfAnyEventOrSunCountdown() throws {
        // At 11:20 the plan has the plane past 5° E, where it crossed into Bravo at about 11:00.
        let facts = try facts(atTheGate: "11:20")
        XCTAssertEqual(facts.headline(at: at("11:20")), "Still on the ground in E0")
        XCTAssertEqual(facts.headline(at: at("11:20"), includesEvents: false), "Still on the ground in E0")
        XCTAssertEqual(facts.sheetHeadline(at: at("11:20")), "Still on the ground in E0")
    }

    func test_headline_atTheGateBeforeThePlansTakeoff_isAsBefore() throws {
        XCTAssertEqual(try facts(atTheGate: "10:10").headline(at: at("10:10")), "Over Alpha")
    }

    func test_headline_inAReplay_isWhereTheMapHasThePlane() throws {
        // With no record, a replay's plane is the schedule's, which crossed into Bravo a few minutes before.
        XCTAssertEqual(try facts(atTheGate: "11:20", isReplay: true).headline(at: at("11:20")), "Just crossed into Bravo")
    }

    // MARK: - The rows

    func test_rows_atTheGate_sayItsStillOnTheGround_howFarItHasToGo_andNoSky() throws {
        let rows = try facts(atTheGate: "11:20").rows(at: at("11:20"), now: at("11:20"))
        let below = try row(.below, in: rows)
        XCTAssertEqual(below.title, "Still on the ground in E0")
        // The plan, run from a takeoff that hasn't happened, has the plane at 14° E at 13:06, 9:06 AM in Louisville.
        XCTAssertEqual(plain(below.detail), "Passes 35 mi from home at about 9:06 AM")
        XCTAssertNil(rows.first { $0.kind == .sky })
        let distance = try row(.distance, in: rows)
        XCTAssertEqual(distance.title, "1,382 mi to go")
        XCTAssertEqual(plain(distance.detail), "Halfway at about 8:17 AM · like driving the Alaska Highway")
        // The plane's row has no height or speed: it isn't in the air.
        XCTAssertEqual(try row(.plane, in: rows).title, "Boeing 767-300 · N370UP")
        XCTAssertNil(try row(.plane, in: rows).detail)
    }

    func test_rows_atTheGate_haveNoSky_whereTheScheduleWouldFlyIntoTheNight() throws {
        // At 16:30 the schedule's plane is over the Test Sea, 52 minutes before its cockpit sunset.
        let replayRows = try facts(atTheGate: "16:30", isReplay: true).rows(at: at("16:30"), now: at("16:30"))
        XCTAssertEqual(try row(.sky, in: replayRows).title, "Flying into the night")
        let rows = try facts(atTheGate: "16:30").rows(at: at("16:30"), now: at("16:30"))
        XCTAssertNil(rows.first { $0.kind == .sky })
    }

    func test_rows_atTheGate_leaveOutTheClosestPointToHome_andHalfway_onceTheirGuessesHaveGoneBy() throws {
        // Nearly eight hours on, the guesses from a takeoff that hasn't happened have both gone by: the plan, run from
        // the leg's start to its new end, has the plane past 14° E before 18:00.
        let rows = try facts(atTheGate: "18:00").rows(at: at("18:00"), now: at("18:00"))
        XCTAssertNil(try row(.below, in: rows).detail)
        XCTAssertFalse(try row(.distance, in: rows).detail?.contains("Halfway") ?? false)
    }

    func test_rows_atTheGateBeforeThePlansTakeoff_areAsBefore() throws {
        let rows = try facts(atTheGate: "10:10").rows(at: at("10:10"), now: at("10:10"))
        XCTAssertEqual(try row(.below, in: rows).title, "Over Alpha")
        XCTAssertEqual(try row(.distance, in: rows).title, "0 mi flown · 1,382 to go")
    }

    // MARK: - The banner and the list

    func test_latestEvent_atTheGate_isNone() throws {
        XCTAssertNil(try facts(atTheGate: "11:20").latestEvent(at: at("11:20")))
    }

    func test_tripSoFar_atTheGate_leavesTheFlightOutUntilItTakesOff() throws {
        let soFar = try facts(atTheGate: "11:20").tripSoFar(at: at("11:20"))
        XCTAssertEqual(soFar.flights.map(\.id), [])
        XCTAssertNotNil(soFar.totals)
    }

    func test_tripSoFar_listsTheFlight_onceItsTakenOff() throws {
        let inTheAir = try FactsTestData.equatorLiveLeg(FactsTestData.equatorLive(seenUntil: at("11:20")), at: at("11:20"))
        let soFar = try facts(of: inTheAir).tripSoFar(at: at("11:20"))
        XCTAssertEqual(soFar.flights.map(\.id), ["eq"])
        XCTAssertEqual(soFar.flights.first?.tag, "In the air now")
    }

    // MARK: - The card's sentence and the timeline

    func test_cardSummary_atTheGate_saysSo_withNothingBelowAndNoLatestEvent() throws {
        XCTAssertEqual(plain(try facts(atTheGate: "11:20").cardSummary(now: at("11:20"), pilotName: "Alex")),
                       "TST1 to E20, still on the ground, 1 hour 5 minutes behind schedule. Lands about 10:27 AM your time.")
    }

    func test_stillOnGroundAirport_isTheDepartureAirport_nowOnly() throws {
        XCTAssertEqual(try facts(atTheGate: "11:20").stillOnGroundAirport(at: at("11:20"))?.code, "E0")
        XCTAssertNil(try facts(atTheGate: "11:20", isReplay: true).stillOnGroundAirport(at: at("11:20")))
        XCTAssertNil(try facts(atTheGate: "10:10").stillOnGroundAirport(at: at("10:10")))
    }
}
```

- [x] **Step 2: The headline, the banner and the list.**

In `Crewluv/Services/TripMap/Facts/TripFacts.swift`:

Replace:

```swift
    /// In flight: a milestone from the last 5 minutes, else a cockpit sunrise or sunset in the next 30, else the place
    /// below, else the landing countdown. While the real plane is out of sight they're its best guesses, in the same
    /// plain words (best guesses design §2). Nil on the ground and on a drive, where Stage 1's words stay.
    /// - Parameter includesEvents: false beside the latest event's banner, which shows the milestone already
    ///   (latest event design §2).
    func headline(at date: Date, includesEvents: Bool = true) -> String? {
        guard let leg = tripMap.legInMotion(at: date), leg.kind == .flight else { return nil }
```

with:

```swift
    /// In flight: a milestone from the last 5 minutes, else a cockpit sunrise or sunset in the next 30, else the place
    /// below, else the landing countdown. While the real plane is out of sight they're its best guesses, in the same
    /// plain words (best guesses design §2). Nil on the ground and on a drive, where Stage 1's words stay.
    ///
    /// A real plane still on the ground at its departure airport after the plan's takeoff time is "Still on the ground
    /// in Rockford", ahead of all of them: it has crossed nothing yet, whatever the schedule's times say (which plane
    /// design §4).
    /// - Parameter includesEvents: false beside the latest event's banner, which shows the milestone already
    ///   (latest event design §2).
    func headline(at date: Date, includesEvents: Bool = true) -> String? {
        guard let leg = tripMap.legInMotion(at: date), leg.kind == .flight else { return nil }
        if isStillOnGround(leg, at: date) {
            return FactsWording.stillOnGround(in: leg.origin)
        }
```

Replace:

```swift
    /// The newest event of the flight between its gates at `date`, for the banner (latest event design §1). Nil on
    /// the ground, on a drive, and before the flight's first event.
    func latestEvent(at date: Date) -> LatestEvent? {
        guard let leg = tripMap.legInMotion(at: date), leg.kind == .flight else { return nil }
```

with:

```swift
    /// The newest event of the flight between its gates at `date`, for the banner (latest event design §1). Nil on
    /// the ground, on a drive, and before the flight's first event, and for a real plane still on the ground at its
    /// departure airport after the plan's takeoff time, which has passed nothing yet (which plane design §4).
    func latestEvent(at date: Date) -> LatestEvent? {
        guard let leg = tripMap.legInMotion(at: date), leg.kind == .flight, !isStillOnGround(leg, at: date) else { return nil }
```

Replace:

```swift
    /// Whether a flight with live data shows, which adsb.lol is credited for (Stage 3 spec §8).
```

with:

```swift
    /// Whether the real plane of `leg`, the leg between its gates at `date`, is still on the ground at its departure
    /// airport after the plan's takeoff time (which plane design §4). The facts then say so in place of what's below,
    /// and count nothing of the flight as passed. Now only: a replay reads where the map has the plane.
    func isStillOnGround(_ leg: MapLeg, at date: Date) -> Bool {
        !isReplay && leg.isStillOnGround(at: date)
    }

    /// The airport where the flight between its gates at `date` waits, while its real plane is still on the ground
    /// there after the plan's takeoff time: the line under the timeline names it (which plane design §4). Nil in a
    /// replay, whose moment is flying, as the map has the plane.
    func stillOnGroundAirport(at date: Date) -> AirportMark? {
        isReplay ? nil : tripMap.stillOnGroundAirport(at: date)
    }

    /// Whether a flight with live data shows, which adsb.lol is credited for (Stage 3 spec §8).
```

Replace:

```swift
    func tripSoFar(at date: Date) -> TripSoFar {
        let started = tripMap.legs.filter { $0.kind == .flight && $0.start <= date }.reversed()
```

with:

```swift
    /// A real plane still on the ground at its departure airport after the plan's takeoff time has passed none of its
    /// flight's events, and its flight is left out until it takes off, with no "In the air now" (which plane design
    /// §4).
    func tripSoFar(at date: Date) -> TripSoFar {
        let started = tripMap.legs.filter { $0.kind == .flight && $0.start <= date && !isStillOnGround($0, at: date) }.reversed()
```

- [x] **Step 3: The rows.**

In `Crewluv/Services/TripMap/Facts/TripFacts+Rows.swift`:

Replace:

```swift
    /// What's below, then where a plane that's out of sight was last seen, then the closest point to home. The
    /// first of them that there is leads the row.
    private func belowRow(on leg: MapLeg, at date: Date) -> FactRow? {
        let lines = [belowText(on: leg, at: date), lastSeenLine(on: leg, at: date), closestToHomeLine(on: leg, at: date)]
            .compactMap { $0 }
```

with:

```swift
    /// What's below, then where a plane that's out of sight was last seen, then the closest point to home. The
    /// first of them that there is leads the row. A real plane still at its departure airport says so in place of
    /// what's below (which plane design §4).
    private func belowRow(on leg: MapLeg, at date: Date) -> FactRow? {
        let place = isStillOnGround(leg, at: date) ? FactsWording.stillOnGround(in: leg.origin) : belowText(on: leg, at: date)
        let lines = [place, lastSeenLine(on: leg, at: date), closestToHomeLine(on: leg, at: date)]
            .compactMap { $0 }
```

Replace:

```swift
    /// "Passes 40 mi from home at 1:05 PM", or "Closest to home was 40 mi at 1:05 PM" once it's passed. Where
    /// nobody saw the real plane it's a best guess, and its time reads "about" (best guesses design §2).
    private func closestToHomeLine(on leg: MapLeg, at date: Date) -> String? {
        guard let story = stories[leg.id], let closest = story.closestToHome else { return nil }
        let distance = closest.fraction * story.length
        guard let time = leg.time(atDistance: distance) else { return nil }
        return FactsWording.closestToHome(miles: Milestone.roundedMiles(closest.meters), at: time, now: date,
                                          isEstimate: !leg.isSeen(atDistance: distance), calendar: calendar, locale: locale)
    }
```

with:

```swift
    /// "Passes 40 mi from home at 1:05 PM", or "Closest to home was 40 mi at 1:05 PM" once it's passed. Where
    /// nobody saw the real plane it's a best guess, and its time reads "about" (best guesses design §2).
    ///
    /// A real plane still on the ground at its departure airport has passed nothing, and its time is a guess from a
    /// takeoff that hasn't happened: "about", and left out once that guess has gone by, as halfway's is (which plane
    /// design §4).
    private func closestToHomeLine(on leg: MapLeg, at date: Date) -> String? {
        guard let story = stories[leg.id], let closest = story.closestToHome else { return nil }
        let distance = closest.fraction * story.length
        guard let time = leg.time(atDistance: distance) else { return nil }
        let isOnGround = isStillOnGround(leg, at: date)
        if isOnGround, time <= date { return nil }
        return FactsWording.closestToHome(miles: Milestone.roundedMiles(closest.meters), at: time, now: date,
                                          isEstimate: isOnGround || !leg.isSeen(atDistance: distance),
                                          calendar: calendar, locale: locale)
    }
```

Replace:

```swift
    private func skyRow(on leg: MapLeg, at date: Date) -> FactRow? {
        let next = sunEvents[leg.id]?.first { $0.time > date }
```

with:

```swift
    /// The sky from the cockpit: the next sunrise or sunset, chasing the sun, the moon. Left out while the real plane
    /// is still at its departure airport after the plan's takeoff time, as nothing says "flying" then: its times would
    /// be the schedule's, for a plane that hasn't left (which plane design §4).
    private func skyRow(on leg: MapLeg, at date: Date) -> FactRow? {
        guard !isStillOnGround(leg, at: date) else { return nil }
        let next = sunEvents[leg.id]?.first { $0.time > date }
```

Replace:

```swift
    /// "1,140 mi flown · 3,010 to go": flown along the path so far, and to go along the rest of it, which for a
    /// real plane is the great circle from where it is to the arrival airport (Stage 3 spec §8).
    private func distanceRow(on leg: MapLeg, plane: PlanePosition, at date: Date) -> FactRow {
        let totalMiles = leg.pathLength / GreatCircle.metersPerMile
        let flown = Int((plane.distance / GreatCircle.metersPerMile).rounded())
        let halfway = leg.halfwayTime.flatMap {
            $0 > date ? FactsWording.halfway(at: $0, isEstimate: !leg.isSeen(atDistance: leg.pathLength / 2),
                                             calendar: calendar, locale: locale) : nil
        }
        // The schedule's speed is told only of a flight with no live data: a real plane's row has its own.
        let speed = leg.hasLiveData ? nil : FlightProgress.airborneWindow(departure: leg.start, arrival: leg.end)
            .map { FactsWording.averageSpeed(milesPerHour: totalMiles / ($0.duration / 3600)) }
        return FactRow(.distance, symbol: "point.topleft.down.to.point.bottomright.curvepath",
                       title: FactsWording.distance(flownMiles: flown, toGoMiles: Int(totalMiles.rounded()) - flown, locale: locale),
                       details: [halfway, speed, comparisons?.phrase(forMiles: totalMiles).map(FactsWording.midLine)])
    }
```

with:

```swift
    /// "1,140 mi flown · 3,010 to go": flown along the path so far, and to go along the rest of it, which for a
    /// real plane is the great circle from where it is to the arrival airport (Stage 3 spec §8). A real plane still
    /// at its departure airport has flown nothing yet: "2,788 mi to go", and its halfway time is a guess from a
    /// takeoff that hasn't happened, "about" (which plane design §4).
    private func distanceRow(on leg: MapLeg, plane: PlanePosition, at date: Date) -> FactRow {
        let totalMiles = leg.pathLength / GreatCircle.metersPerMile
        let flown = Int((plane.distance / GreatCircle.metersPerMile).rounded())
        let isOnGround = isStillOnGround(leg, at: date)
        let halfway = leg.halfwayTime.flatMap {
            $0 > date ? FactsWording.halfway(at: $0, isEstimate: isOnGround || !leg.isSeen(atDistance: leg.pathLength / 2),
                                             calendar: calendar, locale: locale) : nil
        }
        // The schedule's speed is told only of a flight with no live data: a real plane's row has its own.
        let speed = leg.hasLiveData ? nil : FlightProgress.airborneWindow(departure: leg.start, arrival: leg.end)
            .map { FactsWording.averageSpeed(milesPerHour: totalMiles / ($0.duration / 3600)) }
        let title = isOnGround
            ? FactsWording.toGo(miles: Int(totalMiles.rounded()), locale: locale)
            : FactsWording.distance(flownMiles: flown, toGoMiles: Int(totalMiles.rounded()) - flown, locale: locale)
        return FactRow(.distance, symbol: "point.topleft.down.to.point.bottomright.curvepath", title: title,
                       details: [halfway, speed, comparisons?.phrase(forMiles: totalMiles).map(FactsWording.midLine)])
    }
```

---

### Task 4: The status sentence and the line under the timeline

No tests of its own: Task 2 tests `LiveLegs.stillOnGroundFlight` and the timeline's words, and these are the views and the model that use them. Type-checked for iOS with the rest of the app.

- [x] **Step 1: The status screen's model.**

In `Crewluv/Services/PartnerStatusReceiver.swift`:

Replace:

```swift
    private(set) var estimatedArrival: Date?
```

with:

```swift
    private(set) var estimatedArrival: Date?
    /// Whether the flight between its gates has its real plane still on the ground at its departure airport after the
    /// plan's takeoff time: the narrative says so (which plane design §4).
    private(set) var isStillOnGround = false
```

Replace:

```swift
        estimatedArrival = LiveLegs.estimatedArrival(in: legs, flights: flights, at: now)
```

with:

```swift
        estimatedArrival = LiveLegs.estimatedArrival(in: legs, flights: flights, at: now)
        isStillOnGround = LiveLegs.stillOnGroundFlight(in: legs, flights: flights, at: now) != nil
```

Replace:

```swift
        flights = [:]
        estimatedArrival = nil
    }
```

with:

```swift
        flights = [:]
        estimatedArrival = nil
        isStillOnGround = false
    }
```

In `Crewluv/Views/Welcome/ContentView.swift`:

Replace:

```swift
                                estimatedArrival: receiver.estimatedArrival,
```

with:

```swift
                                estimatedArrival: receiver.estimatedArrival,
                                isStillOnGround: receiver.isStillOnGround,
```

Replace:

```swift
                    estimatedArrival: receiver.estimatedArrival,
                    onExitDemo: { receiver.exitDemoMode() },
```

with:

```swift
                    estimatedArrival: receiver.estimatedArrival,
                    isStillOnGround: receiver.isStillOnGround,
                    onExitDemo: { receiver.exitDemoMode() },
```

- [x] **Step 2: The status sentence.**

In `Crewluv/Views/Status/PilotStatusView.swift`:

Replace:

```swift
    var estimatedArrival: Date? = nil
    var onExitDemo: (() -> Void)? = nil
```

with:

```swift
    var estimatedArrival: Date? = nil
    /// Whether the flight in the air's real plane is still on the ground at its departure airport after the plan's
    /// takeoff time, from the screen's model: the narrative says so (which plane design §4).
    var isStillOnGround = false
    var onExitDemo: (() -> Void)? = nil
```

Replace:

```swift
                    NarrativeCardView(status: status, upcomingTrip: upcomingTrip, isLandingEstimated: estimatedArrival != nil)
```

with:

```swift
                    NarrativeCardView(status: status, upcomingTrip: upcomingTrip, isLandingEstimated: estimatedArrival != nil,
                                      isStillOnGround: isStillOnGround)
```

In `Crewluv/Views/Status/NarrativeCardView.swift`:

Replace:

```swift
    var isLandingEstimated = false
```

with:

```swift
    var isLandingEstimated = false
    /// The flight in the air's real plane is still on the ground at its departure airport after the plan's takeoff
    /// time: "Alex is still on the ground in Rockford on UPS flight 2963 to Anchorage", in place of flying, delayed or
    /// not (which plane design §4).
    var isStillOnGround = false
```

Replace:

```swift
                    let arrTimeStr = formattedLocalTime(shiftedArr)
                    if let dep, let dest {
                        Text("\(name) \(pastPhrase) in \(Text(dep).bold()) and is \(verb) to \(Text(dest).bold())\(fltStr) — landing in \(countdownText(to: shiftedArr, color: countdownColor)) which is \(about)\(Text(arrTimeStr).bold()).")
```

with:

```swift
                    let arrTimeStr = formattedLocalTime(shiftedArr)
                    if isStillOnGround, let dep, let dest {
                        Text("\(name) is still on the ground in \(Text(dep).bold())\(fltStr.isEmpty ? " on the flight" : fltStr) to \(Text(dest).bold()) — landing in \(countdownText(to: shiftedArr, color: countdownColor)) which is \(about)\(Text(arrTimeStr).bold()).")
                    } else if let dep, let dest {
                        Text("\(name) \(pastPhrase) in \(Text(dep).bold()) and is \(verb) to \(Text(dest).bold())\(fltStr) — landing in \(countdownText(to: shiftedArr, color: countdownColor)) which is \(about)\(Text(arrTimeStr).bold()).")
```

Replace:

```swift
            let arrTimeStr = formattedLocalTime(arrTime)
            if let dep {
                Text("\(name) is \(verb) to \(Text(dest).bold())\(fltStr) from \(Text(dep).bold()) — landing in \(countdownText(to: arrTime)) which is \(about)\(Text(arrTimeStr).bold()).")
```

with:

```swift
            let arrTimeStr = formattedLocalTime(arrTime)
            if isStillOnGround, let dep {
                Text("\(name) is still on the ground in \(Text(dep).bold())\(fltStr.isEmpty ? " on the flight" : fltStr) to \(Text(dest).bold()) — landing in \(countdownText(to: arrTime)) which is \(about)\(Text(arrTimeStr).bold()).")
            } else if let dep {
                Text("\(name) is \(verb) to \(Text(dest).bold())\(fltStr) from \(Text(dep).bold()) — landing in \(countdownText(to: arrTime)) which is \(about)\(Text(arrTimeStr).bold()).")
```

- [x] **Step 3: The line under the timeline.**

In `Crewluv/Views/TripMap/TripTimelineControl.swift`:

Replace:

```swift
    /// What the pilot is doing at `time`.
    let activity: TripActivity?
    /// The trip time on screen.
```

with:

```swift
    /// What the pilot is doing at `time`.
    let activity: TripActivity?
    /// Where the flight's real plane is still on the ground at its departure airport, now: the line under the bar names
    /// it in place of flying (which plane design §4).
    let stillOnGroundIn: AirportMark?
    /// The trip time on screen.
```

Replace:

```swift
                                spokenValue: TripMapWording.timelineSpokenValue(time, activity: activity),
```

with:

```swift
                                spokenValue: TripMapWording.timelineSpokenValue(time, activity: activity, stillOnGroundIn: stillOnGroundIn),
```

Replace:

```swift
            Text(TripMapWording.timelineLine(time, activity: activity))
```

with:

```swift
            Text(TripMapWording.timelineLine(time, activity: activity, stillOnGroundIn: stillOnGroundIn))
```

In `Crewluv/Views/TripMap/FactsHeader.swift`:

Replace:

```swift
    /// What the pilot is doing at `time`.
    let activity: TripActivity?
```

with:

```swift
    /// What the pilot is doing at `time`.
    let activity: TripActivity?
    /// Where the flight's real plane is still on the ground at its departure airport, now.
    let stillOnGroundIn: AirportMark?
```

Replace:

```swift
            TripTimelineControl(clock: $clock, isQuickLayovers: $isQuickLayovers, timeline: timeline,
                                activity: activity, time: time, now: now)
```

with:

```swift
            TripTimelineControl(clock: $clock, isQuickLayovers: $isQuickLayovers, timeline: timeline,
                                activity: activity, stillOnGroundIn: stillOnGroundIn, time: time, now: now)
```

In `Crewluv/Views/TripMap/FactsSheet.swift`:

Replace:

```swift
                                activity: facts.tripMap.activity(at: time), clock: $clock,
```

with:

```swift
                                activity: facts.tripMap.activity(at: time), stillOnGroundIn: facts.stillOnGroundAirport(at: time),
                                clock: $clock,
```

In `Crewluv/Views/TripMap/FactsPanel.swift`:

Replace:

```swift
                            activity: facts.tripMap.activity(at: time), time: time, now: now)
```

with:

```swift
                            activity: facts.tripMap.activity(at: time), stillOnGroundIn: facts.stillOnGroundAirport(at: time),
                            time: time, now: now)
```

---

### Task 5: The key, beside the banner or under it

- [x] **Step 1: The tests.**

Create `CrewluvTests/TripMapCornerPlacementTests.swift`:

```swift
//
//  TripMapCornerPlacementTests.swift
//  CrewluvTests
//
//  Where the latest event's banner and the key to the two planes go along the map's top (which plane design §2): the
//  key beside the banner where the two fit with a gap, else just under it, at the trailing edge either way.
//

import XCTest
import CoreGraphics
@testable import Crewluv

final class TripMapCornerPlacementTests: XCTestCase {

    private let banner = CGSize(width: 180, height: 44)
    private let key = CGSize(width: 170, height: 24)

    // MARK: - On the card, the banner at the leading edge

    func test_key_besideTheBanner_whereTheyFitWithAGap() {
        // 180 + 6 + 170 = 356.
        let placement = TripMapCornerPlacement(width: 356, banner: banner, reservedWidth: 180, key: key)
        XCTAssertEqual(placement.banner, CGRect(x: 0, y: 0, width: 180, height: 44))
        XCTAssertEqual(placement.key, CGRect(x: 186, y: 0, width: 170, height: 24))
        XCTAssertEqual(placement.height, 44)
    }

    func test_key_justUnderTheBanner_atTheTrailingEdge_whereTheyDont() {
        let placement = TripMapCornerPlacement(width: 355, banner: banner, reservedWidth: 180, key: key)
        XCTAssertEqual(placement.key, CGRect(x: 185, y: 50, width: 170, height: 24))
        XCTAssertEqual(placement.height, 74)
    }

    func test_key_goesByTheWidestTheBannerCanBe_soItDoesntMoveAsTheMinutesCountUp() {
        // "Just now" makes a narrow banner, but "About 88 h 88 min ago" wouldn't leave room beside it.
        let narrow = CGSize(width: 120, height: 44)
        let placement = TripMapCornerPlacement(width: 356, banner: narrow, reservedWidth: 200, key: key)
        XCTAssertEqual(placement.banner, CGRect(x: 0, y: 0, width: 120, height: 44))
        XCTAssertEqual(placement.key?.minY, 50)
        // A title wider than the widest "when" is what the banner reserves.
        let wide = TripMapCornerPlacement(width: 356, banner: CGSize(width: 190, height: 44), reservedWidth: 150, key: key)
        XCTAssertEqual(wide.key?.minY, 50)
    }

    // MARK: - On the full-screen map, the banner centred

    func test_centredBanner_keyBesideIt_whereItsTrailingHalfLeavesRoom() {
        // The banner's trailing edge is at (560 + 180) / 2 = 370; 370 + 6 + 170 = 546 fits in 560.
        let placement = TripMapCornerPlacement(width: 560, banner: banner, reservedWidth: 180, isCentered: true, key: key)
        XCTAssertEqual(placement.banner, CGRect(x: 190, y: 0, width: 180, height: 44))
        XCTAssertEqual(placement.key, CGRect(x: 390, y: 0, width: 170, height: 24))
    }

    func test_centredBanner_keyUnderIt_onAPhone() {
        let placement = TripMapCornerPlacement(width: 361, banner: banner, reservedWidth: 180, isCentered: true, key: key)
        XCTAssertEqual(placement.banner?.midX, 180.5)
        XCTAssertEqual(placement.key, CGRect(x: 191, y: 50, width: 170, height: 24))
        XCTAssertEqual(placement.height, 74)
    }

    // MARK: - One without the other

    func test_noBanner_keyAtTheTrailingEdgeOfTheTop() {
        let placement = TripMapCornerPlacement(width: 300, banner: nil, key: key)
        XCTAssertNil(placement.banner)
        XCTAssertEqual(placement.key, CGRect(x: 130, y: 0, width: 170, height: 24))
        XCTAssertEqual(placement.height, 24)
    }

    func test_noKey_theBannerAlone() {
        let placement = TripMapCornerPlacement(width: 300, banner: banner, reservedWidth: 260, key: nil)
        XCTAssertEqual(placement.banner, CGRect(x: 0, y: 0, width: 180, height: 44))
        XCTAssertNil(placement.key)
        XCTAssertEqual(placement.height, 44)
    }

    func test_neither_isNothing() {
        XCTAssertEqual(TripMapCornerPlacement(width: 300, banner: nil, key: nil).height, 0)
    }

    // MARK: - The widest "when"

    func test_widestEventWhen_isAtLeastAsLongAsAnyWhenAFlightCanShow() {
        let widest = FactsWording.widestEventWhen
        let event = Milestone(kind: .halfway, time: FactsTestData.equinox, isEstimate: true)
        for minutes in stride(from: 0, through: 24 * 60, by: 1) {
            let when = FactsWording.eventWhen(event, at: FactsTestData.equinox.addingTimeInterval(TimeInterval(minutes * 60)))
            XCTAssertLessThanOrEqual(when.count, widest.count, when)
        }
    }
}
```

- [x] **Step 2: Where the key goes.**

Create `Crewluv/Services/TripMap/TripMapCornerPlacement.swift`:

```swift
//
//  TripMapCornerPlacement.swift
//  CrewLuve
//
//  Where the latest event's banner and the key to the two planes go along the map's top in flight (which plane design
//  §2): the banner at the leading edge on the card, or centred under the full-screen map's pill, and the key at the
//  trailing edge, beside the banner where the two fit with a gap, else just under it, still at the trailing edge.
//  Sizes only, so it's tested apart from SwiftUI.
//

import CoreGraphics

nonisolated struct TripMapCornerPlacement: Equatable {
    /// The room between the banner and the key, beside it or under it.
    static let gap: CGFloat = 6

    /// The banner's frame, in the corner's own space. Nil with no banner.
    let banner: CGRect?
    /// The key's frame. Nil with no key.
    let key: CGRect?

    /// How far down the banner and the key reach.
    var height: CGFloat {
        max(banner?.maxY ?? 0, key?.maxY ?? 0)
    }

    /// - Parameters:
    ///   - width: the corner's width: the map's, less its insets.
    ///   - banner: the banner's size, or nil with none.
    ///   - reservedWidth: the widest the banner can be while the same event shows, with the widest "when" it could
    ///     show: the key goes by it, so it doesn't move as "Just now" grows to "About 1 h 5 min ago".
    ///   - isCentered: the banner is centred, as under the full-screen map's pill. Else it's at the leading edge.
    ///   - key: the key's size, or nil with none.
    init(width: CGFloat, banner: CGSize?, reservedWidth: CGFloat = 0, isCentered: Bool = false, key: CGSize?) {
        let bannerFrame = banner.map {
            CGRect(origin: CGPoint(x: isCentered ? (width - $0.width) / 2 : 0, y: 0), size: $0)
        }
        self.banner = bannerFrame
        guard let key else {
            self.key = nil
            return
        }
        let keyLeadingEdge = width - key.width
        guard let bannerFrame else {
            self.key = CGRect(origin: CGPoint(x: keyLeadingEdge, y: 0), size: key)
            return
        }
        let reserved = max(reservedWidth, bannerFrame.width)
        let bannerTrailingEdge = isCentered ? (width + reserved) / 2 : reserved
        let fitsBeside = bannerTrailingEdge + Self.gap <= keyLeadingEdge
        self.key = CGRect(origin: CGPoint(x: keyLeadingEdge, y: fitsBeside ? 0 : bannerFrame.maxY + Self.gap), size: key)
    }
}
```

In `Crewluv/Services/TripMap/Facts/FactsWording.swift`:

Replace:

```swift
    /// The banner as VoiceOver reads it: "Latest: crossed into Canada, 12 minutes ago.", "Latest: halfway, about
```

with:

```swift
    /// The widest "when" the banner shows: a best guess more than ten hours ago. A replay's clock time, "About 10:37
    /// AM", is narrower. The key to the two planes goes by it, so it doesn't move while the same event shows (which
    /// plane design §2).
    static let widestEventWhen = "About 88 h 88 min ago"

    /// The banner as VoiceOver reads it: "Latest: crossed into Canada, 12 minutes ago.", "Latest: halfway, about
```

- [x] **Step 3: The key, and the corner it shares with the banner.** No tests: SwiftUI.

Create `Crewluv/Views/TripMap/PlaneKey.swift`:

```swift
//
//  PlaneKey.swift
//  CrewLuve
//
//  The key to the map's two planes (which plane design §2): the real plane's mark beside "Real plane", and the
//  ghost's beside "On schedule", each drawn as `PlaneMarker` draws it on the map, in the glass of the map's buttons.
//  It's the key to a picture VoiceOver doesn't see, so VoiceOver doesn't see it either: the card's sentence and the
//  pill say how the real plane is doing.
//

import SwiftUI

struct PlaneKey: View {
    var body: some View {
        // Side by side, or one over the other where the text is too large for that.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { items }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .glassEffect(.regular, in: .capsule)
            VStack(alignment: .leading, spacing: 4) { items }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .glassEffect(.regular, in: .rect(cornerRadius: 14))
        }
        .font(.caption.weight(.semibold))
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var items: some View {
        item("Real plane", isGhost: false)
        item("On schedule", isGhost: true)
    }

    private func item(_ name: String, isGhost: Bool) -> some View {
        HStack(spacing: 5) {
            Mark(isGhost: isGhost)
            Text(name)
                .lineLimit(1)
        }
    }

    /// A plane's mark, as on the map: the real plane a blue circle with a white border, the ghost a dashed outline.
    private struct Mark: View {
        let isGhost: Bool

        @ScaledMetric(relativeTo: .caption) private var diameter: CGFloat = 12

        var body: some View {
            Circle()
                .fill(isGhost ? Color.clear : Color.blue)
                .strokeBorder(isGhost ? Color.primary : Color.white,
                              style: StrokeStyle(lineWidth: 1.5, dash: isGhost ? [3, 2] : []))
                .frame(width: diameter, height: diameter)
        }
    }
}

#Preview {
    PlaneKey()
        .padding()
        .background(.teal)
}
```

Create `Crewluv/Views/TripMap/TripMapCornerLayout.swift`:

```swift
//
//  TripMapCornerLayout.swift
//  CrewLuve
//
//  Lays out `TripMapCorner`'s views where `TripMapCornerPlacement` puts them (which plane design §2): the latest
//  event's banner, a hidden copy of it with the widest "when" it could show, which the key goes by, and the key to
//  the two planes. Each view says which it is with `role(_:)`.
//

import SwiftUI

struct TripMapCornerLayout: Layout {

    enum Role {
        case banner
        /// The banner with the widest "when", hidden: measured, never seen.
        case widestBanner
        case key
    }

    /// `role(_:)` sets it.
    fileprivate struct RoleKey: LayoutValueKey {
        static let defaultValue = Role.banner
    }

    /// The banner is centred, as under the full-screen map's pill. Else it's at the leading edge.
    var isCentered = false

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? naturalWidth(of: subviews)
        return CGSize(width: width, height: placement(width: width, subviews: subviews).height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let placement = placement(width: bounds.width, subviews: subviews)
        for subview in subviews {
            let frame = subview[RoleKey.self] == .key ? placement.key : placement.banner
            guard let frame else { continue }
            // The hidden banner sits where the banner does, at its own size.
            let size = subview[RoleKey.self] == .widestBanner ? subview.sizeThatFits(widthOnly(bounds.width)) : frame.size
            subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: ProposedViewSize(size))
        }
    }

    // MARK: - Private

    private func placement(width: CGFloat, subviews: Subviews) -> TripMapCornerPlacement {
        let proposal = widthOnly(width)
        func size(of role: Role) -> CGSize? {
            subviews.first { $0[RoleKey.self] == role }?.sizeThatFits(proposal)
        }
        return TripMapCornerPlacement(width: width, banner: size(of: .banner), reservedWidth: size(of: .widestBanner)?.width ?? 0,
                                      isCentered: isCentered, key: size(of: .key))
    }

    /// The banner and the key side by side, as wide as they'd like to be, for a proposal with no width.
    private func naturalWidth(of subviews: Subviews) -> CGFloat {
        func width(of roles: Set<Role>) -> CGFloat {
            subviews.filter { roles.contains($0[RoleKey.self]) }.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        }
        return width(of: [.banner, .widestBanner]) + TripMapCornerPlacement.gap + width(of: [.key])
    }

    private func widthOnly(_ width: CGFloat) -> ProposedViewSize {
        ProposedViewSize(width: width, height: nil)
    }
}

extension View {
    /// Which of `TripMapCornerLayout`'s views this is.
    func role(_ role: TripMapCornerLayout.Role) -> some View {
        layoutValue(key: TripMapCornerLayout.RoleKey.self, value: role)
    }
}
```

Create `Crewluv/Views/TripMap/TripMapCorner.swift`:

```swift
//
//  TripMapCorner.swift
//  CrewLuve
//
//  What goes along the map's top in flight: the latest event's banner (latest event design §1) and the key to the two
//  planes (which plane design §2). The key stays at the trailing edge, beside the banner where the two fit, else just
//  under it (`TripMapCornerLayout`).
//

import SwiftUI

struct TripMapCorner: View {
    let latest: LatestEvent?
    let showsKey: Bool
    /// The banner is centred, as under the full-screen map's pill. Else it's at the leading edge, as on the card.
    var isCentered = false

    var body: some View {
        TripMapCornerLayout(isCentered: isCentered) {
            if let latest {
                LatestEventBanner(event: latest, alignment: isCentered ? .center : .leading)
                    .role(.banner)
                // The same banner with the widest "when" it could show: the key goes by it, so it doesn't move as the
                // minutes count up.
                LatestEventBanner(event: LatestEvent(title: latest.title, when: FactsWording.widestEventWhen, sentence: latest.sentence),
                                  alignment: isCentered ? .center : .leading)
                    .hidden()
                    .accessibilityHidden(true)
                    .role(.widestBanner)
            }
            if showsKey {
                PlaneKey()
                    .role(.key)
            }
        }
        // It takes no taps: on the full-screen map a tap on it goes on to the map, which pans, or closes a popup.
        .allowsHitTesting(false)
    }
}
```

- [x] **Step 4: The card and the full-screen map.**

In `Crewluv/Views/TripMap/TripMapCard.swift`:

Replace:

```swift
        TimelineView(.periodic(from: .now, by: 10)) { context in
            let cardChips = chips(from: facts, at: context.date)
            let latest = facts.latestEvent(at: context.date)
            VStack(spacing: 0) {
                mapButton(facts: facts, chips: cardChips, latest: latest, at: context.date)
                if dynamicTypeSize.isAccessibilitySize {
                    stackedChips(cardChips, latest: latest)
                }
```

with:

```swift
        TimelineView(.periodic(from: .now, by: 10)) { context in
            let cardChips = chips(from: facts, at: context.date)
            let latest = facts.latestEvent(at: context.date)
            let showsKey = TripMapDrawing.showsPlaneKey(on: tripMap, at: context.date, isReplay: false)
            VStack(spacing: 0) {
                mapButton(facts: facts, chips: cardChips, latest: latest, showsKey: showsKey, at: context.date)
                if dynamicTypeSize.isAccessibilitySize {
                    stackedChips(cardChips, latest: latest, showsKey: showsKey)
                }
```

Replace:

```swift
    private func mapButton(facts: TripFacts, chips: (top: String?, bottom: String?), latest: LatestEvent?, at date: Date) -> some View {
        Button {
            isShowingFullScreen = true
        } label: {
            TripMapView(tripMap: tripMap, date: date, style: .hybrid, camera: $camera,
                        clearance: clearance(for: chips, hasBanner: latest != nil))
                .allowsHitTesting(false)
                .frame(height: 220)
                .overlay(alignment: .topLeading) { topOverlay(chips.top, latest: latest) }
```

with:

```swift
    private func mapButton(facts: TripFacts, chips: (top: String?, bottom: String?), latest: LatestEvent?, showsKey: Bool,
                           at date: Date) -> some View {
        Button {
            isShowingFullScreen = true
        } label: {
            TripMapView(tripMap: tripMap, date: date, style: .hybrid, camera: $camera,
                        clearance: clearance(for: chips, hasCorner: latest != nil || showsKey))
                .allowsHitTesting(false)
                .frame(height: 220)
                .overlay(alignment: .topLeading) { topOverlay(chips.top, latest: latest, showsKey: showsKey) }
```

Replace:

```swift
    /// The top corner: in flight, the latest event's banner (latest event design §1), else Stage 1's top chip. Its
    /// height is measured into `topChipHeight`.
    @ViewBuilder
    private func topOverlay(_ chip: String?, latest: LatestEvent?) -> some View {
        if let latest, !dynamicTypeSize.isAccessibilitySize {
            LatestEventBanner(event: latest)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { topChipHeight = $0 }
                .padding(Self.chipInset)
        } else {
```

with:

```swift
    /// The top of the map: in flight, the latest event's banner (latest event design §1) and the key to the two planes
    /// (which plane design §2), else Stage 1's top chip. Its height is measured into `topChipHeight`.
    @ViewBuilder
    private func topOverlay(_ chip: String?, latest: LatestEvent?, showsKey: Bool) -> some View {
        if latest != nil || showsKey, !dynamicTypeSize.isAccessibilitySize {
            TripMapCorner(latest: latest, showsKey: showsKey)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { topChipHeight = $0 }
                .padding(Self.chipInset)
        } else {
```

Replace:

```swift
    /// The band between the chips on the map: from each edge to the far side of its chip, and a gap. With no chip on
    /// the map at an edge, nothing there. The latest event's banner is the top chip while it shows.
    private func clearance(for chips: (top: String?, bottom: String?), hasBanner: Bool) -> TripMapClearance {
        guard !dynamicTypeSize.isAccessibilitySize else { return .none }
        func depth(isShown: Bool, height: CGFloat) -> CGFloat {
            isShown ? Self.chipInset + height + Self.chipGap : 0
        }
        return TripMapClearance(top: depth(isShown: chips.top != nil || hasBanner, height: topChipHeight),
```

with:

```swift
    /// The band between the chips on the map: from each edge to the far side of its chip, and a gap. With no chip on
    /// the map at an edge, nothing there. The latest event's banner and the key are the top chip while they show.
    private func clearance(for chips: (top: String?, bottom: String?), hasCorner: Bool) -> TripMapClearance {
        guard !dynamicTypeSize.isAccessibilitySize else { return .none }
        func depth(isShown: Bool, height: CGFloat) -> CGFloat {
            isShown ? Self.chipInset + height + Self.chipGap : 0
        }
        return TripMapClearance(top: depth(isShown: chips.top != nil || hasCorner, height: topChipHeight),
```

Replace:

```swift
    /// At the largest text sizes the chips would cover the map, so they move below it (moving map spec §14), the
    /// latest event first.
    private func stackedChips(_ chips: (top: String?, bottom: String?), latest: LatestEvent?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let latest {
                Text("\(latest.title) · \(latest.when)")
                    .font(.headline)
            }
```

with:

```swift
    /// At the largest text sizes the chips would cover the map, so they move below it (moving map spec §14), the
    /// latest event first, then the key to the two planes.
    private func stackedChips(_ chips: (top: String?, bottom: String?), latest: LatestEvent?, showsKey: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let latest {
                Text("\(latest.title) · \(latest.when)")
                    .font(.headline)
            }
            if showsKey {
                PlaneKey()
            }
```

In `Crewluv/Views/TripMap/TripMapScreen.swift`:

Replace:

```swift
    @ViewBuilder
    private func screen(time: Date, now: Date, facts: TripFacts, timeline: TripTimeline) -> some View {
        let latest = facts.latestEvent(at: time)
        let base = ZStack(alignment: .top) {
            // The camera frames the trip in what the sheet or the panel leaves clear, and under the latest event.
            TripMapView(tripMap: tripMap, date: time, style: style, camera: $camera,
                        clearance: TripMapClearance(top: latest == nil ? 0 : mapTopClearance, leading: mapLeadingClearance,
                                                    bottom: mapBottomClearance),
                        isFullScreen: true, isReplay: !clock.isLive)
                .ignoresSafeArea()
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { screenFrame = $0 }
            topChrome(time: time, latest: latest)
```

with:

```swift
    @ViewBuilder
    private func screen(time: Date, now: Date, facts: TripFacts, timeline: TripTimeline) -> some View {
        let latest = facts.latestEvent(at: time)
        let showsKey = TripMapDrawing.showsPlaneKey(on: tripMap, at: time, isReplay: !clock.isLive)
        let base = ZStack(alignment: .top) {
            // The camera frames the trip in what the sheet or the panel leaves clear, and under the latest event and
            // the key.
            TripMapView(tripMap: tripMap, date: time, style: style, camera: $camera,
                        clearance: TripMapClearance(top: latest == nil && !showsKey ? 0 : mapTopClearance,
                                                    leading: mapLeadingClearance, bottom: mapBottomClearance),
                        isFullScreen: true, isReplay: !clock.isLive)
                .ignoresSafeArea()
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { screenFrame = $0 }
            topChrome(time: time, latest: latest, showsKey: showsKey)
```

Replace:

```swift
    /// The top bar, and in flight the latest event's banner under its pill (latest event design §1). Only the bar
    /// pads the side panel: the banner is centred, clear of it.
    private func topChrome(time: Date, latest: LatestEvent?) -> some View {
        VStack(spacing: 8) {
            topBar(time: time)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { topBarHeight = $0 }
            if let latest {
                LatestEventBanner(event: latest, alignment: .center)
                    .padding(.horizontal)
            }
        }
    }
```

with:

```swift
    /// The top bar, and in flight the latest event's banner under its pill (latest event design §1) with the key to
    /// the two planes under the buttons (which plane design §2). Only the bar pads the side panel: the banner is
    /// centred and the key at the trailing edge, clear of it.
    private func topChrome(time: Date, latest: LatestEvent?, showsKey: Bool) -> some View {
        VStack(spacing: 8) {
            topBar(time: time)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { topBarHeight = $0 }
            if latest != nil || showsKey {
                TripMapCorner(latest: latest, showsKey: showsKey, isCentered: true)
                    .padding(.horizontal)
            }
        }
    }
```

Replace:

```swift
    /// From the screen's top edge to a little below the latest event's banner.
```

with:

```swift
    /// From the screen's top edge to a little below the latest event's banner and the key.
```

- [x] **Step 5: Previews of a plane still at its gate.**

In `Crewluv/Views/TripMap/TripMapPreviews.swift`:

Replace:

```swift
    /// A store with Quick layovers set, so each full-screen preview shows its pace whatever the canvas remembered.
```

with:

```swift
    /// The Europe trip `minutesLate` minutes after its first flight's takeoff time, with its real plane still at the
    /// gate in Louisville (which plane design §4).
    static func europeAtTheGate(minutesLate: Double) -> TripMap? {
        let now = Date()
        let start = now.addingTimeInterval(-minutesLate * 60 - FlightProgress.taxiOutAllowance)
        let legs = europeLegs(from: start)
        guard let origin = coordinate("SDF") else { return nil }
        let fix = LiveFlight.Fix(latitude: origin.latitude, longitude: origin.longitude, altitudeFeet: nil, groundSpeedKnots: 0,
                                 trackDegrees: nil, isOnGround: true, registration: "N605UP", typeCode: "B748",
                                 seenAt: now.addingTimeInterval(-30))
        let live = LiveFlight(legID: "UPS207", callsign: "UPS207", state: .ground, fix: fix, landedAt: nil, trail: [])
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
#Preview("Full screen, real plane") {
```

with:

```swift
#Preview("Real plane, still at the gate") {
    if let map = TripMapPreviewData.europeAtTheGate(minutesLate: 25) {
        TripMapCard(tripMap: map, status: .demo, storyStore: LegStoryStore()).padding()
    }
}

#Preview("Full screen, real plane still at the gate") {
    if let map = TripMapPreviewData.europeAtTheGate(minutesLate: 25) {
        TripMapScreen(tripMap: map, storyStore: LegStoryStore(), dayNumber: 1, totalDays: 4)
            .defaultAppStorage(TripMapPreviewData.storage(quickLayovers: true))
    }
}

#Preview("Full screen, real plane") {
```

---

### Task 6: The popup on the full-screen map

- [x] **Step 1: The tests.**

Create `CrewluvTests/PlanePopupPlacementTests.swift`:

```swift
//
//  PlanePopupPlacementTests.swift
//  CrewluvTests
//
//  A plane's popup on the full-screen map (which plane design §3): which markers open one, and where it goes, just
//  above its plane, under it near the top, and slid in near a side.
//

import XCTest
import CoreGraphics
@testable import Crewluv

final class PlanePopupPlacementTests: XCTestCase {

    private let size = CGSize(width: 180, height: 60)
    private let map = CGRect(x: 0, y: 0, width: 400, height: 600)

    // MARK: - Which markers

    func test_planeKind_onlyTheRealPlaneAndItsGhostOpenAPopup() {
        XCTAssertEqual(TripMapMarker.realPlane(angle: 0, isEstimated: false).planeKind, .realPlane)
        XCTAssertEqual(TripMapMarker.realPlane(angle: 1, isEstimated: true).planeKind, .realPlane)
        XCTAssertEqual(TripMapMarker.ghost(angle: 0).planeKind, .ghost)
        XCTAssertNil(TripMapMarker.plane(angle: 0).planeKind)
        XCTAssertNil(TripMapMarker.car.planeKind)
        XCTAssertNil(TripMapMarker.pilot(.layover).planeKind)
        XCTAssertNil(TripMapMarker.airport(code: "SDF", palette: .onDarkMap, isDriveOnly: false).planeKind)
    }

    // MARK: - Where it goes

    func test_frame_justAboveThePlane_centredOnIt() {
        // 18 points from the plane's centre to the popup's bottom edge.
        XCTAssertEqual(PlanePopupPlacement.frame(of: size, over: CGPoint(x: 200, y: 300), inside: map),
                       CGRect(x: 110, y: 222, width: 180, height: 60))
    }

    func test_frame_underThePlane_whereThereIsNoRoomAboveIt() {
        XCTAssertEqual(PlanePopupPlacement.frame(of: size, over: CGPoint(x: 200, y: 70), inside: map),
                       CGRect(x: 110, y: 88, width: 180, height: 60))
        // The map's margins keep it clear of the top bar, the banner and the key.
        let clear = CGRect(x: 0, y: 120, width: 400, height: 480)
        XCTAssertEqual(PlanePopupPlacement.frame(of: size, over: CGPoint(x: 200, y: 190), inside: clear).minY, 208)
        XCTAssertEqual(PlanePopupPlacement.frame(of: size, over: CGPoint(x: 200, y: 198), inside: clear).minY, 120)
    }

    func test_frame_slidesInNearASide() {
        XCTAssertEqual(PlanePopupPlacement.frame(of: size, over: CGPoint(x: 20, y: 300), inside: map).minX, 0)
        XCTAssertEqual(PlanePopupPlacement.frame(of: size, over: CGPoint(x: 390, y: 300), inside: map).maxX, 400)
        // Beside a side panel, the map's leading margin.
        let besidePanel = CGRect(x: 396, y: 0, width: 456, height: 393)
        XCTAssertEqual(PlanePopupPlacement.frame(of: size, over: CGPoint(x: 420, y: 300), inside: besidePanel).minX, 396)
    }

    func test_frame_widerThanTheMap_isCentredOnIt() {
        let narrow = CGRect(x: 10, y: 0, width: 150, height: 600)
        XCTAssertEqual(PlanePopupPlacement.frame(of: size, over: CGPoint(x: 30, y: 300), inside: narrow).midX, 85)
    }
}
```

- [x] **Step 2: Which markers open a popup, and where it goes.**

In `Crewluv/Views/TripMap/TripMapMarker.swift`:

Replace:

```swift
    /// Markers the same size share a key: a marker's view is measured again only when its key changes. Every kind of
```

with:

```swift
    /// Which of a flight's two planes this is, for the popup a tap opens on the full-screen map (which plane design
    /// §3): the real plane or its ghost. Nil for every other marker, the schedule's own plane among them.
    var planeKind: PlaneKind? {
        switch self {
        case .realPlane: .realPlane
        case .ghost: .ghost
        case .airport, .car, .pilot, .plane: nil
        }
    }

    /// Markers the same size share a key: a marker's view is measured again only when its key changes. Every kind of
```

Create `Crewluv/Services/TripMap/PlanePopupPlacement.swift`:

```swift
//
//  PlanePopupPlacement.swift
//  CrewLuve
//
//  Where a plane's popup goes on the full-screen map (which plane design §3): just above the plane's mark, or under it
//  where there's no room above, and slid sideways to stay inside the part of the map that's clear. Rectangles only, so
//  it's tested apart from MapKit.
//

import CoreGraphics

nonisolated enum PlanePopupPlacement {
    /// The gap between a plane's centre and its popup: the plane's radius, and a little more.
    static let gap: CGFloat = 18

    /// The popup's frame, `size` large, for a plane at `plane`, inside `area`: the map less its margins, which keep
    /// clear of the top bar, the banner and the key, and the facts sheet or panel.
    static func frame(of size: CGSize, over plane: CGPoint, inside area: CGRect) -> CGRect {
        let above = plane.y - gap - size.height
        let y = above >= area.minY ? above : plane.y + gap
        // A popup wider than the area is centred on it. Otherwise it's centred on the plane, slid in from either side.
        let x = size.width > area.width
            ? area.midX - size.width / 2
            : min(max(plane.x - size.width / 2, area.minX), area.maxX - size.width)
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }
}
```

- [x] **Step 3: The popup.** No tests: SwiftUI and UIKit.

Create `Crewluv/Views/TripMap/PlanePopup.swift`:

```swift
//
//  PlanePopup.swift
//  CrewLuve
//
//  A plane's popup on the full-screen map (which plane design §3): its title, then a line or two, in the glass of the
//  map's buttons. It's part of the map's picture, which VoiceOver doesn't see, so VoiceOver doesn't see it either:
//  the pill and the facts say the same.
//

import SwiftUI

struct PlanePopup: View {
    /// The widest a popup is at the default text size, in points: its lines wrap beyond it. `TripMapPopupController`
    /// scales it with the text and proposes no more.
    static let widest: CGFloat = 240

    let words: PlanePopupWords

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(words.title)
                .fontWeight(.semibold)
            ForEach(Array(words.lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.footnote)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
        .accessibilityHidden(true)
    }
}

#Preview {
    PlanePopup(words: PlanePopupWords(title: "UPS2963 · best guess",
                                      lines: ["Not seen since 4:05 PM, so it's drawn where it should be by now",
                                              "About 14 min ahead · lands about 6:58 PM"]))
        .frame(width: PlanePopup.widest)
        .padding()
        .background(.teal)
}
```

Create `Crewluv/Views/TripMap/TripMapPopupController.swift`:

```swift
//
//  TripMapPopupController.swift
//  CrewLuve
//
//  Shows a plane's popup on the full-screen map (which plane design §3): over the real plane or the ghost the family
//  tapped, laid again wherever the plane is at each update and all through a pan or pinch, with the words of the
//  moment. It sits over the map in its container and takes no touches, so a tap goes on to the map, which closes the
//  popup or moves it to the other plane.
//

import MapKit
import SwiftUI
import UIKit

final class TripMapPopupController {
    private weak var container: UIView?
    private weak var mapView: MKMapView?
    /// Hosts the popup's SwiftUI view: made the first time a popup opens, and hidden while none is open.
    private var host: UIHostingController<PlanePopup>?
    /// Where the plane is that the open popup is over. Nil while none is open.
    private var coordinate: CLLocationCoordinate2D?
    /// The popup's size as last measured: a pan lays it again up to 60 times a second.
    private var measurement: Measurement?

    /// How far down from the map's top edge the full-screen map's own controls reach: the popup stays below them.
    var controlsHeight: CGFloat = 0

    private struct Measurement {
        let words: PlanePopupWords
        let width: CGFloat
        let textSize: UIContentSizeCategory
        let size: CGSize
    }

    init(container: UIView, mapView: MKMapView) {
        self.container = container
        self.mapView = mapView
    }

    func tearDown() {
        host?.view.removeFromSuperview()
        host = nil
    }

    /// Shows `words` over the plane at `coordinate`. Their view is given new words only when they change.
    func show(_ words: PlanePopupWords, at coordinate: CLLocationCoordinate2D) {
        let host = host(showing: words)
        self.coordinate = coordinate
        host.view.isHidden = false
        layOut(host)
    }

    func hide() {
        coordinate = nil
        host?.view.isHidden = true
    }

    /// Lays the open popup over its plane again, where the map now shows it: through a pan, a pinch, or a new size.
    func reposition() {
        guard let host, coordinate != nil else { return }
        layOut(host)
    }

    // MARK: - Private

    private func host(showing words: PlanePopupWords) -> UIHostingController<PlanePopup> {
        if let host {
            if host.rootView.words != words {
                host.rootView = PlanePopup(words: words)
            }
            return host
        }
        let host = UIHostingController(rootView: PlanePopup(words: words))
        // Laid in the container's own space, which has no safe area of its own to add.
        host.safeAreaRegions = []
        host.view.backgroundColor = .clear
        host.view.isUserInteractionEnabled = false
        container?.addSubview(host.view)
        self.host = host
        return host
    }

    /// Lays the popup over the plane inside the map's margins, which keep clear of the sheet or panel, and below the
    /// top bar, the banner and the key.
    private func layOut(_ host: UIHostingController<PlanePopup>) {
        guard let container, let mapView, let coordinate else { return }
        let margins = mapView.layoutMargins
        let area = mapView.frame.inset(by: UIEdgeInsets(top: max(margins.top, controlsHeight), left: margins.left,
                                                        bottom: margins.bottom, right: margins.right))
        let plane = mapView.convert(coordinate, toPointTo: container)
        host.view.frame = PlanePopupPlacement.frame(of: size(of: host, inside: area.width, for: container.traitCollection),
                                                    over: plane, inside: area)
    }

    /// The popup's size, no wider than its widest at this text size, or than `width`. Measured again only when its
    /// words, the width or the text size change.
    private func size(of host: UIHostingController<PlanePopup>, inside width: CGFloat, for traits: UITraitCollection) -> CGSize {
        let widest = UIFontMetrics(forTextStyle: .footnote).scaledValue(for: PlanePopup.widest, compatibleWith: traits)
        let proposed = min(widest, width)
        let words = host.rootView.words
        if let measurement, measurement.words == words, measurement.width == proposed,
           measurement.textSize == traits.preferredContentSizeCategory {
            return measurement.size
        }
        let size = host.sizeThatFits(in: CGSize(width: proposed, height: .greatestFiniteMagnitude))
        measurement = Measurement(words: words, width: proposed, textSize: traits.preferredContentSizeCategory, size: size)
        return size
    }
}
```

- [x] **Step 4: The planes take a tap, and the map shows their popup.**

In `Crewluv/Views/TripMap/TripMapAnnotationView.swift`:

Replace:

```swift
        canShowCallout = false
        // A marker is never selected, so a tap can't lift a car above the plane. Touches go on to the map.
        isEnabled = false
```

with:

```swift
        canShowCallout = false
```

Replace:

```swift
        let host = host(showing: marker)
        zPriority = Self.zPriority(of: marker)
```

with:

```swift
        let host = host(showing: marker)
        // Only the real plane and its ghost take a tap, which opens their popup on the full-screen map (which plane
        // design §3). Touches on every other marker go on to the map. A tapped plane keeps its place in the stack, so
        // the ghost never lifts over the real plane, nor a car over either.
        isEnabled = marker.planeKind != nil
        zPriority = Self.zPriority(of: marker)
        selectedZPriority = zPriority
```

In `Crewluv/Views/TripMap/TripMapCoordinator.swift`:

Replace:

```swift
    private var cameraController: TripMapCameraController?
    /// The markers on the map, by `TripMapMarker.placements`' names.
    private var annotations: [String: TripMapAnnotation] = [:]
    private var appliedStyle: TripMapStyle?
```

with:

```swift
    private var cameraController: TripMapCameraController?
    private var popup: TripMapPopupController?
    /// The markers on the map, by `TripMapMarker.placements`' names.
    private var annotations: [String: TripMapAnnotation] = [:]
    private var appliedStyle: TripMapStyle?
    /// The plane whose popup is open (which plane design §3).
    private var openPopup: OpenPopup?

    private struct OpenPopup {
        /// The plane's marker's name in `TripMapMarker.placements`.
        let id: String
        /// The flight it's on. It closes when the next flight's planes take its plane's name.
        let legID: String
        let plane: PlaneKind
        /// Whether the map was replaying when it opened. It closes when a replay starts or stops, since what it says
        /// changes.
        let isReplay: Bool
    }
```

Replace:

```swift
        self.cameraController = cameraController
        container.onLayoutChange = { [weak self] in self?.layoutDidChange() }
    }
```

with:

```swift
        self.cameraController = cameraController
        popup = TripMapPopupController(container: container, mapView: mapView)
        container.onLayoutChange = { [weak self] in self?.layoutDidChange() }
    }
```

Replace:

```swift
        shapes?.tearDown()
        shapes = nil
        cameraController = nil
    }
```

with:

```swift
        shapes?.tearDown()
        shapes = nil
        cameraController = nil
        popup?.tearDown()
        popup = nil
    }
```

Replace:

```swift
        syncAnnotations(with: TripMapMarker.placements(for: drawing, palette: palette), on: mapView)
        shapes?.setNight(at: parent.date)
        shapes?.setLines(drawing.segments.map(TripMapLine.init(segment:)))
        cameraController?.update(camera: parent.camera, clearance: parent.clearance, respectsSafeArea: isFullScreen)
        shapes?.draw()
    }

    /// The map's size or safe area has changed.
    private func layoutDidChange() {
        cameraController?.layoutDidChange(camera: parent.camera)
        shapes?.draw()
    }
```

with:

```swift
        syncAnnotations(with: TripMapMarker.placements(for: drawing, palette: palette), on: mapView)
        shapes?.setNight(at: parent.date)
        shapes?.setLines(drawing.segments.map(TripMapLine.init(segment:)))
        cameraController?.update(camera: parent.camera, clearance: parent.clearance, respectsSafeArea: isFullScreen)
        shapes?.draw()
        popup?.controlsHeight = parent.controlsHeight
        updatePopup(on: mapView)
    }

    /// The map's size or safe area has changed.
    private func layoutDidChange() {
        cameraController?.layoutDidChange(camera: parent.camera)
        shapes?.draw()
        popup?.reposition()
    }
```

Replace:

```swift
        mapView.addAnnotations(added)
    }
```

with:

```swift
        mapView.addAnnotations(added)
    }

    // MARK: - The planes' popups

    /// Keeps the open popup over its plane with the words of the moment, or closes it once its plane isn't drawn, or a
    /// replay has started or stopped (which plane design §3).
    private func updatePopup(on mapView: MKMapView) {
        guard let open = openPopup else { return }
        guard parent.isFullScreen, open.isReplay == parent.isReplay, let annotation = annotations[open.id],
              let leg = parent.tripMap.flightInMotion(at: parent.date), leg.id == open.legID else {
            closePopup(on: mapView)
            return
        }
        popup?.show(PlanePopupWords(leg: leg, plane: open.plane, at: parent.date, isReplay: parent.isReplay),
                    at: annotation.coordinate)
    }

    private func closePopup(on mapView: MKMapView) {
        openPopup = nil
        popup?.hide()
        for annotation in mapView.selectedAnnotations {
            mapView.deselectAnnotation(annotation, animated: false)
        }
    }
```

Replace:

```swift
    /// Called all through a pan, pinch or camera move: our drawing is laid where the map now is.
    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
        shapes?.draw()
    }
```

with:

```swift
    /// Called all through a pan, pinch or camera move: our drawing, and any popup, are laid where the map now is.
    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
        shapes?.draw()
        popup?.reposition()
    }

    /// A tap on the real plane or its ghost opens its popup, in place of any other (which plane design §3). Only
    /// they can be selected: every other marker's view is disabled.
    func mapView(_ mapView: MKMapView, didSelect annotation: any MKAnnotation) {
        guard let annotation = annotation as? TripMapAnnotation, let plane = annotation.marker.planeKind else { return }
        guard let leg = parent.tripMap.flightInMotion(at: parent.date) else {
            mapView.deselectAnnotation(annotation, animated: false)
            return
        }
        openPopup = OpenPopup(id: annotation.id, legID: leg.id, plane: plane, isReplay: parent.isReplay)
        updatePopup(on: mapView)
    }

    /// A tap anywhere else on the map closes the popup. A tap on the other plane closes this one as it opens that one.
    func mapView(_ mapView: MKMapView, didDeselect annotation: any MKAnnotation) {
        guard let annotation = annotation as? TripMapAnnotation, annotation.id == openPopup?.id else { return }
        openPopup = nil
        popup?.hide()
    }
```

- [x] **Step 5: The popup stays below the full-screen map's controls.**

In `Crewluv/Views/TripMap/TripMapView.swift`:

Replace:

```swift
    /// What the facts sheet or panel covers: the camera frames the trip clear of it, and Apple's logo sits beside it.
    var clearance: TripMapClearance = .none
```

with:

```swift
    /// What the facts sheet or panel covers: the camera frames the trip clear of it, and Apple's logo sits beside it.
    var clearance: TripMapClearance = .none
    /// How far down from the map's top edge the full-screen map's own controls reach: its top bar, and the banner and
    /// the key under it. A plane's popup stays below them (which plane design §3), whatever the camera keeps clear.
    var controlsHeight: CGFloat = 0
```

In `Crewluv/Views/TripMap/TripMapScreen.swift`:

Replace:

```swift
            // The camera frames the trip in what the sheet or the panel leaves clear, and under the latest event and
            // the key.
            TripMapView(tripMap: tripMap, date: time, style: style, camera: $camera,
                        clearance: TripMapClearance(top: latest == nil && !showsKey ? 0 : mapTopClearance,
                                                    leading: mapLeadingClearance, bottom: mapBottomClearance),
                        isFullScreen: true, isReplay: !clock.isLive)
```

with:

```swift
            // The camera frames the trip in what the sheet or the panel leaves clear, and under the latest event and
            // the key. A plane's popup stays under the top bar, whatever the camera keeps clear.
            TripMapView(tripMap: tripMap, date: time, style: style, camera: $camera,
                        clearance: TripMapClearance(top: latest == nil && !showsKey ? 0 : mapTopClearance,
                                                    leading: mapLeadingClearance, bottom: mapBottomClearance),
                        controlsHeight: mapTopClearance, isFullScreen: true, isReplay: !clock.isLive)
```

---

### Task 7: Todd's run, the commits, and a look

- [x] **Step 1: Todd runs every test of the app once:**

```bash
xcodebuild test -project Crewluv.xcodeproj -scheme Crewluv -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' 2>&1 | grep -E "error:|TEST (SUCCEEDED|FAILED)"
```

Expected: `** TEST SUCCEEDED **`, with 1,138 tests in the result bundle (1,086 before).

- [x] **Step 2: Ask to commit:** one commit for each of Tasks 2 to 6, then the design with this plan.

- [ ] **Step 3: Todd looks,** in the previews and on a real flight:
  - "Real plane, in the air", "Real plane, estimated past an unseen ocean" and "Full screen, real plane": the key, beside the banner or under it, in light and dark; a tap on each plane opens its popup, a tap elsewhere closes it, a tap on the other plane moves it; the popup under its plane near the top, and slid in near a side.
  - "Real plane, still at the gate" and "Full screen, real plane still at the gate": "Still on the ground in Louisville", "… mi to go", no sky row, no banner, nothing of the flight in the list, "On the ground in Louisville" under the timeline.
  - The largest text size: the key under the card's map, after the latest event.

## Changes made during execution

- **Tasks 2 to 6 (16 Nov 2026, evening EST):** on Todd's "Yes, build it", the plan's 40 files were put into the checkout at `9f06e71`, after checking that none had changed since the plan was written. Each came out the same as its tested copy.
- **Todd's run (16 Nov 2026, 9:41 pm EST):** every test of the app, with Tasks 2 to 6 in. All 1,138 passed on the iPhone 17 Pro simulator, iOS 26.5, read from the result bundle `Test-Crewluv-2026.11.16_21-41-00--0500.xcresult`: the 1,086 of the run before, and this plan's 52. The files were compared with the tested ones again after it.
- **The commits (16 Nov 2026),** on Todd's "Yes, commit": Task 2 `6b90829`, Task 3 `03a0fbe`, Task 4 `04b72e9`, Task 5 `8c740a1` and Task 6 `6110892`, each with its files as that task left them; then the design and this plan. Nothing pushed.


## Left for later

- **The website's camera slide for the planes,** if the card's thin band ever hides the plane under the key.
- **The Schedule page's "about"** before a landing estimate.
- **A flag on the map where an event happened.**
- **The map can move a little when the key appears and goes,** as it does for the banner, when Crewlu Cloud first sees the plane and once it lands.
- **From the review, left:** the status sentence's "still on the ground" can be up to 30 seconds late, as "about" can; the key's rule is said twice, by the drawing and by a quicker check for the views, which agree at every shared moment (a test holds them together) and differ only for two flights between their gates at once; a plane at its gate is worked out a few times a second while the full-screen map is live, never in a replay; the widest "when" is checked by its letters, not its drawn width.
