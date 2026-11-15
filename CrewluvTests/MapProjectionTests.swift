//
//  MapProjectionTests.swift
//  CrewluvTests
//
//  Where places on the flat map are on screen, worked out from three places the map is asked about (moving map spec
//  §10). Ported from CrewLu's FlatMapFitTests; cutting off, the date line and the route lines are in
//  MapProjectionClippingTests. Every expected value is plain geometry worked out here, none copied from the code
//  under test.
//

import XCTest
import CoreGraphics
import CoreLocation
@testable import Crewluv

final class MapProjectionTests: XCTestCase {

    private let view = ProjectionTestGeometry.view

    private func place(_ latitude: Double, _ longitude: Double) -> CLLocationCoordinate2D {
        ProjectionTestGeometry.place(latitude, longitude)
    }

    private func area(_ outline: [CGPoint]) -> Double {
        ProjectionTestGeometry.area(outline)
    }

    private func assertInside(_ outline: [CGPoint], _ rect: CGRect, file: StaticString = #filePath, line: UInt = #line) {
        ProjectionTestGeometry.assertInside(outline, rect, file: file, line: line)
    }

    // MARK: - Places on the flat map

    func test_point_middleAndEdges_landWhereTheMapHasThem() {
        let middle = MapProjection.point(for: place(0, 0))
        XCTAssertEqual(middle.x, 0.5, accuracy: 1e-12)
        XCTAssertEqual(middle.y, 0.5, accuracy: 1e-12)
        XCTAssertEqual(MapProjection.point(for: place(0, -180)).x, 0, accuracy: 1e-12)
        XCTAssertEqual(MapProjection.point(for: place(0, 180)).x, 1, accuracy: 1e-12)
        XCTAssertEqual(MapProjection.point(for: place(0, 90)).x, 0.75, accuracy: 1e-12)
    }

    func test_point_north_isTowardsTheTopOfASquareMap() {
        let north = MapProjection.point(for: place(60, 0))
        let south = MapProjection.point(for: place(-60, 0))
        XCTAssertLessThan(north.y, 0.5)
        XCTAssertEqual(north.y + south.y, 1, accuracy: 1e-12)
        // The flat map's top edge is where the map is as tall as it is wide: latitude atan(sinh(pi)).
        let topEdge = atan(sinh(Double.pi)) * 180 / .pi
        XCTAssertEqual(topEdge, 85.0511, accuracy: 0.0001)
        // The app's own limit is a touch inside that edge, so its y is a touch more than nothing.
        let held = MapProjection.point(for: place(NightShade.maxLatitude, 0)).y
        XCTAssertGreaterThanOrEqual(held, 0)
        XCTAssertLessThan(held, 0.0001)
    }

    func test_point_beyondTheMapsEdge_isHeldAtTheEdge() {
        XCTAssertEqual(MapProjection.point(for: place(90, 10)).y, MapProjection.point(for: place(NightShade.maxLatitude, 10)).y)
        XCTAssertEqual(MapProjection.point(for: place(-90, 10)).y, MapProjection.point(for: place(-NightShade.maxLatitude, 10)).y)
    }

    func test_coordinate_ofAPoint_isThePlaceItCameFrom() {
        for latitude in stride(from: -80.0, through: 80.0, by: 20.0) {
            for longitude in stride(from: -170.0, through: 170.0, by: 34.0) {
                let back = MapProjection.coordinate(for: MapProjection.point(for: place(latitude, longitude)))
                XCTAssertEqual(back.latitude, latitude, accuracy: 1e-9)
                XCTAssertEqual(back.longitude, longitude, accuracy: 1e-9)
            }
        }
    }

    // MARK: - The two other places

    func test_probes_awayFromTheEdges_stepEastAndSouth() {
        let probes = MapProjection.probes(around: FlatMapPoint(x: 0.5, y: 0.5), step: 0.1)
        XCTAssertEqual(probes.east.x, 0.6, accuracy: 1e-12)
        XCTAssertEqual(probes.east.y, 0.5, accuracy: 1e-12)
        XCTAssertEqual(probes.south.x, 0.5, accuracy: 1e-12)
        XCTAssertEqual(probes.south.y, 0.6, accuracy: 1e-12)
    }

    func test_probes_nextToAnEdge_stepTheOtherWay() {
        let probes = MapProjection.probes(around: FlatMapPoint(x: 0.95, y: 0.97), step: 0.1)
        XCTAssertEqual(probes.east.x, 0.85, accuracy: 1e-12)
        XCTAssertEqual(probes.south.y, 0.87, accuracy: 1e-12)
        // Never across the date line from the centre, and never off the map.
        for x in stride(from: 0.0, through: 1.0, by: 0.01) {
            for y in stride(from: 0.0, through: 1.0, by: 0.05) {
                let pair = MapProjection.probes(around: FlatMapPoint(x: x, y: y), step: 0.25)
                XCTAssertTrue((0...1).contains(pair.east.x), "east probe at \(pair.east.x) from \(x)")
                XCTAssertTrue((0...1).contains(pair.south.y), "south probe at \(pair.south.y) from \(y)")
                XCTAssertNotEqual(pair.east.x, x)
                XCTAssertNotEqual(pair.south.y, y)
            }
        }
    }

    // MARK: - The projection

    func test_init_slidScaledAndTurnedMap_matchesEveryPlace() throws {
        let centers = [FlatMapPoint(x: 0.5, y: 0.5), FlatMapPoint(x: 0.999, y: 0.4), FlatMapPoint(x: 0.001, y: 0.6),
                       FlatMapPoint(x: 0.3, y: 0.99), FlatMapPoint(x: 0.7, y: 0.01)]
        let places = [FlatMapPoint(x: 0.5, y: 0.5), FlatMapPoint(x: 0, y: 0), FlatMapPoint(x: 1, y: 1),
                      FlatMapPoint(x: 0.123, y: 0.876), FlatMapPoint(x: 1.4, y: 0.3), FlatMapPoint(x: -0.6, y: 0.7)]
        for center in centers {
            for degrees in [0.0, 37.0, 90.0, 180.0, -120.0] {
                for worldWidth in [400.0, 5_000.0] {
                    let map = MadeUpMap(center: center, origin: CGPoint(x: 480, y: 290), worldWidth: worldWidth, degrees: degrees)
                    let projection = try XCTUnwrap(map.projection(), "no projection at \(center), \(degrees) degrees")
                    for place in places {
                        let ours = projection.screenPoint(for: place)
                        let theirs = map.screen(place)
                        XCTAssertEqual(Double(ours.x), Double(theirs.x), accuracy: 0.001, "\(center) \(degrees) \(place)")
                        XCTAssertEqual(Double(ours.y), Double(theirs.y), accuracy: 0.001, "\(center) \(degrees) \(place)")
                    }
                }
            }
        }
    }

    func test_screenPoint_northUp_putsEastRightAndSouthDown() throws {
        let map = MadeUpMap(center: FlatMapPoint(x: 0.5, y: 0.5), origin: CGPoint(x: 500, y: 300), worldWidth: 400, degrees: 0)
        let projection = try XCTUnwrap(map.projection())
        // Tokyo is east of the middle of the map and north of it: right of centre and above it.
        let tokyo = projection.screenPoint(for: MapProjection.point(for: place(35.68, 139.69)))
        XCTAssertGreaterThan(tokyo.x, 500)
        XCTAssertLessThan(tokyo.y, 300)
        // A quarter of the world east of the middle is a quarter of 400 points to the right.
        let quarter = projection.screenPoint(for: FlatMapPoint(x: 0.75, y: 0.5))
        XCTAssertEqual(Double(quarter.x), 600, accuracy: 1e-9)
        XCTAssertEqual(Double(quarter.y), 300, accuracy: 1e-9)
    }

    func test_screenPoint_nextCopyOfTheWorld_isOneWorldAlong() throws {
        let map = MadeUpMap(center: FlatMapPoint(x: 0.5, y: 0.5), origin: CGPoint(x: 500, y: 300), worldWidth: 400, degrees: 0)
        let projection = try XCTUnwrap(map.projection())
        let here = projection.screenPoint(for: FlatMapPoint(x: 0.2, y: 0.5))
        XCTAssertEqual(Double(projection.screenPoint(for: FlatMapPoint(x: 0.2, y: 0.5), copy: 1).x), Double(here.x) + 400, accuracy: 1e-9)
        XCTAssertEqual(Double(projection.screenPoint(for: FlatMapPoint(x: 0.2, y: 0.5), copy: -1).x), Double(here.x) - 400, accuracy: 1e-9)
    }

    func test_flatPoint_ofAScreenPoint_isThePlaceItCameFrom() throws {
        let map = MadeUpMap(center: FlatMapPoint(x: 0.31, y: 0.44), origin: CGPoint(x: 400, y: 250), worldWidth: 2_000, degrees: 37)
        let projection = try XCTUnwrap(map.projection())
        for place in [FlatMapPoint(x: 0.31, y: 0.44), FlatMapPoint(x: 0.9, y: 0.1), FlatMapPoint(x: 1.7, y: 0.8)] {
            let back = projection.flatPoint(at: projection.screenPoint(for: place))
            XCTAssertEqual(back.x, place.x, accuracy: 1e-9)
            XCTAssertEqual(back.y, place.y, accuracy: 1e-9)
        }
    }

    func test_init_threePlacesThatFixNoMap_isNil() {
        let center = FlatMapPoint(x: 0.5, y: 0.5)
        let probes = MapProjection.probes(around: center, step: 0.05)
        let spot = CGPoint(x: 100, y: 100)
        // A map with no size yet puts everything on one point.
        XCTAssertNil(MapProjection(center: center, eastProbe: probes.east, southProbe: probes.south,
                                   centerOnScreen: spot, eastOnScreen: spot, southOnScreen: spot))
        // All three on one line.
        XCTAssertNil(MapProjection(center: center, eastProbe: probes.east, southProbe: probes.south,
                                   centerOnScreen: spot, eastOnScreen: CGPoint(x: 200, y: 100), southOnScreen: CGPoint(x: 300, y: 100)))
        // Not a number.
        XCTAssertNil(MapProjection(center: center, eastProbe: probes.east, southProbe: probes.south,
                                   centerOnScreen: CGPoint(x: CGFloat.nan, y: 100), eastOnScreen: CGPoint(x: 200, y: 100),
                                   southOnScreen: CGPoint(x: 100, y: 200)))
        XCTAssertNil(MapProjection(center: FlatMapPoint(x: .nan, y: 0.5), eastProbe: probes.east, southProbe: probes.south,
                                   centerOnScreen: spot, eastOnScreen: CGPoint(x: 200, y: 100), southOnScreen: CGPoint(x: 100, y: 200)))
        // Screen points so far apart that the size of the world they give is past what a number can hold.
        XCTAssertNil(MapProjection(center: center, eastProbe: probes.east, southProbe: probes.south,
                                   centerOnScreen: spot, eastOnScreen: CGPoint(x: 1e200, y: 100), southOnScreen: CGPoint(x: 100, y: 1e200)))
        // The two other places must not be the centre itself.
        XCTAssertNil(MapProjection(center: center, eastProbe: center, southProbe: probes.south,
                                   centerOnScreen: spot, eastOnScreen: CGPoint(x: 200, y: 100), southOnScreen: CGPoint(x: 100, y: 200)))
    }

    func test_equality_sameMap_isTheSameProjection() throws {
        let map = MadeUpMap(center: FlatMapPoint(x: 0.5, y: 0.5), origin: CGPoint(x: 500, y: 300), worldWidth: 400, degrees: 0)
        XCTAssertEqual(try XCTUnwrap(map.projection()), try XCTUnwrap(map.projection()))
        let moved = MadeUpMap(center: FlatMapPoint(x: 0.5, y: 0.5), origin: CGPoint(x: 501, y: 300), worldWidth: 400, degrees: 0)
        XCTAssertNotEqual(try XCTUnwrap(map.projection()), try XCTUnwrap(moved.projection()))
    }

    // MARK: - Copies of the world

    func test_copies_zoomedOut_everyCopyOnScreen() throws {
        // One world is 400 points wide and the view 1000: the view shows from 0.75 of a world west of the map's
        // left edge to 0.75 east of its right edge. That is three copies.
        let map = MadeUpMap(center: FlatMapPoint(x: 0.5, y: 0.5), origin: CGPoint(x: 500, y: 300), worldWidth: 400, degrees: 0)
        let projection = try XCTUnwrap(map.projection())
        XCTAssertEqual(projection.copies(touching: view), -1...1)
        XCTAssertEqual(projection.copies(touching: view, margin: 1), -2...2)
    }

    func test_copies_zoomedIn_onlyTheOne() throws {
        let map = MadeUpMap(center: FlatMapPoint(x: 0.3, y: 0.4), origin: CGPoint(x: 500, y: 300), worldWidth: 2_000_000, degrees: 0)
        let projection = try XCTUnwrap(map.projection())
        XCTAssertEqual(projection.copies(touching: view), 0...0)
        XCTAssertEqual(projection.copies(touching: view, margin: 1), -1...1)
    }

    func test_copies_overTheDateLine_bothSides() throws {
        // Centred just west of the date line, with a tenth of a world on screen: this copy and the next one east.
        let map = MadeUpMap(center: FlatMapPoint(x: 0.99, y: 0.5), origin: CGPoint(x: 500, y: 300), worldWidth: 10_000, degrees: 0)
        let projection = try XCTUnwrap(map.projection())
        XCTAssertEqual(projection.copies(touching: view), 0...1)
    }

    func test_copies_turnedMap_goesByWhatIsEastAndWestOnScreen() throws {
        // A tall, narrow view, 300 points wide and 1000 tall, centred on the middle of a world 400 points wide.
        let tall = CGRect(x: 350, y: -200, width: 300, height: 1000)
        // North up, its 300-point width shows three quarters of one world: one copy.
        let upright = MadeUpMap(center: FlatMapPoint(x: 0.5, y: 0.5), origin: CGPoint(x: 500, y: 300), worldWidth: 400, degrees: 0)
        XCTAssertEqual(try XCTUnwrap(upright.projection()).copies(touching: tall), 0...0)
        // Turned a quarter turn, east and west run up and down the screen: its 1000-point height shows two and a
        // half worlds, which is three copies.
        let turned = MadeUpMap(center: FlatMapPoint(x: 0.5, y: 0.5), origin: CGPoint(x: 500, y: 300), worldWidth: 400, degrees: 90)
        XCTAssertEqual(try XCTUnwrap(turned.projection()).copies(touching: tall), -1...1)
    }

    func test_copies_tinyWorld_neverPassTheLimit() throws {
        // A world two points wide would put five hundred copies in the view.
        let map = MadeUpMap(center: FlatMapPoint(x: 0.5, y: 0.5), origin: CGPoint(x: 500, y: 300), worldWidth: 2, degrees: 0)
        let projection = try XCTUnwrap(map.projection())
        XCTAssertEqual(projection.copies(touching: view), -MapProjection.copiesEachSide...MapProjection.copiesEachSide)
        XCTAssertEqual(projection.copies(touching: view, margin: 1), -MapProjection.copiesEachSide...MapProjection.copiesEachSide)
    }

    // MARK: - Shapes on screen

    func test_outlines_aBandRoundTheWorld_fillsTheViewFromSideToSide() throws {
        // One world is 400 points wide, so the 1000-point view shows three copies. A band round the middle half
        // of the world is 200 points tall here, and must cover the view's whole width with no gap between copies.
        let map = MadeUpMap(center: FlatMapPoint(x: 0.5, y: 0.5), origin: CGPoint(x: 500, y: 300), worldWidth: 400, degrees: 0)
        let projection = try XCTUnwrap(map.projection())
        let band = [FlatMapPoint(x: 0, y: 0.25), FlatMapPoint(x: 1, y: 0.25), FlatMapPoint(x: 1, y: 0.75), FlatMapPoint(x: 0, y: 0.75)]
        let outlines = projection.outlines(of: band, in: view)
        XCTAssertEqual(outlines.count, 3)
        XCTAssertEqual(outlines.map { area($0) }.reduce(0, +), 1000 * 200, accuracy: 1e-6)
        for outline in outlines { assertInside(outline, view) }
    }

    func test_outlines_zoomedFarIn_onNight_isTheWholeView() throws {
        // A world 200 million points wide: the view is a few city blocks, well inside the band.
        let map = MadeUpMap(center: FlatMapPoint(x: 0.4, y: 0.5), origin: CGPoint(x: 500, y: 300), worldWidth: 200_000_000, degrees: 37)
        let projection = try XCTUnwrap(map.projection())
        let band = [FlatMapPoint(x: 0, y: 0.25), FlatMapPoint(x: 1, y: 0.25), FlatMapPoint(x: 1, y: 0.75), FlatMapPoint(x: 0, y: 0.75)]
        let outlines = projection.outlines(of: band, in: view)
        XCTAssertEqual(outlines.count, 1)
        XCTAssertEqual(area(outlines.first ?? []), 1000 * 600, accuracy: 0.01)
        for outline in outlines { assertInside(outline, view) }
        // And well outside it there is nothing to draw.
        let elsewhere = [FlatMapPoint(x: 0.6, y: 0.25), FlatMapPoint(x: 0.9, y: 0.25), FlatMapPoint(x: 0.9, y: 0.75), FlatMapPoint(x: 0.6, y: 0.75)]
        XCTAssertTrue(projection.outlines(of: elsewhere, in: view).isEmpty)
    }
}
