# Follow the Plane (Crewluve App) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** With "Follow the plane" on, the trip map, on the card and full screen, eases in on a flight's plane as it goes, in gentle steps, live and in a replay. With it off, as it is at first, the map frames as it does today.

**Architecture:**
- **The frame and the step rule** are plain logic in `Crewluv/Services/TripMap/TripMapFollow.swift`. The frame (`rect(for:at:isReplay:)`) holds the plane where the map draws it, a tail of 20% of the path's length behind it, and the path ahead, through `MapFit` with a floor of 300 miles. The step rule (`shouldMove`) moves out at once when the plane or the destination is out of view, and otherwise in only once the frame it wants is 15% smaller, at most every 5 seconds.
- **The camera** (`TripMapCamera.follow`) applies the rule against the last frame it asked for, and leaves a camera the family moved. `TripMap.framingRect(focusingOn:at:followsPlane:isReplay:)` is the frame for a refit: following when asked, the whole flight otherwise.
- **The views:** a remembered setting (`@AppStorage` `tripMapFollowsPlane`, off), an airplane button on the full-screen map's top bar, a follow step on every tick of `TripMapScreen`'s and `TripMapCard`'s timelines, and a refit when the setting changes. Two previews show it.

**Tech Stack:** Swift 5 language mode, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, iOS 26, SwiftUI, MapKit, XCTest.

**Sources:**
- **The design:** `docs/superpowers/specs/2026-11-17-follow-the-plane-design.md` (Todd, 17 Nov 2026, `5012929`): one setting for the card and the full-screen map, off at first, switched by a full-screen button; the tail of 20% of the flight; the 300-mile floor; 15% steps at most every 5 seconds, and out at once.
- **The camera it builds on:** `TripMapCamera`, `MapFit` and `TripMapClearance` (moving map spec §6, base waits and card framing design §4).

**How this plan was checked.**
- **A scratch Swift package** with the app target's settings, made from the repo at `5012929`: 631 XCTest and 71 Swift Testing tests before, 646 and 71 with this plan, all passing, no warnings.
- **26 deliberate breaks** were made in the new Swift, one at a time, and every one fails at least one test: no tail, or the whole flight as the tail; no 300-mile floor; following before takeoff, on a drive or after the gate; the schedule's plane always; no destination in view; never out at once, or out only after 5 seconds; no spacing, or over 5 seconds; any step in, or one under 15%; the width alone; no date line; nothing framed never moving; may move only when out, always, or for the family's camera; follow saying it never moved, following a moved camera, never remembering the move, or never animating; and always or never following in a refit.
- **The whole app was type-checked for iOS** with `swiftc` outside Xcode after Tasks 2 and 3, and compiled for the iOS simulator with the whole plan in: no errors and no warnings. The views, the button and the previews are checked that way only.
- **The plan was followed by a script** on the repo at `5012929`: all 10 files came out the same as the tested ones.
- **Reviewed** by `superpowers:code-reviewer` (sonnet) before the plan was put together: nothing critical; the camera's moves, the clearances, the date line and the card's refits are sound. From its points: a follow step on every tick wrote the camera back and so redrew the full screen up to 60 times a second in a replay, and now writes only when it moves (`follow` says whether it did), with a cheap `mayFollow` before the frame is made and the plane placed once; the plane's distance held to the path's; a comment on why the maps refit when they appear; and more tests (the steps' spacing, a frame narrower but as tall, a plane still at the gate). Left, with reasons, under Left for later: a flight wider than MapKit will zoom out to, and spacing after a refit.
- **Not checked:** nothing ran on a simulator or a device, and no view was seen: how the glides feel is for Todd's look.

**Where this plan settles details.**
- **The button** is `airplane.circle`, filled while following, between recenter and the map style, and to VoiceOver "Follow the plane", "On" or "Off", as a toggle. It shows on the ground too, since the setting is the card's as well.
- **Smooth at 60 updates a second:** on each tick the full-screen map places the plane once, asks the camera whether a move could be due (`mayFollow`: out of view, or 5 seconds gone), makes the frame only then, and writes the camera back only when it moves, since each write redraws the screen.
- **The steps are spaced by the real time,** not the replay's, so a fast replay steps no faster than every 5 seconds.
- **The rule compares with the last frame the camera asked for,** not what MapKit shows, which is that frame grown to the map's shape: a place inside the one is inside the other.
- **The card's frame** follows on its 10-second tick, so its steps are 10 seconds apart at the least. While it follows, a real path that grows no longer refits it to the whole flight: following keeps the plane and the destination in view.
- **Turning the setting on or off,** and every time the map appears, refits at once: the full-screen map takes the camera back from the family then, as recenter does.
- **A plane at the gate, still or back after an air return,** is at the start of its path: the whole flight is framed, as today.

---

## Ground rules

1. **Don't run `xcodebuild` build or test loops.** Todd runs the tests (Task 5).
2. **Never commit without Todd's go-ahead,** and then only this plan's files, by path. **Never push** without a fresh yes.
3. **Copy the code as written.** A replacement is exact: if its text isn't in the file once, stop.
4. **Work on `feature/trip-map-live`.** Never stash, reset or switch branches.

## File map

| File | Task | What changes |
|---|---|---|
| `Crewluv/Services/TripMap/TripMapFollow.swift` (new), `TripMapCamera.swift`, `Crewluv/Views/TripMap/TripMap+Camera.swift`, `CrewluvTests/TripMapFollowTests.swift` (new) | 2 | the frame, the step rule and the camera |
| `Crewluv/Views/TripMap/TripMapTopBar.swift`, `TripMapScreen.swift`, `TripMapCard.swift`, `TripMapPreviews.swift` | 3 | the setting, its button, the two maps and the previews |
| `CLAUDE.md`, `docs/superpowers/specs/2026-11-17-follow-the-plane-design.md` | 4 | the docs |

---

### Task 1: Before starting

- [ ] **Step 1:** The branch is `feature/trip-map-live`, at `5012929` or later, and none of this plan's files has changed since.

```bash
git -C /Users/toddanderson/Dev/Crewluv status --short && git -C /Users/toddanderson/Dev/Crewluv branch --show-current && git -C /Users/toddanderson/Dev/Crewluv log --oneline -1
```

---

### Task 2: The frame, the step rule and the camera (design §3, §4)

- [ ] **Step 1: The tests.**

Create `CrewluvTests/TripMapFollowTests.swift`:

```swift
//
//  TripMapFollowTests.swift
//  CrewluvTests
//
//  Following the plane (follow the plane design §3, §4). The flight is `FactsTestData`'s equator flight from E0 to
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
        // The tail is 20% of the flight behind the plane, 4° of its 20.
        XCTAssertTrue(holds(rect, longitude: plane.coordinate.longitude - 4))
        XCTAssertFalse(holds(rect, longitude: 0), "E0 is left behind")
        let whole = try XCTUnwrap(TripMap(mode: .inFlight(legID: flight.id), legs: [flight], home: nil,
                                          span: DateInterval(start: flight.start, end: flight.end), tripDays: nil)
            .framingRect(focusingOn: flight))
        XCTAssertLessThan(rect.size.width, whole.size.width * 0.85)
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
        XCTAssertTrue(holds(rect, longitude: 2), "its tail")
        XCTAssertEqual(TripMapFollow.places(for: leg, at: seenUntil, isReplay: false).map(\.longitude),
                       [plane.coordinate.longitude, 20])
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

    // MARK: - When the camera moves

    private let shown = MKMapRect(x: 100_000_000, y: 100_000_000, width: 10_000_000, height: 10_000_000)
    private let inside = [MKMapPoint(x: 104_000_000, y: 105_000_000).coordinate]
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func wanted(_ share: Double) -> MKMapRect {
        MKMapRect(x: 102_000_000, y: 102_000_000, width: 10_000_000 * share, height: 10_000_000 * share)
    }

    private func moves(to share: Double, after seconds: TimeInterval?, keeping places: [CLLocationCoordinate2D]? = nil) -> Bool {
        TripMapFollow.shouldMove(from: shown, to: wanted(share), keeping: places ?? inside,
                                 lastMove: seconds.map { start.addingTimeInterval(-$0) }, now: start)
    }

    func test_shouldMove_inOnlyBy15PercentOrMore() {
        XCTAssertFalse(moves(to: 0.9, after: 60))
        XCTAssertFalse(moves(to: 0.86, after: 60))
        XCTAssertTrue(moves(to: 0.85, after: 60))
        XCTAssertTrue(moves(to: 0.5, after: nil), "the first move")
        XCTAssertFalse(moves(to: 1.2, after: 60), "bigger, with the plane and the destination still in view")
        let narrower = MKMapRect(x: 102_000_000, y: 100_000_000, width: 5_000_000, height: 10_000_000)
        XCTAssertFalse(TripMapFollow.shouldMove(from: shown, to: narrower, keeping: inside, lastMove: nil, now: start),
                       "narrower but as tall: it would cut the height")
    }

    func test_shouldMove_inNoSoonerThan5SecondsAfterTheLast() {
        XCTAssertFalse(moves(to: 0.5, after: 4.9))
        XCTAssertTrue(moves(to: 0.5, after: 5))
    }

    func test_shouldMove_outAtOnce_whenThePlaneOrTheDestinationIsOutOfView() {
        let outside = [MKMapPoint(x: 115_000_000, y: 105_000_000).coordinate]
        XCTAssertTrue(moves(to: 1.2, after: 1, keeping: inside + outside))
        XCTAssertTrue(TripMapFollow.shouldMove(from: nil, to: wanted(1), keeping: inside, lastMove: start, now: start),
                      "nothing framed yet")
    }

    func test_shouldMove_holdsAPlaceAcrossTheDateLine() {
        // A frame that runs on past the map's right edge holds a place just east of the date line.
        let world = MKMapSize.world.width
        let across = MKMapRect(x: world - 5_000_000, y: 100_000_000, width: 10_000_000, height: 10_000_000)
        let eastOfIt = MKMapPoint(x: 2_000_000, y: 105_000_000).coordinate
        XCTAssertFalse(TripMapFollow.shouldMove(from: across, to: across, keeping: [eastOfIt], lastMove: nil, now: start))
    }

    // MARK: - The camera

    func test_follow_movesTheCamera_andSpacesItsSteps() {
        var camera = TripMapCamera(framing: shown)
        camera.follow(wanted(0.5), keeping: inside, at: start, animated: true)
        XCTAssertEqual(numbers(camera.rect), numbers(wanted(0.5)))
        XCTAssertEqual(camera.framingNumber, 1)
        XCTAssertTrue(camera.isAnimated)
        XCTAssertEqual(camera.followedAt, start)
        XCTAssertNil(camera.keptInView, "no ground marker to keep in flight")
        camera.follow(wanted(0.25), keeping: [], at: start.addingTimeInterval(2), animated: true)
        XCTAssertEqual(numbers(camera.rect), numbers(wanted(0.5)), "two seconds on")
    }

    func test_mayFollow_onlyWhenAMoveCouldBeDue() {
        var camera = TripMapCamera(framing: shown)
        XCTAssertTrue(camera.mayFollow(keeping: inside, at: start), "never followed yet")
        camera.follow(wanted(0.5), keeping: inside, at: start, animated: true)
        let held = [MKMapPoint(x: 104_000_000, y: 104_000_000).coordinate]
        XCTAssertFalse(camera.mayFollow(keeping: held, at: start.addingTimeInterval(4)))
        XCTAssertTrue(camera.mayFollow(keeping: held, at: start.addingTimeInterval(5)))
        let outside = [MKMapPoint(x: 115_000_000, y: 105_000_000).coordinate]
        XCTAssertTrue(camera.mayFollow(keeping: outside, at: start.addingTimeInterval(1)), "out at once")
        camera.markPositionedByUser()
        XCTAssertFalse(camera.mayFollow(keeping: outside, at: start.addingTimeInterval(10)), "the family's camera")
    }

    func test_follow_saysWhetherItMoved() {
        var camera = TripMapCamera(framing: shown)
        XCTAssertTrue(camera.follow(wanted(0.5), keeping: inside, at: start, animated: true))
        XCTAssertFalse(camera.follow(wanted(0.25), keeping: inside, at: start.addingTimeInterval(1), animated: true))
    }

    func test_follow_leavesACameraTheFamilyMoved() {
        var camera = TripMapCamera(framing: shown)
        camera.markPositionedByUser()
        camera.follow(wanted(0.5), keeping: inside, at: start, animated: true)
        XCTAssertEqual(numbers(camera.rect), numbers(shown))
        XCTAssertEqual(camera.framingNumber, 0)
    }
}
```

- [ ] **Step 2: The frame and the step rule.**

Create `Crewluv/Services/TripMap/TripMapFollow.swift`:

```swift
//
//  TripMapFollow.swift
//  CrewLuve
//
//  Following the plane (follow the plane design §3, §4): the frame that holds a flight's plane, a tail behind it and
//  everything left to the destination, and when the camera moves to it, in gentle steps in and at once out.
//

import MapKit

nonisolated enum TripMapFollow {

    /// The tail behind the plane: this share of the path's whole length, so it's a steady size all flight.
    static let tailShare = 0.2

    /// The frame is never narrower than this across: about 300 miles, in meters, so the end is a regional view.
    static let leastWidth: Double = 300 * GreatCircle.metersPerMile

    /// The camera eases in once the frame it wants is this share of the one it shows, or less, across.
    static let stepShare = 0.85

    /// And no sooner than this after its last move: 5 seconds.
    static let stepInterval: TimeInterval = 5

    /// How many places along the tail and the way ahead the frame is made from.
    private static let placeCount = 33

    /// The frame that follows `leg`'s plane at `date` (§3): the plane where the map draws it, the tail behind it and
    /// the path ahead, with `MapFit`'s margins, at least `leastWidth` across. Nil where the whole flight is framed as
    /// before: it isn't a flight between its gates, or its plane hasn't left.
    /// - Parameter isReplay: `date` is a moment of the replay, so the real plane is where its record has it.
    static func rect(for leg: MapLeg, at date: Date, isReplay: Bool) -> MKMapRect? {
        guard leg.kind == .flight, leg.isMoving(at: date) else { return nil }
        return rect(for: leg, plane: leg.plane(at: date, isReplay: isReplay))
    }

    /// `rect(for:at:isReplay:)` for `leg`'s plane at `plane`, already placed, for a leg between its gates.
    static func rect(for leg: MapLeg, plane: PlanePosition) -> MKMapRect? {
        let path = leg.path
        let distance = min(plane.distance, path.length)
        guard distance > 0, path.length > 0 else { return nil }
        let tailStart = max(0, distance - tailShare * path.length)
        let step = (path.length - tailStart) / Double(placeCount - 1)
        let places = (0..<placeCount).map { path.point(atDistance: tailStart + Double($0) * step) } + [plane.coordinate]
        let leastSide = leastWidth * MKMapPointsPerMeterAtLatitude(plane.coordinate.latitude)
        return MapFit.rect(enclosing: places, minimumSide: leastSide)
    }

    /// The places the frame on screen must always hold while it follows `leg` at `date` (§4): its plane, where the
    /// map draws it, and its destination.
    static func places(for leg: MapLeg, at date: Date, isReplay: Bool) -> [CLLocationCoordinate2D] {
        [leg.plane(at: date, isReplay: isReplay).coordinate, leg.destination.coordinate]
    }

    /// Whether a camera showing `shown`, last moved at `lastMove`, may move at `now` at all: one of `places` is outside
    /// `shown`, or `stepInterval` has gone by. Cheap, so the frame is made only when a move could be due.
    static func mayMove(from shown: MKMapRect?, keeping places: [CLLocationCoordinate2D], lastMove: Date?, now: Date) -> Bool {
        guard let shown, shown.size.width > 0, shown.size.height > 0 else { return true }
        if places.contains(where: { !contains(shown, MKMapPoint($0)) }) { return true }
        return lastMove.map { now.timeIntervalSince($0) >= stepInterval } ?? true
    }

    /// Whether a camera showing `shown`, last moved at `lastMove`, moves to `wanted` at `now` (§4): at once when one of
    /// `places` (the plane and the destination) is outside `shown`; otherwise only when `wanted` is `stepShare` of
    /// `shown` across or less, and `stepInterval` or more has gone by since the last move.
    ///
    /// `shown` is the frame the camera last asked for. MapKit shows it grown to the map's shape, so a place inside it
    /// is on screen, except on a flight wider than MapKit will zoom out to, as the whole flight's frame can be today.
    static func shouldMove(from shown: MKMapRect?, to wanted: MKMapRect, keeping places: [CLLocationCoordinate2D],
                           lastMove: Date?, now: Date) -> Bool {
        guard let shown, shown.size.width > 0, shown.size.height > 0 else { return true }
        if places.contains(where: { !contains(shown, MKMapPoint($0)) }) { return true }
        if let lastMove, now.timeIntervalSince(lastMove) < stepInterval { return false }
        return max(wanted.size.width / shown.size.width, wanted.size.height / shown.size.height) <= stepShare
    }

    /// Whether `rect` holds `point`, on the map or a world east, since a rectangle across the date line runs on past
    /// the map's right edge (`MapFit`).
    private static func contains(_ rect: MKMapRect, _ point: MKMapPoint) -> Bool {
        let world = MKMapSize.world.width
        let isAcross = [point.x, point.x + world].contains { rect.minX <= $0 && $0 <= rect.maxX }
        return isAcross && rect.minY <= point.y && point.y <= rect.maxY
    }
}
```

- [ ] **Step 3: The camera follows.**

In `Crewluv/Services/TripMap/TripMapCamera.swift`:

Replace:

```swift
//  What the trip map's camera should frame, and whether the family has moved it since (moving map spec §6). The map
//  frames each new request once. A pan, pinch or double tap makes the camera the family's: the recenter button shows,
//  and automatic refits leave it alone until they ask.
```

with:

```swift
//  What the trip map's camera should frame, and whether the family has moved it since (moving map spec §6). The map
//  frames each new request once. A pan, pinch or double tap makes the camera the family's: the recenter button shows,
//  and automatic refits leave it alone until they ask. While it follows the plane, it eases in on it in gentle steps
//  (follow the plane design §4).
```

Replace:

```swift
    private(set) var keptInView: CLLocationCoordinate2D?
```

with:

```swift
    private(set) var keptInView: CLLocationCoordinate2D?
    /// When the camera last moved to follow the plane. Nil until it has.
    private(set) var followedAt: Date?
```

Replace:

```swift
    /// The family moved the map.
```

with:

```swift
    /// Whether a follow step could move the camera at `now`: the family hasn't moved it, and `TripMapFollow.mayMove`
    /// says a move could be due. A view asks this on every tick, and makes the frame only when it's true.
    /// - Parameter places: the plane and the destination, which the frame on screen must hold.
    func mayFollow(keeping places: [CLLocationCoordinate2D], at now: Date) -> Bool {
        !isPositionedByUser && TripMapFollow.mayMove(from: rect, keeping: places, lastMove: followedAt, now: now)
    }

    /// Follows the plane: frames `wanted` when `TripMapFollow.shouldMove` says it's time, and leaves a camera the
    /// family moved alone (follow the plane design §4). Returns whether it moved, so a view writes its camera back
    /// only then.
    /// - Parameters:
    ///   - places: the plane and the destination, which the frame on screen must hold.
    ///   - now: the real time, by which the steps are spaced, whether the map is live or a replay.
    @discardableResult
    mutating func follow(_ wanted: MKMapRect, keeping places: [CLLocationCoordinate2D], at now: Date, animated: Bool) -> Bool {
        guard !isPositionedByUser,
              TripMapFollow.shouldMove(from: rect, to: wanted, keeping: places, lastMove: followedAt, now: now) else { return false }
        frame(wanted, animated: animated)
        followedAt = now
        return true
    }

    /// The family moved the map.
```

- [ ] **Step 4: The frame for a refit.**

In `Crewluv/Views/TripMap/TripMap+Camera.swift`:

Replace:

```swift
    /// `framingRect` as numbers a view can compare, so the card frames the trip again when a real path grows past
```

with:

```swift
    /// The frame at `date`: following the plane when `followsPlane` and `leg` is a flight between its gates whose
    /// plane has left (follow the plane design §3), else `framingRect(focusingOn:)` as before.
    /// - Parameter isReplay: `date` is a moment of the replay.
    func framingRect(focusingOn leg: MapLeg?, at date: Date, followsPlane: Bool, isReplay: Bool) -> MKMapRect? {
        if followsPlane, let leg, let rect = TripMapFollow.rect(for: leg, at: date, isReplay: isReplay) { return rect }
        return framingRect(focusingOn: leg)
    }

    /// `framingRect` as numbers a view can compare, so the card frames the trip again when a real path grows past
```

---

### Task 3: The setting, its button, the full-screen map and the card (design §2, §4, §5)

No tests: SwiftUI. The logic they call is Task 2's.

- [ ] **Step 1: The button.**

In `Crewluv/Views/TripMap/TripMapTopBar.swift`:

Replace:

```swift
//  Close, what's happening, recenter and map style, along the top of the full-screen map (moving map spec §6).
```

with:

```swift
//  Close, what's happening, recenter, follow the plane and map style, along the top of the full-screen map (moving map
//  spec §6, follow the plane design §2).
```

Replace:

```swift
    let isShowingRecenter: Bool
    let onClose: () -> Void
    let onRecenter: () -> Void
```

with:

```swift
    let isShowingRecenter: Bool
    let isFollowingPlane: Bool
    let onClose: () -> Void
    let onRecenter: () -> Void
    let onToggleFollow: () -> Void
```

Replace:

```swift
                    .accessibilityLabel("Recenter map")
                }
```

with:

```swift
                    .accessibilityLabel("Recenter map")
                }
                Button(action: onToggleFollow) {
                    Image(systemName: "airplane.circle")
                        .symbolVariant(isFollowingPlane ? .fill : .none)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Follow the plane")
                .accessibilityValue(isFollowingPlane ? "On" : "Off")
                .accessibilityAddTraits(.isToggle)
```

- [ ] **Step 2: The full-screen map.**

In `Crewluv/Views/TripMap/TripMapScreen.swift`:

Replace:

```swift
//  layovers, remembered for every trip, hurries a replay through the waits on the ground (activity markers design §3).
```

with:

```swift
//  layovers, remembered for every trip, hurries a replay through the waits on the ground (activity markers design §3).
//  Follow the plane, remembered too, eases the map in on the plane as a flight goes on (follow the plane design).
```

Replace:

```swift
    static let quickLayoversKey = "tripMapQuickLayovers"
```

with:

```swift
    static let quickLayoversKey = "tripMapQuickLayovers"
    /// Where Follow the plane is remembered, for this map and the card. It's off until the family turns it on (follow
    /// the plane design §2).
    static let followsPlaneKey = "tripMapFollowsPlane"
```

Replace:

```swift
    @AppStorage(TripMapScreen.quickLayoversKey) private var isQuickLayovers = true
```

with:

```swift
    @AppStorage(TripMapScreen.quickLayoversKey) private var isQuickLayovers = true
    @AppStorage(TripMapScreen.followsPlaneKey) private var followsPlane = false
```

Replace:

```swift
        _camera = State(initialValue: TripMapCamera(framing: tripMap.framingRect(focusingOn: tripMap.currentLeg),
                                                    keeping: tripMap.pilotLocation(at: clock.time(at: .now))?.coordinate))
```

with:

```swift
        let time = clock.time(at: .now)
        let framing = tripMap.framingRect(focusingOn: tripMap.currentLeg, at: time,
                                          followsPlane: UserDefaults.standard.bool(forKey: Self.followsPlaneKey),
                                          isReplay: !clock.isLive)
        _camera = State(initialValue: TripMapCamera(framing: framing, keeping: tripMap.pilotLocation(at: time)?.coordinate))
```

Replace:

```swift
                .onChange(of: tripMap.legInMotion(at: time)?.id) { _, legID in
                    refit(legID: legID, at: time)
                }
```

with:

```swift
                .onChange(of: tripMap.legInMotion(at: time)?.id) { _, legID in
                    refit(legID: legID, at: time)
                }
                .onChange(of: context.date) { follow(at: time, now: context.date) }
                // Initially too, for a store other than the standard one `init` framed from, as the previews' is.
                .onChange(of: followsPlane, initial: true) {
                    refit(legID: tripMap.legInMotion(at: time)?.id, at: time, force: true)
                }
```

Replace:

```swift
            isShowingRecenter: camera.isPositionedByUser,
            onClose: close,
            onRecenter: { refit(legID: tripMap.legInMotion(at: time)?.id, at: time, force: true) },
```

with:

```swift
            isShowingRecenter: camera.isPositionedByUser,
            isFollowingPlane: followsPlane,
            onClose: close,
            onRecenter: { refit(legID: tripMap.legInMotion(at: time)?.id, at: time, force: true) },
            onToggleFollow: { followsPlane.toggle() },
```

Replace:

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

with:

```swift
    /// Frames the leg in motion, following its plane when the family has asked, or the whole trip, keeping the pilot's
    /// ground marker at `time` in view. Leaves a camera the family moved alone, unless they asked.
    private func refit(legID: String?, at time: Date, force: Bool = false) {
        guard force || !camera.isPositionedByUser else { return }
        let leg = legID.flatMap { id in tripMap.legs.first { $0.id == id } }
        camera.frame(tripMap.framingRect(focusingOn: leg, at: time, followsPlane: followsPlane, isReplay: !clock.isLive),
                     keeping: tripMap.pilotLocation(at: time)?.coordinate, animated: !reduceMotion)
    }

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

- [ ] **Step 3: The card.**

In `Crewluv/Views/TripMap/TripMapCard.swift`:

Replace:

```swift
//  the map opens it full screen.
```

with:

```swift
//  the map opens it full screen. With Follow the plane on, it eases in on the plane as the flight goes on (follow the
//  plane design).
```

Replace:

```swift
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
```

with:

```swift
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(TripMapScreen.followsPlaneKey) private var followsPlane = false
```

Replace:

```swift
        _camera = State(initialValue: TripMapCamera(framing: tripMap.framingRect(focusingOn: tripMap.currentLeg),
                                                    keeping: tripMap.pilotLocation(at: .now)?.coordinate))
```

with:

```swift
        let framing = tripMap.framingRect(focusingOn: tripMap.currentLeg, at: .now,
                                          followsPlane: UserDefaults.standard.bool(forKey: TripMapScreen.followsPlaneKey),
                                          isReplay: false)
        _camera = State(initialValue: TripMapCamera(framing: framing, keeping: tripMap.pilotLocation(at: .now)?.coordinate))
```

Replace:

```swift
                bar(facts: facts, at: context.date)
            }
        }
```

with:

```swift
                bar(facts: facts, at: context.date)
            }
            .onChange(of: context.date) { follow(at: context.date) }
        }
```

Replace:

```swift
        .onChange(of: tripMap.mode) { refit() }
        .onChange(of: tripMap.legs.map(\.id)) { refit() }
        // A real path can grow past what the card framed (Stage 3 spec §6.2).
        .onChange(of: tripMap.framingKey(focusingOn: tripMap.currentLeg)) { refit() }
```

with:

```swift
        .onChange(of: tripMap.mode) { refit() }
        .onChange(of: tripMap.legs.map(\.id)) { refit() }
        // Initially too, for a store other than the standard one `init` framed from, as the previews' is.
        .onChange(of: followsPlane, initial: true) { refit() }
        // A real path can grow past what the card framed (Stage 3 spec §6.2). While the card follows the plane,
        // following keeps it in view.
        .onChange(of: tripMap.framingKey(focusingOn: tripMap.currentLeg)) {
            if !isFollowingPlane(at: .now) { refit() }
        }
```

Replace:

```swift
    /// Frames the leg in the air, or the whole trip, afresh when the trip's state or legs change, keeping the pilot's
    /// ground marker in view.
    private func refit() {
        camera.frame(tripMap.framingRect(focusingOn: tripMap.currentLeg),
                     keeping: tripMap.pilotLocation(at: .now)?.coordinate, animated: false)
    }
```

with:

```swift
    /// Frames the leg in the air, following its plane when the family has asked, or the whole trip, afresh when the
    /// trip's state or legs change, keeping the pilot's ground marker in view.
    private func refit() {
        camera.frame(tripMap.framingRect(focusingOn: tripMap.currentLeg, at: .now, followsPlane: followsPlane, isReplay: false),
                     keeping: tripMap.pilotLocation(at: .now)?.coordinate, animated: false)
    }

    /// Whether the card follows the flight's plane at `date`: the family asked, and it has left (follow the plane
    /// design §3).
    private func isFollowingPlane(at date: Date) -> Bool {
        guard followsPlane, let leg = tripMap.currentLeg else { return false }
        return TripMapFollow.rect(for: leg, at: date, isReplay: false) != nil
    }

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

- [ ] **Step 4: The previews.**

In `Crewluv/Views/TripMap/TripMapPreviews.swift`:

Replace:

```swift
    static func storage(quickLayovers isOn: Bool) -> UserDefaults {
        let defaults = UserDefaults(suiteName: "TripMapPreviews.quickLayovers.\(isOn)") ?? .standard
        defaults.set(isOn, forKey: TripMapScreen.quickLayoversKey)
        return defaults
    }
```

with:

```swift
    static func storage(quickLayovers isOn: Bool, followsPlane: Bool = false) -> UserDefaults {
        let defaults = UserDefaults(suiteName: "TripMapPreviews.quickLayovers.\(isOn).follows.\(followsPlane)") ?? .standard
        defaults.set(isOn, forKey: TripMapScreen.quickLayoversKey)
        defaults.set(followsPlane, forKey: TripMapScreen.followsPlaneKey)
        return defaults
    }
```

Replace:

```swift
#Preview("Real plane, in the air") {
```

with:

```swift
#Preview("Following the plane") {
    if let map = TripMapPreviewData.europeLive(hoursIn: 6, lastSeenMinutesAgo: 0.5) {
        TripMapCard(tripMap: map, status: .demo, storyStore: LegStoryStore()).padding()
            .defaultAppStorage(TripMapPreviewData.storage(quickLayovers: true, followsPlane: true))
    }
}

#Preview("Full screen, following the plane") {
    if let map = TripMapPreviewData.europeLive(hoursIn: 6, lastSeenMinutesAgo: 0.5) {
        TripMapScreen(tripMap: map, storyStore: LegStoryStore(), dayNumber: 1, totalDays: 4)
            .defaultAppStorage(TripMapPreviewData.storage(quickLayovers: true, followsPlane: true))
    }
}

#Preview("Real plane, in the air") {
```

---

### Task 4: The docs

- [ ] **Step 1:**

In `CLAUDE.md`:

Replace:

```swift
- North stays up and the map never tilts, so `PlaneHeading` aims the plane from coordinates alone and `MapProjection` (CrewLu's `FlatMapFit`) places everything from three points the map is asked about. The camera is `TripMapCamera`: a pan, pinch or double tap makes it the family's until they recenter. `TripMapClearance` keeps the map's framing and Apple's logo clear of the facts sheet or panel, and of the card's chips, through the map's layout margins alone: MapKit fits `setVisibleMapRect` inside them, so padding the camera for the sheet or panel as well counts it twice. MapKit won't zoom out past its own limit, so a trip much wider than the map can be cut off: after each framing the camera slides the pilot's ground marker into view if it's outside the margins (`TripMapSlide`)
```

with:

```swift
- North stays up and the map never tilts, so `PlaneHeading` aims the plane from coordinates alone and `MapProjection` (CrewLu's `FlatMapFit`) places everything from three points the map is asked about. The camera is `TripMapCamera`: a pan, pinch or double tap makes it the family's until they recenter. With Follow the plane on (`@AppStorage` `tripMapFollowsPlane`, off at first, the airplane button on the full-screen map, for the card too), a flight's frame is its plane, a tail of 20% of the flight behind it and the way ahead, never under 300 miles across (`TripMapFollow`): the camera eases in on it once it's 15% smaller, at most every 5 seconds, and out at once when the plane or the destination would leave the view (follow the plane design `docs/superpowers/specs/2026-11-17-follow-the-plane-design.md`). `TripMapClearance` keeps the map's framing and Apple's logo clear of the facts sheet or panel, and of the card's chips, through the map's layout margins alone: MapKit fits `setVisibleMapRect` inside them, so padding the camera for the sheet or panel as well counts it twice. MapKit won't zoom out past its own limit, so a trip much wider than the map can be cut off: after each framing the camera slides the pilot's ground marker into view if it's outside the margins (`TripMapSlide`)
```

- [ ] **Step 2: The design's button, as built.**

In `docs/superpowers/specs/2026-11-17-follow-the-plane-design.md`:

Replace:

```swift
- **Switched on the full-screen map** by a button beside recenter: an SF Symbol such as `scope`, filled while it's on,
```

with:

```swift
- **Switched on the full-screen map** by a button beside recenter: `airplane.circle`, filled while it's on,
```

---

### Task 5: Todd's run, the commits and a look

- [ ] **Step 1: Todd runs every test of the app once:**

```bash
xcodebuild test -project Crewluv.xcodeproj -scheme Crewluv -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' 2>&1 | grep -E "error:|TEST (SUCCEEDED|FAILED)"
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 2: Ask to commit:** one commit for each of Tasks 2 and 3, then Task 4 with this plan. Then ask whether to add a line to the 1.4 (49) release note: "A new Follow the plane button on the full-screen map eases the map in on the plane as a flight goes on, on the card too. It's off until you turn it on."

- [ ] **Step 3: Todd looks** at the previews "Following the plane" and "Full screen, following the plane", and in the app with a replay: the map eases in, never in a hurry, and zooms out at once when the replay is dragged back; a pan stops it until recenter; the button turns it off and on.

## Left for later

- **Following a drive.**
- **A frame that leads the plane by its heading** on a flight that turns back on itself.
- **A flight wider than MapKit will zoom out to:** the step rule compares with the frame asked for, which MapKit may cut off there, as the whole flight's frame can be today. Reading back what MapKit shows would cover it (from the plan's review).
- **Spacing after a refit:** a recenter, the setting changing or a new leg doesn't count as a step, so a step can come within 5 seconds of one; right after a refit the frame wanted is the one shown, so it rarely does.
