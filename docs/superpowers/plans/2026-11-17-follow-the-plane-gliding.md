# Follow the Plane, Gliding (Crewluve App) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Follow the plane holds the plane, a short tail and the way ahead to the destination, and glides there continuously, with no zoom, stop, zoom, as Todd asked after trying the first build.

**Architecture:**
- **The frame** (`Crewluv/Services/TripMap/TripMapFollow.swift`): the plane, a tail of 10% of the flight (was 20%), and the path ahead to the destination, at least 300 miles across. The first build's step rule (`mayMove`, `shouldMove`, `places`) and `TripMapCamera.follow` go.
- **The glide** (`Crewluv/Services/TripMap/TripMapGlide.swift`): each display frame closes 1 − e^(−t ÷ 0.35 s) of the gap to the frame, its middle and the log of its size alike, across the date line the short way, arriving exactly.
- **The map moves itself:** the screen and the card hand `TripMapView` the frame for each tick as a plain value (`followFrame`). `TripMapCameraController` glides toward it on a `CADisplayLink` that runs only until it gets there, so SwiftUI redraws nothing for it. A pan or pinch stops it; recenter starts it again from where the map is; the first framing goes straight there; Reduce Motion goes straight there every time.

**Tech Stack:** Swift 5 language mode, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, iOS 26, SwiftUI, MapKit, UIKit (`CADisplayLink`), XCTest.

**Sources:**
- **The design, revised:** `docs/superpowers/specs/2026-11-17-follow-the-plane-design.md` (Todd, 17 Nov 2026: "It doesn't zoom in close enough and it zooms and stops and zooms and stops on playback", "It still has way more behind the plane than in front. The destination needs to stay in view", then "10% of the flight" and "Yes, write it up"). Task 4 commits its revision.
- **Why the first build fell short:** its rule moved only when the frame shrank by 15%, so as the frame slid forward at about the same size the camera kept its old middle and the plane drifted to the far edge; and its steps came 5 seconds apart.

**How this plan was checked.**
- **A scratch Swift package** with the app target's settings, made from the repo at `46b9fa9`: 646 XCTest and 71 Swift Testing tests before, 645 and 71 with this plan, all passing, no warnings.
- **13 deliberate breaks** were made in the frame and the glide, one at a time, and every one fails at least one test: a 20% tail, or none; no 300-mile floor; not to the destination; following before takeoff; a faster glide; a linear zoom; the long way round the world; never there, or there too soon; a frame starting before the map; moving with no time gone by; and always there. (652 tests pass after Task 2; the first build's step tests go in Task 3, so 645 after it.)
- **The whole app was type-checked for iOS** with `swiftc` outside Xcode after each of Tasks 2 and 3, and compiled for the iOS simulator with the whole plan in: no errors and no warnings. The camera controller, the coordinator and the views are checked that way only.
- **The plan was followed by a script** on the repo at `46b9fa9`: all 12 files came out the same as the tested ones.
- **Reviewed** by `superpowers:code-reviewer` (sonnet) before the plan was put together. Its critical point, taken: a glide's frame isn't one MapKit need report, so each now redraws the route, the night and any popup itself (`onFramedWithoutAnimation`, which redraws the popup now too). Its important points, taken: the maps refit when following starts or stops within a leg, as a replay dragged back before takeoff does; the first framing waits for the map to have a size; a frame already shown isn't shown again; a frame that isn't all real numbers never reaches MapKit; and the glide runs at no more than 60 frames a second. Left, with its reasons: the plane can sit a little behind its frame in a fast replay (the glide's lag, about a third of a second of flying), and VoiceOver's own map gestures don't stop the glide, as only the four the family uses do.
- **Not checked:** nothing ran on a simulator or a device: how the glide feels is for Todd's look.

**Where this plan settles details.**
- **About a second to catch up:** the gap shrinks to 37% every 0.35 s, so to 5% in about a second. A replay at speed is tracked a little behind; live, the frame moves so little each second that the map goes straight there with no glide (`TripMapGlide.isThere`, a thousandth of the frame).
- **The display link runs only while gliding,** and stops once there, when following stops, when the family moves the map, and when the map goes.
- **A glide starts from what the map shows** inside its margins (`shownRect`), so a recenter or a new leg glides from where the map is, not from a frame it was once asked for.
- **While it follows, a refit is the glide's to make:** the screen still asks for one on a new leg, the setting changing or recenter, and the controller notes it, so when following stops, a later refit frames as before.
- **The card** glides too, toward a frame that moves every 10 seconds.

---

## Ground rules

1. **Don't run `xcodebuild` build or test loops.** Todd runs the tests (Task 5).
2. **Never commit without Todd's go-ahead,** and then only this plan's files, by path. **Never push** without a fresh yes.
3. **Copy the code as written.** A replacement is exact: if its text isn't in the file once, stop.
4. **Work on `feature/trip-map-live`.** Never stash, reset or switch branches.

## File map

| File | Task | What changes |
|---|---|---|
| `Crewluv/Services/TripMap/TripMapGlide.swift` (new), `CrewluvTests/TripMapGlideTests.swift` (new) | 2 | the glide |
| `Crewluv/Services/TripMap/TripMapFollow.swift`, `TripMapCamera.swift`, `CrewluvTests/TripMapFollowTests.swift`, `Crewluv/Views/TripMap/TripMapView.swift`, `TripMapCoordinator.swift`, `TripMapCameraController.swift`, `TripMapScreen.swift`, `TripMapCard.swift` | 3 | the frame, the map's glide, and the two maps |
| `CLAUDE.md`, `docs/superpowers/specs/2026-11-17-follow-the-plane-design.md` | 4 | the docs |

---

### Task 1: Before starting

- [ ] **Step 1:** The branch is `feature/trip-map-live`, at `46b9fa9` or later, and none of this plan's files has changed since, but the design, whose revision is this plan's.

```bash
git -C /Users/toddanderson/Dev/Crewluv status --short && git -C /Users/toddanderson/Dev/Crewluv branch --show-current && git -C /Users/toddanderson/Dev/Crewluv log --oneline -1
```

---

### Task 2: The glide (design §4)

- [ ] **Step 1: The tests.**

Create `CrewluvTests/TripMapGlideTests.swift`:

```swift
//
//  TripMapGlideTests.swift
//  CrewluvTests
//
//  The glide toward the frame that follows the plane (follow the plane design §4).
//

import XCTest
import MapKit
@testable import Crewluv

final class TripMapGlideTests: XCTestCase {

    private let current = MKMapRect(x: 100_000_000, y: 100_000_000, width: 8_000_000, height: 8_000_000)
    private let frame: TimeInterval = 1.0 / 60

    private func numbers(_ rect: MKMapRect) -> [Double] {
        [rect.origin.x, rect.origin.y, rect.size.width, rect.size.height]
    }

    func test_step_closesPartOfTheGap_inItsMiddleAndItsZoomAlike() {
        let target = MKMapRect(x: 104_000_000, y: 102_000_000, width: 2_000_000, height: 2_000_000)
        let next = TripMapGlide.step(from: current, toward: target, over: TripMapGlide.timeConstant)
        let share = 1 - exp(-1.0)
        XCTAssertEqual(next.midX, current.midX + (target.midX - current.midX) * share, accuracy: 1)
        XCTAssertEqual(next.midY, current.midY + (target.midY - current.midY) * share, accuracy: 1)
        // The zoom eases by the same share of its log: from 8 to 2 million is a quarter, so 4^0.632 smaller.
        XCTAssertEqual(next.size.width, 8_000_000 / pow(4, share), accuracy: 1)
        XCTAssertEqual(next.size.height, next.size.width, accuracy: 1)
    }

    func test_step_catchesUp_inAboutASecond_frameByFrame() {
        let target = MKMapRect(x: 104_000_000, y: 102_000_000, width: 2_000_000, height: 2_000_000)
        var rect = current
        for _ in 0..<60 { rect = TripMapGlide.step(from: rect, toward: target, over: frame) }
        XCTAssertLessThan(abs(rect.midX - target.midX), 0.06 * abs(current.midX - target.midX), "within 6% after a second")
        for _ in 0..<240 { rect = TripMapGlide.step(from: rect, toward: target, over: frame) }
        XCTAssertEqual(numbers(rect), numbers(target), "there, exactly, and no further")
    }

    func test_step_isNeverInAHurry() {
        // A fifth of a second on, more than half the gap is still to go.
        let target = MKMapRect(x: 104_000_000, y: 100_000_000, width: 8_000_000, height: 8_000_000)
        let next = TripMapGlide.step(from: current, toward: target, over: 0.2)
        XCTAssertGreaterThan(target.midX - next.midX, 0.5 * (target.midX - current.midX))
    }

    func test_step_neverOvershoots() {
        let target = MKMapRect(x: 104_000_000, y: 102_000_000, width: 2_000_000, height: 2_000_000)
        let next = TripMapGlide.step(from: current, toward: target, over: 60)
        XCTAssertEqual(numbers(next), numbers(target))
        XCTAssertEqual(numbers(TripMapGlide.step(from: current, toward: target, over: 0)), numbers(current), "no time, no move")
    }

    func test_step_goesTheShortWayAcrossTheDateLine() {
        let world = MKMapSize.world.width
        let west = MKMapRect(x: world - 6_000_000, y: 100_000_000, width: 4_000_000, height: 4_000_000)
        let east = MKMapRect(x: 2_000_000, y: 100_000_000, width: 4_000_000, height: 4_000_000)
        let next = TripMapGlide.step(from: west, toward: east, over: TripMapGlide.timeConstant)
        // Its middle moves east across the line, 6.32 million of the 8 million, not back across the world.
        let moved = (next.midX - west.midX + world).truncatingRemainder(dividingBy: world)
        XCTAssertEqual(moved, 8_000_000 * (1 - exp(-1.0)), accuracy: 1)
        XCTAssertGreaterThanOrEqual(next.minX, 0)
        XCTAssertLessThan(next.minX, world)
        // And back west across it, still starting on the map.
        let back = TripMapGlide.step(from: east, toward: west, over: TripMapGlide.timeConstant)
        XCTAssertGreaterThanOrEqual(back.minX, 0)
        XCTAssertLessThan(back.minX, world)
    }

    func test_isThere_onlyWhenTheGapIsTiny() {
        let nudged = MKMapRect(x: current.origin.x + 4_000, y: current.origin.y, width: current.size.width, height: current.size.height)
        XCTAssertTrue(TripMapGlide.isThere(current, at: nudged), "4,000 of 8 million: a twentieth of a percent")
        let moved = MKMapRect(x: current.origin.x + 80_000, y: current.origin.y, width: current.size.width, height: current.size.height)
        XCTAssertFalse(TripMapGlide.isThere(current, at: moved))
    }
}
```

- [ ] **Step 2: The glide.**

Create `Crewluv/Services/TripMap/TripMapGlide.swift`:

```swift
//
//  TripMapGlide.swift
//  CrewLuve
//
//  The glide toward the frame that follows the plane (follow the plane design §4): on every display frame the map
//  closes part of the gap to the frame it wants, its middle and its zoom together, so it tracks the plane smoothly with
//  no steps, and catches up in about a second.
//

import MapKit

nonisolated enum TripMapGlide {

    /// How quickly the gap closes: it shrinks by e (to 37%) every this long, so it's down to 5% in about a second.
    static let timeConstant: TimeInterval = 0.35

    /// Closer than this share of the frame's size, in its middle and its zoom, the glide has arrived.
    static let arrival = 0.001

    /// The frame `elapsed` seconds on from `current`, gliding toward `target`. Its middle and its zoom (the log of its
    /// size) each close the same share of their gaps, 1 − e^(−elapsed ÷ `timeConstant`), so zooming in and out ease
    /// alike, and a frame across the date line glides the short way round. It's `target` once within `arrival`.
    static func step(from current: MKMapRect, toward target: MKMapRect, over elapsed: TimeInterval) -> MKMapRect {
        guard current.size.width > 0, current.size.height > 0, target.size.width > 0, target.size.height > 0 else { return target }
        let share = elapsed > 0 ? 1 - exp(-elapsed / timeConstant) : 0
        let world = MKMapSize.world.width
        var dx = target.midX - current.midX
        if dx > world / 2 { dx -= world } else if dx < -world / 2 { dx += world }
        let dy = target.midY - current.midY
        let widthRatio = target.size.width / current.size.width
        let heightRatio = target.size.height / current.size.height
        let left = 1 - share
        let isThere = abs(dx * left) < arrival * target.size.width && abs(dy * left) < arrival * target.size.height
            && abs(log(widthRatio) * left) < arrival && abs(log(heightRatio) * left) < arrival
        guard !isThere else { return target }
        let width = current.size.width * pow(widthRatio, share)
        let height = current.size.height * pow(heightRatio, share)
        var midX = current.midX + dx * share
        // A frame is kept starting on the map, running on past its right edge if it must, as `MapFit` keeps it.
        if midX - width / 2 < 0 { midX += world } else if midX - width / 2 >= world { midX -= world }
        return MKMapRect(x: midX - width / 2, y: current.midY + dy * share - height / 2, width: width, height: height)
    }

    /// Whether `current` is close enough to `target` to show `target` at once, with no glide.
    static func isThere(_ current: MKMapRect, at target: MKMapRect) -> Bool {
        MKMapRectEqualToRect(step(from: current, toward: target, over: 0), target)
    }
}
```

---

### Task 3: The frame, the map's glide, and the two maps handing it the frame (design §3, §4)

The frame and the camera change with the views that call them, so every commit builds.

- [ ] **Step 1: The frame's tests.**

Replace the whole of `CrewluvTests/TripMapFollowTests.swift` with:

```swift
//
//  TripMapFollowTests.swift
//  CrewluvTests
//
//  The frame that follows the plane (follow the plane design §3). The flight is `FactsTestData`'s equator flight from E0 to
//  E20, 1,382 mi: its gates at 10:00 and 13:22 UTC, its plan in the air from 10:15 to 13:15, flown by the schedule.
//

import XCTest
import MapKit
@testable import Crewluv

final class TripMapFollowTests: XCTestCase {

    private func at(_ time: String) -> Date { FactsTestData.date("2026-03-20T\(time):00Z") }

    private let flight = FactsTestData.equatorFlight(from: 0, to: 20)

    private func point(longitude: Double) -> MKMapPoint {
        MKMapPoint(CLLocationCoordinate2D(latitude: 0, longitude: longitude))
    }

    /// A rectangle as numbers XCTest can compare: MapKit's isn't `Equatable`.
    private func numbers(_ rect: MKMapRect?) -> [Double]? {
        rect.map { [$0.origin.x, $0.origin.y, $0.size.width, $0.size.height] }
    }

    private func holds(_ rect: MKMapRect, longitude: Double) -> Bool {
        rect.contains(point(longitude: longitude))
    }

    // MARK: - The frame

    func test_rect_midFlight_holdsThePlaneItsTailAndTheWayAhead_butNotTheStart() throws {
        let rect = try XCTUnwrap(TripMapFollow.rect(for: flight, at: at("11:45"), isReplay: false))
        let plane = flight.plane(at: at("11:45"), isReplay: false)
        XCTAssertTrue(rect.contains(MKMapPoint(plane.coordinate)))
        XCTAssertTrue(holds(rect, longitude: 20), "the destination")
        // The tail is 10% of the flight behind the plane, 2° of its 20, and the margin adds a fifth of the width.
        XCTAssertTrue(holds(rect, longitude: plane.coordinate.longitude - 3), "the tail and its margin")
        XCTAssertFalse(holds(rect, longitude: plane.coordinate.longitude - 5))
        XCTAssertFalse(holds(rect, longitude: 0), "E0 is left behind")
        let whole = try XCTUnwrap(TripMap(mode: .inFlight(legID: flight.id), legs: [flight], home: nil,
                                          span: DateInterval(start: flight.start, end: flight.end), tripDays: nil)
            .framingRect(focusingOn: flight))
        XCTAssertLessThan(rect.size.width, whole.size.width * 0.85)
    }

    func test_rect_holdsMoreAheadThanBehind_untilTheLastTenthOfTheFlight() throws {
        let rect = try XCTUnwrap(TripMapFollow.rect(for: flight, at: at("11:45"), isReplay: false))
        let plane = MKMapPoint(flight.plane(at: at("11:45"), isReplay: false).coordinate)
        XCTAssertGreaterThan(rect.maxX - plane.x, 2 * (plane.x - rect.minX))
    }

    func test_rect_growsSmallerAsTheFlightGoesOn() throws {
        let early = try XCTUnwrap(TripMapFollow.rect(for: flight, at: at("10:45"), isReplay: false))
        let middle = try XCTUnwrap(TripMapFollow.rect(for: flight, at: at("11:45"), isReplay: false))
        let late = try XCTUnwrap(TripMapFollow.rect(for: flight, at: at("12:45"), isReplay: false))
        XCTAssertGreaterThan(early.size.width, middle.size.width)
        XCTAssertGreaterThan(middle.size.width, late.size.width)
    }

    func test_rect_isNeverNarrowerThan300Miles() throws {
        // E0 to E2 is 138 mi: half way, the plane, a tail and the way ahead span far less than 300.
        let short = FactsTestData.equatorFlight(from: 0, to: 2, departure: at("10:00"), id: "short")
        let rect = try XCTUnwrap(TripMapFollow.rect(for: short, at: short.start.addingTimeInterval(short.end.timeIntervalSince(short.start) / 2),
                                                    isReplay: false))
        let least = TripMapFollow.leastWidth * MKMapPointsPerMeterAtLatitude(0)
        XCTAssertEqual(rect.size.width, least, accuracy: least * 0.01)
    }

    func test_rect_isNone_beforeThePlaneHasLeft_afterTheGate_andOnADrive() {
        XCTAssertNil(TripMapFollow.rect(for: flight, at: at("10:10"), isReplay: false), "taxiing out: the whole flight")
        XCTAssertNil(TripMapFollow.rect(for: flight, at: at("13:30"), isReplay: false), "at the gate")
        let drive = MapLeg(id: "d1", kind: .drive, origin: flight.origin, destination: flight.destination,
                           start: flight.start, end: flight.end, flightNumber: nil)
        XCTAssertNil(TripMapFollow.rect(for: drive, at: at("11:45"), isReplay: false))
    }

    func test_rect_followsTheRealPlane_whereTheMapDrawsIt() throws {
        // The real plane is seen to 6° E at 11:03, ahead of the schedule's.
        let seenUntil = FactsTestData.liveTime(atLongitude: 6)
        let leg = try FactsTestData.equatorLiveLeg(FactsTestData.equatorLive(seenUntil: seenUntil), at: seenUntil)
        let rect = try XCTUnwrap(TripMapFollow.rect(for: leg, at: seenUntil, isReplay: false))
        let plane = leg.plane(at: seenUntil, isReplay: false)
        XCTAssertEqual(plane.coordinate.longitude, 6, accuracy: 0.1)
        XCTAssertTrue(rect.contains(MKMapPoint(plane.coordinate)))
        XCTAssertTrue(holds(rect, longitude: 4.5), "its tail")
    }

    func test_rect_ofARealPlaneStillAtTheGate_isTheWholeFlightNow_butFollowsTheReplaysPlane() throws {
        let fix = LiveFlight.Fix(latitude: 0, longitude: 0, altitudeFeet: nil, groundSpeedKnots: 0, trackDegrees: nil,
                                 isOnGround: true, registration: "N370UP", typeCode: "B763", seenAt: at("11:19"))
        let atTheGate = LiveFlight(legID: "eq", callsign: "TST1", state: .ground, fix: fix, landedAt: nil, trail: [])
        let leg = try FactsTestData.equatorLiveLeg(atTheGate, at: at("11:20"))
        XCTAssertNil(TripMapFollow.rect(for: leg, at: at("11:20"), isReplay: false), "it hasn't left")
        XCTAssertNotNil(TripMapFollow.rect(for: leg, at: at("11:20"), isReplay: true), "the replay's plane, by the schedule")
    }

    func test_framingRect_followsOnlyWhenAsked() throws {
        let map = TripMap(mode: .inFlight(legID: flight.id), legs: [flight], home: nil,
                          span: DateInterval(start: flight.start, end: flight.end), tripDays: nil)
        let whole = map.framingRect(focusingOn: flight)
        XCTAssertEqual(numbers(map.framingRect(focusingOn: flight, at: at("11:45"), followsPlane: false, isReplay: false)), numbers(whole))
        XCTAssertEqual(numbers(map.framingRect(focusingOn: flight, at: at("11:45"), followsPlane: true, isReplay: false)),
                       numbers(TripMapFollow.rect(for: flight, at: at("11:45"), isReplay: false)))
        XCTAssertEqual(numbers(map.framingRect(focusingOn: flight, at: at("10:10"), followsPlane: true, isReplay: false)), numbers(whole),
                       "before the plane has left")
    }
}
```

- [ ] **Step 2: The frame, with a 10% tail and no step rule.**

Replace the whole of `Crewluv/Services/TripMap/TripMapFollow.swift` with:

```swift
//
//  TripMapFollow.swift
//  CrewLuve
//
//  Following the plane (follow the plane design §3): the frame that holds a flight's plane, a short tail behind it and
//  everything left to the destination. The map glides toward it (`TripMapGlide`).
//

import MapKit

nonisolated enum TripMapFollow {

    /// The tail behind the plane: this share of the path's whole length, so it's a steady size all flight.
    static let tailShare = 0.1

    /// The frame is never narrower than this across: about 300 miles, in meters, so the end is a regional view.
    static let leastWidth: Double = 300 * GreatCircle.metersPerMile

    /// How many places along the tail and the way ahead the frame is made from.
    private static let placeCount = 33

    /// The frame that follows `leg`'s plane at `date` (§3): the plane where the map draws it, the tail behind it and
    /// the path ahead to the destination, with `MapFit`'s margins, at least `leastWidth` across. Nil where the whole
    /// flight is framed as before: it isn't a flight between its gates, or its plane hasn't left.
    /// - Parameter isReplay: `date` is a moment of the replay, so the real plane is where its record has it.
    static func rect(for leg: MapLeg, at date: Date, isReplay: Bool) -> MKMapRect? {
        guard leg.kind == .flight, leg.isMoving(at: date) else { return nil }
        let plane = leg.plane(at: date, isReplay: isReplay)
        let path = leg.path
        let distance = min(plane.distance, path.length)
        guard distance > 0, path.length > 0 else { return nil }
        let tailStart = max(0, distance - tailShare * path.length)
        let step = (path.length - tailStart) / Double(placeCount - 1)
        let places = (0..<placeCount).map { path.point(atDistance: tailStart + Double($0) * step) } + [plane.coordinate]
        let leastSide = leastWidth * MKMapPointsPerMeterAtLatitude(plane.coordinate.latitude)
        return MapFit.rect(enclosing: places, minimumSide: leastSide)
    }
}
```

- [ ] **Step 3: The camera, as it was before Follow the plane.**

Replace the whole of `Crewluv/Services/TripMap/TripMapCamera.swift` with:

```swift
//
//  TripMapCamera.swift
//  CrewLuve
//
//  What the trip map's camera should frame, and whether the family has moved it since (moving map spec §6). The map
//  frames each new request once. A pan, pinch or double tap makes the camera the family's: the recenter button shows,
//  and automatic refits leave it alone until they ask.
//

import MapKit

nonisolated struct TripMapCamera {
    /// The flat-map rectangle to frame (`MapFit`), or nil to leave the camera where it is.
    private(set) var rect: MKMapRect?
    /// Whether moving to `rect` animates. A map's first framing never does.
    private(set) var isAnimated = false
    /// True once the family has panned or zoomed since the camera was last framed.
    private(set) var isPositionedByUser = false
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
        isPositionedByUser = false
        framingNumber += 1
    }

    /// The family moved the map.
    mutating func markPositionedByUser() {
        isPositionedByUser = true
    }
}
```

- [ ] **Step 4: The map takes the frame.** No tests for the rest: UIKit and SwiftUI.

In `Crewluv/Views/TripMap/TripMapView.swift`:

Replace:

```swift
import SwiftUI
```

with:

```swift
import MapKit
import SwiftUI
```

Replace:

```swift
    var isReplay = false
```

with:

```swift
    var isReplay = false
    /// The frame the map glides toward while it follows the plane, for this tick (follow the plane design §4), or nil
    /// when it isn't following. A plain value, not the camera's state, so the glide redraws only the map.
    var followFrame: MKMapRect? = nil
```

Replace:

```swift
        context.coordinator.update(colorScheme: context.environment.colorScheme)
```

with:

```swift
        context.coordinator.update(colorScheme: context.environment.colorScheme,
                                   reduceMotion: context.environment.accessibilityReduceMotion)
```

In `Crewluv/Views/TripMap/TripMapCoordinator.swift`:

Replace:

```swift
        cameraController = nil
```

with:

```swift
        cameraController?.stopFollowing()
        cameraController = nil
```

Replace:

```swift
        cameraController.onFramedWithoutAnimation = { [weak self] in self?.shapes?.draw() }
```

with:

```swift
        // A framing or a glide's frame MapKit needn't report: our drawing, and any popup, are laid where the map now is.
        cameraController.onFramedWithoutAnimation = { [weak self] in
            self?.shapes?.draw()
            self?.popup?.reposition()
        }
```

Replace:

```swift
    func update(colorScheme: ColorScheme) {
```

with:

```swift
    func update(colorScheme: ColorScheme, reduceMotion: Bool) {
```

Replace:

```swift
        cameraController?.update(camera: parent.camera, clearance: parent.clearance, respectsSafeArea: isFullScreen)
```

with:

```swift
        cameraController?.update(camera: parent.camera, clearance: parent.clearance, respectsSafeArea: isFullScreen,
                                 followFrame: parent.followFrame, glides: !reduceMotion)
```

- [ ] **Step 5: The camera controller glides.**

In `Crewluv/Views/TripMap/TripMapCameraController.swift`:

Replace:

```swift
//  a framing leaves it out, and notices when the family moves the map themselves.
```

with:

```swift
//  a framing leaves it out, and notices when the family moves the map themselves. While the map follows the plane, it
//  glides toward the frame it's handed on every display frame (follow the plane design §4).
```

Replace:

```swift
    /// The marker an animated framing keeps in view, slid in once the framing has finished.
    private var pendingKeptInView: CLLocationCoordinate2D?
```

with:

```swift
    /// The marker an animated framing keeps in view, slid in once the framing has finished.
    private var pendingKeptInView: CLLocationCoordinate2D?
    /// While the map follows the plane: the frame it glides toward, the frame it's at, and the display link that moves
    /// it, which runs only until it gets there.
    private var followTarget: MKMapRect?
    private var followCurrent: MKMapRect?
    private var displayLink: CADisplayLink?
    private var lastGlide: CFTimeInterval?
```

Replace:

```swift
    /// SwiftUI's latest camera, clearance and kind of map.
    func update(camera: TripMapCamera, clearance newClearance: TripMapClearance, respectsSafeArea newRespectsSafeArea: Bool) {
        clearance = newClearance
        respectsSafeArea = newRespectsSafeArea
        applyMargins()
        frameIfNeeded(camera)
    }

    /// The map's size or safe area has changed.
    func layoutDidChange(camera: TripMapCamera) {
        applyMargins()
        frameIfNeeded(camera)
    }
```

with:

```swift
    /// SwiftUI's latest camera, clearance and kind of map, and the frame to follow the plane to, if it's following.
    /// While it follows, the glide moves the map, and a refit's request is the glide's to make: a pan or pinch stops
    /// it, and recenter starts it again from where the map is.
    func update(camera: TripMapCamera, clearance newClearance: TripMapClearance, respectsSafeArea newRespectsSafeArea: Bool,
                followFrame: MKMapRect?, glides: Bool) {
        clearance = newClearance
        respectsSafeArea = newRespectsSafeArea
        applyMargins()
        if let followFrame, !camera.isPositionedByUser {
            guard let mapView, mapView.bounds.width > 0, mapView.bounds.height > 0 else { return }
            // The map's first framing goes straight there, as every first framing does.
            let isFirstFraming = framedNumber == nil
            framedNumber = camera.framingNumber
            framedSize = mapView.bounds.size
            framedMargins = mapView.layoutMargins
            follow(toward: followFrame, glides: glides && !isFirstFraming)
        } else {
            stopFollowing()
            frameIfNeeded(camera)
        }
    }

    /// The map's size or safe area has changed.
    func layoutDidChange(camera: TripMapCamera) {
        applyMargins()
        if let followCurrent {
            show(followCurrent)
        } else {
            frameIfNeeded(camera)
        }
    }

    // MARK: - Following the plane

    /// Glides toward `target` from where the map is, on every display frame until it gets there, or goes straight to
    /// it with Reduce Motion on, or when it's already as good as there, as live it nearly always is. A frame that's
    /// already shown isn't shown again.
    private func follow(toward target: MKMapRect, glides: Bool) {
        guard let mapView, Self.isFinite(target) else { return }
        pendingKeptInView = nil
        if let followCurrent, displayLink == nil, MKMapRectEqualToRect(followCurrent, target) { return }
        followTarget = target
        let current = followCurrent ?? shownRect(of: mapView)
        guard glides, !TripMapGlide.isThere(current, at: target) else {
            followCurrent = target
            show(target)
            pauseGlide()
            return
        }
        followCurrent = current
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(glide(_:)))
        // Smooth enough at 60 a second, and no more on a ProMotion screen.
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    /// One display frame of the glide.
    @objc private func glide(_ link: CADisplayLink) {
        guard let target = followTarget, let current = followCurrent else { return stopFollowing() }
        let elapsed = lastGlide.map { link.timestamp - $0 } ?? link.duration
        lastGlide = link.timestamp
        let next = TripMapGlide.step(from: current, toward: target, over: elapsed)
        followCurrent = next
        show(next)
        if MKMapRectEqualToRect(next, target) { pauseGlide() }
    }

    /// The glide has got there: the link stops until the frame moves on.
    private func pauseGlide() {
        displayLink?.invalidate()
        displayLink = nil
        lastGlide = nil
    }

    /// The map isn't following now: nothing glides, and the next follow starts from where the map is.
    func stopFollowing() {
        pauseGlide()
        followTarget = nil
        followCurrent = nil
    }

    /// Shows `rect` inside the map's margins, as a framing does, at once, and has the drawing and any popup follow,
    /// since MapKit needn't report a move it wasn't asked to animate.
    private func show(_ rect: MKMapRect) {
        mapView?.setVisibleMapRect(rect, edgePadding: .zero, animated: false)
        onFramedWithoutAnimation?()
    }

    /// Whether every number of `rect` is a real one, so a frame worked out from bad data never reaches MapKit.
    private static func isFinite(_ rect: MKMapRect) -> Bool {
        [rect.origin.x, rect.origin.y, rect.size.width, rect.size.height].allSatisfy(\.isFinite)
    }

    /// What the map shows inside its margins, as a frame: where a glide starts from.
    private func shownRect(of mapView: MKMapView) -> MKMapRect {
        let visible = mapView.visibleMapRect
        let scale = visible.size.width / mapView.bounds.width
        let margins = mapView.layoutMargins
        return MKMapRect(x: visible.origin.x + margins.left * scale, y: visible.origin.y + margins.top * scale,
                         width: visible.size.width - (margins.left + margins.right) * scale,
                         height: visible.size.height - (margins.top + margins.bottom) * scale)
    }
```

Replace:

```swift
        // The family's move wins over a slide still to come.
        pendingKeptInView = nil
```

with:

```swift
        // The family's move wins over a slide still to come, and over the glide.
        pendingKeptInView = nil
        stopFollowing()
```

- [ ] **Step 6: The full-screen map.**

In `Crewluv/Views/TripMap/TripMapScreen.swift`:

Replace:

```swift
import SwiftUI
```

with:

```swift
import MapKit
import SwiftUI
```

Replace:

```swift
                .onChange(of: context.date) { follow(at: time, now: context.date) }
                // Initially too, for a store other than the standard one `init` framed from, as the previews' is.
```

with:

```swift
                // Following starts or stops within a leg, as a replay is dragged back before takeoff: the map
                // frames as the setting now says.
                .onChange(of: followFrame(at: time) != nil) {
                    refit(legID: tripMap.legInMotion(at: time)?.id, at: time)
                }
                // Initially too, for a store other than the standard one `init` framed from, as the previews' is.
```

Replace:

```swift
                        controlsHeight: mapTopClearance, isFullScreen: true, isReplay: !clock.isLive)
```

with:

```swift
                        controlsHeight: mapTopClearance, isFullScreen: true, isReplay: !clock.isLive,
                        followFrame: followFrame(at: time))
```

Replace:

```swift
    /// Eases the camera in on the flight's plane at `time` while the family follows it, in steps spaced by the real
    /// time `now` (follow the plane design §4). It runs on every tick, up to 60 a second in a replay, so it makes the
    /// frame only when a move could be due, and writes the camera back only when it moves: a write redraws the screen.
    private func follow(at time: Date, now: Date) {
        guard followsPlane, let leg = tripMap.legInMotion(at: time), leg.kind == .flight else { return }
        let plane = leg.plane(at: time, isReplay: !clock.isLive)
        let places = [plane.coordinate, leg.destination.coordinate]
        guard camera.mayFollow(keeping: places, at: now), let wanted = TripMapFollow.rect(for: leg, plane: plane) else { return }
        var moved = camera
        if moved.follow(wanted, keeping: places, at: now, animated: !reduceMotion) { camera = moved }
    }
```

with:

```swift
    /// The frame the map glides toward at `time` while the family follows the plane, or nil (follow the plane design
    /// §3, §4). It's handed to the map on every tick, up to 60 a second in a replay, as a plain value.
    private func followFrame(at time: Date) -> MKMapRect? {
        guard followsPlane, let leg = tripMap.legInMotion(at: time) else { return nil }
        return TripMapFollow.rect(for: leg, at: time, isReplay: !clock.isLive)
    }
```

- [ ] **Step 7: The card.**

In `Crewluv/Views/TripMap/TripMapCard.swift`:

Replace:

```swift
import SwiftUI
```

with:

```swift
import MapKit
import SwiftUI
```

Replace:

```swift
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(TripMapScreen.followsPlaneKey) private var followsPlane = false
```

with:

```swift
    @AppStorage(TripMapScreen.followsPlaneKey) private var followsPlane = false
```

Replace:

```swift
                bar(facts: facts, at: context.date)
            }
            .onChange(of: context.date) { follow(at: context.date) }
```

with:

```swift
                bar(facts: facts, at: context.date)
            }
            // Following starts or stops within a leg: the card frames as the setting now says.
            .onChange(of: followFrame(at: context.date) != nil) { refit() }
```

Replace:

```swift
    /// Eases the card in on the flight's plane at `date`, every tick, while the family follows it (follow the plane
    /// design §4).
    private func follow(at date: Date) {
        guard followsPlane, let leg = tripMap.currentLeg,
              let wanted = TripMapFollow.rect(for: leg, at: date, isReplay: false) else { return }
        var moved = camera
        if moved.follow(wanted, keeping: TripMapFollow.places(for: leg, at: date, isReplay: false), at: date,
                        animated: !reduceMotion) {
            camera = moved
        }
    }
```

with:

```swift
    /// The frame the card's map glides toward at `date` while the family follows the plane, or nil (follow the plane
    /// design §3, §4).
    private func followFrame(at date: Date) -> MKMapRect? {
        guard followsPlane, let leg = tripMap.currentLeg else { return nil }
        return TripMapFollow.rect(for: leg, at: date, isReplay: false)
    }
```

Replace:

```swift
                        clearance: clearance(for: chips, hasCorner: latest != nil || showsKey))
                .allowsHitTesting(false)
```

with:

```swift
                        clearance: clearance(for: chips, hasCorner: latest != nil || showsKey), followFrame: followFrame(at: date))
                .allowsHitTesting(false)
```

---

### Task 4: The docs

- [ ] **Step 1: The design, revised.**

Replace the whole of `docs/superpowers/specs/2026-11-17-follow-the-plane-design.md` with:

```swift
# Crewluve Trip Map: Follow the Plane

Status: approved by Todd on 17 Nov 2026 ("Card and full screen", "Full-screen button, off", "Tail of 20% of the
flight", then "Yes, write it up"). The app's own camera: the website isn't part of it.

Revised the same day after Todd tried it ("It doesn't zoom in close enough and it zooms and stops and zooms and stops on
playback", "It still has way more behind the plane than in front. The destination needs to stay in view"): the first
build's step rule moved only when the frame shrank by 15%, so as the frame slid forward at about the same size the
camera kept its old middle, and its steps came 5 seconds apart. Now the tail is 10% ("10% of the flight") and the map
glides continuously toward the frame ("Yes, write it up"): §3 and §4.

## 1. Why

In flight the map frames the whole flight when the leg begins (`TripMap.framingRect(focusingOn:)`) and keeps that view
until the next leg. Live or in a replay, the plane crawls across a map that never comes closer, and at the end of a
long flight the arrival is a small corner of it. Todd likes today's view too, so following is a choice.

## 2. The setting

- **"Follow the plane",** one setting for the card and the full-screen map, remembered (`@AppStorage`
  `tripMapFollowsPlane`), as Quick layovers is.
- **Off at first,** so today's whole-flight view stays until the family turns it on.
- **Switched on the full-screen map** by a button beside recenter: `airplane.circle`, filled while it's on,
  and to VoiceOver "Follow the plane", with the value "on" or "off". The card has no button: it follows the setting.

## 3. What it frames

While the setting is on and a flight is between its gates (`TripMap.legInMotion` is a flight):

- **The plane,** wherever the map draws it: the real plane where there's live data (as `FlightDrawing` places it), the
  schedule's otherwise, and the replay's plane at the replay's moment.
- **A tail behind it:** the stretch of the flight's path from 10% of the path's whole length behind the plane (or its
  start, if that's nearer) up to the plane. The tail is a steady size, so the plane is never hard against the edge.
- **Everything left,** along the path from the plane to the destination, which always stays in view.
- **Room around it,** as the whole-flight framing has: the same margins, and the same clearances for the facts sheet,
  the panel and the card's chips (`TripMapClearance`).
- **Never narrower than about 300 miles** across, centred on the same middle, so near the end it's a regional view, not
  one airport filling the map.

Before the plane has left (the plan's takeoff, or a real plane still at the gate), the tail is nothing and the frame is
the whole flight, as today.

## 4. How it moves

- **A continuous glide:** SwiftUI hands the map the frame it wants on every tick (up to 60 a second in a replay, once a
  second live, every 10 seconds on the card), and the map itself eases toward it on every display frame, its middle
  and its zoom together, catching up in about a second. Nothing steps, so nothing stops and starts. Live, the frame
  changes so slowly the motion is hardly seen; a replay is tracked smoothly; a replay dragged back glides to its new
  frame.
- **No SwiftUI state on each frame:** the frame wanted is a plain value the map is drawn with, not the camera's state,
  so the glide redraws only the map, not the screen.
- **With Reduce Motion on** it follows without the glide.
- **The family's pan or pinch** stops it, as today, until they tap recenter, which frames as the setting says.
- **Turning the setting on or off** frames at once, the way the setting now says.

## 5. When it stands aside

On the ground, on a drive, before a trip and in the recap the map frames as it does today. A flight with no plane to
place frames the whole flight.

## 6. Tests

The frame and the glide's step are plain logic beside `TripMapCamera`, `nonisolated` and tested:

- a flight's frame at its start, its middle and its last stretch, against expected rectangles, and the 300-mile floor;
- a frame before takeoff and with no plane, which are the whole flight's;
- the glide's step: part of the way toward the frame each display frame, more the longer the frame, the middle and the
  zoom eased together, across the date line the short way, and arriving without overshoot;
- the setting off, which frames as today.

Previews: the card and the full screen in flight with the setting on.

## 7. Left for later

- Following a drive.
- A frame that leads the plane by its heading on a flight that turns back on itself.
```

- [ ] **Step 2:**

In `CLAUDE.md`:

Replace:

```swift
- North stays up and the map never tilts, so `PlaneHeading` aims the plane from coordinates alone and `MapProjection` (CrewLu's `FlatMapFit`) places everything from three points the map is asked about. The camera is `TripMapCamera`: a pan, pinch or double tap makes it the family's until they recenter. With Follow the plane on (`@AppStorage` `tripMapFollowsPlane`, off at first, the airplane button on the full-screen map, for the card too), a flight's frame is its plane, a tail of 20% of the flight behind it and the way ahead, never under 300 miles across (`TripMapFollow`): the camera eases in on it once it's 15% smaller, at most every 5 seconds, and out at once when the plane or the destination would leave the view (follow the plane design `docs/superpowers/specs/2026-11-17-follow-the-plane-design.md`). `TripMapClearance` keeps the map's framing and Apple's logo clear of the facts sheet or panel, and of the card's chips, through the map's layout margins alone: MapKit fits `setVisibleMapRect` inside them, so padding the camera for the sheet or panel as well counts it twice. MapKit won't zoom out past its own limit, so a trip much wider than the map can be cut off: after each framing the camera slides the pilot's ground marker into view if it's outside the margins (`TripMapSlide`)
```

with:

```swift
- North stays up and the map never tilts, so `PlaneHeading` aims the plane from coordinates alone and `MapProjection` (CrewLu's `FlatMapFit`) places everything from three points the map is asked about. The camera is `TripMapCamera`: a pan, pinch or double tap makes it the family's until they recenter. With Follow the plane on (`@AppStorage` `tripMapFollowsPlane`, off at first, the airplane button on the full-screen map, for the card too), a flight's frame is its plane, a tail of 10% of the flight behind it and the way ahead to the destination, never under 300 miles across (`TripMapFollow`), handed to the map as a plain value on each tick: the map's camera controller glides toward it on every display frame, its middle and zoom together, catching up in about a second (`TripMapGlide`), so SwiftUI redraws nothing for it; a pan or pinch stops it until recenter (follow the plane design `docs/superpowers/specs/2026-11-17-follow-the-plane-design.md`). `TripMapClearance` keeps the map's framing and Apple's logo clear of the facts sheet or panel, and of the card's chips, through the map's layout margins alone: MapKit fits `setVisibleMapRect` inside them, so padding the camera for the sheet or panel as well counts it twice. MapKit won't zoom out past its own limit, so a trip much wider than the map can be cut off: after each framing the camera slides the pilot's ground marker into view if it's outside the margins (`TripMapSlide`)
```

---

### Task 5: Todd's run, a look, and the commits

- [ ] **Step 1: Todd runs every test of the app once:**

```bash
xcodebuild test -project Crewluv.xcodeproj -scheme Crewluv -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' 2>&1 | grep -E "error:|TEST (SUCCEEDED|FAILED)"
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 2: Todd looks** in the app with Follow the plane on: a replay glides in smoothly with the plane near the back of the view and the destination ahead in it; dragging the replay back glides out; a pan stops it until recenter; the card follows too.

- [ ] **Step 3: Ask to commit:** one commit for each of Tasks 2 and 3, then Task 4 with this plan.

## Left for later

- **Following a drive.**
- **A frame that leads the plane by its heading** on a flight that turns back on itself.
