# Moving Map Stage 1A (Crewluve App) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Crewluve's hand-drawn in-flight map with a trip map built on Apple's map, driven by the schedule. It shows the whole trip on the ground, the next trip from home, and the plane in the air. It opens into a full-screen map that can replay the trip.

**Architecture:**
- **Pure logic** goes in `nonisolated` value types under `Utils/` and `Services/TripMap/`, each with XCTest:
  - maths ported from CrewLu's moving map (`NightShade`, `PlaneHeading`, a date-line camera fit, the subsolar point);
  - the schedule's plane (`FlightProgress`);
  - the trip model (`TripMap`, `MapLeg`) and what to draw at an instant (`TripMapDrawing`);
  - the replay clock;
  - the wording.
- **Views** go in `Views/TripMap/` and only render what the logic says. They use SwiftUI's `Map` with `MapPolyline`, `MapPolygon` and `Annotation`: no `UIViewRepresentable`, no private MapKit views.
- **Status screen:** in flight, the card takes the location card's place. On the ground, it sits above the location card.

**Tech Stack:** Swift 5 language mode, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` in the app target (not in the test target), iOS 26 deployment target, SwiftUI, MapKit for SwiftUI, XCTest.

**Spec:** `docs/superpowers/specs/2026-11-13-crewluve-moving-map-design.md`. This plan is Stage 1 for the app (§4): §5, §6, §7.1–§7.3, §10 and §12–§15 as they apply without facts or live data. Plan 1B covers the website and `mapkit-token`.

---

## Ground rules for whoever runs this plan

These come from Todd's standing instructions. They override the skill's defaults.

1. **Don't run `xcodebuild` build or test loops,** and don't let subagents run them. Write the code and tests. At each task's checkpoint, Todd runs the named tests in Xcode, or with the command given.
2. **Never commit without Todd's go-ahead in the conversation.** Each task ends with a suggested commit message. Ask, then commit only on a yes.
3. **After a commit that changes what families see** (Tasks 12–14), draft the "Crewluve revisions" Apple Note entry as the release-notes memory describes, and confirm the version with Todd.
4. **New files join the app target on their own.** The `Crewluv/` folder is a synchronized folder. Don't tick `CrewluveAlerts` on any new file: the helper doesn't use the map.
5. **Mark pure types `nonisolated`** (`nonisolated enum` / `nonisolated struct`), as `SolarPosition` and `TripLeg` already are. The app target defaults to the main actor, and the test target doesn't.
6. **Tests use XCTest,** with names in the form `test_<methodOrBehavior>_<scenario>_<expectedResult>()` and `XCTAssertEqual` over `XCTAssertTrue`.

Test command for Todd, with one class per checkpoint:

```bash
xcodebuild test -project Crewluv.xcodeproj -scheme Crewluv -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:CrewluvTests/<TestClass>
```

## File map

| File | Status | Responsibility |
|---|---|---|
| `Crewluv/Utils/SolarPosition.swift` | modify | add `subsolarPoint(at:)`; make `altitude` internal |
| `Crewluv/Utils/GreatCircle.swift` | create | distances and points along the shortest path |
| `Crewluv/Utils/NightShade.swift` | create | night as fillable shapes (port from CrewLu) |
| `Crewluv/Utils/PlaneHeading.swift` | create | which way the plane points (slim port) |
| `Crewluv/Utils/MapFit.swift` | create | camera rectangle, taken the short way across the date line |
| `Crewluv/Services/TripMap/FlightProgress.swift` | create | the schedule's plane: taxi allowances and fraction along the route |
| `Crewluv/Services/TripMap/AirportMark.swift` | create | an airport on the map |
| `Crewluv/Services/TripMap/MapLeg.swift` | create | one drawable flight or drive |
| `Crewluv/Services/TripMap/TripMap.swift` | create | the trip's legs, the mode, home, and where the pilot is |
| `Crewluv/Services/TripMap/TripMap+Status.swift` | create | picks the legs from `SharedPilotStatus` |
| `Crewluv/Services/TripMap/TripMapDrawing.swift` | create | the lines, airports, cars, plane and pin at an instant |
| `Crewluv/Services/TripMap/NightBand.swift` | create | night shapes with stable ids, for `ForEach` |
| `Crewluv/Services/TripMap/TripReplayClock.swift` | create | live, scrubbed or playing time |
| `Crewluv/Services/TripMap/TripMapWording.swift` | create | every sentence the map shows or speaks |
| `Crewluv/Views/TripMap/TripMapStyle.swift` | create | hybrid, standard, imagery |
| `Crewluv/Views/TripMap/TripMapPalette.swift` | create | line colours and strokes per map style |
| `Crewluv/Views/TripMap/TripMapMarkers.swift` | create | airport dot, heart pin, car |
| `Crewluv/Views/TripMap/PlaneMarker.swift` | create | the schedule's plane, turning the short way |
| `Crewluv/Views/TripMap/TripMapChip.swift` | create | a glass chip on the map |
| `Crewluv/Views/TripMap/TripMapView.swift` | create | the SwiftUI `Map` and its content |
| `Crewluv/Views/TripMap/TripMap+Camera.swift` | create | the camera for a leg or the whole trip |
| `Crewluv/Views/TripMap/TripMapCard.swift` | create | the status screen's card |
| `Crewluv/Views/TripMap/TripMapInFlightBar.swift` | create | flight number, landing time |
| `Crewluv/Views/TripMap/TripMapStatsBar.swift` | create | the day, cities and miles |
| `Crewluv/Views/TripMap/TripMapScreen.swift` | create | the full-screen map |
| `Crewluv/Views/TripMap/TripMapTopBar.swift` | create | close, pill, recenter, style |
| `Crewluv/Views/TripMap/TripMapPanel.swift` | create | the headline and the timeline |
| `Crewluv/Views/TripMap/TripTimelineControl.swift` | create | play, slider, Live, speed |
| `Crewluv/Views/TripMap/TripMapPreviews.swift` | create | DEBUG previews of every state |
| `Crewluv/Views/Status/FlightDelayBanner.swift` | create | the delay banner, moved out of `LocationCardView` |
| `Crewluv/Views/Status/RouteFallbackView.swift` | create | "SDF → CGN" when an airport is unknown |
| `Crewluv/Views/Status/PilotStatusView.swift` | modify | place the card; the location card's in-flight view uses the new pieces |
| `Crewluv/Views/Status/FlightRouteMapView.swift` | delete | replaced |
| `Crewluv/Utils/AirportDataProvider.swift` | modify | doc comment only |
| `CrewluvTests/Fixtures/TripMap/progress-cases.json` | create | shared schedule cases (plan 1B copies them) |
| `CrewluvTests/Helpers/TripMapFixtures.swift` | create | reads the cases file |
| `CrewluvTests/Helpers/TripMapTestLegs.swift` | create | sample airports and legs |
| `CrewluvTests/*Tests.swift` | create or modify | one class per type above |
| `CLAUDE.md` | modify | the trip map in Key Components and File Structure |

---

### Task 1: The branch

**Files:** none.

- [ ] **Step 1: Branch from the current tip.**
  - `feature/alert-pushes` is 113 commits ahead of `main` and holds 1.3.3, so it's the base.
  - Run:

```bash
git -C /Users/toddanderson/Dev/Crewluv switch -c feature/trip-map
```

  - Expected: `Switched to a new branch 'feature/trip-map'`.

---

### Task 2: The subsolar point in `SolarPosition`

The night shading needs the point with the sun straight overhead. Stage 2 needs the sun's altitude anywhere. Crewluve's `SolarPosition` already works both out inside `altitude`; this task splits them out without changing any answer.

**Files:**
- Modify: `Crewluv/Utils/SolarPosition.swift`
- Test: `CrewluvTests/SolarPositionTests.swift` (add tests at the end of the class)

- [ ] **Step 1: Write the failing tests.** Add inside `final class SolarPositionTests`, before its closing brace:

```swift
    // MARK: - The subsolar point (moving map spec §7.1, the night shading)

    private func utcDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    func test_subsolarPoint_atTheJuneSolstice_isOverTheTropicOfCancer() {
        let sun = SolarPosition.subsolarPoint(at: utcDate(2026, 6, 21, 8, 24))
        XCTAssertEqual(sun.declination * 180 / .pi, 23.44, accuracy: 0.05)
    }

    func test_subsolarPoint_atTheMarchEquinox_isOverTheEquator() {
        let sun = SolarPosition.subsolarPoint(at: utcDate(2026, 3, 20, 14, 46))
        XCTAssertEqual(sun.declination * 180 / .pi, 0, accuracy: 0.05)
    }

    /// In mid-October the sun runs about 14 minutes ahead of the clock, so at noon UTC it has already passed Greenwich.
    func test_subsolarPoint_atNoonUTCInMidOctober_isAFewDegreesWestOfGreenwich() {
        let sun = SolarPosition.subsolarPoint(at: utcDate(2026, 10, 15, 12, 0))
        XCTAssertEqual(sun.longitude, -3.55, accuracy: 0.2)
    }

    func test_subsolarPoint_longitude_staysWithinTheMap() {
        let start = utcDate(2026, 1, 1, 0, 0)
        for hours in stride(from: 0, to: 24 * 365, by: 7) {
            let longitude = SolarPosition.subsolarPoint(at: start.addingTimeInterval(Double(hours) * 3600)).longitude
            XCTAssertLessThanOrEqual(abs(longitude), 180)
        }
    }

    func test_altitude_underTheSubsolarPoint_isStraightUp() {
        let date = utcDate(2026, 11, 13, 17, 0)
        let sun = SolarPosition.subsolarPoint(at: date)
        let altitude = SolarPosition.altitude(latitude: sun.declination * 180 / .pi, longitude: sun.longitude, at: date)
        XCTAssertEqual(altitude, 90, accuracy: 0.01)
    }
```

- [ ] **Step 2: Implement.** In `Crewluv/Utils/SolarPosition.swift`, replace everything from the line `    /// The altitude of the sun's center above the horizon, in degrees.` down to just before `    private static func radians` with:

```swift
    /// The point on the earth with the sun straight overhead at `date`: its
    /// latitude (the sun's declination) in radians, and its longitude in
    /// degrees, positive east, within -180...180.
    static func subsolarPoint(at date: Date) -> (declination: Double, longitude: Double) {
        let days = date.timeIntervalSince(j2000) / 86_400
        let meanLongitude = 280.460 + 0.9856474 * days
        let meanAnomaly = radians(357.528 + 0.9856003 * days)
        let eclipticLongitude = radians(meanLongitude + 1.915 * sin(meanAnomaly) + 0.020 * sin(2 * meanAnomaly))
        let obliquity = radians(23.439 - 0.0000004 * days)

        let declination = asin(sin(obliquity) * sin(eclipticLongitude))
        let rightAscension = degrees(atan2(cos(obliquity) * sin(eclipticLongitude), cos(eclipticLongitude)))

        // Apparent minus mean solar time: how far the real sun runs ahead of
        // or behind clock time, between about −14 and +16 minutes in a year.
        let equationOfTimeMinutes = 4 * (meanLongitude - rightAscension).remainder(dividingBy: 360)

        // The sun crosses Greenwich near 12:00 UTC and moves west 15° an hour.
        let utcHours = date.timeIntervalSince1970.truncatingRemainder(dividingBy: 86_400) / 3_600
        let longitude = (-15 * (utcHours - 12) - equationOfTimeMinutes / 4).remainder(dividingBy: 360)
        return (declination, longitude)
    }

    /// The altitude of the sun's center above the horizon, in degrees: negative below it.
    static func altitude(latitude: Double, longitude: Double, at date: Date) -> Double {
        let sun = subsolarPoint(at: date)
        let hourAngle = radians(longitude - sun.longitude)
        let latitudeRadians = radians(latitude)
        let sineOfAltitude = sin(latitudeRadians) * sin(sun.declination)
            + cos(latitudeRadians) * cos(sun.declination) * cos(hourAngle)
        return degrees(asin(sineOfAltitude))
    }

```

Also change the file's header comment (lines 5–6) to:

```swift
//  Where the sun is: whether it's up at a place, its height there, and the
//  point it's straight above, for the trip map's night shading.
```

- [ ] **Step 3: Checkpoint (Todd).** Run `-only-testing:CrewluvTests/SolarPositionTests`.
  - Expected: all pass, the existing USNO sunrise and sunset tests included. Only the subsolar longitude's range changed, and `cos(hourAngle)` doesn't see whole turns.

- [ ] **Step 4: Ask to commit.** Suggested message: `feat(crewluv): the sun's subsolar point, for the trip map's night (moving map spec §7.1)`

---

### Task 3: `GreatCircle`

**Files:**
- Create: `Crewluv/Utils/GreatCircle.swift`
- Test: `CrewluvTests/GreatCircleTests.swift`

- [ ] **Step 1: Write the failing tests.** Create `CrewluvTests/GreatCircleTests.swift`:

```swift
//
//  GreatCircleTests.swift
//  CrewluvTests
//
//  Distances and points along the shortest path (moving map spec §7.1). Expected values were worked out
//  independently with the same sphere (radius 6,371,008.8 m).
//

import XCTest
import CoreLocation
@testable import Crewluv

final class GreatCircleTests: XCTestCase {

    private let jfk = CLLocationCoordinate2D(latitude: 40.6413, longitude: -73.7781)
    private let lhr = CLLocationCoordinate2D(latitude: 51.4700, longitude: -0.4543)
    private let anc = CLLocationCoordinate2D(latitude: 61.1743, longitude: -149.9963)
    private let nrt = CLLocationCoordinate2D(latitude: 35.7720, longitude: 140.3929)

    func test_distance_newYorkToLondon_isAbout5540Kilometers() {
        XCTAssertEqual(GreatCircle.distance(from: jfk, to: lhr) / 1000, 5540.02, accuracy: 0.05)
    }

    func test_distance_isTheSameBothWays() {
        XCTAssertEqual(GreatCircle.distance(from: jfk, to: lhr), GreatCircle.distance(from: lhr, to: jfk), accuracy: 0.001)
    }

    func test_distance_samePlace_isZero() {
        XCTAssertEqual(GreatCircle.distance(from: jfk, to: jfk), 0, accuracy: 0.000_001)
    }

    func test_point_atTheEnds_isTheAirports() {
        let start = GreatCircle.point(from: jfk, to: lhr, fraction: 0)
        let end = GreatCircle.point(from: jfk, to: lhr, fraction: 1)
        XCTAssertEqual(start.latitude, jfk.latitude, accuracy: 1e-9)
        XCTAssertEqual(start.longitude, jfk.longitude, accuracy: 1e-9)
        XCTAssertEqual(end.latitude, lhr.latitude, accuracy: 1e-9)
        XCTAssertEqual(end.longitude, lhr.longitude, accuracy: 1e-9)
    }

    func test_point_halfwayToLondon_curvesNorthOverTheAtlantic() {
        let middle = GreatCircle.point(from: jfk, to: lhr, fraction: 0.5)
        XCTAssertEqual(middle.latitude, 52.2167, accuracy: 0.001)
        XCTAssertEqual(middle.longitude, -41.3027, accuracy: 0.001)
    }

    func test_point_outsideTheLeg_isHeldAtTheEnds() {
        let before = GreatCircle.point(from: jfk, to: lhr, fraction: -0.5)
        let after = GreatCircle.point(from: jfk, to: lhr, fraction: 1.5)
        XCTAssertEqual(before.latitude, jfk.latitude, accuracy: 1e-9)
        XCTAssertEqual(after.longitude, lhr.longitude, accuracy: 1e-9)
    }

    func test_point_anchorageToTokyo_crossesTheDateLineTheShortWay() {
        let middle = GreatCircle.point(from: anc, to: nrt, fraction: 0.5)
        XCTAssertEqual(middle.latitude, 53.557, accuracy: 0.001)
        XCTAssertEqual(middle.longitude, 165.165, accuracy: 0.001)
    }

    func test_point_samePlace_isThatPlace() {
        let point = GreatCircle.point(from: jfk, to: jfk, fraction: 0.5)
        XCTAssertEqual(point.latitude, jfk.latitude, accuracy: 1e-9)
        XCTAssertEqual(point.longitude, jfk.longitude, accuracy: 1e-9)
    }

    func test_points_giveTheCountAsked_withBothEnds() {
        let points = GreatCircle.points(from: jfk, to: lhr, count: 33)
        XCTAssertEqual(points.count, 33)
        XCTAssertEqual(points[0].latitude, jfk.latitude, accuracy: 1e-9)
        XCTAssertEqual(points[32].longitude, lhr.longitude, accuracy: 1e-9)
    }

    func test_points_fewerThanTwo_giveTheTwoEnds() {
        XCTAssertEqual(GreatCircle.points(from: jfk, to: lhr, count: 1).count, 2)
    }
}
```

- [ ] **Step 2: Implement.** Create `Crewluv/Utils/GreatCircle.swift`:

```swift
//
//  GreatCircle.swift
//  CrewLuve
//
//  The shortest path between two places, for the trip map's routes and planes (moving map spec §7.1).
//

import CoreLocation

/// The earth as a sphere: distances along it, and places part way along the shortest path between two others.
nonisolated enum GreatCircle {

    /// The earth's mean radius, in meters.
    static let earthRadius: Double = 6_371_008.8

    /// One statute mile, in meters. Families think in miles (moving map spec §8.3).
    static let metersPerMile: Double = 1_609.344

    /// The distance between two places along the earth's surface, in meters.
    static func distance(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> Double {
        earthRadius * centralAngle(from: start, to: end)
    }

    /// The place `fraction` of the way from `start` to `end`. A fraction outside 0...1 is held at the nearer end.
    /// Two places on exactly opposite sides of the earth have no single shortest path; no leg is ever that long.
    static func point(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, fraction: Double) -> CLLocationCoordinate2D {
        let share = min(max(fraction, 0), 1)
        let angle = centralAngle(from: start, to: end)
        guard angle > 1e-9 else { return start }
        let weightOfStart = sin((1 - share) * angle) / sin(angle)
        let weightOfEnd = sin(share * angle) / sin(angle)
        let a = vector(start)
        let b = vector(end)
        let x = weightOfStart * a.x + weightOfEnd * b.x
        let y = weightOfStart * a.y + weightOfEnd * b.y
        let z = weightOfStart * a.z + weightOfEnd * b.z
        return CLLocationCoordinate2D(latitude: degrees(atan2(z, (x * x + y * y).squareRoot())),
                                      longitude: degrees(atan2(y, x)))
    }

    /// `count` evenly spaced places from `start` to `end`, both ends included. Never fewer than two.
    static func points(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, count: Int) -> [CLLocationCoordinate2D] {
        let total = max(count, 2)
        return (0..<total).map { point(from: start, to: end, fraction: Double($0) / Double(total - 1)) }
    }

    // MARK: - Private

    /// The angle between two places seen from the earth's centre, in radians. The haversine form stays exact for
    /// short hops, where the cosine form loses digits.
    private static func centralAngle(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> Double {
        let startLatitude = radians(start.latitude)
        let endLatitude = radians(end.latitude)
        let latitudeChange = endLatitude - startLatitude
        let longitudeChange = radians(end.longitude - start.longitude)
        let haversine = sin(latitudeChange / 2) * sin(latitudeChange / 2)
            + cos(startLatitude) * cos(endLatitude) * sin(longitudeChange / 2) * sin(longitudeChange / 2)
        return 2 * asin(min(1, haversine.squareRoot()))
    }

    private static func vector(_ coordinate: CLLocationCoordinate2D) -> (x: Double, y: Double, z: Double) {
        let latitude = radians(coordinate.latitude)
        let longitude = radians(coordinate.longitude)
        return (cos(latitude) * cos(longitude), cos(latitude) * sin(longitude), sin(latitude))
    }

    private static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }

    private static func degrees(_ radians: Double) -> Double { radians * 180 / .pi }
}
```

- [ ] **Step 3: Checkpoint (Todd).** Run `-only-testing:CrewluvTests/GreatCircleTests`. Expected: all pass.

- [ ] **Step 4: Ask to commit.** Suggested message: `feat(crewluv): great-circle distances and points, for the trip map (moving map spec §7.1)`

---

### Task 4: `NightShade`, ported from CrewLu

This is a straight port of `Duty/Duty/Utils/NightShade.swift` (spec 2026-11-10-moving-map-one-sun-design, CrewLu repo). Its tests come along, run against Crewluve's own `SolarPosition`.

**Files:**
- Create: `Crewluv/Utils/NightShade.swift`
- Test: `CrewluvTests/NightShadeTests.swift`

- [ ] **Step 1: Write the failing tests.** Create `CrewluvTests/NightShadeTests.swift`:

```swift
//
//  NightShadeTests.swift
//  CrewluvTests
//
//  The trip map's night shapes (moving map spec §7.1), ported with NightShade from CrewLu's moving map.
//  Every expected value comes from SolarPosition at test time: the tests fill each shape the way a flat
//  map does and check that against where the sun really is.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class NightShadeTests: XCTestCase {

    // MARK: - Helpers

    private func utc(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    /// Both equinoxes, both solstices and three dates between.
    private let dates = [(2026, 3, 20), (2026, 6, 21), (2026, 9, 23), (2026, 11, 15), (2026, 12, 21), (2026, 2, 10), (2026, 5, 1)]

    /// How far north a latitude sits on a flat (Mercator) map. Kept here on purpose, so the tests fill the shapes
    /// the way the map does without leaning on code under test.
    private func flatMapY(_ latitude: Double) -> Double {
        log(tan(.pi / 4 + latitude * .pi / 360))
    }

    /// A set of shapes, ready to be asked "is this place shaded?" the way a flat map fills them.
    private struct FlatShapes {
        private var edges: [(ya: Double, xa: Double, yb: Double, xb: Double)] = []

        init(_ shapes: [[CLLocationCoordinate2D]], flatMapY: (Double) -> Double) {
            for shape in shapes {
                let ys = shape.map { flatMapY($0.latitude) }
                for index in shape.indices {
                    let next = (index + 1) % shape.count
                    edges.append((ys[index], shape[index].longitude, ys[next], shape[next].longitude))
                }
            }
        }

        /// Where the shapes' edges cross one line of latitude, west to east.
        func crossings(atY y: Double) -> [Double] {
            edges.filter { ($0.ya > y) != ($0.yb > y) }
                .map { $0.xa + (y - $0.ya) / ($0.yb - $0.ya) * ($0.xb - $0.xa) }
                .sorted()
        }
    }

    /// A place is inside when an odd number of edges lie to its east.
    private func isShaded(longitude: Double, crossings: [Double]) -> Bool {
        crossings.filter { $0 > longitude }.count % 2 == 1
    }

    private func isShaded(latitude: Double, longitude: Double, in shapes: [[CLLocationCoordinate2D]]) -> Bool {
        let flat = FlatShapes(shapes, flatMapY: flatMapY)
        return isShaded(longitude: longitude, crossings: flat.crossings(atY: flatMapY(latitude)))
    }

    private func night(at date: Date) -> [[CLLocationCoordinate2D]] {
        let sun = SolarPosition.subsolarPoint(at: date)
        return NightShade.region(sunDepth: 0, declination: sun.declination, subsolarLongitude: sun.longitude)
    }

    // MARK: - Against the true sun

    /// Seven dates, every hour, every layer: a place is inside the shape exactly when the sun is lower than that
    /// layer's depth. Places within 0.3 degrees of the edge are skipped, because the shape is drawn from points.
    func test_region_everyLayerEveryHourOfSevenDates_matchesTheSun() {
        let latitudes = stride(from: -84.0, to: 84.0, by: 6.0).map { $0 + 0.37 }
        let longitudes = stride(from: -180.0, to: 180.0, by: 6.0).map { $0 + 0.41 }
        var checked = 0
        var wrong = 0
        for (year, month, day) in dates {
            for hour in 0..<24 {
                let date = utc(year, month, day, hour, 17)
                let sun = SolarPosition.subsolarPoint(at: date)
                for depth in NightShade.sunDepths {
                    let flat = FlatShapes(NightShade.region(sunDepth: depth, declination: sun.declination, subsolarLongitude: sun.longitude),
                                          flatMapY: flatMapY)
                    for latitude in latitudes {
                        let crossings = flat.crossings(atY: flatMapY(latitude))
                        for longitude in longitudes {
                            let altitude = SolarPosition.altitude(latitude: latitude, longitude: longitude, at: date)
                            if abs(altitude + depth) < 0.3 { continue }
                            checked += 1
                            if isShaded(longitude: longitude, crossings: crossings) != (altitude < -depth) { wrong += 1 }
                        }
                    }
                }
            }
        }
        XCTAssertGreaterThan(checked, 1_500_000, "the loops ran")
        XCTAssertEqual(wrong, 0, "\(wrong) of \(checked) places were shaded on the wrong side of the edge")
    }

    // MARK: - Inside the map

    func test_layers_everyPoint_staysInsideTheMapAndNoEdgeCrossesTheDateLine() {
        for (year, month, day) in dates {
            for hour in 0..<24 {
                let layers = NightShade.layers(at: utc(year, month, day, hour, 17))
                XCTAssertEqual(layers.count, NightShade.sunDepths.count)
                for shapes in layers {
                    XCTAssertTrue(shapes.count == 1 || shapes.count == 2)
                    for shape in shapes {
                        XCTAssertGreaterThanOrEqual(shape.count, 3)
                        for index in shape.indices {
                            let point = shape[index]
                            let next = shape[(index + 1) % shape.count]
                            XCTAssertTrue(point.latitude.isFinite && point.longitude.isFinite)
                            XCTAssertLessThanOrEqual(abs(point.latitude), NightShade.maxLatitude)
                            XCTAssertLessThanOrEqual(abs(point.longitude), 180)
                            XCTAssertLessThan(abs(next.longitude - point.longitude), 180)
                        }
                    }
                }
            }
        }
    }

    // MARK: - The poles

    func test_region_polarNight_isShadedAllTheWayRound() {
        let december = night(at: utc(2026, 12, 21, 12))
        let june = night(at: utc(2026, 6, 21, 12))
        for longitude in stride(from: -179.5, to: 180.0, by: 30.0) {
            XCTAssertTrue(isShaded(latitude: 80, longitude: longitude, in: december), "80N at \(longitude) in December")
            XCTAssertFalse(isShaded(latitude: -80, longitude: longitude, in: december), "80S at \(longitude) in December")
            XCTAssertTrue(isShaded(latitude: -80, longitude: longitude, in: june), "80S at \(longitude) in June")
            XCTAssertFalse(isShaded(latitude: 80, longitude: longitude, in: june), "80N at \(longitude) in June")
        }
    }

    // MARK: - The sun exactly over the equator

    func test_region_sunOverTheEquator_shadesTheFarHalf() {
        let shapes = NightShade.region(sunDepth: 0, declination: 0, subsolarLongitude: 0)
        XCTAssertEqual(shapes.count, 1)
        XCTAssertTrue(isShaded(latitude: 10, longitude: 179, in: shapes))
        XCTAssertTrue(isShaded(latitude: 10, longitude: -179, in: shapes))
        XCTAssertTrue(isShaded(latitude: 10, longitude: 95, in: shapes))
        XCTAssertFalse(isShaded(latitude: 10, longitude: 0, in: shapes))
        XCTAssertFalse(isShaded(latitude: 10, longitude: 85, in: shapes))

        // Half the earth by area: each place counts for the width of its line of latitude.
        let flat = FlatShapes(shapes, flatMapY: flatMapY)
        var shaded = 0.0
        var all = 0.0
        for latitude in stride(from: -84.0, to: 84.0, by: 4.0).map({ $0 + 0.37 }) {
            let crossings = flat.crossings(atY: flatMapY(latitude))
            let weight = cos(latitude * .pi / 180)
            for longitude in stride(from: -180.0, to: 180.0, by: 4.0).map({ $0 + 0.41 }) {
                all += weight
                if isShaded(longitude: longitude, crossings: crossings) { shaded += weight }
            }
        }
        XCTAssertEqual(shaded / all, 0.5, accuracy: 0.01)
    }

    // MARK: - Nesting

    /// Each layer lies inside the one before it, so stacking them only ever darkens towards full night.
    func test_layers_eachDeeperLayer_liesInsideTheOneBefore() {
        let latitudes = stride(from: -84.0, to: 84.0, by: 7.0).map { $0 + 0.37 }
        let longitudes = stride(from: -180.0, to: 180.0, by: 7.0).map { $0 + 0.41 }
        for date in [utc(2026, 3, 20, 9, 17), utc(2026, 6, 21, 3, 17), utc(2026, 11, 15, 13, 51), utc(2026, 12, 21, 22, 17)] {
            let rowsByLatitude = latitudes.map { latitude in
                NightShade.layers(at: date).map { FlatShapes($0, flatMapY: flatMapY).crossings(atY: flatMapY(latitude)) }
            }
            for (row, latitude) in zip(rowsByLatitude, latitudes) {
                for longitude in longitudes {
                    for deeper in 1..<row.count where isShaded(longitude: longitude, crossings: row[deeper]) {
                        XCTAssertTrue(isShaded(longitude: longitude, crossings: row[deeper - 1]),
                                      "layer \(deeper) reaches outside layer \(deeper - 1) at \(latitude), \(longitude)")
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Implement.** Create `Crewluv/Utils/NightShade.swift`. Copy `Duty/Duty/Utils/NightShade.swift` verbatim with three changes:
  - the header names Crewluve and this spec;
  - the enum is `nonisolated`;
  - the one comment that names `FlightMapUIView` now names `TripMapView`.

  The full file:

```swift
//
//  NightShade.swift
//  CrewLuve
//
//  Where it is night on a flat map, as shapes MapKit can fill (moving map spec §7.1). Ported from CrewLu's moving
//  map (Duty/Duty/Utils/NightShade.swift). Pure: no MapKit and no views. `TripMapView` fills each shape.
//
//  The dark area for a given sun height is everything within a set distance of the point on earth directly
//  opposite the sun. On any one line of longitude that area is a single stretch of latitude, so each shape is
//  built one line of longitude at a time and no edge ever crosses the date line.
//

import Foundation
import CoreLocation

nonisolated enum NightShade {
    /// How far below the horizon the sun is at the edge of each layer, in degrees: sunset through the end of
    /// astronomical twilight. Stacked, the layers make the night's soft edge.
    static let sunDepths: [Double] = [0, 3, 6, 9, 12, 15, 18]

    /// The opacity of one layer. Seven stacked reach 42%.
    static let layerAlpha: Double = 0.075

    /// MapKit's flat map ends at this latitude, north and south.
    static let maxLatitude: Double = 85.05

    /// One layer per entry in `sunDepths` for the sun's position at `date`. Each layer is one or two closed shapes.
    static func layers(at date: Date) -> [[[CLLocationCoordinate2D]]] {
        let sun = SolarPosition.subsolarPoint(at: date)
        return sunDepths.map {
            region(sunDepth: $0, declination: sun.declination, subsolarLongitude: sun.longitude)
        }
    }

    /// The area where the sun is more than `sunDepth` degrees below the horizon, as one or two closed shapes.
    /// `declination` is in radians and `subsolarLongitude` in degrees, as `SolarPosition.subsolarPoint` gives them.
    /// Every longitude is within -180...180 and every latitude within `maxLatitude`. Edges are drawn between points
    /// up to 1 degree of longitude apart, so close to an equinox, when the sunset line runs almost straight north
    /// to south, it can sit up to that far out.
    static func region(sunDepth: Double, declination: Double, subsolarLongitude: Double) -> [[CLLocationCoordinate2D]] {
        // The middle of the dark area is the point opposite the sun.
        let centerLatitude = -declination
        var centerLongitude = subsolarLongitude + 180
        while centerLongitude >= 180 { centerLongitude -= 360 }
        while centerLongitude < -180 { centerLongitude += 360 }
        // The cosine of the dark area's radius. Zero at sunset, when the area is exactly half the earth.
        let reach = sin(sunDepth * .pi / 180)

        func shape(longitudes: [Double], shiftedBy shift: Double) -> [CLLocationCoordinate2D] {
            let stretches = longitudes.map { longitude in
                (longitude: longitude + shift,
                 stretch: darkStretch(centerLatitude: centerLatitude, centerLongitude: centerLongitude, reach: reach, longitude: longitude))
            }
            let northEdge = stretches.map { CLLocationCoordinate2D(latitude: $0.stretch.north, longitude: $0.longitude) }
            let southEdge = stretches.reversed().map { CLLocationCoordinate2D(latitude: $0.stretch.south, longitude: $0.longitude) }
            return northEdge + southEdge
        }

        // The dark area reaches a pole: every line of longitude has a stretch, so the shape spans the whole map.
        if abs(sin(centerLatitude)) >= reach {
            return [shape(longitudes: (0...360).map { -180 + Double($0) }, shiftedBy: 0)]
        }

        // Otherwise it is a rounded blob. Its lines of longitude crowd together towards the two ends, where the
        // edge turns steeply, so the ends stay round.
        let squeeze = (reach * reach - sin(centerLatitude) * sin(centerLatitude)) / (cos(centerLatitude) * cos(centerLatitude))
        let halfWidth = acos(min(1, max(0, squeeze)).squareRoot()) * 180 / .pi
        let longitudes = stride(from: -90.0, through: 90.0, by: 2.0).map {
            centerLongitude + halfWidth * sin($0 * .pi / 180)
        }
        // A blob over the date line is cut there into two shapes, each with an exact edge on the line. A blob is
        // never more than 180 degrees wide, so it can pass the line at one end only: at most one of these runs.
        if let last = longitudes.last, last > 180 {
            return [shape(longitudes: longitudes.filter { $0 < 180 } + [180], shiftedBy: 0),
                    shape(longitudes: [180] + longitudes.filter { $0 > 180 }, shiftedBy: -360)]
        }
        if let first = longitudes.first, first < -180 {
            return [shape(longitudes: longitudes.filter { $0 < -180 } + [-180], shiftedBy: 360),
                    shape(longitudes: [-180] + longitudes.filter { $0 > -180 }, shiftedBy: 0)]
        }
        return [shape(longitudes: longitudes, shiftedBy: 0)]
    }

    /// The dark stretch of one line of longitude, as its south and north ends in degrees. A stretch that lies
    /// wholly beyond the map's edge comes back with both ends on that edge, and the line at the very tip of a blob
    /// comes back as a single point. Either way it adds no area.
    private static func darkStretch(centerLatitude: Double, centerLongitude: Double, reach: Double, longitude: Double) -> (south: Double, north: Double) {
        let a = sin(centerLatitude)
        let b = cos(centerLatitude) * cos((longitude - centerLongitude) * .pi / 180)
        let size = max((a * a + b * b).squareRoot(), 1e-12)
        let middle = atan2(a, b) * 180 / .pi
        let halfHeight = acos(min(1, max(-1, reach / size))) * 180 / .pi
        let south = min(max(middle - halfHeight, -maxLatitude), maxLatitude)
        let north = max(min(middle + halfHeight, maxLatitude), -maxLatitude)
        return (south, north)
    }
}
```

- [ ] **Step 3: Checkpoint (Todd).** Run `-only-testing:CrewluvTests/NightShadeTests`.
  - Expected: all pass. The first test checks about two million places and takes several seconds.

- [ ] **Step 4: Ask to commit.** Suggested message: `feat(crewluv): night as map shapes, ported from CrewLu's moving map (moving map spec §7.1)`

---

### Task 5: `PlaneHeading`, the parts a north-up map needs

CrewLu's version asks MapKit for screen points because its map can rotate. The trip map can't rotate: it allows pan and zoom only. So the angle comes from the coordinates, and this port keeps only those parts.

**Files:**
- Create: `Crewluv/Utils/PlaneHeading.swift`
- Test: `CrewluvTests/PlaneHeadingTests.swift`

- [ ] **Step 1: Write the failing tests.** Create `CrewluvTests/PlaneHeadingTests.swift`:

```swift
//
//  PlaneHeadingTests.swift
//  CrewluvTests
//
//  Which way the trip map's plane points (moving map spec §7.2), ported from CrewLu's PlaneHeading tests.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class PlaneHeadingTests: XCTestCase {

    func test_aimFractions_midLeg_aimsJustAheadOfThePlane() {
        let aim = PlaneHeading.aimFractions(at: 0.3, lookAhead: 0.01)
        XCTAssertEqual(aim.from, 0.3, accuracy: 1e-12)
        XCTAssertEqual(aim.to, 0.31, accuracy: 1e-12)
    }

    func test_aimFractions_nearTheEnd_aimsAlongTheLastStretch() {
        let aim = PlaneHeading.aimFractions(at: 0.998, lookAhead: 0.005)
        XCTAssertEqual(aim.from, 0.995, accuracy: 1e-12)
        XCTAssertEqual(aim.to, 1, accuracy: 1e-12)
    }

    func test_aimFractions_beforeTheStart_countsAsTheStart() {
        let aim = PlaneHeading.aimFractions(at: -0.2, lookAhead: 0.005)
        XCTAssertEqual(aim.from, 0, accuracy: 1e-12)
        XCTAssertEqual(aim.to, 0.005, accuracy: 1e-12)
    }

    func test_shortestTurn_acrossDueWest_goesTheShortWayRound() {
        let degree = Double.pi / 180
        XCTAssertEqual(PlaneHeading.shortestTurn(from: 170 * degree, to: -170 * degree), 20 * degree, accuracy: 1e-9)
        XCTAssertEqual(PlaneHeading.shortestTurn(from: -170 * degree, to: 170 * degree), -20 * degree, accuracy: 1e-9)
    }

    func test_shortestTurn_anyPair_isNeverMoreThanHalfATurn() {
        for from in stride(from: -10.0, through: 10.0, by: 0.7) {
            for to in stride(from: -10.0, through: 10.0, by: 0.9) {
                XCTAssertLessThanOrEqual(abs(PlaneHeading.shortestTurn(from: from, to: to)), .pi + 1e-12)
            }
        }
    }

    func test_continuing_pastDueWest_neverSpinsTheLongWay() {
        let next = PlaneHeading.continuing(3.0, toward: -3.0)
        XCTAssertLessThanOrEqual(abs(next - 3.0), .pi)
        XCTAssertEqual(cos(next), cos(-3.0), accuracy: 1e-12)
        XCTAssertEqual(sin(next), sin(-3.0), accuracy: 1e-12)
    }

    func test_flatMapAngle_eastNorthSouth_pointRightUpDown() throws {
        let origin = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let east = try XCTUnwrap(PlaneHeading.flatMapAngle(from: origin, to: CLLocationCoordinate2D(latitude: 0, longitude: 10)))
        let north = try XCTUnwrap(PlaneHeading.flatMapAngle(from: origin, to: CLLocationCoordinate2D(latitude: 10, longitude: 0)))
        let south = try XCTUnwrap(PlaneHeading.flatMapAngle(from: origin, to: CLLocationCoordinate2D(latitude: -10, longitude: 0)))
        XCTAssertEqual(east, 0, accuracy: 1e-12)
        XCTAssertEqual(north, -.pi / 2, accuracy: 1e-12)
        XCTAssertEqual(south, .pi / 2, accuracy: 1e-12)
    }

    func test_flatMapAngle_acrossTheDateLine_matchesTheSameLegElsewhere() throws {
        let acrossLine = try XCTUnwrap(PlaneHeading.flatMapAngle(from: CLLocationCoordinate2D(latitude: 50, longitude: 179),
                                                                 to: CLLocationCoordinate2D(latitude: 51, longitude: -179)))
        let elsewhere = try XCTUnwrap(PlaneHeading.flatMapAngle(from: CLLocationCoordinate2D(latitude: 50, longitude: -1),
                                                                to: CLLocationCoordinate2D(latitude: 51, longitude: 1)))
        XCTAssertEqual(acrossLine, elsewhere, accuracy: 1e-12)
    }

    func test_flatMapAngle_samePlace_givesNoAnswer() {
        let place = CLLocationCoordinate2D(latitude: 38, longitude: -85)
        XCTAssertNil(PlaneHeading.flatMapAngle(from: place, to: place))
    }

    func test_flatMapAngle_atAPole_isStillANumber() throws {
        let angle = try XCTUnwrap(PlaneHeading.flatMapAngle(from: CLLocationCoordinate2D(latitude: 90, longitude: 0),
                                                            to: CLLocationCoordinate2D(latitude: 89, longitude: 10)))
        XCTAssertTrue(angle.isFinite)
    }
}
```

- [ ] **Step 2: Implement.** Create `Crewluv/Utils/PlaneHeading.swift`:

```swift
//
//  PlaneHeading.swift
//  CrewLuve
//
//  Which way the trip map's plane points (moving map spec §7.2). Ported from CrewLu's moving map, keeping only
//  what a map that never rotates needs: its camera always faces north, so the angle comes from the coordinates
//  alone and no screen points are needed.
//
//  Angles are in radians as the screen draws them: 0 points right (east) and a quarter turn points down (south).
//  SF Symbols' "airplane" points right, so `rotationEffect(.radians(angle))` aims it.
//

import CoreLocation

nonisolated enum PlaneHeading {

    /// How far ahead along the leg the plane is aimed, as a share of the leg.
    static let lookAhead: Double = 0.005

    /// The two places on a leg to aim between when the plane is `fraction` of the way along it. Near the end of
    /// the leg there is no room ahead, so the aim is along the last stretch.
    static func aimFractions(at fraction: Double, lookAhead: Double = PlaneHeading.lookAhead) -> (from: Double, to: Double) {
        let here = min(max(fraction, 0), 1)
        if here + lookAhead <= 1 { return (here, here + lookAhead) }
        return (max(1 - lookAhead, 0), 1)
    }

    /// The smallest turn that takes the angle `from` to the angle `to`: never more than half a turn either way.
    static func shortestTurn(from: Double, to: Double) -> Double {
        var turn = (to - from).truncatingRemainder(dividingBy: 2 * .pi)
        if turn > .pi { turn -= 2 * .pi }
        if turn < -.pi { turn += 2 * .pi }
        return turn
    }

    /// The angle to show next when the plane was showing `previous` and should now point at `target`: `target`
    /// moved by whole turns to sit the short way round from `previous`, so an animated turn never spins the long way.
    static func continuing(_ previous: Double, toward target: Double) -> Double {
        previous + shortestTurn(from: previous, to: target)
    }

    /// The direction from one place to another on a flat map facing north. Nil when the two places are the same.
    static func flatMapAngle(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double? {
        var east = to.longitude - from.longitude
        if east > 180 { east -= 360 }
        if east < -180 { east += 360 }
        let dx = east * .pi / 180
        let north = flatMapY(to.latitude) - flatMapY(from.latitude)
        guard dx != 0 || north != 0 else { return nil }
        // The screen's y grows downward, so north is up the screen.
        return atan2(-north, dx)
    }

    /// How far north a latitude sits on a flat (Mercator) map, in the same units as longitude in radians. The
    /// poles are infinitely far up a flat map, so the latitude is held just short of them.
    private static func flatMapY(_ latitude: Double) -> Double {
        let held = min(max(latitude, -89.9), 89.9)
        return log(tan(.pi / 4 + held * .pi / 360))
    }
}
```

- [ ] **Step 3: Checkpoint (Todd).** Run `-only-testing:CrewluvTests/PlaneHeadingTests`. Expected: all pass.

- [ ] **Step 4: Ask to commit.** Suggested message: `feat(crewluv): which way the trip map's plane points, ported from CrewLu (moving map spec §7.2)`

---

### Task 6: `MapFit`, the camera across the date line

**Files:**
- Create: `Crewluv/Utils/MapFit.swift`
- Test: `CrewluvTests/MapFitTests.swift`

- [ ] **Step 1: Write the failing tests.** Create `CrewluvTests/MapFitTests.swift`:

```swift
//
//  MapFitTests.swift
//  CrewluvTests
//
//  The trip map camera's rectangle (moving map spec §6, §12): the short way round, and never empty.
//

import XCTest
import MapKit
@testable import Crewluv

final class MapFitTests: XCTestCase {

    private let sdf = CLLocationCoordinate2D(latitude: 38.1744, longitude: -85.7360)
    private let cgn = CLLocationCoordinate2D(latitude: 50.8659, longitude: 7.1427)
    private let anc = CLLocationCoordinate2D(latitude: 61.1743, longitude: -149.9963)
    private let nrt = CLLocationCoordinate2D(latitude: 35.7720, longitude: 140.3929)
    private let world = MKMapSize.world.width

    func test_rect_noCoordinates_isNil() {
        XCTAssertNil(MapFit.rect(enclosing: []))
    }

    func test_rect_louisvilleAndCologne_holdsBoth() throws {
        let rect = try XCTUnwrap(MapFit.rect(enclosing: [sdf, cgn]))
        XCTAssertTrue(rect.contains(MKMapPoint(sdf)))
        XCTAssertTrue(rect.contains(MKMapPoint(cgn)))
        XCTAssertFalse(rect.spans180thMeridian)
    }

    func test_rect_anchorageToTokyo_framesThePacificNotTheWorld() throws {
        let rect = try XCTUnwrap(MapFit.rect(enclosing: [anc, nrt], padding: 0.1))
        XCTAssertTrue(rect.spans180thMeridian)
        XCTAssertLessThan(rect.size.width, world / 4)
        XCTAssertTrue(rect.contains(MKMapPoint(nrt)))
        let anchorageOnTheNextWorld = MKMapPoint(x: MKMapPoint(anc).x + world, y: MKMapPoint(anc).y)
        XCTAssertTrue(rect.contains(anchorageOnTheNextWorld))
    }

    func test_rect_onePlace_isTheMinimumSize() throws {
        let rect = try XCTUnwrap(MapFit.rect(enclosing: [sdf], minimumSide: 500_000))
        XCTAssertEqual(rect.size.width, 500_000, accuracy: 0.001)
        XCTAssertEqual(rect.size.height, 500_000, accuracy: 0.001)
        XCTAssertEqual(rect.midX, MKMapPoint(sdf).x, accuracy: 0.001)
    }

    func test_rect_padding_growsEachSide() throws {
        let tight = try XCTUnwrap(MapFit.rect(enclosing: [sdf, cgn], padding: 0))
        let padded = try XCTUnwrap(MapFit.rect(enclosing: [sdf, cgn], padding: 0.25))
        XCTAssertEqual(padded.size.width, tight.size.width * 1.5, accuracy: 1)
        XCTAssertEqual(padded.midX, tight.midX, accuracy: 1)
    }

    func test_rect_nearTheMapsLeftEdge_neverStartsBelowZero() throws {
        let nearDateLineWest = CLLocationCoordinate2D(latitude: 20, longitude: -179.9)
        let rect = try XCTUnwrap(MapFit.rect(enclosing: [nearDateLineWest]))
        XCTAssertGreaterThanOrEqual(rect.minX, 0)
    }
}
```

- [ ] **Step 2: Implement.** Create `Crewluv/Utils/MapFit.swift`:

```swift
//
//  MapFit.swift
//  CrewLuve
//
//  The flat-map rectangle the trip map's camera shows (moving map spec §6, §12). A trip across the date line is
//  laid out in one piece, so Anchorage to Tokyo frames the North Pacific, not the whole world.
//

import MapKit

nonisolated enum MapFit {

    /// The smallest rectangle on the flat map that holds every coordinate, taken the short way round the world.
    /// It's grown by `padding` (a share of its width and height, on each side) and made at least `minimumSide`
    /// map points on each side. Nil for no coordinates.
    static func rect(enclosing coordinates: [CLLocationCoordinate2D], padding: Double = 0.2, minimumSide: Double = 400_000) -> MKMapRect? {
        let points = coordinates.map(MKMapPoint.init)
        let xs = points.map(\.x).sorted()
        guard let westmost = xs.first, let eastmost = xs.last,
              let minY = points.map(\.y).min(), let maxY = points.map(\.y).max() else { return nil }
        let world = MKMapSize.world.width

        // The widest empty stretch of longitude is left out of the rectangle. When it's the stretch across the date
        // line, the rectangle sits inside one copy of the world; otherwise it runs on past the map's right edge,
        // which MapKit shows as one piece.
        var gapAfter = xs.count - 1
        var widestGap = world - eastmost + westmost
        for index in 0..<(xs.count - 1) where xs[index + 1] - xs[index] > widestGap {
            widestGap = xs[index + 1] - xs[index]
            gapAfter = index
        }
        let minX = gapAfter == xs.count - 1 ? westmost : xs[gapAfter + 1]
        let maxX = gapAfter == xs.count - 1 ? eastmost : xs[gapAfter] + world

        let width = max((maxX - minX) * (1 + 2 * padding), minimumSide)
        let height = max((maxY - minY) * (1 + 2 * padding), minimumSide)
        var originX = (minX + maxX) / 2 - width / 2
        // MapKit runs a rectangle on past the right edge, not the left, so one that starts left of the date line
        // is moved a whole world east.
        if originX < 0 { originX += world }
        return MKMapRect(x: originX, y: (minY + maxY) / 2 - height / 2, width: width, height: height)
    }
}
```

- [ ] **Step 3: Checkpoint (Todd).** Run `-only-testing:CrewluvTests/MapFitTests`. Expected: all pass.

- [ ] **Step 4: Ask to commit.** Suggested message: `feat(crewluv): the trip map camera's rectangle, the short way across the date line (moving map spec §6)`

---

### Task 7: `FlightProgress` and the shared schedule cases

The schedule's plane follows the spec's §7.3. Its constants and cases live in a JSON file. Plan 1B copies the file, so the website gives the same answers.

**Files:**
- Create: `Crewluv/Services/TripMap/FlightProgress.swift`
- Create: `CrewluvTests/Fixtures/TripMap/progress-cases.json`
- Create: `CrewluvTests/Helpers/TripMapFixtures.swift`
- Test: `CrewluvTests/FlightProgressTests.swift`

- [ ] **Step 1: Write the cases file.** Create `CrewluvTests/Fixtures/TripMap/progress-cases.json`:

```json
{
  "about": "Where the schedule's plane is (Crewluve moving map spec §7.3). The app's FlightProgressTests and the website's tests both run every case. Change both copies together.",
  "constants": {
    "taxiOutMinutes": 15,
    "taxiInMinutes": 7,
    "shortestCruiseMinutes": 10
  },
  "scheduleCases": [
    { "name": "before pushback", "departure": "2026-11-13T18:00:00Z", "arrival": "2026-11-14T02:00:00Z", "at": "2026-11-13T17:50:00Z", "fraction": 0 },
    { "name": "taxiing out", "departure": "2026-11-13T18:00:00Z", "arrival": "2026-11-14T02:00:00Z", "at": "2026-11-13T18:10:00Z", "fraction": 0 },
    { "name": "wheels up", "departure": "2026-11-13T18:00:00Z", "arrival": "2026-11-14T02:00:00Z", "at": "2026-11-13T18:15:00Z", "fraction": 0 },
    { "name": "halfway through the airborne window", "departure": "2026-11-13T18:00:00Z", "arrival": "2026-11-14T02:00:00Z", "at": "2026-11-13T22:04:00Z", "fraction": 0.5 },
    { "name": "taxiing in", "departure": "2026-11-13T18:00:00Z", "arrival": "2026-11-14T02:00:00Z", "at": "2026-11-14T01:55:00Z", "fraction": 1 },
    { "name": "at the gate", "departure": "2026-11-13T18:00:00Z", "arrival": "2026-11-14T02:00:00Z", "at": "2026-11-14T02:00:00Z", "fraction": 1 },
    { "name": "an hour after", "departure": "2026-11-13T18:00:00Z", "arrival": "2026-11-14T02:00:00Z", "at": "2026-11-14T03:00:00Z", "fraction": 1 },
    { "name": "a 30-minute hop is flown gate to gate", "departure": "2026-11-13T12:00:00Z", "arrival": "2026-11-13T12:30:00Z", "at": "2026-11-13T12:15:00Z", "fraction": 0.5 },
    { "name": "a 32-minute hop is just long enough for the allowances", "departure": "2026-11-13T12:00:00Z", "arrival": "2026-11-13T12:32:00Z", "at": "2026-11-13T12:20:00Z", "fraction": 0.5 },
    { "name": "no block time, before", "departure": "2026-11-13T12:00:00Z", "arrival": "2026-11-13T12:00:00Z", "at": "2026-11-13T11:59:00Z", "fraction": 0 },
    { "name": "no block time, at", "departure": "2026-11-13T12:00:00Z", "arrival": "2026-11-13T12:00:00Z", "at": "2026-11-13T12:00:00Z", "fraction": 1 }
  ]
}
```

- [ ] **Step 2: Write the fixtures helper.** Create `CrewluvTests/Helpers/TripMapFixtures.swift`:

```swift
//
//  TripMapFixtures.swift
//  CrewluvTests
//
//  Reads Fixtures/TripMap: the trip map's shared cases, which the website runs too (moving map spec §15.1).
//

import Foundation

enum TripMapFixtures {

    /// Found beside this file on the Mac's disk, which tests on a simulator can read.
    static let folder = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "Fixtures/TripMap")

    struct ProgressCases: Decodable {
        struct Constants: Decodable {
            let taxiOutMinutes: Double
            let taxiInMinutes: Double
            let shortestCruiseMinutes: Double
        }

        struct ScheduleCase: Decodable {
            let name: String
            let departure: Date
            let arrival: Date
            let at: Date
            let fraction: Double
        }

        let constants: Constants
        let scheduleCases: [ScheduleCase]
    }

    static func progressCases() throws -> ProgressCases {
        let data = try Data(contentsOf: folder.appending(path: "progress-cases.json"))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ProgressCases.self, from: data)
    }
}
```

- [ ] **Step 3: Write the failing tests.** Create `CrewluvTests/FlightProgressTests.swift`:

```swift
//
//  FlightProgressTests.swift
//  CrewluvTests
//
//  The schedule's plane (moving map spec §7.3), held to the shared cases in Fixtures/TripMap.
//

import XCTest
@testable import Crewluv

final class FlightProgressTests: XCTestCase {

    func test_constants_matchTheSharedCases() throws {
        let constants = try TripMapFixtures.progressCases().constants
        XCTAssertEqual(FlightProgress.taxiOutAllowance, constants.taxiOutMinutes * 60)
        XCTAssertEqual(FlightProgress.taxiInAllowance, constants.taxiInMinutes * 60)
        XCTAssertEqual(FlightProgress.shortestCruise, constants.shortestCruiseMinutes * 60)
    }

    func test_scheduledFraction_everySharedCase_matches() throws {
        let cases = try TripMapFixtures.progressCases().scheduleCases
        XCTAssertFalse(cases.isEmpty)
        for scheduleCase in cases {
            let fraction = FlightProgress.scheduledFraction(departure: scheduleCase.departure, arrival: scheduleCase.arrival, at: scheduleCase.at)
            XCTAssertEqual(fraction, scheduleCase.fraction, accuracy: 1e-9, scheduleCase.name)
        }
    }

    func test_airborneWindow_longFlight_leavesRoomToTaxi() throws {
        let departure = Date(timeIntervalSince1970: 1_800_000_000)
        let window = try XCTUnwrap(FlightProgress.airborneWindow(departure: departure, arrival: departure.addingTimeInterval(8 * 3600)))
        XCTAssertEqual(window.start, departure.addingTimeInterval(15 * 60))
        XCTAssertEqual(window.end, departure.addingTimeInterval(8 * 3600 - 7 * 60))
    }

    func test_airborneWindow_arrivalBeforeDeparture_isNil() {
        let departure = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertNil(FlightProgress.airborneWindow(departure: departure, arrival: departure.addingTimeInterval(-60)))
    }
}
```

- [ ] **Step 4: Implement.** Create `Crewluv/Services/TripMap/FlightProgress.swift`:

```swift
//
//  FlightProgress.swift
//  CrewLuve
//
//  Where the schedule says a flight is (moving map spec §7.3). Stage 3 adds the live plane beside it.
//  The constants are written down in CrewluvTests/Fixtures/TripMap/progress-cases.json, which the website shares.
//

import Foundation

nonisolated enum FlightProgress {

    /// The schedule's plane waits this long at the gate before it takes off.
    static let taxiOutAllowance: TimeInterval = 15 * 60

    /// It lands this long before the scheduled gate arrival.
    static let taxiInAllowance: TimeInterval = 7 * 60

    /// A block shorter than both allowances plus this is flown from gate to gate, with no allowances.
    static let shortestCruise: TimeInterval = 10 * 60

    /// When the schedule's plane is in the air, for a flight that leaves the gate at `departure` and reaches it at
    /// `arrival` (both already moved by any delay). Nil when it arrives no later than it leaves.
    static func airborneWindow(departure: Date, arrival: Date) -> DateInterval? {
        let block = arrival.timeIntervalSince(departure)
        guard block > 0 else { return nil }
        guard block >= taxiOutAllowance + taxiInAllowance + shortestCruise else {
            return DateInterval(start: departure, end: arrival)
        }
        return DateInterval(start: departure.addingTimeInterval(taxiOutAllowance),
                            end: arrival.addingTimeInterval(-taxiInAllowance))
    }

    /// How far along its route the schedule's plane is at `date`: 0 at the departure airport, 1 at the arrival
    /// airport, at a steady speed while it's in the air.
    static func scheduledFraction(departure: Date, arrival: Date, at date: Date) -> Double {
        guard let window = airborneWindow(departure: departure, arrival: arrival) else {
            return date >= arrival ? 1 : 0
        }
        let share = date.timeIntervalSince(window.start) / window.duration
        return min(max(share, 0), 1)
    }
}
```

- [ ] **Step 5: Checkpoint (Todd).** Run `-only-testing:CrewluvTests/FlightProgressTests`. Expected: all pass.

- [ ] **Step 6: Ask to commit.** Suggested message: `feat(crewluv): the schedule's plane, with taxi allowances and shared cases (moving map spec §7.3, §15.1)`

---

### Task 8: The trip model: `AirportMark`, `MapLeg`, `TripMap`

**Files:**
- Create: `Crewluv/Services/TripMap/AirportMark.swift`
- Create: `Crewluv/Services/TripMap/MapLeg.swift`
- Create: `Crewluv/Services/TripMap/TripMap.swift`
- Create: `CrewluvTests/Helpers/TripMapTestLegs.swift`
- Test: `CrewluvTests/TripMapTests.swift`

- [ ] **Step 1: Write the test legs helper.** Create `CrewluvTests/Helpers/TripMapTestLegs.swift`:

```swift
//
//  TripMapTestLegs.swift
//  CrewluvTests
//
//  Airports and legs for the trip map's tests: Louisville to Cologne to Dubai and home, plus a drive.
//

import CoreLocation
@testable import Crewluv

enum TripMapTestLegs {

    static let airports: [String: CLLocationCoordinate2D] = [
        "SDF": CLLocationCoordinate2D(latitude: 38.1744, longitude: -85.7360),
        "LEX": CLLocationCoordinate2D(latitude: 38.0365, longitude: -84.6059),
        "CGN": CLLocationCoordinate2D(latitude: 50.8659, longitude: 7.1427),
        "DXB": CLLocationCoordinate2D(latitude: 25.2532, longitude: 55.3657),
        "ANC": CLLocationCoordinate2D(latitude: 61.1743, longitude: -149.9963),
        "NRT": CLLocationCoordinate2D(latitude: 35.7720, longitude: 140.3929),
    ]

    static func coordinate(_ code: String) -> CLLocationCoordinate2D? { airports[code] }

    /// 2026-11-13 12:00 UTC, a Friday.
    static let tripStart = Date(timeIntervalSince1970: 1_794_571_200)

    static func leg(
        _ id: String,
        _ type: TripLeg.LegType = .flight,
        from departure: String? = nil,
        to arrival: String? = nil,
        start: Date,
        hours: Double,
        flightNumber: String? = nil,
        delayMinutes: Int? = nil,
        departureCity: String? = nil,
        arrivalCity: String? = nil,
        timezone: String? = nil,
        arrivalTimezone: String? = nil,
        tripId: String? = "T1"
    ) -> TripLeg {
        TripLeg(
            id: id,
            tripId: tripId,
            type: type,
            startTime: start,
            endTime: start.addingTimeInterval(hours * 3600),
            airportCode: nil,
            city: nil,
            timezoneIdentifier: timezone,
            arrivalTimezoneIdentifier: arrivalTimezone,
            flightNumber: flightNumber,
            departureAirport: departure,
            arrivalAirport: arrival,
            departureCity: departureCity,
            arrivalCity: arrivalCity,
            tripDayNumber: nil,
            tripTotalDays: nil,
            delayMinutes: delayMinutes,
            airlineCode: nil,
            label: nil
        )
    }

    /// SDF → CGN (8 h), a day in Cologne, CGN → DXB (6 h), 20 h in Dubai, DXB → SDF (14 h), from `start`.
    static func europeTrip(startingAt start: Date = tripStart, firstDelayMinutes: Int? = nil) -> [TripLeg] {
        func at(_ hours: Double) -> Date { start.addingTimeInterval(hours * 3600) }
        return [
            leg("f1", from: "SDF", to: "CGN", start: at(0), hours: 8, flightNumber: "UPS207", delayMinutes: firstDelayMinutes,
                departureCity: "Louisville", arrivalCity: "Cologne", timezone: "America/New_York", arrivalTimezone: "Europe/Berlin"),
            leg("l1", .layover, start: at(8), hours: 24, timezone: "Europe/Berlin"),
            leg("f2", from: "CGN", to: "DXB", start: at(32), hours: 6, flightNumber: "UPS208",
                departureCity: "Cologne", arrivalCity: "Dubai", timezone: "Europe/Berlin", arrivalTimezone: "Asia/Dubai"),
            leg("l2", .layover, start: at(38), hours: 20, timezone: "Asia/Dubai"),
            leg("f3", from: "DXB", to: "SDF", start: at(58), hours: 14, flightNumber: "UPS209",
                departureCity: "Dubai", arrivalCity: "Louisville", timezone: "Asia/Dubai", arrivalTimezone: "America/New_York"),
        ]
    }

    static func map(_ legs: [TripLeg], isNextTrip: Bool = false, legacyDelayMinutes: Int? = nil, at now: Date) -> TripMap? {
        TripMap.make(tripLegs: legs, isNextTrip: isNextTrip, homeAirportCode: "SDF",
                     legacyDelayMinutes: legacyDelayMinutes, at: now, coordinate: coordinate)
    }
}
```

> `tripStart`, 1,794,571,200 s, is Friday 2026-11-13 12:00:00 UTC (checked with `date -u -r 1794571200`).

- [ ] **Step 2: Write the failing tests.** Create `CrewluvTests/TripMapTests.swift`:

```swift
//
//  TripMapTests.swift
//  CrewluvTests
//
//  The trip map's model (moving map spec §5.1, §7.1, §12): which legs it draws, its mode, and where the pilot is.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class TripMapTests: XCTestCase {

    private let start = TripMapTestLegs.tripStart
    private func hours(_ value: Double) -> Date { start.addingTimeInterval(value * 3600) }

    func test_make_duringTheFirstFlight_isInFlightOnIt() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(4)))
        XCTAssertEqual(map.mode, .inFlight(legID: "f1"))
        XCTAssertEqual(map.currentLeg?.id, "f1")
        XCTAssertEqual(map.legs.map(\.id), ["f1", "f2", "f3"], "layovers aren't drawn")
    }

    func test_make_onTheLayover_isOnTripWithThePilotInCologne() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(12)))
        XCTAssertEqual(map.mode, .onTrip)
        XCTAssertNil(map.currentLeg)
        let place = try XCTUnwrap(map.pilotLocation(at: hours(12)))
        XCTAssertEqual(place.code, "CGN")
        XCTAssertEqual(place.city, "Cologne")
        XCTAssertEqual(place.timeZone?.identifier, "Europe/Berlin")
    }

    func test_make_nextTrip_putsThePilotAtHomeUntilItStarts() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), isNextTrip: true, at: hours(-48)))
        XCTAssertEqual(map.mode, .nextTrip)
        XCTAssertEqual(map.pilotLocation(at: hours(-48))?.code, "SDF")
        XCTAssertNil(map.pilotLocation(at: hours(4)), "replaying it, the plane shows instead")
    }

    func test_make_unknownAirport_leavesThatLegOut() throws {
        var legs = TripMapTestLegs.europeTrip()
        legs[2] = TripMapTestLegs.leg("f2", from: "CGN", to: "ZZZ", start: hours(32), hours: 6)
        let map = try XCTUnwrap(TripMapTestLegs.map(legs, at: hours(12)))
        XCTAssertEqual(map.legs.map(\.id), ["f1", "f3"])
    }

    func test_make_nothingDrawable_isNil() {
        let legs = [TripMapTestLegs.leg("x", from: "ZZZ", to: "YYY", start: hours(0), hours: 2)]
        XCTAssertNil(TripMapTestLegs.map(legs, at: hours(1)))
        XCTAssertNil(TripMapTestLegs.map([], at: hours(1)))
    }

    func test_make_legDelay_movesThatLeg() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(firstDelayMinutes: 45), at: hours(4)))
        let first = try XCTUnwrap(map.legs.first)
        XCTAssertEqual(first.start, hours(0.75))
        XCTAssertEqual(first.end, hours(8.75))
        XCTAssertEqual(map.legs[1].start, hours(32), "other legs keep their times")
    }

    func test_make_legacyDelay_movesOnlyTheFlightItCovers() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), legacyDelayMinutes: 60, at: hours(8.5)))
        XCTAssertEqual(map.mode, .inFlight(legID: "f1"), "an hour late, the first flight is still in the air")
        XCTAssertEqual(map.legs[0].end, hours(9))
        XCTAssertEqual(map.legs[1].start, hours(32))
    }

    func test_make_legacyDelay_isIgnoredWhenAnyLegCarriesItsOwn() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(firstDelayMinutes: 30), legacyDelayMinutes: 120, at: hours(4)))
        XCTAssertEqual(map.legs[0].end, hours(8.5))
    }

    func test_make_arrivalTimeZone_fallsBackToTheNextGroundLeg() throws {
        var legs = TripMapTestLegs.europeTrip()
        legs[0] = TripMapTestLegs.leg("f1", from: "SDF", to: "CGN", start: hours(0), hours: 8, arrivalCity: "Cologne")
        let map = try XCTUnwrap(TripMapTestLegs.map(legs, at: hours(4)))
        XCTAssertEqual(map.legs[0].destination.timeZone?.identifier, "Europe/Berlin")
    }

    func test_make_drive_isADriveLeg() throws {
        let legs = [TripMapTestLegs.leg("d1", .drive, from: "LEX", to: "SDF", start: hours(0), hours: 1.5)]
        let map = try XCTUnwrap(TripMapTestLegs.map(legs, at: hours(0.5)))
        XCTAssertEqual(map.legs.first?.kind, .drive)
        XCTAssertEqual(map.mode, .onTrip, "only a flight makes the map in flight")
    }

    func test_span_runsFromTheFirstDepartureToTheLastArrival() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(12)))
        XCTAssertEqual(map.span.start, hours(0))
        XCTAssertEqual(map.span.end, hours(72))
    }

    func test_legInMotion_onlyBetweenGateTimes() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(12)))
        XCTAssertEqual(map.legInMotion(at: hours(35))?.id, "f2")
        XCTAssertNil(map.legInMotion(at: hours(40)))
    }

    func test_nextFlight_afterTheLayoverStarts_isCologneToDubai() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(12)))
        XCTAssertEqual(map.nextFlight(after: hours(12))?.id, "f2")
        XCTAssertNil(map.nextFlight(after: hours(70)))
    }

    func test_framingCoordinates_aLeg_holdsOnlyThatLegsArc() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(4)))
        XCTAssertEqual(map.framingCoordinates(focusingOn: map.currentLeg).count, 33)
        XCTAssertEqual(map.framingCoordinates(focusingOn: nil).count, 3 * 33 + 1, "every leg, and home")
    }

    func test_mapLeg_positionAndHeading_followTheSchedule() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(4)))
        let leg = try XCTUnwrap(map.currentLeg)
        let fraction = leg.progress(at: hours(4))
        XCTAssertEqual(fraction, FlightProgress.scheduledFraction(departure: hours(0), arrival: hours(8), at: hours(4)), accuracy: 1e-12)
        let expected = GreatCircle.point(from: leg.origin.coordinate, to: leg.destination.coordinate, fraction: fraction)
        XCTAssertEqual(leg.position(at: hours(4)).latitude, expected.latitude, accuracy: 1e-9)
        let heading = try XCTUnwrap(leg.heading(at: hours(4)))
        XCTAssertLessThan(abs(heading), .pi / 2, "Louisville to Cologne heads east")
    }
}
```

- [ ] **Step 3: Implement `AirportMark`.** Create `Crewluv/Services/TripMap/AirportMark.swift`:

```swift
//
//  AirportMark.swift
//  CrewLuve
//
//  An airport on the trip map (moving map spec §5.1).
//

import CoreLocation

nonisolated struct AirportMark: Identifiable {
    let code: String
    let city: String?
    let coordinate: CLLocationCoordinate2D
    /// The airport's time zone when the legs say, for "9:14 PM there".
    let timeZone: TimeZone?

    var id: String { code }

    /// The city when the legs name it, else the code.
    var name: String { city ?? code }
}
```

- [ ] **Step 4: Implement `MapLeg`.** Create `Crewluv/Services/TripMap/MapLeg.swift`:

```swift
//
//  MapLeg.swift
//  CrewLuve
//
//  One drawable leg of the trip map: a flight or a drive between two known airports, at its delay-shifted times
//  (moving map spec §7.1, §7.3).
//

import CoreLocation

nonisolated struct MapLeg: Identifiable {
    enum Kind { case flight, drive }

    let id: String
    let kind: Kind
    let origin: AirportMark
    let destination: AirportMark
    /// Leaving the gate (or the driveway), moved by any delay.
    let start: Date
    /// Reaching the gate, moved by any delay.
    let end: Date
    let flightNumber: String?

    /// The great-circle distance between the two airports, in meters.
    var distance: Double { GreatCircle.distance(from: origin.coordinate, to: destination.coordinate) }

    /// True from leaving the gate until reaching the other one.
    func isMoving(at date: Date) -> Bool { start <= date && date < end }

    /// How far along the leg the schedule has the pilot at `date`, 0...1. A flight uses the taxi allowances;
    /// a drive moves steadily.
    func progress(at date: Date) -> Double {
        switch kind {
        case .flight:
            return FlightProgress.scheduledFraction(departure: start, arrival: end, at: date)
        case .drive:
            let duration = end.timeIntervalSince(start)
            guard duration > 0 else { return date >= end ? 1 : 0 }
            return min(max(date.timeIntervalSince(start) / duration, 0), 1)
        }
    }

    func position(at date: Date) -> CLLocationCoordinate2D {
        position(atFraction: progress(at: date))
    }

    func position(atFraction fraction: Double) -> CLLocationCoordinate2D {
        GreatCircle.point(from: origin.coordinate, to: destination.coordinate, fraction: fraction)
    }

    /// The angle the plane points at `date` on a north-up map (`PlaneHeading`). Nil for a leg that starts and
    /// ends at the same place.
    func heading(at date: Date) -> Double? {
        let aim = PlaneHeading.aimFractions(at: progress(at: date))
        return PlaneHeading.flatMapAngle(from: position(atFraction: aim.from), to: position(atFraction: aim.to))
    }
}
```

- [ ] **Step 5: Implement `TripMap`.** Create `Crewluv/Services/TripMap/TripMap.swift`:

```swift
//
//  TripMap.swift
//  CrewLuve
//
//  The trip the map shows (moving map spec §5.1): its drawable legs, whether the pilot is flying, on the ground
//  mid-trip, or home with this trip ahead, and where the pilot is at any moment.
//

import CoreLocation

nonisolated struct TripMap {

    enum Mode: Equatable {
        /// A flight is between its gates.
        case inFlight(legID: String)
        /// On a trip, and not in the air.
        case onTrip
        /// At home or base, with this trip still ahead.
        case nextTrip
    }

    let mode: Mode
    /// Never empty, earliest first.
    let legs: [MapLeg]
    let home: AirportMark?
    /// From the first departure to the last arrival: the full-screen map's timeline.
    let span: DateInterval

    var isInFlight: Bool {
        if case .inFlight = mode { return true }
        return false
    }

    /// The flight in the air when the map was made.
    var currentLeg: MapLeg? {
        guard case .inFlight(let legID) = mode else { return nil }
        return legs.first { $0.id == legID }
    }

    func legInMotion(at date: Date) -> MapLeg? {
        legs.first { $0.isMoving(at: date) }
    }

    func nextFlight(after date: Date) -> MapLeg? {
        legs.first { $0.kind == .flight && $0.start > date }
    }

    /// Where the pilot is at `date` when nothing is moving, or nil while a leg is. Before a trip still ahead
    /// starts, that's home.
    func pilotLocation(at date: Date) -> AirportMark? {
        guard legInMotion(at: date) == nil else { return nil }
        if mode == .nextTrip, date < span.start { return home ?? legs.first?.origin }
        return legs.last(where: { $0.end <= date })?.destination ?? legs.first?.origin
    }

    /// The places the camera must show: one leg's arc, or every leg's arcs and home.
    func framingCoordinates(focusingOn leg: MapLeg?) -> [CLLocationCoordinate2D] {
        let shown = leg.map { [$0] } ?? legs
        var coordinates = shown.flatMap {
            GreatCircle.points(from: $0.origin.coordinate, to: $0.destination.coordinate, count: 33)
        }
        if leg == nil, let home { coordinates.append(home.coordinate) }
        return coordinates
    }

    // MARK: - Making one

    /// The map of `tripLegs`, one trip's legs as the status screen picked them, or nil when none can be drawn.
    /// - `isNextTrip`: the legs are a trip still ahead, shown from home.
    /// - `legacyDelayMinutes`: the summary-wide delay from a CrewLu that doesn't tag legs. As `TripStateResolver`
    ///   does, it moves only the flight it covers, and only when no leg carries its own.
    /// - `coordinate`: where an airport is, by code.
    static func make(
        tripLegs: [TripLeg],
        isNextTrip: Bool,
        homeAirportCode: String?,
        legacyDelayMinutes: Int?,
        at now: Date,
        coordinate: (String) -> CLLocationCoordinate2D?
    ) -> TripMap? {
        let sorted = tripLegs.sorted { $0.startTime < $1.startTime }
        let legacyDelay = legacyDelayedFlight(in: sorted, delayMinutes: legacyDelayMinutes, at: now)
        let legs = sorted.compactMap { leg in
            mapLeg(for: leg,
                   arrivalZoneFallback: sorted.first(where: { $0.startTime >= leg.endTime && $0.type != .flight })?.timezoneIdentifier,
                   extraDelayMinutes: leg.id == legacyDelay?.legID ? legacyDelay?.minutes : nil,
                   coordinate: coordinate)
        }
        guard let first = legs.first else { return nil }
        let lastArrival = legs.map(\.end).max() ?? first.end
        let home = homeAirportCode.flatMap { code in
            coordinate(code).map { AirportMark(code: code, city: nil, coordinate: $0, timeZone: nil) }
        }
        let mode: Mode
        if isNextTrip {
            mode = .nextTrip
        } else if let flying = legs.first(where: { $0.kind == .flight && $0.isMoving(at: now) }) {
            mode = .inFlight(legID: flying.id)
        } else {
            mode = .onTrip
        }
        return TripMap(mode: mode, legs: legs, home: home,
                       span: DateInterval(start: first.start, end: max(lastArrival, first.start)))
    }

    private static func mapLeg(
        for leg: TripLeg,
        arrivalZoneFallback: String?,
        extraDelayMinutes: Int?,
        coordinate: (String) -> CLLocationCoordinate2D?
    ) -> MapLeg? {
        let kind: MapLeg.Kind
        switch leg.type {
        case .flight: kind = .flight
        case .drive: kind = .drive
        default: return nil
        }
        guard let originCode = leg.departureAirport, let destinationCode = leg.arrivalAirport,
              let originCoordinate = coordinate(originCode), let destinationCoordinate = coordinate(destinationCode) else { return nil }
        let delay = TimeInterval(((leg.delayMinutes ?? 0) + (extraDelayMinutes ?? 0)) * 60)
        let originZone = leg.timezoneIdentifier.flatMap(TimeZone.init(identifier:))
        let destinationZone = (leg.arrivalTimezoneIdentifier ?? arrivalZoneFallback).flatMap(TimeZone.init(identifier:))
        return MapLeg(
            id: leg.id,
            kind: kind,
            origin: AirportMark(code: originCode, city: leg.departureCity, coordinate: originCoordinate, timeZone: originZone),
            destination: AirportMark(code: destinationCode, city: leg.arrivalCity, coordinate: destinationCoordinate, timeZone: destinationZone),
            start: leg.startTime.addingTimeInterval(delay),
            end: leg.endTime.addingTimeInterval(delay),
            flightNumber: leg.flightNumber
        )
    }

    /// The flight the summary-wide delay applies to, as `TripStateResolver.resolve` picks it.
    private static func legacyDelayedFlight(in sorted: [TripLeg], delayMinutes: Int?, at now: Date) -> (legID: String, minutes: Int)? {
        guard let minutes = delayMinutes, minutes != 0,
              !sorted.contains(where: { ($0.delayMinutes ?? 0) != 0 }) else { return nil }
        let shift = TimeInterval(minutes * 60)
        let flight = sorted.first {
            $0.type == .flight && $0.startTime.addingTimeInterval(shift) <= now && now < $0.endTime.addingTimeInterval(shift)
        }
        return flight.map { ($0.id, minutes) }
    }
}
```

- [ ] **Step 6: Checkpoint (Todd).** Run `-only-testing:CrewluvTests/TripMapTests`. Expected: all pass.

- [ ] **Step 7: Ask to commit.** Suggested message: `feat(crewluv): the trip map's model: drawable legs, mode and where the pilot is (moving map spec §5.1)`

---

### Task 9: What to draw at an instant: `TripMapDrawing` and `NightBand`

**Files:**
- Create: `Crewluv/Services/TripMap/TripMapDrawing.swift`
- Create: `Crewluv/Services/TripMap/NightBand.swift`
- Test: `CrewluvTests/TripMapDrawingTests.swift`

- [ ] **Step 1: Write the failing tests.** Create `CrewluvTests/TripMapDrawingTests.swift`:

```swift
//
//  TripMapDrawingTests.swift
//  CrewluvTests
//
//  What the trip map draws at an instant (moving map spec §7.1, §7.2).
//

import XCTest
import CoreLocation
@testable import Crewluv

final class TripMapDrawingTests: XCTestCase {

    private let start = TripMapTestLegs.tripStart
    private func hours(_ value: Double) -> Date { start.addingTimeInterval(value * 3600) }
    private func styles(_ drawing: TripMapDrawing) -> [String: RouteSegment.Style] {
        Dictionary(uniqueKeysWithValues: drawing.segments.map { ($0.id, $0.style) })
    }

    func test_init_midFlight_splitsTheLegAtThePlane() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(4)))
        let drawing = TripMapDrawing(tripMap: map, at: hours(4))
        XCTAssertEqual(styles(drawing), ["f1-flying": .flying, "f1-upcoming": .upcoming, "f2-upcoming": .upcoming, "f3-upcoming": .upcoming])
        let plane = try XCTUnwrap(drawing.plane)
        let expected = try XCTUnwrap(map.currentLeg).position(at: hours(4))
        XCTAssertEqual(plane.coordinate.latitude, expected.latitude, accuracy: 1e-9)
        XCTAssertNil(drawing.pin, "the plane shows where they are")
    }

    func test_init_onTheLayover_greysTheFlownLegAndPinsCologne() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(12)))
        let drawing = TripMapDrawing(tripMap: map, at: hours(12))
        XCTAssertEqual(styles(drawing), ["f1-flown": .flown, "f2-upcoming": .upcoming, "f3-upcoming": .upcoming])
        XCTAssertNil(drawing.plane)
        XCTAssertEqual(drawing.pin?.code, "CGN")
    }

    func test_init_taxiingOut_showsThePlaneAtTheGateWithTheWholeLegAhead() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(0.1)))
        let drawing = TripMapDrawing(tripMap: map, at: hours(0.1))
        XCTAssertEqual(styles(drawing)["f1-upcoming"], .upcoming)
        XCTAssertNil(styles(drawing)["f1-flying"])
        let plane = try XCTUnwrap(drawing.plane)
        XCTAssertEqual(plane.coordinate.latitude, TripMapTestLegs.airports["SDF"]!.latitude, accuracy: 1e-9)
    }

    func test_init_airports_eachOnce() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(12)))
        XCTAssertEqual(TripMapDrawing(tripMap: map, at: hours(12)).airports.map(\.code), ["SDF", "CGN", "DXB"])
    }

    func test_init_drive_isDottedWithACar() throws {
        let legs = [TripMapTestLegs.leg("d1", .drive, from: "LEX", to: "SDF", start: hours(0), hours: 2)]
        let map = try XCTUnwrap(TripMapTestLegs.map(legs, at: hours(-1)))
        let drawing = TripMapDrawing(tripMap: map, at: hours(-1))
        XCTAssertEqual(styles(drawing), ["d1-drive": .drive])
        XCTAssertEqual(drawing.segments.first?.isGeodesic, false)
        let car = try XCTUnwrap(drawing.cars.first)
        let middle = try XCTUnwrap(map.legs.first).position(atFraction: 0.5)
        XCTAssertEqual(car.coordinate.longitude, middle.longitude, accuracy: 1e-9, "parked halfway when not driving")
    }

    func test_nightDate_holdsBackToTheStep() {
        let date = Date(timeIntervalSince1970: 1_000_059)
        XCTAssertEqual(TripMapDrawing.nightDate(for: date, step: 60), Date(timeIntervalSince1970: 1_000_020))
        XCTAssertEqual(TripMapDrawing.nightDate(for: date, step: 0), date)
    }

    func test_nightBands_haveUniqueIDs_andEveryShape() {
        let date = Date(timeIntervalSince1970: 1_794_571_200)
        let bands = NightBand.bands(at: date)
        XCTAssertEqual(bands.count, NightShade.layers(at: date).map(\.count).reduce(0, +))
        XCTAssertEqual(Set(bands.map(\.id)).count, bands.count)
    }
}
```

- [ ] **Step 2: Implement `TripMapDrawing`.** Create `Crewluv/Services/TripMap/TripMapDrawing.swift`:

```swift
//
//  TripMapDrawing.swift
//  CrewLuve
//
//  Everything the trip map draws at one instant (moving map spec §7.1, §7.2), worked out here so `TripMapView`
//  only renders it.
//

import CoreLocation

/// One line on the map.
nonisolated struct RouteSegment: Identifiable {
    enum Style: Equatable {
        /// Still to fly: dashed.
        case upcoming
        /// Flown so far on the leg in the air: solid.
        case flying
        /// A leg already flown: grey.
        case flown
        /// A drive: dotted.
        case drive
    }

    let id: String
    let coordinates: [CLLocationCoordinate2D]
    let style: Style

    /// Flights follow the great circle. Drives are short enough to draw straight.
    var isGeodesic: Bool { style != .drive }
}

/// A place with an identity, for a marker.
nonisolated struct TripMapPoint: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
}

/// The schedule's plane and the way it points (`PlaneHeading`'s angle).
nonisolated struct PlaneMark {
    let coordinate: CLLocationCoordinate2D
    let angle: Double
}

nonisolated struct TripMapDrawing {
    let segments: [RouteSegment]
    let airports: [AirportMark]
    let cars: [TripMapPoint]
    let plane: PlaneMark?
    /// The heart: where the pilot is when nothing is moving.
    let pin: AirportMark?

    init(tripMap: TripMap, at date: Date) {
        var segments: [RouteSegment] = []
        var cars: [TripMapPoint] = []
        var plane: PlaneMark?
        for leg in tripMap.legs {
            let origin = leg.origin.coordinate
            let destination = leg.destination.coordinate
            switch leg.kind {
            case .drive:
                segments.append(RouteSegment(id: "\(leg.id)-drive", coordinates: [origin, destination], style: .drive))
                let fraction = leg.isMoving(at: date) ? leg.progress(at: date) : 0.5
                cars.append(TripMapPoint(id: "\(leg.id)-car", coordinate: leg.position(atFraction: fraction)))
            case .flight where date >= leg.end:
                segments.append(RouteSegment(id: "\(leg.id)-flown", coordinates: [origin, destination], style: .flown))
            case .flight where leg.isMoving(at: date):
                let fraction = leg.progress(at: date)
                let here = leg.position(atFraction: fraction)
                if fraction > 0 {
                    segments.append(RouteSegment(id: "\(leg.id)-flying", coordinates: [origin, here], style: .flying))
                }
                if fraction < 1 {
                    segments.append(RouteSegment(id: "\(leg.id)-upcoming", coordinates: [here, destination], style: .upcoming))
                }
                plane = PlaneMark(coordinate: here, angle: leg.heading(at: date) ?? 0)
            case .flight:
                segments.append(RouteSegment(id: "\(leg.id)-upcoming", coordinates: [origin, destination], style: .upcoming))
            }
        }
        var seen = Set<String>()
        self.segments = segments
        self.airports = tripMap.legs.flatMap { [$0.origin, $0.destination] }.filter { seen.insert($0.code).inserted }
        self.cars = cars
        self.plane = plane
        self.pin = tripMap.pilotLocation(at: date)
    }

    /// `date` held back to a whole number of `step` seconds, so the night is redrawn only once it has moved enough
    /// to see (moving map spec §10): every minute live, about ten times a second in replay.
    static func nightDate(for date: Date, step: TimeInterval) -> Date {
        guard step > 0 else { return date }
        return Date(timeIntervalSince1970: (date.timeIntervalSince1970 / step).rounded(.down) * step)
    }
}
```

- [ ] **Step 3: Implement `NightBand`.** Create `Crewluv/Services/TripMap/NightBand.swift`:

```swift
//
//  NightBand.swift
//  CrewLuve
//
//  NightShade's shapes with stable identities, so the map's `ForEach` updates them in place (moving map spec §7.1).
//

import CoreLocation

nonisolated struct NightBand: Identifiable {
    let id: String
    let coordinates: [CLLocationCoordinate2D]

    /// Every shape of every night layer at `date`, shallowest layer first.
    static func bands(at date: Date) -> [NightBand] {
        NightShade.layers(at: date).enumerated().flatMap { layer, shapes in
            shapes.enumerated().map { index, shape in
                NightBand(id: "night-\(layer)-\(index)", coordinates: shape)
            }
        }
    }
}
```

- [ ] **Step 4: Checkpoint (Todd).** Run `-only-testing:CrewluvTests/TripMapDrawingTests`. Expected: all pass.

- [ ] **Step 5: Ask to commit.** Suggested message: `feat(crewluv): what the trip map draws at an instant: lines, planes, cars, the heart and night (moving map spec §7.1, §7.2)`

---

### Task 10: The replay clock

**Files:**
- Create: `Crewluv/Services/TripMap/TripReplayClock.swift`
- Test: `CrewluvTests/TripReplayClockTests.swift`

- [ ] **Step 1: Write the failing tests.** Create `CrewluvTests/TripReplayClockTests.swift`:

```swift
//
//  TripReplayClockTests.swift
//  CrewluvTests
//
//  The full-screen map's timeline (moving map spec §6): live, scrubbed, or playing at 1x to 10x.
//

import XCTest
@testable import Crewluv

final class TripReplayClockTests: XCTestCase {

    private let span = DateInterval(start: Date(timeIntervalSince1970: 1_800_000_000), duration: 2 * 86_400)
    private let now = Date(timeIntervalSince1970: 1_800_050_000)

    func test_time_whenLive_isNow() {
        let clock = TripReplayClock(span: span)
        XCTAssertTrue(clock.isLive)
        XCTAssertFalse(clock.isPlaying)
        XCTAssertEqual(clock.time(at: now), now)
    }

    func test_scrub_outsideTheTrip_isHeldToItsEnds() {
        var clock = TripReplayClock(span: span)
        clock.scrub(to: span.start.addingTimeInterval(-3600))
        XCTAssertEqual(clock.time(at: now), span.start)
        clock.scrub(to: span.end.addingTimeInterval(3600))
        XCTAssertEqual(clock.time(at: now), span.end)
        XCTAssertFalse(clock.isLive)
        XCTAssertFalse(clock.isPlaying)
    }

    func test_play_fromLive_startsAtTheTripsStart_atADayIn48Seconds() {
        var clock = TripReplayClock(span: span)
        clock.play(at: now)
        XCTAssertTrue(clock.isPlaying)
        XCTAssertEqual(clock.time(at: now), span.start)
        XCTAssertEqual(clock.time(at: now.addingTimeInterval(48)), span.start.addingTimeInterval(86_400))
    }

    func test_setSpeed_whilePlaying_keepsThePlaceAndGoesFaster() {
        var clock = TripReplayClock(span: span)
        clock.play(at: now)
        let later = now.addingTimeInterval(10)
        let before = clock.time(at: later)
        clock.setSpeed(.ten, at: later)
        XCTAssertEqual(clock.time(at: later), before)
        XCTAssertEqual(clock.time(at: later.addingTimeInterval(1)), before.addingTimeInterval(18_000))
    }

    func test_play_pastTheEnd_stopsThere_andPlayingAgainStartsOver() {
        var clock = TripReplayClock(span: span)
        clock.play(at: now)
        let afterTheEnd = now.addingTimeInterval(500)
        XCTAssertEqual(clock.time(at: afterTheEnd), span.end)
        XCTAssertTrue(clock.hasFinished(at: afterTheEnd))
        clock.play(at: afterTheEnd)
        XCTAssertEqual(clock.time(at: afterTheEnd), span.start)
    }

    func test_pause_holdsTheTime() {
        var clock = TripReplayClock(span: span)
        clock.play(at: now)
        clock.pause(at: now.addingTimeInterval(5))
        XCTAssertFalse(clock.isPlaying)
        XCTAssertEqual(clock.time(at: now.addingTimeInterval(60)), span.start.addingTimeInterval(5 * 1_800))
    }

    func test_goLive_returnsToNow() {
        var clock = TripReplayClock(span: span)
        clock.scrub(to: span.start)
        clock.goLive()
        XCTAssertTrue(clock.isLive)
        XCTAssertEqual(clock.time(at: now), now)
    }
}
```

- [ ] **Step 2: Implement.** Create `Crewluv/Services/TripMap/TripReplayClock.swift`:

```swift
//
//  TripReplayClock.swift
//  CrewLuve
//
//  The full-screen map's time (moving map spec §6): now, a moment dragged to, or a replay running at 1x to 10x.
//  A value: the screen keeps it in `@State` and reads `time(at:)` on each tick, so nothing mutates per frame.
//

import Foundation

nonisolated struct TripReplayClock {

    enum Speed: Int, CaseIterable, Identifiable {
        case one = 1, two = 2, five = 5, ten = 10
        var id: Int { rawValue }
    }

    /// Seconds of trip per second of replay at 1x: a day in 48 seconds, as on CrewLu's moving map.
    static let baseRate: Double = 1_800

    let span: DateInterval
    private(set) var speed: Speed = .one

    /// Nil while live. Otherwise the trip time it was set to, and when it started playing from there.
    private var anchor: (tripTime: Date, playingSince: Date?)?

    init(span: DateInterval) {
        self.span = span
    }

    var isLive: Bool { anchor == nil }

    var isPlaying: Bool { anchor?.playingSince != nil }

    /// The trip time to show at the real time `now`.
    func time(at now: Date) -> Date {
        guard let anchor else { return now }
        guard let playingSince = anchor.playingSince else { return anchor.tripTime }
        let elapsed = max(now.timeIntervalSince(playingSince), 0) * Self.baseRate * Double(speed.rawValue)
        return min(anchor.tripTime.addingTimeInterval(elapsed), span.end)
    }

    /// True once a replay has run to the trip's end.
    func hasFinished(at now: Date) -> Bool {
        isPlaying && time(at: now) >= span.end
    }

    mutating func scrub(to date: Date) {
        anchor = (min(max(date, span.start), span.end), nil)
    }

    /// Plays from where it is, from the start when live, and again from the start once it has finished.
    mutating func play(at now: Date) {
        let current = isLive ? span.start : time(at: now)
        anchor = (current >= span.end ? span.start : current, now)
    }

    mutating func pause(at now: Date) {
        guard isPlaying else { return }
        anchor = (time(at: now), nil)
    }

    mutating func setSpeed(_ newSpeed: Speed, at now: Date) {
        if isPlaying { anchor = (time(at: now), now) }
        speed = newSpeed
    }

    mutating func goLive() {
        anchor = nil
    }
}
```

- [ ] **Step 3: Checkpoint (Todd).** Run `-only-testing:CrewluvTests/TripReplayClockTests`. Expected: all pass.

- [ ] **Step 4: Ask to commit.** Suggested message: `feat(crewluv): the full-screen map's replay clock (moving map spec §6)`

---

### Task 11: The words: `TripMapWording`

Each sentence the map shows or speaks lives in one tested place. Times are in the family's time zone (`calendar.timeZone`) unless the words say "there".

**Files:**
- Create: `Crewluv/Services/TripMap/TripMapWording.swift`
- Test: `CrewluvTests/TripMapWordingTests.swift`

- [ ] **Step 1: Write the failing tests.** Create `CrewluvTests/TripMapWordingTests.swift`:

```swift
//
//  TripMapWordingTests.swift
//  CrewluvTests
//
//  The trip map's words (moving map spec §5, §6, §14), in US English for a family in Louisville.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class TripMapWordingTests: XCTestCase {

    private let locale = Locale(identifier: "en_US")
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }
    /// Friday 2026-11-13, 3:14 PM in Louisville, 9:14 PM in Cologne.
    private let now = Date(timeIntervalSince1970: 1_794_600_840)

    /// iOS writes a narrow no-break space before AM and PM; the tests read it as a plain space.
    private func plain(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{202F}", with: " ")
    }

    private func mark(_ code: String, _ city: String, _ zone: String) -> AirportMark {
        AirportMark(code: code, city: city, coordinate: TripMapTestLegs.airports[code]!, timeZone: TimeZone(identifier: zone))
    }

    private func leg(from origin: AirportMark, to destination: AirportMark, start: Date, end: Date, flightNumber: String? = "UPS207") -> MapLeg {
        MapLeg(id: "f", kind: .flight, origin: origin, destination: destination, start: start, end: end, flightNumber: flightNumber)
    }

    private var louisville: AirportMark { mark("SDF", "Louisville", "America/New_York") }
    private var cologne: AirportMark { mark("CGN", "Cologne", "Europe/Berlin") }
    private var dubai: AirportMark { mark("DXB", "Dubai", "Asia/Dubai") }

    func test_placeChip_showsTheTimeThere() {
        XCTAssertEqual(plain(TripMapWording.placeChip(for: cologne, at: now, locale: locale)), "Cologne · 9:14 PM there")
    }

    func test_nextDepartureChip_tomorrowMorning_inYourTime() {
        let next = leg(from: cologne, to: dubai, start: now.addingTimeInterval(14 * 3600 + 56 * 60), end: now.addingTimeInterval(21 * 3600))
        XCTAssertEqual(plain(TripMapWording.nextDepartureChip(for: next, now: now, calendar: calendar, locale: locale)),
                       "Next: Dubai, tomorrow 6:10 AM")
    }

    func test_landingCountdown_hoursAndMinutes() {
        func countdown(minutes: Double) -> String {
            TripMapWording.landingCountdown(for: leg(from: louisville, to: cologne, start: now.addingTimeInterval(-3600),
                                                     end: now.addingTimeInterval(minutes * 60)), now: now)
        }
        XCTAssertEqual(countdown(minutes: 130), "Landing in 2 h 10 min")
        XCTAssertEqual(countdown(minutes: 120), "Landing in 2 h")
        XCTAssertEqual(countdown(minutes: 45), "Landing in 45 min")
        XCTAssertEqual(countdown(minutes: -1), "Landing now")
    }

    func test_landingLine_anotherTimeZone_givesBothTimes() {
        let flight = leg(from: louisville, to: cologne, start: now.addingTimeInterval(-6 * 3600), end: now.addingTimeInterval(16 * 60))
        XCTAssertEqual(plain(TripMapWording.landingLine(for: flight, calendar: calendar, locale: locale)),
                       "Lands Cologne 9:30 PM · 3:30 PM your time")
    }

    func test_landingLine_yourTimeZone_givesOneTime() {
        let homeward = leg(from: cologne, to: louisville, start: now.addingTimeInterval(-6 * 3600), end: now.addingTimeInterval(16 * 60))
        XCTAssertEqual(plain(TripMapWording.landingLine(for: homeward, calendar: calendar, locale: locale)), "Lands Louisville 3:30 PM")
        XCTAssertNil(TripMapWording.arrivalLocalTime(for: homeward, calendar: calendar, locale: locale))
    }

    func test_landsAt_andArrivalLocalTime_forTheBar() {
        let flight = leg(from: louisville, to: cologne, start: now.addingTimeInterval(-6 * 3600), end: now.addingTimeInterval(16 * 60))
        XCTAssertEqual(plain(TripMapWording.landsAt(for: flight, calendar: calendar, locale: locale)), "Lands 3:30 PM")
        XCTAssertEqual(plain(TripMapWording.arrivalLocalTime(for: flight, calendar: calendar, locale: locale) ?? ""), "9:30 PM in Cologne")
    }

    func test_dayPhrase_todayTomorrowWeekdayDate() {
        let day: TimeInterval = 86_400
        XCTAssertEqual(TripMapWording.dayPhrase(for: now, now: now, calendar: calendar, locale: locale), "today")
        XCTAssertEqual(TripMapWording.dayPhrase(for: now.addingTimeInterval(day), now: now, calendar: calendar, locale: locale), "tomorrow")
        XCTAssertEqual(TripMapWording.dayPhrase(for: now.addingTimeInterval(5 * day), now: now, calendar: calendar, locale: locale), "Wednesday")
        XCTAssertEqual(TripMapWording.dayPhrase(for: now.addingTimeInterval(7 * day), now: now, calendar: calendar, locale: locale), "Nov 20")
    }

    func test_nextTripChip_namesTheDay() {
        XCTAssertEqual(TripMapWording.nextTripChip(startingAt: now.addingTimeInterval(5 * 86_400), now: now, calendar: calendar, locale: locale),
                       "Home · next trip Wednesday")
    }

    func test_dateRange_fridayToMonday() {
        XCTAssertEqual(TripMapWording.dateRange(from: now.addingTimeInterval(7 * 86_400), to: now.addingTimeInterval(10 * 86_400),
                                                calendar: calendar, locale: locale), "Fri–Mon")
        XCTAssertEqual(TripMapWording.dateRange(from: now, to: now.addingTimeInterval(3600), calendar: calendar, locale: locale), "Fri")
    }

    func test_statsItems_onTheLayover_dayCitiesAndMilesSoFar() throws {
        let start = TripMapTestLegs.tripStart
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: start.addingTimeInterval(12 * 3600)))
        let miles = Int((map.legs[0].distance / GreatCircle.metersPerMile).rounded())
        let items = TripMapWording.statsItems(for: map, at: start.addingTimeInterval(12 * 3600), dayNumber: 1, totalDays: 4,
                                              calendar: calendar, locale: locale)
        XCTAssertEqual(items, ["Day 1 of 4", "2 cities", "\(miles.formatted(.number.locale(locale))) mi so far"])
    }

    func test_statsItems_nextTrip_datesCitiesAndTotalMiles() throws {
        let start = TripMapTestLegs.tripStart
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), isNextTrip: true, at: start.addingTimeInterval(-86_400)))
        let total = Int((map.legs.map(\.distance).reduce(0, +) / GreatCircle.metersPerMile).rounded())
        let items = TripMapWording.statsItems(for: map, at: start.addingTimeInterval(-86_400), dayNumber: nil, totalDays: nil,
                                              calendar: calendar, locale: locale)
        XCTAssertEqual(items, ["Fri–Mon", "CGN · DXB", "\(total.formatted(.number.locale(locale))) mi"])
    }

    func test_cardChips_eachMode() throws {
        let start = TripMapTestLegs.tripStart
        let flying = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: start.addingTimeInterval(4 * 3600)))
        let flyingChips = TripMapWording.cardChips(for: flying, at: start.addingTimeInterval(4 * 3600), calendar: calendar, locale: locale)
        XCTAssertNil(flyingChips.top)
        XCTAssertEqual(flyingChips.bottom, "Landing in 4 h")

        let resting = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: start.addingTimeInterval(12 * 3600)))
        let restingChips = TripMapWording.cardChips(for: resting, at: start.addingTimeInterval(12 * 3600), calendar: calendar, locale: locale)
        XCTAssertTrue(restingChips.top?.hasPrefix("Cologne · ") ?? false)
        XCTAssertTrue(restingChips.bottom?.hasPrefix("Next: Dubai, ") ?? false)
    }

    func test_cardSummary_inFlight_readsAsOneSentence() throws {
        let start = TripMapTestLegs.tripStart
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: start.addingTimeInterval(4 * 3600)))
        let summary = plain(TripMapWording.cardSummary(for: map, now: start.addingTimeInterval(4 * 3600), pilotName: "Alex",
                                                       calendar: calendar, locale: locale))
        XCTAssertEqual(summary, "UPS207 to Cologne, landing at 3:00 PM your time. Estimated from the schedule.")
    }

    func test_timelineTime_weekdayAndTime() {
        XCTAssertEqual(plain(TripMapWording.timelineTime(now, calendar: calendar, locale: locale)), "Fri 3:14 PM")
    }
}
```

> **The fixed instants** (checked with `date`):
> - `now`, 1,794,600,840 s, is Friday 2026-11-13 20:14 UTC: 3:14 PM in Louisville and 9:14 PM in Cologne.
> - `TripMapTestLegs.tripStart` is 12:00 UTC the same day. The first flight ends at 20:00 UTC, which is 3:00 PM in Louisville: that's the time in `test_cardSummary_inFlight_readsAsOneSentence`.

- [ ] **Step 2: Implement.** Create `Crewluv/Services/TripMap/TripMapWording.swift`:

```swift
//
//  TripMapWording.swift
//  CrewLuve
//
//  Every sentence the trip map shows or speaks (moving map spec §5, §6, §14). Times are the family's own, in
//  `calendar.timeZone`, unless the words say "there".
//

import Foundation

nonisolated enum TripMapWording {

    // MARK: - The card's chips

    /// The chips on the card's map: the top one and the bottom one (moving map spec §5.1, §5.2).
    static func cardChips(for tripMap: TripMap, at date: Date, calendar: Calendar = .current, locale: Locale = .current) -> (top: String?, bottom: String?) {
        switch tripMap.mode {
        case .inFlight:
            return (nil, tripMap.currentLeg.map { landingCountdown(for: $0, now: date) })
        case .onTrip:
            let place = tripMap.pilotLocation(at: date).map { placeChip(for: $0, at: date, locale: locale) }
            let next = tripMap.nextFlight(after: date).map { nextDepartureChip(for: $0, now: date, calendar: calendar, locale: locale) }
            return (place, next)
        case .nextTrip:
            return (nextTripChip(startingAt: tripMap.span.start, now: date, calendar: calendar, locale: locale), nil)
        }
    }

    /// "Cologne · 9:14 PM there".
    static func placeChip(for place: AirportMark, at now: Date, locale: Locale = .current) -> String {
        guard let zone = place.timeZone else { return place.name }
        return "\(place.name) · \(clockTime(now, in: zone, locale: locale)) there"
    }

    /// "Next: Dubai, tomorrow 6:10 AM".
    static func nextDepartureChip(for leg: MapLeg, now: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let day = dayPhrase(for: leg.start, now: now, calendar: calendar, locale: locale)
        return "Next: \(leg.destination.name), \(day) \(clockTime(leg.start, in: calendar.timeZone, locale: locale))"
    }

    /// "Home · next trip Wednesday".
    static func nextTripChip(startingAt start: Date, now: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        "Home · next trip \(dayPhrase(for: start, now: now, calendar: calendar, locale: locale))"
    }

    /// "Landing in 2 h 10 min", to the gate arrival.
    static func landingCountdown(for leg: MapLeg, now: Date) -> String {
        let minutes = Int((leg.end.timeIntervalSince(now) / 60).rounded(.up))
        guard minutes > 0 else { return "Landing now" }
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 { return "Landing in \(rest) min" }
        if rest == 0 { return "Landing in \(hours) h" }
        return "Landing in \(hours) h \(rest) min"
    }

    // MARK: - Landing

    /// "Lands Cologne 9:30 PM · 3:30 PM your time", or one time when the destination keeps the family's.
    static func landingLine(for leg: MapLeg, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let yours = clockTime(leg.end, in: calendar.timeZone, locale: locale)
        guard let there = arrivalLocalClock(for: leg, calendar: calendar, locale: locale) else {
            return "Lands \(leg.destination.name) \(yours)"
        }
        return "Lands \(leg.destination.name) \(there) · \(yours) your time"
    }

    /// "Lands 3:30 PM", for the card's bar.
    static func landsAt(for leg: MapLeg, calendar: Calendar = .current, locale: Locale = .current) -> String {
        "Lands \(clockTime(leg.end, in: calendar.timeZone, locale: locale))"
    }

    /// "9:30 PM in Cologne", or nil when the destination keeps the family's time.
    static func arrivalLocalTime(for leg: MapLeg, calendar: Calendar = .current, locale: Locale = .current) -> String? {
        arrivalLocalClock(for: leg, calendar: calendar, locale: locale).map { "\($0) in \(leg.destination.name)" }
    }

    // MARK: - The bar under the map

    /// The bar's words on the ground (moving map spec §5.3): the day, cities and miles so far mid-trip; the dates,
    /// cities and total miles for a trip ahead. Empty in flight, where the bar shows the flight.
    static func statsItems(for tripMap: TripMap, at date: Date, dayNumber: Int?, totalDays: Int?,
                           calendar: Calendar = .current, locale: Locale = .current) -> [String] {
        let cities = destinations(of: tripMap.legs, leavingOut: Set([tripMap.home?.code].compactMap { $0 }))
        switch tripMap.mode {
        case .inFlight:
            return []
        case .onTrip:
            var items: [String] = []
            if let dayNumber, let totalDays { items.append("Day \(dayNumber) of \(totalDays)") }
            items.append(cities.count == 1 ? "1 city" : "\(cities.count) cities")
            items.append("\(milesText(milesFlown(by: date, on: tripMap.legs), locale: locale)) so far")
            return items
        case .nextTrip:
            return [dateRange(from: tripMap.span.start, to: tripMap.span.end, calendar: calendar, locale: locale),
                    cities.joined(separator: " · "),
                    milesText(totalMiles(of: tripMap.legs), locale: locale)]
        }
    }

    /// Miles flown by `date`, counting the part of a flight that's in the air.
    static func milesFlown(by date: Date, on legs: [MapLeg]) -> Int {
        let meters = legs.filter { $0.kind == .flight }.reduce(0) { $0 + $1.distance * $1.progress(at: date) }
        return Int((meters / GreatCircle.metersPerMile).rounded())
    }

    static func totalMiles(of legs: [MapLeg]) -> Int {
        let meters = legs.filter { $0.kind == .flight }.reduce(0) { $0 + $1.distance }
        return Int((meters / GreatCircle.metersPerMile).rounded())
    }

    /// The airports the trip's flights reach, in order, each once, home left out.
    static func destinations(of legs: [MapLeg], leavingOut homeCodes: Set<String>) -> [String] {
        var seen = homeCodes
        return legs.filter { $0.kind == .flight }.map(\.destination.code).filter { seen.insert($0).inserted }
    }

    /// "Fri–Mon", or "Fri" for one day.
    static func dateRange(from start: Date, to end: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let weekday = style(calendar: calendar, locale: locale).weekday(.abbreviated)
        guard !calendar.isDate(start, inSameDayAs: end) else { return start.formatted(weekday) }
        return "\(start.formatted(weekday))–\(end.formatted(weekday))"
    }

    /// "today", "tomorrow", a weekday within the week, else "Nov 20".
    static func dayPhrase(for date: Date, now: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
        switch days {
        case 0: return "today"
        case 1: return "tomorrow"
        case 2...6: return date.formatted(style(calendar: calendar, locale: locale).weekday(.wide))
        default: return date.formatted(style(calendar: calendar, locale: locale).month(.abbreviated).day())
        }
    }

    // MARK: - The full-screen map

    /// The pill at the top: "UPS207 · In flight", "Driving to Louisville", "Day 2 of 4" or "Next trip".
    static func topPill(for tripMap: TripMap, at date: Date, dayNumber: Int?, totalDays: Int?) -> String {
        if let leg = tripMap.legInMotion(at: date) {
            switch leg.kind {
            case .flight: return [leg.flightNumber, "In flight"].compactMap { $0 }.joined(separator: " · ")
            case .drive: return "Driving to \(leg.destination.name)"
            }
        }
        if tripMap.mode == .nextTrip, date < tripMap.span.start { return "Next trip" }
        if let dayNumber, let totalDays { return "Day \(dayNumber) of \(totalDays)" }
        return "Trip map"
    }

    /// The panel's first line: the landing line in the air, else where they are.
    static func panelHeadline(for tripMap: TripMap, at date: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        if let leg = tripMap.legInMotion(at: date) {
            return leg.kind == .flight ? landingLine(for: leg, calendar: calendar, locale: locale) : "Driving to \(leg.destination.name)"
        }
        if tripMap.mode == .nextTrip, date < tripMap.span.start {
            return nextTripChip(startingAt: tripMap.span.start, now: date, calendar: calendar, locale: locale)
        }
        return tripMap.pilotLocation(at: date).map { placeChip(for: $0, at: date, locale: locale) } ?? ""
    }

    /// "Fri 9:14 PM", under the timeline and as the slider's VoiceOver value.
    static func timelineTime(_ date: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        date.formatted(style(calendar: calendar, locale: locale).weekday(.abbreviated).hour().minute())
    }

    // MARK: - VoiceOver

    /// The card as one sentence (moving map spec §14).
    static func cardSummary(for tripMap: TripMap, now: Date, pilotName: String,
                            calendar: Calendar = .current, locale: Locale = .current) -> String {
        switch tripMap.mode {
        case .inFlight:
            guard let leg = tripMap.currentLeg else { return "Trip map" }
            let lead = leg.flightNumber.map { "\($0) to" } ?? "Flying to"
            return "\(lead) \(leg.destination.name), landing at \(clockTime(leg.end, in: calendar.timeZone, locale: locale)) your time. Estimated from the schedule."
        case .onTrip:
            var parts = ["Trip map."]
            if let place = tripMap.pilotLocation(at: now) { parts.append("\(pilotName) is in \(place.name).") }
            if let next = tripMap.nextFlight(after: now) {
                parts.append("\(nextDepartureChip(for: next, now: now, calendar: calendar, locale: locale)).")
            }
            return parts.joined(separator: " ")
        case .nextTrip:
            let cities = destinations(of: tripMap.legs, leavingOut: Set([tripMap.home?.code].compactMap { $0 }))
            let day = dayPhrase(for: tripMap.span.start, now: now, calendar: calendar, locale: locale)
            return "Map of the next trip, \(day): \(cities.joined(separator: ", "))."
        }
    }

    // MARK: - Private

    private static func milesText(_ miles: Int, locale: Locale) -> String {
        "\(miles.formatted(.number.locale(locale))) mi"
    }

    private static func arrivalLocalClock(for leg: MapLeg, calendar: Calendar, locale: Locale) -> String? {
        guard let there = leg.destination.timeZone,
              there.secondsFromGMT(for: leg.end) != calendar.timeZone.secondsFromGMT(for: leg.end) else { return nil }
        return clockTime(leg.end, in: there, locale: locale)
    }

    private static func clockTime(_ date: Date, in zone: TimeZone, locale: Locale) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, timeZone: zone))
    }

    private static func style(calendar: Calendar, locale: Locale) -> Date.FormatStyle {
        Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
    }
}
```

- [ ] **Step 3: Checkpoint (Todd).** Run `-only-testing:CrewluvTests/TripMapWordingTests`. Expected: all pass.
  - If a formatted string differs only in spacing or punctuation from what this iOS version's ICU gives, fix the test's expectation. Keep the words. The `plain()` helper already covers the narrow space before AM and PM.

- [ ] **Step 4: Ask to commit.** Suggested message: `feat(crewluv): the trip map's words: chips, the bar, landing lines and VoiceOver (moving map spec §5, §6, §14)`

---

### Task 12: The map view and its pieces

These are views, with no logic of their own. Todd verifies them with the previews in Task 13 and on the simulator in Task 15.

**Files:**
- Create: `Crewluv/Views/TripMap/TripMapStyle.swift`
- Create: `Crewluv/Views/TripMap/TripMapPalette.swift`
- Create: `Crewluv/Views/TripMap/TripMapMarkers.swift`
- Create: `Crewluv/Views/TripMap/PlaneMarker.swift`
- Create: `Crewluv/Views/TripMap/TripMapChip.swift`
- Create: `Crewluv/Views/TripMap/TripMapView.swift`
- Create: `Crewluv/Views/TripMap/TripMap+Camera.swift`

- [ ] **Step 1: `TripMapStyle`.**

```swift
//
//  TripMapStyle.swift
//  CrewLuve
//
//  The map styles the full-screen map's style button cycles through, as on CrewLu's moving map (moving map spec §6).
//  Kept flat: no 3D globe, so the night drawn here is the only one.
//

import MapKit
import SwiftUI

enum TripMapStyle: CaseIterable {
    case hybrid, standard, imagery

    var next: TripMapStyle {
        switch self {
        case .hybrid: .standard
        case .standard: .imagery
        case .imagery: .hybrid
        }
    }

    /// The style's name for VoiceOver.
    var name: String {
        switch self {
        case .hybrid: "Hybrid"
        case .standard: "Map"
        case .imagery: "Satellite"
        }
    }

    var mapStyle: MapStyle {
        switch self {
        case .hybrid: .hybrid(elevation: .flat, pointsOfInterest: .excludingAll)
        case .standard: .standard(elevation: .flat, pointsOfInterest: .excludingAll)
        case .imagery: .imagery(elevation: .flat)
        }
    }

    var palette: TripMapPalette {
        self == .standard ? .onLightMap : .onDarkMap
    }
}
```

- [ ] **Step 2: `TripMapPalette`.**

```swift
//
//  TripMapPalette.swift
//  CrewLuve
//
//  The trip map's line colours and strokes (moving map spec §7.1). Satellite and hybrid maps are dark in both light
//  and dark mode, so their lines are light; the standard map gets the system blue.
//

import SwiftUI

struct TripMapPalette {
    let upcoming: Color
    let flying: Color
    let flown: Color
    let drive: Color

    /// One night layer. `NightShade` stacks seven of these.
    static let night = Color(red: 0.02, green: 0.05, blue: 0.16).opacity(NightShade.layerAlpha)

    static let onDarkMap = TripMapPalette(
        upcoming: Color(red: 0.62, green: 0.76, blue: 1.0),
        flying: Color(red: 0.62, green: 0.76, blue: 1.0),
        flown: Color(white: 0.82),
        drive: .white
    )

    static let onLightMap = TripMapPalette(upcoming: .blue.opacity(0.6), flying: .blue, flown: .gray, drive: .gray)

    func color(for style: RouteSegment.Style) -> Color {
        switch style {
        case .upcoming: upcoming
        case .flying: flying
        case .flown: flown
        case .drive: drive
        }
    }

    func stroke(for style: RouteSegment.Style) -> StrokeStyle {
        switch style {
        case .upcoming: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 6])
        case .flying: StrokeStyle(lineWidth: 3, lineCap: .round)
        case .flown: StrokeStyle(lineWidth: 2.5, lineCap: .round)
        case .drive: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [0.5, 6])
        }
    }
}
```

- [ ] **Step 3: `TripMapMarkers`.** These are fixed-size map graphics, like MapKit's own markers, so they don't scale with Dynamic Type. The card's VoiceOver sentence describes them, and they're hidden from VoiceOver themselves.

```swift
//
//  TripMapMarkers.swift
//  CrewLuve
//
//  The trip map's small fixed-size markers (moving map spec §5.1, §7.1). VoiceOver reads the card's sentence
//  instead of these.
//

import SwiftUI

enum TripMapMarkers {

    /// A white dot under each airport's code.
    struct Airport: View {
        var body: some View {
            Circle()
                .fill(.white)
                .frame(width: 7, height: 7)
                .overlay(Circle().stroke(.black.opacity(0.4), lineWidth: 0.5))
                .accessibilityHidden(true)
        }
    }

    /// Where the pilot is.
    struct Heart: View {
        var body: some View {
            Image(systemName: "heart.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(.pink))
                .overlay(Circle().stroke(.white, lineWidth: 1.5))
                .accessibilityHidden(true)
        }
    }

    /// A drive, parked halfway along it, or where the pilot is while driving.
    struct Car: View {
        var body: some View {
            Image(systemName: "car.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(.black.opacity(0.45)))
                .overlay(Circle().stroke(.white, lineWidth: 1))
                .accessibilityHidden(true)
        }
    }
}
```

- [ ] **Step 4: `PlaneMarker`.**

```swift
//
//  PlaneMarker.swift
//  CrewLuve
//
//  The schedule's plane (moving map spec §7.2): a white outline circle, turning the short way round between legs.
//  Stage 3 adds the filled live plane beside it.
//

import SwiftUI

struct PlaneMarker: View {
    /// `PlaneHeading`'s angle: 0 points east, positive turns clockwise.
    let angle: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shownAngle: Double?

    var body: some View {
        Image(systemName: "airplane")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white)
            .rotationEffect(.radians(shownAngle ?? angle))
            .frame(width: 26, height: 26)
            .background(Circle().fill(.black.opacity(0.35)))
            .overlay(Circle().stroke(.white, lineWidth: 1.5))
            .animation(reduceMotion ? nil : .snappy, value: shownAngle)
            .onChange(of: angle, initial: true) { _, newAngle in
                shownAngle = PlaneHeading.continuing(shownAngle ?? newAngle, toward: newAngle)
            }
            .accessibilityHidden(true)
    }
}
```

- [ ] **Step 5: `TripMapChip`.**

```swift
//
//  TripMapChip.swift
//  CrewLuve
//
//  A line of text on the card's map (moving map spec §5.2), on Liquid Glass so it reads over any map.
//

import SwiftUI

struct TripMapChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .glassEffect(.regular, in: .capsule)
    }
}
```

- [ ] **Step 6: `TripMapView`.**

```swift
//
//  TripMapView.swift
//  CrewLuve
//
//  The trip map itself (moving map spec §7.1, §10): SwiftUI's `Map` with night, routes, airports, cars, the heart
//  and the plane. It renders `TripMapDrawing` and decides nothing. North stays up: the map pans and zooms but never
//  rotates or tilts, which is what lets `PlaneHeading` aim the plane from coordinates alone.
//

import MapKit
import SwiftUI

struct TripMapView: View {
    let tripMap: TripMap
    let date: Date
    let style: TripMapStyle
    /// How often the night is redrawn, in trip seconds (`TripMapDrawing.nightDate`).
    var nightStep: TimeInterval = 60
    @Binding var position: MapCameraPosition
    var isInteractive = false

    var body: some View {
        let drawing = TripMapDrawing(tripMap: tripMap, at: date)
        let night = NightBand.bands(at: TripMapDrawing.nightDate(for: date, step: nightStep))
        let palette = style.palette
        Map(position: $position, interactionModes: isInteractive ? [.pan, .zoom] : []) {
            ForEach(night) { band in
                MapPolygon(coordinates: band.coordinates)
                    .foregroundStyle(TripMapPalette.night)
            }
            ForEach(drawing.segments) { segment in
                MapPolyline(coordinates: segment.coordinates, contourStyle: segment.isGeodesic ? .geodesic : .straight)
                    .stroke(palette.color(for: segment.style), style: palette.stroke(for: segment.style))
            }
            ForEach(drawing.airports) { airport in
                Annotation(airport.code, coordinate: airport.coordinate) {
                    TripMapMarkers.Airport()
                }
            }
            ForEach(drawing.cars) { car in
                Annotation("", coordinate: car.coordinate) {
                    TripMapMarkers.Car()
                }
                .annotationTitles(.hidden)
            }
            if let pin = drawing.pin {
                Annotation("", coordinate: pin.coordinate, anchor: .bottom) {
                    TripMapMarkers.Heart()
                }
                .annotationTitles(.hidden)
            }
            if let plane = drawing.plane {
                Annotation("", coordinate: plane.coordinate) {
                    PlaneMarker(angle: plane.angle)
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(style.mapStyle)
    }
}
```

- [ ] **Step 7: `TripMap+Camera`.**

```swift
//
//  TripMap+Camera.swift
//  CrewLuve
//
//  Where the trip map's camera looks (moving map spec §6): one leg, or the whole trip and home.
//

import MapKit
import SwiftUI

extension TripMap {
    func camera(focusingOn leg: MapLeg?) -> MapCameraPosition {
        guard let rect = MapFit.rect(enclosing: framingCoordinates(focusingOn: leg)) else { return .automatic }
        return .rect(rect)
    }
}
```

- [ ] **Step 8: Checkpoint (Todd).** Build the app in Xcode (⌘B). Expected: it builds, with no new warnings in these files. Nothing shows the map yet.

- [ ] **Step 9: Ask to commit.** Suggested message: `feat(crewluve): the trip map view: night, routes, airports, cars, the heart and the plane (moving map spec §7.1, §10)`

---

### Task 13: The card on the status screen

**Files:**
- Create: `Crewluv/Services/TripMap/TripMap+Status.swift`
- Create: `Crewluv/Views/TripMap/TripMapCard.swift`
- Create: `Crewluv/Views/TripMap/TripMapInFlightBar.swift`
- Create: `Crewluv/Views/TripMap/TripMapStatsBar.swift`
- Create: `Crewluv/Views/TripMap/TripMapPreviews.swift`
- Create: `Crewluv/Views/Status/FlightDelayBanner.swift`
- Create: `Crewluv/Views/Status/RouteFallbackView.swift`
- Modify: `Crewluv/Views/Status/PilotStatusView.swift` (the card stack around line 191; `LocationCardView.inFlightView` around lines 503–520)
- Modify: `Crewluv/Utils/AirportDataProvider.swift:22`
- Delete: `Crewluv/Views/Status/FlightRouteMapView.swift`

- [ ] **Step 1: `TripMap+Status`, picking the legs.**

```swift
//
//  TripMap+Status.swift
//  CrewLuve
//
//  Which trip the status screen's map shows (moving map spec §5.1, §12):
//  - at home or base, the next trip;
//  - on a trip, that trip's legs;
//  - from a CrewLu too old to send legs, just the flight in the air.
//

import CoreLocation

extension TripMap {

    /// The status screen's trip map, or nil when there's nothing to draw.
    init?(status: SharedPilotStatus, at now: Date) {
        let airports = AirportDataProvider.shared
        let coordinate: (String) -> CLLocationCoordinate2D? = { code in
            airports.airportInfo(forIataCode: code).map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        }
        let isNextTrip = status.displayStatus.isSettled
        let legs: [TripLeg]
        if isNextTrip {
            guard let trip = UpcomingTripInfo.from(tripLegs: status.tripLegs, at: now, homeAirportCode: status.homeAirportCode) else { return nil }
            legs = status.tripLegs.filter { $0.tripId == trip.tripId }
        } else if status.hasTripLegs {
            legs = TripStateResolver.contiguousSegment(covering: now, in: status.tripLegs)
        } else {
            legs = Self.currentFlightLeg(of: status).map { [$0] } ?? []
        }
        guard let map = TripMap.make(tripLegs: legs, isNextTrip: isNextTrip,
                                     homeAirportCode: status.homeAirportCode ?? status.baseAirportCode,
                                     legacyDelayMinutes: status.flightDelayMinutes, at: now, coordinate: coordinate) else { return nil }
        self = map
    }

    /// The flight in the air, from the summary's `currentFlight*` fields, for a CrewLu that sends no legs.
    private static func currentFlightLeg(of status: SharedPilotStatus) -> TripLeg? {
        guard status.displayStatus == .inFlight,
              let departure = status.currentFlightDeparture, let arrival = status.currentFlightArrival,
              let start = status.currentFlightDepartureTime, let end = status.currentFlightArrivalTime else { return nil }
        return TripLeg(
            id: "current-flight", tripId: nil, type: .flight, startTime: start, endTime: end,
            airportCode: nil, city: nil, timezoneIdentifier: status.currentTimezone,
            arrivalTimezoneIdentifier: status.currentFlightArrivalTimezone, flightNumber: status.currentFlightNumber,
            departureAirport: departure, arrivalAirport: arrival, departureCity: nil, arrivalCity: nil,
            tripDayNumber: nil, tripTotalDays: nil, delayMinutes: nil, airlineCode: nil, label: nil
        )
    }
}
```

- [ ] **Step 2: `FlightDelayBanner`, moved out of `LocationCardView` unchanged in look.**

```swift
//
//  FlightDelayBanner.swift
//  CrewLuve
//
//  "DELAYED 45m" or "EARLY DEP 10m" under the in-flight map. Moved out of LocationCardView so the trip map's card
//  and the in-flight fallback share it.
//

import SwiftUI

struct FlightDelayBanner: View {
    /// Signed: positive late, negative early.
    let delayMinutes: Int

    var body: some View {
        let isEarly = delayMinutes < 0
        HStack(spacing: 6) {
            Image(systemName: isEarly ? "clock.badge.checkmark.fill" : "exclamationmark.triangle.fill")
                .font(.caption)
                .accessibilityHidden(true)
            Text("\(isEarly ? "EARLY DEP" : "DELAYED") \(LocationCardView.formatDelayDuration(abs(delayMinutes)))")
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(isEarly ? Color.green : Color.orange)
        .accessibilityElement(children: .combine)
    }
}
```

- [ ] **Step 3: `RouteFallbackView`, the old map's fallback.** It shows when the flight in the air can't be drawn.

```swift
//
//  RouteFallbackView.swift
//  CrewLuve
//
//  "SDF → CGN" in place of the map when an airport isn't in Crewluve's list (moving map spec §12).
//

import SwiftUI

struct RouteFallbackView: View {
    let departure: String?
    let arrival: String?

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "airplane")
                .font(.title2)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("\(departure ?? "???") → \(arrival ?? "???")")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Flying from \(departure ?? "an unknown airport") to \(arrival ?? "an unknown airport")")
    }
}
```

- [ ] **Step 4: `TripMapInFlightBar`.**

```swift
//
//  TripMapInFlightBar.swift
//  CrewLuve
//
//  The bar under the card's map in flight (moving map spec §5.3): the flight number, which opens the tracking links
//  as before, and the landing time, in the family's time and the destination's.
//

import SwiftUI

struct TripMapInFlightBar: View {
    let leg: MapLeg

    @State private var isShowingTracking = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                if let flightNumber = leg.flightNumber {
                    Button {
                        isShowingTracking = true
                    } label: {
                        Text(flightNumber)
                            .font(.headline)
                            .underline()
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Shows live tracking links")
                }
                Text("In flight")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(TripMapWording.landsAt(for: leg))
                    .font(.headline)
                    .monospacedDigit()
                if let local = TripMapWording.arrivalLocalTime(for: leg) {
                    Text(local)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .fullScreenCover(isPresented: $isShowingTracking) {
            if let flightNumber = leg.flightNumber {
                FlightTrackingPopupView(flightNumber: flightNumber)
            }
        }
    }
}
```

- [ ] **Step 5: `TripMapStatsBar`.**

```swift
//
//  TripMapStatsBar.swift
//  CrewLuve
//
//  The bar under the card's map on the ground (moving map spec §5.3): "Day 2 of 4 · 2 cities · 4,350 mi so far",
//  or a trip ahead's dates, cities and miles.
//

import SwiftUI

struct TripMapStatsBar: View {
    let items: [String]

    var body: some View {
        HStack {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index > 0 { Spacer(minLength: 8) }
                Text(item)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}
```

- [ ] **Step 6: `TripMapCard`.**

```swift
//
//  TripMapCard.swift
//  CrewLuve
//
//  The trip map on the status screen (moving map spec §5). In flight it follows the plane; on the ground it shows
//  the whole trip with a heart where the pilot is; at home, the next trip. Tapping the map opens it full screen.
//

import MapKit
import SwiftUI

struct TripMapCard: View {
    let tripMap: TripMap
    let status: SharedPilotStatus

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var position: MapCameraPosition
    @State private var isShowingFullScreen = false

    init(tripMap: TripMap, status: SharedPilotStatus) {
        self.tripMap = tripMap
        self.status = status
        _position = State(initialValue: tripMap.camera(focusingOn: tripMap.currentLeg))
    }

    var body: some View {
        // The plane moves about a pixel in ten seconds at this size, as today's map refreshed.
        TimelineView(.periodic(from: .now, by: 10)) { context in
            VStack(spacing: 0) {
                mapButton(at: context.date)
                if dynamicTypeSize.isAccessibilitySize {
                    stackedChips(at: context.date)
                }
                if tripMap.isInFlight, status.hasFlightDelay, let delay = status.effectiveFlightDelayMinutes {
                    FlightDelayBanner(delayMinutes: delay)
                }
                if let leg = tripMap.currentLeg {
                    TripMapInFlightBar(leg: leg)
                } else {
                    TripMapStatsBar(items: TripMapWording.statsItems(for: tripMap, at: context.date,
                                                                     dayNumber: status.tripDayNumber, totalDays: status.tripTotalDays))
                }
            }
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .onChange(of: tripMap.mode) {
            position = tripMap.camera(focusingOn: tripMap.currentLeg)
        }
        .fullScreenCover(isPresented: $isShowingFullScreen) {
            TripMapScreen(tripMap: tripMap, dayNumber: status.tripDayNumber, totalDays: status.tripTotalDays)
        }
    }

    private func mapButton(at date: Date) -> some View {
        let chips = TripMapWording.cardChips(for: tripMap, at: date)
        return Button {
            isShowingFullScreen = true
        } label: {
            TripMapView(tripMap: tripMap, date: date, style: .hybrid, position: $position)
                .allowsHitTesting(false)
                .frame(height: 220)
                .overlay(alignment: .topLeading) { overlayChip(chips.top) }
                .overlay(alignment: .bottomLeading) { overlayChip(chips.bottom) }
                .clipShape(.rect(topLeadingRadius: 20, topTrailingRadius: 20))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(TripMapWording.cardSummary(for: tripMap, now: date, pilotName: status.pilotFirstName))
        .accessibilityHint("Opens the full-screen map")
    }

    @ViewBuilder
    private func overlayChip(_ text: String?) -> some View {
        if let text, !dynamicTypeSize.isAccessibilitySize {
            TripMapChip(text: text)
                .padding(10)
        }
    }

    /// At the largest text sizes the chips would cover the map, so they move below it (moving map spec §14).
    private func stackedChips(at date: Date) -> some View {
        let chips = TripMapWording.cardChips(for: tripMap, at: date)
        return VStack(alignment: .leading, spacing: 6) {
            ForEach([chips.top, chips.bottom].compactMap { $0 }, id: \.self) { chip in
                Text(chip).font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, 10)
    }
}
```

> Before `TripMapScreen` exists (Task 14), Xcode won't build this file. Do Steps 1–9 of this task, then Task 14's Steps 1–4, then build. Or stub `TripMapScreen` with `Text("")` for one build and replace it in Task 14.

- [ ] **Step 7: Place the card in `PilotStatusView`.** In `Crewluv/Views/Status/PilotStatusView.swift`, replace:

```swift
                    // Location Card
                    LocationCardView(status: status)
```

with:

```swift
                    // Trip map (moving map spec §5): in flight it takes the location card's
                    // place; on the ground it sits above it.
                    let tripMap = TripMap(status: status, at: Date())
                    if let tripMap {
                        TripMapCard(tripMap: tripMap, status: status)
                    }

                    // Location Card
                    if tripMap?.isInFlight != true {
                        LocationCardView(status: status)
                    }
```

- [ ] **Step 8: The location card's in-flight view becomes the fallback.** In `LocationCardView.inFlightView`, replace:

```swift
            // Flight route map visualization
            FlightRouteMapView(status: status)

            // Delay / early banner
            if status.hasFlightDelay, let delayMinutes = status.effectiveFlightDelayMinutes {
                let isEarly = delayMinutes < 0
                HStack(spacing: 6) {
                    Image(systemName: isEarly ? "clock.badge.checkmark.fill" : "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text("\(isEarly ? "EARLY DEP" : "DELAYED") \(Self.formatDelayDuration(abs(delayMinutes)))")
                        .font(.caption.weight(.bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(isEarly ? Color.green : Color.orange)
            }
```

with:

```swift
            // Shown only when the trip map can't draw this flight (moving map spec §12)
            RouteFallbackView(departure: status.currentFlightDeparture, arrival: status.currentFlightArrival)

            if status.hasFlightDelay, let delayMinutes = status.effectiveFlightDelayMinutes {
                FlightDelayBanner(delayMinutes: delayMinutes)
            }
```

- [ ] **Step 9: Remove the old map.** Delete the file, and update the provider's comment:

```bash
git -C /Users/toddanderson/Dev/Crewluv rm Crewluv/Views/Status/FlightRouteMapView.swift
```

In `Crewluv/Utils/AirportDataProvider.swift`, change line 22 from `/// Provider for airport location data used by FlightRouteMapView` to `/// Provider for airport location data used by the trip map (TripMap+Status)`. Then confirm nothing else names the old map:

```bash
grep -rn "FlightRouteMapView" /Users/toddanderson/Dev/Crewluv/Crewluv
```

Expected: no output.

- [ ] **Step 10: Previews of every state.** Create `Crewluv/Views/TripMap/TripMapPreviews.swift`:

```swift
//
//  TripMapPreviews.swift
//  CrewLuve
//
//  The trip map card in each state, around the time the canvas opens: Louisville to Cologne to Dubai and home,
//  and Anchorage to Tokyo across the date line.
//

#if DEBUG
import CoreLocation
import SwiftUI

private enum TripMapPreviewData {

    static func coordinate(_ code: String) -> CLLocationCoordinate2D? {
        AirportDataProvider.shared.airportInfo(forIataCode: code).map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    static func flight(_ flightNumber: String, _ from: String, _ to: String, _ fromCity: String, _ toCity: String,
                       start: Date, hours: Double, zone: String, arrivalZone: String) -> TripLeg {
        TripLeg(id: flightNumber, tripId: "P1", type: .flight, startTime: start, endTime: start.addingTimeInterval(hours * 3600),
                airportCode: nil, city: nil, timezoneIdentifier: zone, arrivalTimezoneIdentifier: arrivalZone,
                flightNumber: flightNumber, departureAirport: from, arrivalAirport: to,
                departureCity: fromCity, arrivalCity: toCity, tripDayNumber: nil, tripTotalDays: nil,
                delayMinutes: nil, airlineCode: nil, label: nil)
    }

    /// The Europe trip, `hoursIn` hours after its first departure.
    static func europe(hoursIn: Double, isNextTrip: Bool = false) -> TripMap? {
        let now = Date()
        let start = now.addingTimeInterval(-hoursIn * 3600)
        let legs = [
            flight("UPS207", "SDF", "CGN", "Louisville", "Cologne", start: start, hours: 8, zone: "America/New_York", arrivalZone: "Europe/Berlin"),
            flight("UPS208", "CGN", "DXB", "Cologne", "Dubai", start: start.addingTimeInterval(32 * 3600), hours: 6, zone: "Europe/Berlin", arrivalZone: "Asia/Dubai"),
            flight("UPS209", "DXB", "SDF", "Dubai", "Louisville", start: start.addingTimeInterval(58 * 3600), hours: 14, zone: "Asia/Dubai", arrivalZone: "America/New_York"),
        ]
        return TripMap.make(tripLegs: legs, isNextTrip: isNextTrip, homeAirportCode: "SDF", legacyDelayMinutes: nil, at: now, coordinate: coordinate)
    }

    static var pacific: TripMap? {
        let start = Date().addingTimeInterval(-3 * 3600)
        let legs = [flight("UPS61", "ANC", "NRT", "Anchorage", "Tokyo", start: start, hours: 8, zone: "America/Anchorage", arrivalZone: "Asia/Tokyo")]
        return TripMap.make(tripLegs: legs, isNextTrip: false, homeAirportCode: "SDF", legacyDelayMinutes: nil, at: Date(), coordinate: coordinate)
    }
}

#Preview("In flight") {
    if let map = TripMapPreviewData.europe(hoursIn: 4) {
        TripMapCard(tripMap: map, status: .demo).padding()
    }
}

#Preview("Layover") {
    if let map = TripMapPreviewData.europe(hoursIn: 12) {
        TripMapCard(tripMap: map, status: .demo).padding()
    }
}

#Preview("Next trip") {
    if let map = TripMapPreviewData.europe(hoursIn: -48, isNextTrip: true) {
        TripMapCard(tripMap: map, status: .demo).padding()
    }
}

#Preview("Across the date line") {
    if let map = TripMapPreviewData.pacific {
        TripMapCard(tripMap: map, status: .demo).padding()
    }
}

#Preview("Full screen, in flight") {
    if let map = TripMapPreviewData.europe(hoursIn: 4) {
        TripMapScreen(tripMap: map, dayNumber: 1, totalDays: 4)
    }
}
#endif
```

- [ ] **Step 11: Checkpoint (Todd), after Task 14 builds.** Open `TripMapPreviews.swift` in Xcode's canvas. Check each preview:
  - **In flight:** the leg fills the card; solid blue behind the plane and dashed ahead; "Landing in …" bottom-left; the flight number and "Lands …" in the bar.
  - **Layover:** the whole trip, with Louisville to Cologne grey; the heart on Cologne; "Cologne · … there" top-left and "Next: Dubai, …" bottom-left; "N cities · … mi so far".
  - **Next trip:** every leg dashed; the heart on Louisville; "Home · next trip …".
  - **Across the date line:** the North Pacific framed, not the whole world.
  - **All:** night shading with a soft edge, and the airports' codes.

- [ ] **Step 12: Ask to commit.** Suggested message: `feat(crewluv): the trip map card replaces the in-flight map; on the ground it sits above the location card (moving map spec §5)`

---

### Task 14: The full-screen map

**Files:**
- Create: `Crewluv/Views/TripMap/TripMapScreen.swift`
- Create: `Crewluv/Views/TripMap/TripMapTopBar.swift`
- Create: `Crewluv/Views/TripMap/TripMapPanel.swift`
- Create: `Crewluv/Views/TripMap/TripTimelineControl.swift`

The panel is a Liquid Glass panel in the safe-area inset, not a `.sheet`. In Stage 1 it holds only a line and the timeline, and it needs the replay time on every tick, which a sheet presented from the cover can't share without a second timeline. Stage 2, when facts fill it, decides whether it becomes a resizable sheet.

- [ ] **Step 1: `TripTimelineControl`.**

```swift
//
//  TripTimelineControl.swift
//  CrewLuve
//
//  Play, drag through the trip, go back to Live, and pick 1x to 10x (moving map spec §6).
//

import SwiftUI

struct TripTimelineControl: View {
    @Binding var clock: TripReplayClock
    /// The trip time on screen.
    let time: Date
    /// The real time of this tick.
    let now: Date

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                playButton
                Slider(value: sliderValue, in: range)
                    .accessibilityLabel("Trip time")
                    .accessibilityValue(TripMapWording.timelineTime(time))
                if !clock.isLive {
                    Button("Live") { clock.goLive() }
                        .buttonStyle(.bordered)
                        .accessibilityHint("Shows where things are now")
                }
            }
            HStack {
                Text(TripMapWording.timelineTime(time))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("Replay speed", selection: speed) {
                    ForEach(TripReplayClock.Speed.allCases) { speed in
                        Text("\(speed.rawValue)×").tag(speed)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
        }
    }

    private var isShowingPause: Bool {
        clock.isPlaying && !clock.hasFinished(at: now)
    }

    private var playButton: some View {
        Button {
            if isShowingPause { clock.pause(at: .now) } else { clock.play(at: .now) }
        } label: {
            Image(systemName: isShowingPause ? "pause.fill" : "play.fill")
                .imageScale(.large)
        }
        .accessibilityLabel(isShowingPause ? "Pause replay" : "Replay the trip")
    }

    private var range: ClosedRange<Double> {
        clock.span.start.timeIntervalSince1970...clock.span.end.timeIntervalSince1970
    }

    private var sliderValue: Binding<Double> {
        Binding(
            get: { min(max(time.timeIntervalSince1970, range.lowerBound), range.upperBound) },
            set: { clock.scrub(to: Date(timeIntervalSince1970: $0)) }
        )
    }

    private var speed: Binding<TripReplayClock.Speed> {
        Binding(get: { clock.speed }, set: { clock.setSpeed($0, at: .now) })
    }
}
```

- [ ] **Step 2: `TripMapPanel`.**

```swift
//
//  TripMapPanel.swift
//  CrewLuve
//
//  The full-screen map's panel (moving map spec §6): where they are or when they land, and the timeline. Stage 2
//  adds a row for each kind of fact.
//

import SwiftUI

struct TripMapPanel: View {
    let headline: String
    @Binding var clock: TripReplayClock
    let time: Date
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !headline.isEmpty {
                Text(headline)
                    .font(.headline)
            }
            TripTimelineControl(clock: $clock, time: time, now: now)
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }
}
```

- [ ] **Step 3: `TripMapTopBar`.**

```swift
//
//  TripMapTopBar.swift
//  CrewLuve
//
//  Close, what's happening, recenter and map style, along the top of the full-screen map (moving map spec §6).
//

import SwiftUI

struct TripMapTopBar: View {
    let pill: String
    let style: TripMapStyle
    let isShowingRecenter: Bool
    let onClose: () -> Void
    let onRecenter: () -> Void
    let onNextStyle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onClose) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.glass)
            .accessibilityLabel("Close map")

            Spacer(minLength: 0)
            Text(pill)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .glassEffect(.regular, in: .capsule)
            Spacer(minLength: 0)

            if isShowingRecenter {
                Button(action: onRecenter) {
                    Image(systemName: "location.fill")
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Recenter map")
            }
            Button(action: onNextStyle) {
                Image(systemName: "map")
            }
            .buttonStyle(.glass)
            .accessibilityLabel("Map style")
            .accessibilityValue(style.name)
        }
        .padding(.horizontal)
    }
}
```

- [ ] **Step 4: `TripMapScreen`.**

```swift
//
//  TripMapScreen.swift
//  CrewLuve
//
//  The full-screen trip map (moving map spec §6): pan and zoom, change the style, and replay the trip. Opens on the
//  leg in the air, or on the whole trip. On iPhone the panel sits at the bottom; on iPad and in landscape it floats
//  at the side.
//

import MapKit
import SwiftUI

struct TripMapScreen: View {
    let tripMap: TripMap
    let dayNumber: Int?
    let totalDays: Int?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var clock: TripReplayClock
    @State private var style: TripMapStyle = .hybrid
    @State private var position: MapCameraPosition

    init(tripMap: TripMap, dayNumber: Int?, totalDays: Int?) {
        self.tripMap = tripMap
        self.dayNumber = dayNumber
        self.totalDays = totalDays
        _clock = State(initialValue: TripReplayClock(span: tripMap.span))
        _position = State(initialValue: tripMap.camera(focusingOn: tripMap.currentLeg))
    }

    var body: some View {
        // Every second live; about 30 times a second while a replay runs.
        TimelineView(.periodic(from: .now, by: clock.isPlaying ? 1.0 / 30 : 1)) { context in
            let time = clock.time(at: context.date)
            screen(time: time, now: context.date)
                .onChange(of: tripMap.legInMotion(at: time)?.id) { _, legID in
                    refit(legID: legID)
                }
        }
    }

    @ViewBuilder
    private func screen(time: Date, now: Date) -> some View {
        let map = TripMapView(tripMap: tripMap, date: time, style: style, nightStep: nightStep,
                              position: $position, isInteractive: true)
            .ignoresSafeArea()
            .overlay(alignment: .top) { topBar(time: time) }
        let panel = TripMapPanel(headline: TripMapWording.panelHeadline(for: tripMap, at: time),
                                 clock: $clock, time: time, now: now)
        if usesSidePanel {
            map.overlay(alignment: .bottomLeading) {
                panel.frame(maxWidth: 380).padding()
            }
        } else {
            map.safeAreaInset(edge: .bottom) {
                panel.padding(.horizontal).padding(.bottom, 8)
            }
        }
    }

    private func topBar(time: Date) -> some View {
        TripMapTopBar(
            pill: TripMapWording.topPill(for: tripMap, at: time, dayNumber: dayNumber, totalDays: totalDays),
            style: style,
            isShowingRecenter: position.positionedByUser,
            onClose: { dismiss() },
            onRecenter: { refit(legID: tripMap.legInMotion(at: time)?.id, force: true) },
            onNextStyle: { style = style.next }
        )
    }

    /// iPad, and iPhone in landscape.
    private var usesSidePanel: Bool {
        horizontalSizeClass == .regular || verticalSizeClass == .compact
    }

    /// Night moves about a degree every four minutes. Live it's redrawn each minute; in replay about ten times a
    /// second of real time, whatever the speed (moving map spec §10).
    private var nightStep: TimeInterval {
        clock.isPlaying ? TripReplayClock.baseRate / 10 * Double(clock.speed.rawValue) : 60
    }

    /// Frames the leg in motion, or the whole trip. Leaves a camera the family moved alone, unless they asked.
    private func refit(legID: String?, force: Bool = false) {
        guard force || !position.positionedByUser else { return }
        let leg = legID.flatMap { id in tripMap.legs.first { $0.id == id } }
        let camera = tripMap.camera(focusingOn: leg)
        if reduceMotion {
            position = camera
        } else {
            withAnimation(.smooth) { position = camera }
        }
    }
}
```

- [ ] **Step 5: Checkpoint (Todd).** Build (⌘B). Then, in the canvas or on the simulator:
  - Open "Full screen, in flight" from `TripMapPreviews.swift`. Close, the pill, style and the panel are all visible.
  - Tap play: the planes and the night sweep across the trip. The camera re-frames each leg as replay reaches it.
  - Drag the slider: a Live button appears; tap it to return.
  - 10× runs the whole trip in about 15 s. Watch that the night redraws smoothly. If it stutters, raise `nightStep`'s divisor from 10 to 5 and recheck.
  - Pan the map: the recenter button appears, and tapping it frames the leg again.
  - Rotate the simulator to landscape: the panel moves to the leading side.
  - Turn on Settings ▸ Accessibility ▸ Motion ▸ Reduce Motion: the camera jumps instead of gliding.

- [ ] **Step 6: Ask to commit.** Suggested message: `feat(crewluv): the full-screen trip map, with styles, recenter and a replayable timeline (moving map spec §6)`

---

### Task 15: Docs, and a check of the whole status screen

**Files:**
- Modify: `CLAUDE.md` (Key Components and File Structure)

- [ ] **Step 1: `CLAUDE.md`, Key Components.** After the "Data Model" subsection and before "### App Flow", add:

```markdown
#### Trip Map (`Services/TripMap/`, `Views/TripMap/`)
- The status screen's map (moving map spec `docs/superpowers/specs/2026-11-13-crewluve-moving-map-design.md`): the whole trip on the ground with a heart where the pilot is, the next trip from home, and the plane in the air. In flight it takes the location card's place; on the ground it sits above it
- Built on SwiftUI's `Map` (`MapPolyline`, `MapPolygon`, `Annotation`); north stays up, so `PlaneHeading` aims the plane from coordinates alone
- The logic is `nonisolated` and tested: `TripMap` (which legs, the mode, where the pilot is), `TripMapDrawing` (what to draw at an instant), `FlightProgress` (the schedule's plane, with taxi allowances), `TripReplayClock`, `TripMapWording`. The maths in `Utils/` (`NightShade`, `PlaneHeading`, `MapFit`, `GreatCircle`) came from CrewLu's moving map with its tests
- `CrewluvTests/Fixtures/TripMap/progress-cases.json` holds the schedule's plane to the same answers as the website: change both copies together
```

- [ ] **Step 2: `CLAUDE.md`, File Structure.** In the tree:
  - under `├── Views/`, add `│   ├── TripMap/             # The trip map card and full-screen map`;
  - under `└── Services/`, add `│   ├── TripMap/                      # The trip map's model, drawing, clock and words`.

- [ ] **Step 3: Checkpoint (Todd), the whole screen on the simulator.** Run the app and enter demo mode. Check:
  - The demo pilot's state shows the map card with the location card beneath it, and the weather, local time and sun circle are all still there.
  - With a real connection on a day the pilot flies, or with the previews: the card takes the location card's place in flight. The flight number still opens the tracking links, and the delay banner shows under the map when there's a delay.
  - Dark Mode: the card's glass and bar adapt, and the map reads the same.
  - Dynamic Type at AX3: the chips move below the map, and nothing is cut off.
  - VoiceOver on the card reads one sentence, then "Opens the full-screen map".

- [ ] **Step 4: Ask to commit.** Suggested message: `docs(crewluv): the trip map in CLAUDE.md`

- [ ] **Step 5: Release note.** After the user-visible commits land, draft the "Crewluve revisions" entry per the release-notes memory, for the version Todd names. Suggested words:

  > The map is new. It shows the whole trip: every city, where they are tonight, and the next trip while they're home. In the air it follows the plane over a real map, with day and night drawn as they really are. Tap it to open it full screen, change the map's look, and replay the trip.

---

## Changes made during execution (2026-11-13)

Review findings applied to the code after it was written from this plan. The code, not the blocks above, is the reference for these:

- **Task 5:** `aimFractions`'s default reads `PlaneHeading.lookAhead`, so it doesn't look like it names its own parameter.
- **Task 6:** the Anchorage–Tokyo test pads by 10%, so both airports sit strictly inside the rectangle and not on its edge.
- **Tasks 8–11:**
  - Nested enums (`TripMap.Mode`, `MapLeg.Kind`, `RouteSegment.Style`, `TripReplayClock.Speed`) are marked `nonisolated`, like `TripLeg.LegType`, so the tests can use their conformances.
  - The trip's span starts at its earliest leg, which an early departure can move.
  - VoiceOver reads the next trip's city names, not codes.
  - The bar leaves out "0 cities" and empty items.
  - `dateRange` gives "Nov 13–Nov 20" for six days or more.
  - `isPlaying`'s doc says to check `hasFinished(at:)`.
  - New tests: `test_span_withAnEarlyLegLaterInTheList_startsAtTheEarliestLeg`, `test_cardSummary_nextTrip_readsCityNames`, `test_dateRange_aWeekOrMore_givesDates` and `test_statsItems_onTripWithNoFlights_leavesOutTheCityCount`.
- **Tasks 12–14 (from the views' review):**
  - The full-screen map: only the map ignores the safe area (a `ZStack` with the top bar), and the top bar is a `GlassEffectContainer` with circular, large glass buttons.
  - The card's label has `.contentShape(.rect)`, so taps reach it through the non-hit-testing map. The camera reframes when the trip's legs change, not only its mode.
  - Tap targets are 44 pt: play, and the flight number.
  - At accessibility text sizes, the speed picker is a menu and the bars stack (`ViewThatFits`).
  - The standard map uses the light palette only in light mode (`TripMapStyle.palette(for:)`).
  - The slider's range is never empty.
  - VoiceOver: the panel's headline is a header, and the stacked chips and the timeline's time text are hidden as duplicates.
  - Previews pass the airport lookup as a closure.
- **From the final review:** when the legs don't cover now but the summary says the pilot is in flight (stale legs, or a flight running late past them), `TripMap+Status` falls back to the `currentFlight*` leg, as the old map did, instead of showing only "SDF → CGN". The final review's "stale mode" point is already covered: `PartnerStatusReceiver` re-resolves and republishes the status at each leg boundary.
