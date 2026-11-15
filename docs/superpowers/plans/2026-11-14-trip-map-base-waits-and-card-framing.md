# Waits at Base, and a Card That Keeps the Pilot in View: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A commuter's waits at base read "At base", a pilot waiting at base for a trip shows the briefcase there, and the trip map card frames the trip between its chips and slides the pilot's ground marker into view when a wide trip doesn't fit.

**Architecture:**
- **What the pilot is doing:** `TripMap` gains the base, as its legs name it, and whether the pilot waits at base for a trip ahead. `TripMap+Activity` names an unnamed wait by where it is before its length.
- **The camera:** `TripMapCamera` carries the coordinate to keep in view with each framing. `TripMapCameraController` slides it in after framing, using `TripMapSlide`, a pure function of rectangles.
- **The card:** it measures its chips and passes them as `TripMapClearance` top and bottom, which go into the map's layout margins.

**Tech Stack:** Swift 5 mode, SwiftUI, MapKit (`MKMapView`), XCTest and Swift Testing. iOS 26 SDK, deployment iOS 17.

**Design:** `docs/superpowers/specs/2026-11-14-trip-map-base-waits-and-card-framing-design.md`, approved by Todd on 2026-11-14.

---

## Ground rules for whoever runs this plan

- **Todd builds and tests.** Don't run `xcodebuild`, and don't let a subagent run it. At the end of each batch, Todd presses ⌘B or ⌘U in Xcode and pastes the result.
- **Commits:** one per batch once Todd's tests are green, with his OK, staging only that batch's files. Never push. Never commit `.superpowers/`.
- **The Duty repo** (`/Users/toddanderson/Dev/Duty`) is read-only.
- **The website** is the trip-map-web session's (local_1a5c7dff-d57c-49fe-97ef-10b521db7b14). Send it the shared cases' new rows after Batch A. Don't touch its repo.
- **Isolation:** the project builds with `SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor`. Pure types are `nonisolated`. Member import visibility is on, so each file imports the modules its members come from.
- **Synchronized folders:** a new file joins its target by being in the folder. There are no project-file edits.
- **Applying the blocks:** each `#### Edit` heading is followed by Replace/With pairs, and each Replace must match exactly once. Each `#### Create` heading is followed by the whole file.

## File map

| File | Change |
|---|---|
| `Crewluv/Services/TripMap/TripMap.swift` | `base`, `isWaitingAtBase`; `make` takes the base code and whether the pilot waits at base; `pilotLocation` before a trip ahead |
| `Crewluv/Services/TripMap/TripMap+Activity.swift` | An unnamed wait by where it is (design §2); before a trip ahead, base while waiting there (§3) |
| `Crewluv/Services/TripMap/TripMap+Status.swift` | Passes `baseAirportCode` and `displayStatus == .base` |
| `Crewluv/Services/TripMap/TripMapWording.swift` | "At base · next trip …" |
| `Crewluv/Services/TripMap/TripMapSlide.swift` | New: the slide's maths (§4.2) |
| `Crewluv/Services/TripMap/TripMapCamera.swift` | `keptInView` |
| `Crewluv/Views/TripMap/TripMapClearance.swift` | `top` |
| `Crewluv/Views/TripMap/TripMapCameraController.swift` | Slides after framing |
| `Crewluv/Views/TripMap/TripMapCoordinator.swift` | Tells the controller when the region settles |
| `Crewluv/Views/TripMap/TripMapMarkers.swift` | `Pilot.diameter` |
| `Crewluv/Views/TripMap/TripMapCard.swift` | Measures its chips; keeps the pilot in view |
| `Crewluv/Views/TripMap/TripMapScreen.swift` | Keeps the pilot in view at the timeline's moment |
| `Crewluv/Views/TripMap/TripMapPreviews.swift` | A preview of waiting at base |
| `CrewluvTests/Fixtures/TripMap/activity-cases.json` | Two new trips; `base`, `waitingAt` |
| `CrewluvTests/Helpers/TripMapFixtures.swift`, `CrewluvTests/Helpers/TripMap+HandMade.swift` | The new fields |
| `CrewluvTests/TripMapActivityTests.swift`, `TripMapStatusTests.swift`, `TripMapWordingTests.swift`, `TripMapClearanceTests.swift`, `TripMapCameraTests.swift` | New tests |
| `CrewluvTests/TripMapSlideTests.swift` | New |

## Batches

- **Batch A (Tasks 1–6):** the model, the rule, the words, the slide's maths, the clearance and the camera. Each change keeps today's callers building, through default arguments. Todd runs ⌘U.
- **Batch B (Tasks 7–9):** the controller, the card, the screen and a preview. Todd builds, looks at the previews and runs ⌘U.
- **Batch C (Tasks 10–13):** the docs, a review, Todd's tests and Todd's device check, then the close-out.

---

### Task 1: The base, waiting at base, and an unnamed wait by where it is

**Files:**
- Modify: `Crewluv/Services/TripMap/TripMap.swift`
- Modify: `Crewluv/Services/TripMap/TripMap+Activity.swift`
- Modify: `CrewluvTests/Helpers/TripMap+HandMade.swift`
- Test: `CrewluvTests/TripMapActivityTests.swift`

- [ ] **Step 1: Write the failing tests.**

#### Edit `CrewluvTests/TripMapActivityTests.swift`

Replace:

```swift
    func test_activity_everySharedCase_matches() throws {
```

With:

```swift
    // MARK: - Waits CrewLu doesn't name (base waits design §2, §3)

    /// A commuter, home at Lexington and based at Louisville, with no ground legs at all: the drive in the night before,
    /// 12 h 30 at base, Cologne and back with 2 hours there, an hour at base, and the drive home.
    private func commuter(baseAirportCode: String? = "SDF") throws -> TripMap {
        let legs = [
            TripMapTestLegs.leg("d1", .drive, from: "LEX", to: "SDF", start: hours(-14), hours: 1.5),
            TripMapTestLegs.leg("f1", from: "SDF", to: "CGN", start: hours(0), hours: 8),
            TripMapTestLegs.leg("f2", from: "CGN", to: "SDF", start: hours(10), hours: 9),
            TripMapTestLegs.leg("d2", .drive, from: "SDF", to: "LEX", start: hours(20), hours: 1.5),
        ]
        return try XCTUnwrap(TripMap.make(tripLegs: legs, isNextTrip: false, homeAirportCode: "LEX",
                                          baseAirportCode: baseAirportCode, legacyDelayMinutes: nil, at: hours(-20),
                                          coordinate: TripMapTestLegs.coordinate))
    }

    func test_waits_noGroundLegAtBase_isBase_evenFor8HoursOrMore() throws {
        let map = try commuter()
        XCTAssertEqual(map.waits.map(\.kind), [.base, .turn, .base])
        let first = try XCTUnwrap(map.waits.first)
        XCTAssertEqual(first.end.timeIntervalSince(first.start), 12.5 * 3600)
        XCTAssertEqual(map.activity(at: hours(-6))?.kind, .base)
        XCTAssertEqual(map.activity(at: hours(-6))?.place.code, "SDF")
    }

    func test_waits_noGroundLegAtBase_withNoBaseKnown_isByItsLength() throws {
        let map = try commuter(baseAirportCode: nil)
        XCTAssertEqual(map.waits.map(\.kind), [.layover, .turn, .turn])
    }

    func test_waits_noGroundLegAtHome_isHome() throws {
        let legs = [
            TripMapTestLegs.leg("f1", from: "SDF", to: "LEX", start: hours(0), hours: 1),
            TripMapTestLegs.leg("f2", from: "LEX", to: "CGN", start: hours(12), hours: 8),
        ]
        let map = try XCTUnwrap(TripMap.make(tripLegs: legs, isNextTrip: false, homeAirportCode: "LEX",
                                             baseAirportCode: "SDF", legacyDelayMinutes: nil, at: hours(-1),
                                             coordinate: TripMapTestLegs.coordinate))
        XCTAssertEqual(map.waits.map(\.kind), [.home])
    }

    func test_waits_crewLusGroundLegAtBase_stillNamesIt() throws {
        let legs = [
            TripMapTestLegs.leg("f1", from: "CGN", to: "SDF", start: hours(0), hours: 9),
            TripMapTestLegs.leg("t1", .turn, start: hours(9), hours: 1),
            TripMapTestLegs.leg("f2", from: "SDF", to: "DXB", start: hours(10), hours: 13),
        ]
        let map = try XCTUnwrap(TripMap.make(tripLegs: legs, isNextTrip: false, homeAirportCode: "LEX",
                                             baseAirportCode: "SDF", legacyDelayMinutes: nil, at: hours(-1),
                                             coordinate: TripMapTestLegs.coordinate))
        XCTAssertEqual(map.waits.map(\.kind), [.turn])
    }

    func test_activity_beforeATripAheadWhileWaitingAtBase_isAtBase() throws {
        let map = try XCTUnwrap(TripMap.make(tripLegs: TripMapTestLegs.europeTrip(), isNextTrip: true,
                                             homeAirportCode: "LEX", baseAirportCode: "SDF", isWaitingAtBase: true,
                                             legacyDelayMinutes: nil, at: hours(-3), coordinate: TripMapTestLegs.coordinate))
        let activity = try XCTUnwrap(map.activity(at: hours(-3)))
        XCTAssertEqual(activity.kind, .base)
        XCTAssertEqual(activity.place.code, "SDF")
        XCTAssertEqual(activity.words, "At base in Louisville", "base as the trip's legs name it, with its city")
    }

    func test_activity_beforeATripAheadAtHome_isStillHome() throws {
        let map = try XCTUnwrap(TripMap.make(tripLegs: TripMapTestLegs.europeTrip(), isNextTrip: true,
                                             homeAirportCode: "LEX", baseAirportCode: "SDF", legacyDelayMinutes: nil,
                                             at: hours(-3), coordinate: TripMapTestLegs.coordinate))
        XCTAssertEqual(map.activity(at: hours(-3))?.kind, .home)
        XCTAssertEqual(map.pilotLocation(at: hours(-3))?.code, "LEX")
    }

    func test_make_base_isTheLegsOwnMark_andIsWaitedAtOnlyForATripAhead() throws {
        let underWay = try XCTUnwrap(TripMap.make(tripLegs: TripMapTestLegs.europeTrip(), isNextTrip: false,
                                                  homeAirportCode: "LEX", baseAirportCode: "SDF", isWaitingAtBase: true,
                                                  legacyDelayMinutes: nil, at: hours(12), coordinate: TripMapTestLegs.coordinate))
        XCTAssertEqual(underWay.base?.name, "Louisville")
        XCTAssertFalse(underWay.isWaitingAtBase, "only a trip still ahead is waited for")
        let elsewhere = try XCTUnwrap(TripMap.make(tripLegs: TripMapTestLegs.europeTrip(), isNextTrip: true,
                                                   homeAirportCode: "LEX", baseAirportCode: "ORD", legacyDelayMinutes: nil,
                                                   at: hours(-3), coordinate: TripMapTestLegs.coordinate))
        XCTAssertNil(elsewhere.base, "no leg names it")
    }

    func test_activity_everySharedCase_matches() throws {
```

- [ ] **Step 2: Add the model.**

#### Edit `Crewluv/Services/TripMap/TripMap.swift`

Replace:

```swift
    let home: AirportMark?
    /// From the first departure to the last arrival: the full-screen map's timeline.
```

With:

```swift
    let home: AirportMark?
    /// The pilot's base, as the trip's legs name it, or nil when none does (base waits design §2, §3).
    let base: AirportMark?
    /// With this trip ahead, the pilot waits at base rather than at home, as the status says (base waits design §3).
    let isWaitingAtBase: Bool
    /// From the first departure to the last arrival: the full-screen map's timeline.
```

Replace:

```swift
    /// Where the pilot is at `date` when nothing is moving, or nil while a leg is. Before a trip still ahead
    /// starts, that's home.
    func pilotLocation(at date: Date) -> AirportMark? {
        guard legInMotion(at: date) == nil else { return nil }
        if mode == .recap, date >= span.end { return home ?? legs.last?.destination }
        if mode == .nextTrip, date < span.start { return home ?? legs.first?.origin }
```

With:

```swift
    /// Where the pilot is at `date` when nothing is moving, or nil while a leg is. Before a trip still ahead
    /// starts, that's home, or base while the pilot waits there.
    func pilotLocation(at date: Date) -> AirportMark? {
        guard legInMotion(at: date) == nil else { return nil }
        if mode == .recap, date >= span.end { return home ?? legs.last?.destination }
        if mode == .nextTrip, date < span.start { return (isWaitingAtBase ? base : home) ?? legs.first?.origin }
```

Replace:

```swift
    /// - `legacyDelayMinutes`: the summary-wide delay from a CrewLu that doesn't tag legs. As `TripStateResolver`
```

With:

```swift
    /// - `baseAirportCode`: the pilot's base, which names a wait there that CrewLu doesn't (base waits design §2).
    /// - `isWaitingAtBase`: with a trip ahead, the status says the pilot is at base, not home (base waits design §3).
    /// - `legacyDelayMinutes`: the summary-wide delay from a CrewLu that doesn't tag legs. As `TripStateResolver`
```

Replace:

```swift
        homeAirportCode: String?,
        legacyDelayMinutes: Int?,
```

With:

```swift
        homeAirportCode: String?,
        baseAirportCode: String? = nil,
        isWaitingAtBase: Bool = false,
        legacyDelayMinutes: Int?,
```

Replace:

```swift
        let firstDeparture = legs.map(\.start).min() ?? first.start
        return TripMap(mode: mode, legs: legs, groundStops: groundStops, home: home,
                       span: DateInterval(start: firstDeparture, end: max(lastArrival, firstDeparture)),
```

With:

```swift
        // Base as the legs name it, with its city and time zone: a wait or a marker there is at one of their airports.
        let base = baseAirportCode.flatMap { code in
            legs.flatMap { [$0.origin, $0.destination] }.first { $0.code == code }
        }
        let firstDeparture = legs.map(\.start).min() ?? first.start
        return TripMap(mode: mode, legs: legs, groundStops: groundStops, home: home, base: base,
                       isWaitingAtBase: mode == .nextTrip && isWaitingAtBase,
                       span: DateInterval(start: firstDeparture, end: max(lastArrival, firstDeparture)),
```

#### Edit `CrewluvTests/Helpers/TripMap+HandMade.swift`

Replace:

```swift
        self.init(mode: mode, legs: legs, groundStops: [], home: home, span: span, tripDays: tripDays)
```

With:

```swift
        self.init(mode: mode, legs: legs, groundStops: [], home: home, base: nil, isWaitingAtBase: false, span: span,
                  tripDays: tripDays)
```

- [ ] **Step 3: The rule.**

#### Edit `Crewluv/Services/TripMap/TripMap+Activity.swift`

Replace:

```swift
    /// Before the first departure, home for a next trip, else home or base by where the trip starts. From the last
    /// arrival on, home for a recap, else home or base by where it ends. In between, the wait's kind.
    private func groundKind(at date: Date, place: AirportMark) -> TripActivity.Kind {
        let isHomeAirport = place.code == home?.code
        if date < span.start { return (mode == .nextTrip || isHomeAirport) ? .home : .base }
```

With:

```swift
    /// Before the first departure, home for a next trip, or base while the pilot waits there, else home or base by
    /// where the trip starts. From the last arrival on, home for a recap, else home or base by where it ends. In
    /// between, the wait's kind.
    private func groundKind(at date: Date, place: AirportMark) -> TripActivity.Kind {
        let isHomeAirport = place.code == home?.code
        if date < span.start, mode == .nextTrip { return isWaitingAtBase && !isHomeAirport ? .base : .home }
        if date < span.start { return isHomeAirport ? .home : .base }
```

Replace:

```swift
    /// The wait from `start` to `end`, named by the ground stop that overlaps it most, the earlier on a tie; with none,
    /// by its length.
```

With:

```swift
    /// The wait from `start` to `end`, named by the ground stop that overlaps it most, the earlier on a tie; with none,
    /// by where it is, then by its length (base waits design §2).
```

Replace:

```swift
        let kind = best?.kind ?? (end.timeIntervalSince(start) >= TripWait.shortestLayover ? .layover : .turn)
        return TripWait(start: start, end: end, kind: kind)
    }
```

With:

```swift
        let kind = best?.kind ?? unnamedKind(from: start, to: end)
        return TripWait(start: start, end: end, kind: kind)
    }

    /// A wait CrewLu doesn't name: home at the home airport, base at the base airport, else a layover from 8 hours and
    /// a turn under. It's where the pilot's marker stands as it starts.
    private func unnamedKind(from start: Date, to end: Date) -> TripActivity.Kind {
        switch pilotLocation(at: start)?.code {
        case let code? where code == home?.code: .home
        case let code? where code == base?.code: .base
        default: end.timeIntervalSince(start) >= TripWait.shortestLayover ? .layover : .turn
        }
    }
```

- [ ] **Step 4:** No commit yet: Batch A commits together after Todd's ⌘U (Task 6).

---

### Task 2: The shared cases

**Files:**
- Modify: `CrewluvTests/Fixtures/TripMap/activity-cases.json`
- Modify: `CrewluvTests/Helpers/TripMapFixtures.swift`
- Modify: `CrewluvTests/TripMapActivityTests.swift`

- [ ] **Step 1: The cases.** The file's `about` gains the rules, and two trips go in before the recap trip. Every trip already there is unchanged; none has an unnamed wait at its home airport, so their answers stand.

#### Edit `CrewluvTests/Fixtures/TripMap/activity-cases.json`

Replace:

```json
and with none it's a layover from 8 h and a turn under.
```

With:

```json
and with none it's home at the home airport, base at the base airport, and elsewhere a layover from 8 h and a turn under (Crewluve base waits design §2).
```

Replace:

```json
Before the first departure: home for a nextTrip, else home or base by whether the first origin is the home airport.
```

With:

```json
Before the first departure: for a nextTrip, base when waitingAt is base and that isn't the home airport, else home; otherwise home or base by whether the first origin is the home airport.
```

Replace:

```json
mode is trip, nextTrip or recap.
```

With:

```json
mode is trip, nextTrip or recap. base is the base airport, and waitingAt, home or base, is where a nextTrip's pilot waits; both are optional, and waitingAt is home when left out.
```

Replace:

```json
    {
      "name": "A recap shows home after the trip, wherever it ended",
```

With:

```json
    {
      "name": "A commuter whose CrewLu sends no base legs",
      "note": "Home is Lexington (LEX); base is Louisville (SDF). CrewLu sends the drives, the flights and its layover in Denver, but nothing for the waits at base. Waits: SDF 23:30 to 12:00 (12 h 30, at base though 8 h or more), Denver 15:00 to 11:00 (20 h, layover l1), Chicago 13:30 to 14:30 (1 h, not home or base: a turn), SDF 15:30 to 17:00 (1 h 30, at base).",
      "home": "LEX", "base": "SDF", "mode": "trip",
      "legs": [
        { "id": "d1", "type": "drive", "from": "LEX", "to": "SDF", "start": "2026-11-12T22:00:00Z", "end": "2026-11-12T23:30:00Z" },
        { "id": "f1", "type": "flight", "from": "SDF", "to": "DEN", "start": "2026-11-13T12:00:00Z", "end": "2026-11-13T15:00:00Z" },
        { "id": "l1", "type": "layover", "airport": "DEN", "start": "2026-11-13T15:00:00Z", "end": "2026-11-14T11:00:00Z" },
        { "id": "f2", "type": "flight", "from": "DEN", "to": "ORD", "start": "2026-11-14T11:00:00Z", "end": "2026-11-14T13:30:00Z" },
        { "id": "f3", "type": "flight", "from": "ORD", "to": "SDF", "start": "2026-11-14T14:30:00Z", "end": "2026-11-14T15:30:00Z" },
        { "id": "d2", "type": "drive", "from": "SDF", "to": "LEX", "start": "2026-11-14T17:00:00Z", "end": "2026-11-14T18:30:00Z" }
      ],
      "moments": [
        { "at": "2026-11-12T21:00:00Z", "kind": "home", "words": "Home", "note": "before the drive, at LEX, the home airport: home" },
        { "at": "2026-11-12T23:00:00Z", "kind": "driving", "words": "Driving to Louisville", "note": "d1 is on the road" },
        { "at": "2026-11-13T06:00:00Z", "kind": "base", "words": "At base in Louisville", "note": "in the 12 h 30 wait at SDF, which no ground leg covers: at base, though 8 h or more" },
        { "at": "2026-11-13T22:00:00Z", "kind": "layover", "words": "Layover in Denver", "note": "in the 20-hour wait in Denver, named by CrewLu's layover" },
        { "at": "2026-11-14T14:00:00Z", "kind": "turn", "words": "Turn in Chicago", "note": "in the 1-hour wait in Chicago, which no ground leg covers, not home or base: a turn" },
        { "at": "2026-11-14T16:00:00Z", "kind": "base", "words": "At base in Louisville", "note": "in the 1 h 30 wait at SDF before the drive home: at base" },
        { "at": "2026-11-14T18:00:00Z", "kind": "driving", "words": "Driving to Lexington", "note": "d2 is on the road home" },
        { "at": "2026-11-14T19:00:00Z", "kind": "home", "words": "Home", "note": "after the last arrival, at LEX, the home airport: home" }
      ]
    },
    {
      "name": "A next trip while waiting at base shows base until it starts",
      "note": "Home is Lexington (LEX); base is Louisville (SDF), where the status says the pilot is, with this trip ahead. Before its first departure the pilot is at base, as the trip's legs name it.",
      "home": "LEX", "base": "SDF", "mode": "nextTrip", "waitingAt": "base",
      "legs": [
        { "id": "f1", "type": "flight", "from": "SDF", "to": "DEN", "start": "2026-11-13T12:00:00Z", "end": "2026-11-13T15:00:00Z" },
        { "id": "l1", "type": "layover", "airport": "DEN", "start": "2026-11-13T15:00:00Z", "end": "2026-11-14T11:00:00Z" },
        { "id": "f2", "type": "flight", "from": "DEN", "to": "SDF", "start": "2026-11-14T11:00:00Z", "end": "2026-11-14T14:00:00Z" }
      ],
      "moments": [
        { "at": "2026-11-13T08:00:00Z", "kind": "base", "words": "At base in Louisville", "note": "before the first departure, waiting at base: base" },
        { "at": "2026-11-13T22:00:00Z", "kind": "layover", "words": "Layover in Denver", "note": "replaying it: the 20-hour wait in Denver, named by CrewLu's layover" },
        { "at": "2026-11-14T15:00:00Z", "kind": "base", "words": "At base in Louisville", "note": "after the last arrival, at SDF, not the home airport: base" }
      ]
    },
    {
      "name": "A recap shows home after the trip, wherever it ended",
```

- [ ] **Step 2: Read the new fields.**

#### Edit `CrewluvTests/Helpers/TripMapFixtures.swift`

Replace:

```swift
        enum Mode: String, Decodable {
            case trip, nextTrip, recap
        }
```

With:

```swift
        enum Mode: String, Decodable {
            case trip, nextTrip, recap
        }

        /// Where a next trip's pilot waits for it.
        enum Place: String, Decodable {
            case home, base
        }
```

Replace:

```swift
            let home: String
            let mode: Mode
            let legs: [Leg]
            let moments: [Moment]
        }
```

With:

```swift
            let home: String
            /// The base airport, when the case gives one.
            let base: String?
            let mode: Mode
            /// Where a next trip's pilot waits: home when the case leaves it out.
            let waitingAt: Place?
            let legs: [Leg]
            let moments: [Moment]
        }
```

#### Edit `CrewluvTests/TripMapActivityTests.swift`

Replace:

```swift
        return TripMap.make(tripLegs: legs, isNextTrip: trip.mode == .nextTrip, isRecap: trip.mode == .recap,
                            homeAirportCode: trip.home, legacyDelayMinutes: nil, at: .distantPast,
```

With:

```swift
        return TripMap.make(tripLegs: legs, isNextTrip: trip.mode == .nextTrip, isRecap: trip.mode == .recap,
                            homeAirportCode: trip.home, baseAirportCode: trip.base,
                            isWaitingAtBase: trip.waitingAt == .base, legacyDelayMinutes: nil, at: .distantPast,
```

- [ ] **Step 3: Check the new trips by hand.** The cases were worked out against the design's rules. They're checked again in Batch A's ⌘U through `test_activity_everySharedCase_matches`. After the commit, send the trip-map-web session the file's path, so the website copies it byte for byte.

---

### Task 3: The status passes the base, and the chip says "At base"

**Files:**
- Modify: `Crewluv/Services/TripMap/TripMap+Status.swift`
- Modify: `Crewluv/Services/TripMap/TripMapWording.swift`
- Test: `CrewluvTests/TripMapStatusTests.swift`, `CrewluvTests/TripMapWordingTests.swift`

- [ ] **Step 1: Write the failing tests.**

#### Edit `CrewluvTests/TripMapStatusTests.swift`

Replace:

```swift
        #expect(map.pilotLocation(at: hours(-24))?.code == "SDF")
    }

    // MARK: - Legs
```

With:

```swift
        #expect(map.pilotLocation(at: hours(-24))?.code == "SDF")
    }

    @Test func test_initStatus_atBaseBeforeATrip_waitsAtBase() throws {
        let status = status(.base, legs: lastTrip + tripThrough(.base), homeAirportCode: "LEX")
        let map = try #require(TripMap(status: status, at: hours(-24)))

        #expect(map.mode == .nextTrip)
        #expect(map.isWaitingAtBase)
        #expect(map.pilotLocation(at: hours(-24))?.code == "SDF")
        #expect(map.activity(at: hours(-24))?.kind == .base)
    }

    @Test func test_initStatus_atHomeBeforeATrip_isntWaitingAtBase() throws {
        let status = status(.home, legs: lastTrip + tripThrough(.base), homeAirportCode: "LEX")
        let map = try #require(TripMap(status: status, at: hours(-24)))

        #expect(!map.isWaitingAtBase)
        #expect(map.activity(at: hours(-24))?.kind == .home)
    }

    // MARK: - Legs
```

#### Edit `CrewluvTests/TripMapWordingTests.swift`

Replace:

```swift
    func test_nextTripChip_namesTheDay() {
```

With:

```swift
    func test_nextTripChip_whileWaitingAtBase_saysAtBase() {
        XCTAssertEqual(TripMapWording.nextTripChip(startingAt: now.addingTimeInterval(5 * 86_400), now: now, isAtBase: true,
                                                   calendar: calendar, locale: locale),
                       "At base · next trip Wednesday")
    }

    func test_nextTripChip_namesTheDay() {
```

- [ ] **Step 2: The status.**

#### Edit `Crewluv/Services/TripMap/TripMap+Status.swift`

Replace:

```swift
                                     homeAirportCode: status.homeAirportCode ?? status.baseAirportCode,
                                     legacyDelayMinutes: status.flightDelayMinutes, at: now, coordinate: coordinate) else { return nil }
```

With:

```swift
                                     homeAirportCode: status.homeAirportCode ?? status.baseAirportCode,
                                     baseAirportCode: status.baseAirportCode,
                                     isWaitingAtBase: status.displayStatus == .base,
                                     legacyDelayMinutes: status.flightDelayMinutes, at: now, coordinate: coordinate) else { return nil }
```

- [ ] **Step 3: The words.**

#### Edit `Crewluv/Services/TripMap/TripMapWording.swift`

Replace:

```swift
        case .nextTrip:
            return (nextTripChip(startingAt: tripMap.span.start, now: date, calendar: calendar, locale: locale), nil)
```

With:

```swift
        case .nextTrip:
            return (nextTripChip(startingAt: tripMap.span.start, now: date, isAtBase: tripMap.isWaitingAtBase,
                                 calendar: calendar, locale: locale), nil)
```

Replace:

```swift
    /// "Home · next trip Wednesday".
    static func nextTripChip(startingAt start: Date, now: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        "Home · next trip \(dayPhrase(for: start, now: now, calendar: calendar, locale: locale))"
    }
```

With:

```swift
    /// "Home · next trip Wednesday", or "At base · next trip Wednesday" while the pilot waits at base (base waits
    /// design §3).
    static func nextTripChip(startingAt start: Date, now: Date, isAtBase: Bool = false, calendar: Calendar = .current,
                             locale: Locale = .current) -> String {
        let place = isAtBase ? "At base" : "Home"
        return "\(place) · next trip \(dayPhrase(for: start, now: now, calendar: calendar, locale: locale))"
    }
```

Replace:

```swift
        if tripMap.mode == .nextTrip, date < tripMap.span.start {
            return nextTripChip(startingAt: tripMap.span.start, now: date, calendar: calendar, locale: locale)
        }
```

With:

```swift
        if tripMap.mode == .nextTrip, date < tripMap.span.start {
            return nextTripChip(startingAt: tripMap.span.start, now: date, isAtBase: tripMap.isWaitingAtBase,
                                calendar: calendar, locale: locale)
        }
```

---

### Task 4: The slide's maths

**Files:**
- Create: `Crewluv/Services/TripMap/TripMapSlide.swift`
- Create: `CrewluvTests/TripMapSlideTests.swift`

- [ ] **Step 1: Write the failing tests.**

#### Create `CrewluvTests/TripMapSlideTests.swift`

```swift
//
//  TripMapSlideTests.swift
//  CrewluvTests
//
//  How far the trip map slides to keep the pilot's ground marker in view (base waits and card framing design §4.2):
//  not at all when it's clear, the least distance along each axis when it isn't, and centered when it can't fit.
//

import XCTest
import CoreGraphics
@testable import Crewluv

final class TripMapSlideTests: XCTestCase {

    /// A card's map, 360 × 220, inside its margins: 16 points each side, 44 at the top and bottom for the chips.
    private let band = CGRect(x: 16, y: 44, width: 328, height: 132)

    func test_markerFrame_standsOnThePoint_withRoomAllRound() {
        XCTAssertEqual(TripMapSlide.markerFrame(standingOn: CGPoint(x: 100, y: 100), size: CGSize(width: 24, height: 24)),
                       CGRect(x: 80, y: 68, width: 40, height: 40))
    }

    func test_offset_aMarkerInside_staysPut() {
        XCTAssertEqual(TripMapSlide.offset(moving: CGRect(x: 100, y: 80, width: 40, height: 40), inside: band), .zero)
    }

    func test_offset_offTheLeadingEdge_slidesJustInside() {
        XCTAssertEqual(TripMapSlide.offset(moving: CGRect(x: -60, y: 80, width: 40, height: 40), inside: band),
                       CGVector(dx: 76, dy: 0))
    }

    func test_offset_underTheBottomChip_slidesUpIntoTheBand() {
        XCTAssertEqual(TripMapSlide.offset(moving: CGRect(x: 100, y: 170, width: 40, height: 40), inside: band),
                       CGVector(dx: 0, dy: -34))
    }

    func test_offset_pastTheTrailingEdgeAndUnderTheTopChip_slidesAlongBothAxes() {
        XCTAssertEqual(TripMapSlide.offset(moving: CGRect(x: 330, y: 10, width: 40, height: 40), inside: band),
                       CGVector(dx: -26, dy: 34))
    }

    func test_offset_aMarkerTallerThanTheBand_isCenteredInIt() {
        let thinBand = CGRect(x: 16, y: 100, width: 328, height: 20)
        XCTAssertEqual(TripMapSlide.offset(moving: CGRect(x: 100, y: 0, width: 40, height: 40), inside: thinBand),
                       CGVector(dx: 0, dy: 90))
    }
}
```

- [ ] **Step 2: The maths.**

#### Create `Crewluv/Services/TripMap/TripMapSlide.swift`

```swift
//
//  TripMapSlide.swift
//  CrewLuve
//
//  How far the trip map slides to keep the pilot's ground marker in view once it has framed (base waits and card
//  framing design §4.2): the least distance along each axis that brings the marker, with room around it, inside the
//  space the map's margins leave. Rectangles only, so it's tested apart from MapKit.
//

import CoreGraphics

nonisolated enum TripMapSlide {
    /// The room kept around the marker, in points.
    static let room: CGFloat = 8

    /// The frame, room included, of a marker of `size` standing on `point`: its bottom edge on the point, as
    /// `TripMapAnnotationView` places the pilot's marker.
    static func markerFrame(standingOn point: CGPoint, size: CGSize) -> CGRect {
        CGRect(x: point.x - size.width / 2, y: point.y - size.height, width: size.width, height: size.height)
            .insetBy(dx: -room, dy: -room)
    }

    /// How far `frame` moves to lie inside `area`: zero when it already does, else the least distance along each axis
    /// on its own. On an axis where `frame` is larger than `area`, it's centered.
    static func offset(moving frame: CGRect, inside area: CGRect) -> CGVector {
        CGVector(dx: offset(of: frame.minX...frame.maxX, inside: area.minX...area.maxX),
                 dy: offset(of: frame.minY...frame.maxY, inside: area.minY...area.maxY))
    }

    private static func offset(of span: ClosedRange<CGFloat>, inside area: ClosedRange<CGFloat>) -> CGFloat {
        let spanLength = span.upperBound - span.lowerBound
        let areaLength = area.upperBound - area.lowerBound
        if spanLength > areaLength {
            return (area.lowerBound + area.upperBound - span.lowerBound - span.upperBound) / 2
        }
        if span.lowerBound < area.lowerBound { return area.lowerBound - span.lowerBound }
        if span.upperBound > area.upperBound { return area.upperBound - span.upperBound }
        return 0
    }
}
```

---

### Task 5: The clearance's top edge

**Files:**
- Modify: `Crewluv/Views/TripMap/TripMapClearance.swift`
- Test: `CrewluvTests/TripMapClearanceTests.swift`

- [ ] **Step 1: Write the failing tests.**

#### Edit `CrewluvTests/TripMapClearanceTests.swift`

Replace:

```swift
    func test_marginsBeyondSafeArea_noClearance_addNothing() {
        XCTAssertEqual(TripMapClearance.none.marginsBeyondSafeArea(portrait, isRightToLeft: false), .zero)
    }
```

With:

```swift
    func test_marginsBeyondSafeArea_noClearance_addNothing() {
        XCTAssertEqual(TripMapClearance.none.marginsBeyondSafeArea(portrait, isRightToLeft: false), .zero)
    }

    func test_marginsBeyondSafeArea_theCardsChips_addTheirClearanceTopAndBottom() {
        let clearance = TripMapClearance(top: 46, bottom: 46)
        XCTAssertEqual(clearance.marginsBeyondSafeArea(.zero, isRightToLeft: false),
                       NSDirectionalEdgeInsets(top: 46, leading: 0, bottom: 46, trailing: 0))
    }

    func test_marginsBeyondSafeArea_topClearance_countsTheSafeAreaOnce() {
        let clearance = TripMapClearance(top: 100)
        XCTAssertEqual(clearance.marginsBeyondSafeArea(portrait, isRightToLeft: false),
                       NSDirectionalEdgeInsets(top: 41, leading: 0, bottom: 0, trailing: 0))
    }
```

- [ ] **Step 2: The top edge.** Today's callers pass `leading:` and `bottom:`, and keep building through the defaults.

#### Edit `Crewluv/Views/TripMap/TripMapClearance.swift`

Replace:

```swift
//  What the facts sheet or side panel covers of the full-screen map (Stage 2 spec §6.1, §6.2), and how the map keeps
//  clear of it: in its layout margins.
```

With:

```swift
//  What covers the map: the facts sheet or side panel on the full screen (Stage 2 spec §6.1, §6.2), and the chips on
//  the card (base waits and card framing design §4.1). The map keeps clear of it in its layout margins.
```

Replace:

```swift
nonisolated struct TripMapClearance: Equatable {
    /// From the map's leading edge to the panel's trailing edge, padding included.
    let leading: CGFloat
    /// From the map's bottom edge to the top of the sheet.
    let bottom: CGFloat

    static let none = TripMapClearance(leading: 0, bottom: 0)
```

With:

```swift
nonisolated struct TripMapClearance: Equatable {
    /// From the map's top edge to the bottom of the card's top chip, its gap included.
    let top: CGFloat
    /// From the map's leading edge to the panel's trailing edge, padding included.
    let leading: CGFloat
    /// From the map's bottom edge to the top of the sheet, or of the card's bottom chip and its gap.
    let bottom: CGFloat

    static let none = TripMapClearance()

    init(top: CGFloat = 0, leading: CGFloat = 0, bottom: CGFloat = 0) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
    }
```

Replace:

```swift
        return NSDirectionalEdgeInsets(top: 0, leading: max(0, leading - leadingSafeArea),
                                       bottom: max(0, bottom - safeArea.bottom), trailing: 0)
```

With:

```swift
        return NSDirectionalEdgeInsets(top: max(0, top - safeArea.top), leading: max(0, leading - leadingSafeArea),
                                       bottom: max(0, bottom - safeArea.bottom), trailing: 0)
```

---

### Task 6: The camera keeps a coordinate in view; Batch A's tests and commit

**Files:**
- Modify: `Crewluv/Services/TripMap/TripMapCamera.swift`
- Test: `CrewluvTests/TripMapCameraTests.swift`

- [ ] **Step 1: Write the failing test.**

#### Edit `CrewluvTests/TripMapCameraTests.swift`

Replace:

```swift
        XCTAssertEqual(camera.framingNumber, 0)
    }
```

With:

```swift
        XCTAssertEqual(camera.framingNumber, 0)
    }

    func test_frame_keepsTheMarkerItsGiven_andANewFramingReplacesIt() {
        let cologne = CLLocationCoordinate2D(latitude: 50.87, longitude: 7.14)
        var camera = TripMapCamera(framing: rect, keeping: cologne)
        XCTAssertEqual(camera.keptInView?.latitude, 50.87)
        camera.frame(rect, animated: false)
        XCTAssertNil(camera.keptInView, "in flight, or with no marker, nothing is kept")
    }
```

- [ ] **Step 2: The camera.**

#### Edit `Crewluv/Services/TripMap/TripMapCamera.swift`

Replace:

```swift
    /// Goes up with every framing, so asking for the same rectangle again still moves the map.
    private(set) var framingNumber = 0

    init(framing rect: MKMapRect?) {
        self.rect = rect
    }

    /// Frames `rect` afresh, taking the camera back from the family.
    mutating func frame(_ rect: MKMapRect?, animated: Bool) {
        self.rect = rect
        isAnimated = animated
```

With:

```swift
    /// Goes up with every framing, so asking for the same rectangle again still moves the map.
    private(set) var framingNumber = 0
    /// Where the pilot's ground marker stands as the map frames, slid into view if the framing leaves it out (base
    /// waits and card framing design §4.2). Nil in flight, or with no marker to keep.
    private(set) var keptInView: CLLocationCoordinate2D?

    init(framing rect: MKMapRect?, keeping keptInView: CLLocationCoordinate2D? = nil) {
        self.rect = rect
        self.keptInView = keptInView
    }

    /// Frames `rect` afresh, taking the camera back from the family, and keeps `keptInView` in view.
    mutating func frame(_ rect: MKMapRect?, keeping keptInView: CLLocationCoordinate2D? = nil, animated: Bool) {
        self.rect = rect
        self.keptInView = keptInView
        isAnimated = animated
```

- [ ] **Step 3: Todd runs ⌘U on an iPhone simulator.** Expected: no failures.
  - **New:** `TripMapSlideTests` (6), and in `TripMapActivityTests` 7 more (20 in all).
  - **Grown:** `TripMapStatusTests` +2, `TripMapWordingTests` +1 (25), `TripMapClearanceTests` +2 (7) and `TripMapCameraTests` +1 (6).
  - **The shared cases:** `test_activity_everySharedCase_matches` runs the two new trips.
  - **Missing class:** an open Xcode can miss a new test file. Close the project, open it again, and press ⌘U again.
  - **A failure:** read it and stop. Never change an expected value or a shared case to make it pass.

- [ ] **Step 4: Ask to commit Batch A.** Suggested message: `feat(crewluv): a commuter's waits at base read "At base", a pilot waiting at base for a trip is shown there, and the camera's slide and the card's clearance are ready`. Stage only Tasks 1–6's files and this plan. Then send the trip-map-web session the path of `CrewluvTests/Fixtures/TripMap/activity-cases.json` and the commit, so the website copies the file.

---

### Task 7: The controller slides after framing

**Files:**
- Modify: `Crewluv/Views/TripMap/TripMapMarkers.swift`
- Modify: `Crewluv/Views/TripMap/TripMapCameraController.swift`
- Modify: `Crewluv/Views/TripMap/TripMapCoordinator.swift`

- [ ] **Step 1: The marker's size, in one place.**

#### Edit `Crewluv/Views/TripMap/TripMapMarkers.swift`

Replace:

```swift
    struct Pilot: View {
        let kind: TripActivity.Kind

        var body: some View {
            Image(systemName: kind.symbolName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
```

With:

```swift
    struct Pilot: View {
        /// The circle's width and height, which the camera keeps in view (base waits and card framing design §4.2).
        static let diameter: CGFloat = 24

        let kind: TripActivity.Kind

        var body: some View {
            Image(systemName: kind.symbolName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: Self.diameter, height: Self.diameter)
```

- [ ] **Step 2: The slide.** A framing without animation slides at once, before anything is drawn. An animated one slides with an animation once MapKit says the region has settled, unless the family has touched the map since.

#### Edit `Crewluv/Views/TripMap/TripMapCameraController.swift`

Replace:

```swift
//  The trip map's camera (moving map spec §6, Stage 2 spec §6.1, §6.2). It frames each new `TripMapCamera` request,
//  keeps the map's margins (where MapKit puts Apple's logo and Legal link) and its framing clear of the facts sheet or
//  panel, and notices when the family moves the map themselves.
```

With:

```swift
//  The trip map's camera (moving map spec §6, Stage 2 spec §6.1, §6.2, base waits and card framing design §4). It
//  frames each new `TripMapCamera` request, keeps the map's margins (where MapKit puts Apple's logo and Legal link) and
//  its framing clear of the facts sheet, the panel or the card's chips, slides the pilot's ground marker into view when
//  a framing leaves it out, and notices when the family moves the map themselves.
```

Replace:

```swift
    private var framedMargins: UIEdgeInsets = .zero
```

With:

```swift
    private var framedMargins: UIEdgeInsets = .zero
    /// The marker an animated framing keeps in view, slid in once the framing has finished.
    private var pendingKeptInView: CLLocationCoordinate2D?
```

Replace:

```swift
        guard let rect = camera.rect else { return }
        mapView.setVisibleMapRect(rect, edgePadding: .zero, animated: isAnimated)
        if !isAnimated { onFramedWithoutAnimation?() }
    }
```

With:

```swift
        guard let rect = camera.rect else { return }
        mapView.setVisibleMapRect(rect, edgePadding: .zero, animated: isAnimated)
        if isAnimated {
            pendingKeptInView = camera.keptInView
        } else {
            pendingKeptInView = nil
            slide(toKeep: camera.keptInView, animated: false)
            onFramedWithoutAnimation?()
        }
    }

    // MARK: - Keeping the pilot in view

    /// MapKit has finished moving the map: an animated framing's marker slides in now (base waits and card framing
    /// design §4.2).
    func regionDidChange() {
        guard let coordinate = pendingKeptInView else { return }
        pendingKeptInView = nil
        slide(toKeep: coordinate, animated: true)
    }

    /// Slides the map the least distance that brings the pilot's marker, with room around it, inside the map's
    /// margins: on the card between its chips, on the full-screen map clear of the sheet or panel. It never zooms.
    private func slide(toKeep coordinate: CLLocationCoordinate2D?, animated: Bool) {
        guard let mapView, let coordinate else { return }
        let size = CGSize(width: TripMapMarkers.Pilot.diameter, height: TripMapMarkers.Pilot.diameter)
        let marker = TripMapSlide.markerFrame(standingOn: mapView.convert(coordinate, toPointTo: mapView), size: size)
        let offset = TripMapSlide.offset(moving: marker, inside: mapView.bounds.inset(by: mapView.layoutMargins))
        guard offset != .zero else { return }
        // The marker moves by `offset` when the point that far the other way from the middle becomes the middle.
        let middle = CGPoint(x: mapView.bounds.midX - offset.dx, y: mapView.bounds.midY - offset.dy)
        mapView.setCenter(mapView.convert(middle, toCoordinateFrom: mapView), animated: animated)
    }
```

Replace:

```swift
        guard recognizer.state == .began || recognizer.state == .ended else { return }
        onUserMoved?()
```

With:

```swift
        guard recognizer.state == .began || recognizer.state == .ended else { return }
        // The family's move wins over a slide still to come.
        pendingKeptInView = nil
        onUserMoved?()
```

#### Edit `Crewluv/Views/TripMap/TripMapCoordinator.swift`

Replace:

```swift
    /// the call MapKit makes (CrewLu found this), so the drawing is laid again here too.
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        shapes?.draw()
    }
```

With:

```swift
    /// the call MapKit makes (CrewLu found this), so the drawing is laid again here too. It's also when an animated
    /// framing has finished, so the pilot's marker slides into view if it needs to.
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        shapes?.draw()
        cameraController?.regionDidChange()
    }
```

---

### Task 8: The card's band, and the pilot kept in view on both maps

**Files:**
- Modify: `Crewluv/Views/TripMap/TripMapCard.swift`
- Modify: `Crewluv/Views/TripMap/TripMapScreen.swift`

- [ ] **Step 1: The card.** It measures each chip's height, not its width, so the time on a chip changing never moves the camera. At the largest text sizes the chips go under the map, and the band goes with them.

#### Edit `Crewluv/Views/TripMap/TripMapCard.swift`

Replace:

```swift
    @State private var isShowingFullScreen = false
```

With:

```swift
    @State private var isShowingFullScreen = false
    /// The chips' heights as last measured, for the band the trip is framed in (base waits and card framing design
    /// §4.1).
    @State private var topChipHeight: CGFloat = 0
    @State private var bottomChipHeight: CGFloat = 0

    /// How far the chips sit from the map's edges, and the gap kept between a chip and the trip.
    private static let chipInset: CGFloat = 10
    private static let chipGap: CGFloat = 4
```

Replace:

```swift
        _camera = State(initialValue: TripMapCamera(framing: tripMap.framingRect(focusingOn: tripMap.currentLeg)))
```

With:

```swift
        _camera = State(initialValue: TripMapCamera(framing: tripMap.framingRect(focusingOn: tripMap.currentLeg),
                                                    keeping: tripMap.pilotLocation(at: .now)?.coordinate))
```

Replace:

```swift
    /// Frames the leg in the air, or the whole trip, afresh when the trip's state or legs change.
    private func refit() {
        camera.frame(tripMap.framingRect(focusingOn: tripMap.currentLeg), animated: false)
    }
```

With:

```swift
    /// Frames the leg in the air, or the whole trip, afresh when the trip's state or legs change, keeping the pilot's
    /// ground marker in view.
    private func refit() {
        camera.frame(tripMap.framingRect(focusingOn: tripMap.currentLeg),
                     keeping: tripMap.pilotLocation(at: .now)?.coordinate, animated: false)
    }
```

Replace:

```swift
            TripMapView(tripMap: tripMap, date: date, style: .hybrid, camera: $camera)
                .allowsHitTesting(false)
                .frame(height: 220)
                .overlay(alignment: .topLeading) { overlayChip(chips.top) }
                .overlay(alignment: .bottomLeading) { overlayChip(chips.bottom, systemImage: bottomChipSymbol) }
```

With:

```swift
            TripMapView(tripMap: tripMap, date: date, style: .hybrid, camera: $camera, clearance: clearance(for: chips))
                .allowsHitTesting(false)
                .frame(height: 220)
                .overlay(alignment: .topLeading) { overlayChip(chips.top, height: $topChipHeight) }
                .overlay(alignment: .bottomLeading) {
                    overlayChip(chips.bottom, systemImage: bottomChipSymbol, height: $bottomChipHeight)
                }
```

Replace:

```swift
    @ViewBuilder
    private func overlayChip(_ text: String?, systemImage: String? = nil) -> some View {
        if let text, !dynamicTypeSize.isAccessibilitySize {
            TripMapChip(text: text, systemImage: systemImage)
                .padding(10)
        }
    }
```

With:

```swift
    /// A chip on the map, its height measured into `height`.
    @ViewBuilder
    private func overlayChip(_ text: String?, systemImage: String? = nil, height: Binding<CGFloat>) -> some View {
        if let text, !dynamicTypeSize.isAccessibilitySize {
            TripMapChip(text: text, systemImage: systemImage)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height.wrappedValue = $0 }
                .padding(Self.chipInset)
        }
    }

    /// The band between the chips on the map: from each edge to the far side of its chip, and a gap. With no chip on
    /// the map at an edge, nothing there.
    private func clearance(for chips: (top: String?, bottom: String?)) -> TripMapClearance {
        guard !dynamicTypeSize.isAccessibilitySize else { return .none }
        func depth(of chip: String?, height: CGFloat) -> CGFloat {
            chip == nil ? 0 : Self.chipInset + height + Self.chipGap
        }
        return TripMapClearance(top: depth(of: chips.top, height: topChipHeight),
                                bottom: depth(of: chips.bottom, height: bottomChipHeight))
    }
```

- [ ] **Step 2: The full-screen map.** It keeps the marker where the timeline is, on opening, on recenter, and as a flight starts or ends.

#### Edit `Crewluv/Views/TripMap/TripMapScreen.swift`

Replace:

```swift
        _clock = State(initialValue: Self.clock(for: tripMap, isQuickLayovers: rememberedQuickLayovers))
        _camera = State(initialValue: TripMapCamera(framing: tripMap.framingRect(focusingOn: tripMap.currentLeg)))
```

With:

```swift
        let clock = Self.clock(for: tripMap, isQuickLayovers: rememberedQuickLayovers)
        _clock = State(initialValue: clock)
        _camera = State(initialValue: TripMapCamera(framing: tripMap.framingRect(focusingOn: tripMap.currentLeg),
                                                    keeping: tripMap.pilotLocation(at: clock.time(at: .now))?.coordinate))
```

Replace:

```swift
                .onChange(of: tripMap.legInMotion(at: time)?.id) { _, legID in
                    refit(legID: legID)
                }
```

With:

```swift
                .onChange(of: tripMap.legInMotion(at: time)?.id) { _, legID in
                    refit(legID: legID, at: time)
                }
```

Replace:

```swift
            onRecenter: { refit(legID: tripMap.legInMotion(at: time)?.id, force: true) },
```

With:

```swift
            onRecenter: { refit(legID: tripMap.legInMotion(at: time)?.id, at: time, force: true) },
```

Replace:

```swift
    /// Frames the leg in motion, or the whole trip. Leaves a camera the family moved alone, unless they asked.
    private func refit(legID: String?, force: Bool = false) {
        guard force || !camera.isPositionedByUser else { return }
        let leg = legID.flatMap { id in tripMap.legs.first { $0.id == id } }
        camera.frame(tripMap.framingRect(focusingOn: leg), animated: !reduceMotion)
    }
```

With:

```swift
    /// Frames the leg in motion, or the whole trip, keeping the pilot's ground marker at `time` in view. Leaves a
    /// camera the family moved alone, unless they asked.
    private func refit(legID: String?, at time: Date, force: Bool = false) {
        guard force || !camera.isPositionedByUser else { return }
        let leg = legID.flatMap { id in tripMap.legs.first { $0.id == id } }
        camera.frame(tripMap.framingRect(focusingOn: leg), keeping: tripMap.pilotLocation(at: time)?.coordinate,
                     animated: !reduceMotion)
    }
```

---

### Task 9: A preview of waiting at base; Batch B's build, previews and commit

**Files:**
- Modify: `Crewluv/Views/TripMap/TripMapPreviews.swift`

#### Edit `Crewluv/Views/TripMap/TripMapPreviews.swift`

Replace:

```swift
    static var pacific: TripMap? {
```

With:

```swift
    /// A commuter who lives in Lexington, waiting at base in Louisville with the Europe trip a day ahead.
    static var waitingAtBase: TripMap? {
        let now = Date()
        return TripMap.make(tripLegs: europeLegs(from: now.addingTimeInterval(24 * 3600)), isNextTrip: true,
                            homeAirportCode: "LEX", baseAirportCode: "SDF", isWaitingAtBase: true,
                            legacyDelayMinutes: nil, at: now, coordinate: { coordinate($0) })
    }

    static var pacific: TripMap? {
```

Replace:

```swift
#Preview("Recap") {
```

With:

```swift
#Preview("Next trip, waiting at base") {
    if let map = TripMapPreviewData.waitingAtBase {
        TripMapCard(tripMap: map, status: .demo, storyStore: LegStoryStore()).padding()
    }
}

#Preview("Recap") {
```

- [ ] **Step 1: Todd builds (⌘B), then looks at the card previews:**
  - **Next trip, waiting at base:** the teal briefcase at Louisville, and "At base · next trip …".
  - **At base, Next trip and Recap:** the marker is on the card now, not off its left edge, and no chip covers it.
  - **Layover:** the bed isn't under "Next: …", and Apple's logo sits above the bottom chip.
- [ ] **Step 2: Todd runs ⌘U.** Expected: no failures. Batch B adds no tests; the slide's maths is tested in Batch A.
- [ ] **Step 3: Ask to commit Batch B.** Suggested message: `feat(crewluv): the trip map card frames the trip between its chips and slides the pilot's marker into view when a wide trip doesn't fit`. Stage only Tasks 7–9's files and this plan.

---

### Task 10: The docs

**Files:**
- Modify: `docs/superpowers/specs/2026-11-13-crewluve-moving-map-design.md`
- Modify: `docs/superpowers/specs/2026-11-14-trip-map-activity-markers-and-quick-layovers-design.md`
- Modify: `CLAUDE.md`

#### Edit `docs/superpowers/specs/2026-11-13-crewluve-moving-map-design.md`

Replace:

```markdown
through a quick layover at 1x and 10x.
```

With:

```markdown
through a quick layover at 1x and 10x.

**Amended 2026-11-14, waits at base and the card's framing:** §5.1 and §10. A commuter's waits at base, which CrewLu doesn't name, read "At base"; a pilot waiting at base for a trip is shown there; and the card frames the trip between its chips, sliding the pilot's marker into view when a wide trip doesn't fit. Design: `docs/superpowers/specs/2026-11-14-trip-map-base-waits-and-card-framing-design.md`. Plan: `docs/superpowers/plans/2026-11-14-trip-map-base-waits-and-card-framing.md`.
```

Replace:

```markdown
- **Home, with a trip ahead:** the next trip's route, every leg dashed, with the home marker at home ("Home · next trip Friday").
```

With:

```markdown
- **Home, with a trip ahead:** the next trip's route, every leg dashed, with the home marker at home ("Home · next trip Friday").
- **At base, with a trip ahead** (amended 2026-11-14, base waits and card framing design §3): the same, with the base marker at base ("At base · next trip Friday").
- **The card's framing** (amended 2026-11-14, design §4): the trip is framed in the band between the card's two chips. When a wide trip still doesn't fit, the map slides the least distance that shows the pilot's ground marker.
```

Replace:

```markdown
  - **Camera:** `TripMapCamera`. The map frames each new request once, with `MapFit`'s rectangle. A pan, pinch or double tap makes the camera the family's until they recenter.
```

With:

```markdown
  - **Camera:** `TripMapCamera`. The map frames each new request once, with `MapFit`'s rectangle. A pan, pinch or double tap makes the camera the family's until they recenter. After each framing, the pilot's ground marker slides into view if the framing left it outside the map's margins, which hold the card's chips as well as the sheet and panel (amended 2026-11-14, base waits and card framing design §4; `TripMapSlide`).
```

#### Edit `docs/superpowers/specs/2026-11-14-trip-map-activity-markers-and-quick-layovers-design.md`

Replace:

```markdown
  - With no ground leg overlapping, the wait's length decides: 8 hours or more is a layover, less is a turn.
```

With:

```markdown
  - With no ground leg overlapping, the wait is home at the home airport and base at the base airport (amended 2026-11-14, base waits and card framing design §2). Elsewhere its length decides: 8 hours or more is a layover, less is a turn.
```

Replace:

```markdown
  - **A next trip** (the pilot at home with this trip ahead) shows home.
```

With:

```markdown
  - **A next trip** (the pilot at home with this trip ahead) shows home, or base while the status says the pilot waits there (amended 2026-11-14, base waits and card framing design §3).
```

#### Edit `CLAUDE.md`

Replace:

```markdown
with none, 8 hours or more is a layover.
```

With:

```markdown
with none, it's home at the home airport, base at the base airport, and elsewhere 8 hours or more is a layover. A pilot waiting at base for a trip shows at base (base waits and card framing design `docs/superpowers/specs/2026-11-14-trip-map-base-waits-and-card-framing-design.md`).
```

Replace:

```markdown
`TripMapClearance` keeps the map's framing and Apple's logo clear of the facts sheet or panel, through the map's layout margins alone:
```

With:

```markdown
`TripMapClearance` keeps the map's framing and Apple's logo clear of the facts sheet or panel, and of the card's chips, through the map's layout margins alone:
```

Replace:

```markdown
MapKit won't zoom out past its own limit, so a trip much wider than the map can be cut off
```

With:

```markdown
MapKit won't zoom out past its own limit, so a trip much wider than the map can be cut off: after each framing the camera slides the pilot's ground marker into view if it's outside the margins (`TripMapSlide`)
```

Replace:

```markdown
`TripMapCamera`, `TripMapClearance`, `TripMapMarker`'s placements,
```

With:

```markdown
`TripMapCamera`, `TripMapClearance`, `TripMapSlide` (how far the camera slides to keep the pilot in view), `TripMapMarker`'s placements,
```

- [ ] **Step 1: Ask to commit.** Suggested message: `docs(crewluv): the moving map spec, the activity markers design and CLAUDE.md for waits at base and the card's framing`.

---

### Task 11: Code review

- [ ] **Step 1:** Dispatch `superpowers:code-reviewer` with `model: "sonnet"`. Give it the design, this plan, and every file Tasks 1–9 changed. Ask it to check:
  - **The rule:** CrewLu's ground legs still win. Home comes before base. With no base known, nothing changes. A trip ahead waits at base only when the status says so.
  - **The slide:** it follows a framing only. A non-animated framing slides before `onFramedWithoutAnimation`. A family's touch drops a pending slide. It never zooms. It isn't used in flight.
  - **The card:** only heights are measured, the band goes at accessibility sizes, and the clearance can't drive a framing loop. A changed margin refits once, since the heights settle.
  - **Isolation and imports:** `TripMapSlide` is `nonisolated`, and each file imports what its members need.
- [ ] **Step 2:** Check each finding against the code before acting. Keep a list for Todd of what was fixed and what was left, and why.

### Task 12: Todd runs the tests

- [ ] Todd runs ⌘U on an iPhone simulator. Expected: no failures, with the counts in Task 6 Step 3.

### Task 13: Todd's device check, then close out

- [ ] **Step 1: On the iPad, then the iPhone.** Run from Xcode, press ⌘., and open Crewluve from its icon.
  1. **The Louisville–Cologne–Dubai trip on the card** (the previews or the demo): at base, before the next trip and in the recap, the marker always shows, and no chip covers it or an airport.
  2. **Apple's logo** on the card sits above the bottom chip.
  3. **Waiting at base before a trip:** the briefcase at base, and "At base · next trip …".
  4. **The full-screen map:** recenter on a wide trip slides the marker into view after its zoom. Pan the map: nothing slides afterwards.
  5. **A replay:** the map moves only as a flight starts or ends, as before, and the marker shows after each landing.
- [ ] **Step 2: Close out.** Tell Todd what's ready, what the review found, and what the device check showed. Mark the moving map spec's 2026-11-14 waits-at-base paragraph with the check's day, tick this plan, and commit both on Todd's yes. Never push.
- [ ] **Step 3: The revision note.** Add to the Apple Note "Crewluve revisions", under 1.4 (49), after the Quick layovers bullet: "• When your pilot commutes, the map shows them at base before and after the trip, and the card keeps their marker in view on long trips, clear of the labels."

---

## Self-critique

- **Scope:** three small changes, each in the design and each tested. Nothing else changes: the recap, in flight, and the facts.
- **Risk, the slide:** it reads MapKit's state right after a non-animated `setVisibleMapRect`. MapKit applies that at once, so `convert` sees the framed map. The slide then moves the map before anything draws. If MapKit ever did lag, the slide would just do nothing: it only slides when the marker is outside.
- **Risk, an interrupted animation:** if a framing animation is cut short by another, MapKit may report the region settled early, and the pending slide would run against that region. Recenter is the only animated framing outside a replay's leg changes, so this is rare, and harmless: one more slide.
- **Risk, a loop:** the card's clearance changes its margins, which refits, which doesn't change the chips' heights. So it settles after one refit.
- **Not covered by tests:** the controller and the card are UIKit and SwiftUI glue. The maths they use is tested, and Todd's device check covers the rest.

## Changes made during execution

The code, not the blocks above, is the reference for these.

### Batch A (Tasks 1–6)

- **Applied:** the blocks were copied from this plan by script, and every replacement matched once.
- **The shared cases:** an independent model of the rules got all 48 moments in the 12 trips, the old and the new. Todd's ⌘U passed, with every count Task 6 expects.
- **A design fix:** §4.2's "When" now says the full-screen map already frames as a flight starts or ends, in a replay too, and that the slide follows those framings.
- **The website:** the trip-map-web session copied `activity-cases.json` and passes all 48 moments, committed there as `004846f`.
