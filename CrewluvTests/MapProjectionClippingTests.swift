//
//  MapProjectionClippingTests.swift
//  CrewluvTests
//
//  Cutting shapes and lines off at the edge of the view, laying routes out across the date line, and where each
//  piece of a line starts, for its dashes (moving map spec §7.1, §10). Ported from CrewLu's FlatMapFitTests, with the
//  dash tests added for Crewluve's dashed and dotted lines. Every expected value is plain geometry worked out here.
//

import XCTest
import CoreGraphics
import CoreLocation
@testable import Crewluv

final class MapProjectionClippingTests: XCTestCase {

    private let view = ProjectionTestGeometry.view

    private func place(_ latitude: Double, _ longitude: Double) -> CLLocationCoordinate2D {
        ProjectionTestGeometry.place(latitude, longitude)
    }

    private func area(_ outline: [CGPoint]) -> Double {
        ProjectionTestGeometry.area(outline)
    }

    private func square(_ x: Double, _ y: Double, _ side: Double) -> [CGPoint] {
        ProjectionTestGeometry.square(x, y, side)
    }

    private func assertInside(_ outline: [CGPoint], _ rect: CGRect, file: StaticString = #filePath, line: UInt = #line) {
        ProjectionTestGeometry.assertInside(outline, rect, file: file, line: line)
    }

    /// Where in a dash pattern `patternLength` long a horizontal piece is at screen `x`.
    private func patternPosition(of piece: MapProjection.LinePiece, atX x: Double, patternLength: Double) -> Double {
        let start = Double(piece.points.first?.x ?? 0)
        let position = (Double(piece.dashPhase(patternLength: patternLength)) + x - start).truncatingRemainder(dividingBy: patternLength)
        return position < 0 ? position + patternLength : position
    }

    // MARK: - Cutting a shape off at the edge of the view

    func test_clippedPolygon_insideTheView_isUnchanged() {
        let shape = square(100, 100, 200)
        XCTAssertEqual(MapProjection.clipped(polygon: shape, to: view), shape)
    }

    func test_clippedPolygon_outsideTheView_isGone() {
        XCTAssertTrue(MapProjection.clipped(polygon: square(1100, 100, 200), to: view).isEmpty)
        XCTAssertTrue(MapProjection.clipped(polygon: square(100, -500, 200), to: view).isEmpty)
        // Outside, but not wholly to one side of the view: past the top right corner.
        let pastTheCorner = [CGPoint(x: 900, y: -300), CGPoint(x: 1300, y: 100), CGPoint(x: 1300, y: -300)]
        XCTAssertTrue(MapProjection.clipped(polygon: pastTheCorner, to: view).isEmpty)
    }

    func test_clippedPolygon_coveringTheView_becomesTheView() {
        let cut = MapProjection.clipped(polygon: square(-5_000, -5_000, 20_000), to: view)
        XCTAssertEqual(area(cut), 1000 * 600, accuracy: 1e-6)
        assertInside(cut, view)
    }

    func test_clippedPolygon_halfIn_keepsTheHalf() {
        // A 200 square, half of it past the view's right edge.
        let cut = MapProjection.clipped(polygon: square(900, 100, 200), to: view)
        XCTAssertEqual(area(cut), 100 * 200, accuracy: 1e-6)
        assertInside(cut, view)
    }

    func test_clippedPolygon_cornersAThousandMillionPointsAway_staysInsideTheView() {
        let far = 1e9
        let huge = [CGPoint(x: -far, y: -far), CGPoint(x: far, y: -far), CGPoint(x: far, y: far), CGPoint(x: -far, y: far)]
        let cut = MapProjection.clipped(polygon: huge, to: view)
        XCTAssertEqual(area(cut), 1000 * 600, accuracy: 1e-3)
        assertInside(cut, view)
        // A slanted edge from far away still crosses the view where it should: this shape is everything below
        // the line from the view's bottom left corner to its top right one.
        let half = [CGPoint(x: -far, y: 600 + far * 0.6), CGPoint(x: far + 1000, y: -far * 0.6),
                    CGPoint(x: far + 1000, y: far), CGPoint(x: -far, y: far)]
        let cutHalf = MapProjection.clipped(polygon: half, to: view)
        XCTAssertEqual(area(cutHalf), 1000 * 600 / 2, accuracy: 1)
        assertInside(cutHalf, view)
    }

    func test_clippedPolygon_dentedShape_keepsTheCorrectArea() {
        // A U: two legs 100 wide that reach down into the view, joined by a bar above it. Only the legs show.
        let u = [CGPoint(x: 200, y: -200), CGPoint(x: 600, y: -200), CGPoint(x: 600, y: 300), CGPoint(x: 500, y: 300),
                 CGPoint(x: 500, y: -100), CGPoint(x: 300, y: -100), CGPoint(x: 300, y: 300), CGPoint(x: 200, y: 300)]
        let cut = MapProjection.clipped(polygon: u, to: view)
        XCTAssertEqual(area(cut), 2 * 100 * 300, accuracy: 1e-6)
        assertInside(cut, view)
    }

    func test_clippedPolygon_tooFewCorners_isGone() {
        XCTAssertTrue(MapProjection.clipped(polygon: [CGPoint(x: 1, y: 1), CGPoint(x: 5, y: 5)], to: view).isEmpty)
        XCTAssertTrue(MapProjection.clipped(polygon: [], to: view).isEmpty)
    }

    // MARK: - Cutting a line off at the edge of the view

    func test_clippedLine_insideTheView_isUnchanged() {
        let line = [CGPoint(x: 100, y: 100), CGPoint(x: 300, y: 200), CGPoint(x: 500, y: 100)]
        XCTAssertEqual(MapProjection.clipped(line: line, to: view), [line])
    }

    func test_clippedLine_throughTheView_keepsThePartInside() {
        let line = [CGPoint(x: -500, y: 300), CGPoint(x: 1500, y: 300)]
        XCTAssertEqual(MapProjection.clipped(line: line, to: view), [[CGPoint(x: 0, y: 300), CGPoint(x: 1000, y: 300)]])
    }

    func test_clippedLine_leavesAndComesBack_givesTwoPieces() {
        let line = [CGPoint(x: 100, y: 100), CGPoint(x: 100, y: -100), CGPoint(x: 300, y: -100), CGPoint(x: 300, y: 100)]
        XCTAssertEqual(MapProjection.clipped(line: line, to: view),
                       [[CGPoint(x: 100, y: 100), CGPoint(x: 100, y: 0)], [CGPoint(x: 300, y: 0), CGPoint(x: 300, y: 100)]])
    }

    func test_clippedLine_missesTheView_givesNothing() {
        XCTAssertTrue(MapProjection.clipped(line: [CGPoint(x: -500, y: -10), CGPoint(x: 1500, y: -10)], to: view).isEmpty)
        // Both ends outside, on different sides, and the line passes outside the corner.
        XCTAssertTrue(MapProjection.clipped(line: [CGPoint(x: -100, y: 50), CGPoint(x: 50, y: -100)], to: view).isEmpty)
        XCTAssertTrue(MapProjection.clipped(line: [CGPoint(x: 5, y: 5)], to: view).isEmpty)
    }

    func test_clippedLine_fromFarAway_crossesWhereItShould() {
        let far = 1e9
        // The view's long slanted line, bottom left corner to top right, carried on a thousand million points each way.
        let pieces = MapProjection.clipped(line: [CGPoint(x: -far, y: 600 + far * 0.6), CGPoint(x: 1000 + far, y: -far * 0.6)], to: view)
        XCTAssertEqual(pieces.count, 1)
        let piece = pieces.first ?? []
        XCTAssertEqual(piece.count, 2)
        XCTAssertEqual(Double(piece.first?.x ?? -1), 0, accuracy: 0.001)
        XCTAssertEqual(Double(piece.first?.y ?? -1), 600, accuracy: 0.001)
        XCTAssertEqual(Double(piece.last?.x ?? -1), 1000, accuracy: 0.001)
        XCTAssertEqual(Double(piece.last?.y ?? -1), 0, accuracy: 0.001)
    }

    // MARK: - Where each piece of a line starts, for its dashes

    func test_clippedPieces_insideTheView_startAtTheBeginningAndKnowTheWholeLength() {
        // The long side of a 3-4-5 triangle, 500 points.
        let pieces = MapProjection.clippedPieces(line: [CGPoint(x: 100, y: 100), CGPoint(x: 400, y: 500)], to: view)
        XCTAssertEqual(pieces.count, 1)
        XCTAssertEqual(pieces.first?.startDistance ?? -1, 0, accuracy: 1e-9)
        XCTAssertEqual(pieces.first?.lineLength ?? -1, 500, accuracy: 1e-9)
    }

    func test_clippedPieces_cutAtTheLeftEdge_startWhereTheCutIs() {
        let pieces = MapProjection.clippedPieces(line: [CGPoint(x: -300, y: 300), CGPoint(x: 700, y: 300)], to: view)
        XCTAssertEqual(pieces.count, 1)
        XCTAssertEqual(Double(pieces.first?.points.first?.x ?? -1), 0, accuracy: 1e-9)
        XCTAssertEqual(pieces.first?.startDistance ?? -1, 300, accuracy: 1e-9)
        XCTAssertEqual(pieces.first?.lineLength ?? -1, 1000, accuracy: 1e-9)
    }

    func test_clippedPieces_leavesAndComesBack_countTheWayRound() {
        // Up out of the view, along above it and back down: three stretches of 200 points. The second piece starts
        // where the line comes back in, 100 points down the last stretch.
        let pieces = MapProjection.clippedPieces(line: [CGPoint(x: 100, y: 100), CGPoint(x: 100, y: -100),
                                                        CGPoint(x: 300, y: -100), CGPoint(x: 300, y: 100)], to: view)
        XCTAssertEqual(pieces.map(\.startDistance), [0, 500])
        XCTAssertEqual(pieces.map(\.lineLength), [600, 600])
    }

    func test_dashPhase_isLaidFromTheLinesFarEnd() {
        let piece = MapProjection.LinePiece(points: [CGPoint(x: 0, y: 300), CGPoint(x: 700, y: 300)], startDistance: 300, lineLength: 1000)
        // 300 - 1000 = -700, which is 8 more than a whole number of 12s.
        XCTAssertEqual(Double(piece.dashPhase(patternLength: 12)), 8, accuracy: 1e-9)
        // So the pattern starts afresh exactly at the line's end, at x 700.
        XCTAssertEqual(patternPosition(of: piece, atX: 700, patternLength: 12), 0, accuracy: 1e-9)
    }

    func test_dashPhase_aPanThatMovesTheCut_keepsEachDashOnTheMap() throws {
        let line = [CGPoint(x: -300, y: 300), CGPoint(x: 700, y: 300)]
        let panned = line.map { CGPoint(x: $0.x + 50, y: $0.y) }
        let before = try XCTUnwrap(MapProjection.clippedPieces(line: line, to: view).first)
        let after = try XCTUnwrap(MapProjection.clippedPieces(line: panned, to: view).first)
        // The same place on the map is at x 401 before the pan and x 451 after it.
        XCTAssertEqual(patternPosition(of: before, atX: 401, patternLength: 12),
                       patternPosition(of: after, atX: 451, patternLength: 12), accuracy: 1e-9)
    }

    func test_dashPhase_lineShortenedAtItsStart_keepsEachDashOnTheMap() throws {
        // The line still to fly, before and after the plane has moved 37 points along it.
        let before = try XCTUnwrap(MapProjection.clippedPieces(line: [CGPoint(x: 100, y: 300), CGPoint(x: 900, y: 300)], to: view).first)
        let after = try XCTUnwrap(MapProjection.clippedPieces(line: [CGPoint(x: 137, y: 300), CGPoint(x: 900, y: 300)], to: view).first)
        XCTAssertEqual(patternPosition(of: before, atX: 500, patternLength: 12),
                       patternPosition(of: after, atX: 500, patternLength: 12), accuracy: 1e-9)
    }

    // MARK: - Across the date line

    func test_unwrapped_eastAcrossTheDateLine_runsOnPastTheEdge() {
        // Tokyo to Anchorage: longitudes 139.7 east, 170 east, 170 west, 150 west.
        let leg = [139.7, 170.0, -170.0, -150.0].map { MapProjection.point(for: place(40, $0)) }
        let xs = MapProjection.unwrapped(leg).map(\.x)
        XCTAssertEqual(xs[0], 139.7 / 360 + 0.5, accuracy: 1e-12)
        XCTAssertEqual(xs[1], 170.0 / 360 + 0.5, accuracy: 1e-12)
        XCTAssertEqual(xs[2], 190.0 / 360 + 0.5, accuracy: 1e-12)
        XCTAssertEqual(xs[3], 210.0 / 360 + 0.5, accuracy: 1e-12)
    }

    func test_unwrapped_westAcrossTheDateLine_runsOnPastTheEdge() {
        let leg = [-150.0, -170.0, 170.0, 139.7].map { MapProjection.point(for: place(40, $0)) }
        let xs = MapProjection.unwrapped(leg).map(\.x)
        XCTAssertEqual(xs[2], -190.0 / 360 + 0.5, accuracy: 1e-12)
        XCTAssertEqual(xs[3], -220.3 / 360 + 0.5, accuracy: 1e-12)
    }

    func test_unwrapped_awayFromTheDateLine_isUnchanged() {
        let leg = [FlatMapPoint(x: 0.2, y: 0.4), FlatMapPoint(x: 0.45, y: 0.3), FlatMapPoint(x: 0.69, y: 0.35)]
        XCTAssertEqual(MapProjection.unwrapped(leg), leg)
        XCTAssertTrue(MapProjection.unwrapped([]).isEmpty)
    }

    // MARK: - Lines on screen

    func test_pieces_aLegAcrossTheDateLine_isDrawnOnBothSidesOfTheMap() throws {
        // The whole world on screen, 800 points wide, centred on the middle of the map. A leg from 170 east to 170
        // west shows twice: running off the right edge of the map, and coming in at the left edge.
        let map = MadeUpMap(center: FlatMapPoint(x: 0.5, y: 0.5), origin: CGPoint(x: 500, y: 300), worldWidth: 800, degrees: 0)
        let projection = try XCTUnwrap(map.projection())
        let leg = MapProjection.unwrapped([170.0, 180.0, -170.0].map { MapProjection.point(for: place(0, $0)) })
        let pieces = projection.pieces(of: leg, in: view)
        // 170 east is 20/360 of 800 points inside the map's right edge, which is at 900: from 877.8 to 922.2.
        // The same leg one world to the west runs from 77.8 to 122.2.
        let spans = pieces.map { piece in (Double(piece.map(\.x).min() ?? 0), Double(piece.map(\.x).max() ?? 0)) }.sorted { $0.0 < $1.0 }
        XCTAssertEqual(spans.count, 2)
        XCTAssertEqual(spans[0].0, 100 - 800.0 * 10 / 360, accuracy: 1e-6)
        XCTAssertEqual(spans[0].1, 100 + 800.0 * 10 / 360, accuracy: 1e-6)
        XCTAssertEqual(spans[1].0, 900 - 800.0 * 10 / 360, accuracy: 1e-6)
        XCTAssertEqual(spans[1].1, 900 + 800.0 * 10 / 360, accuracy: 1e-6)
    }

    func test_pieces_justEastOfTheDateLine_drawsALegThatBeganWestOfIt() throws {
        // Zoomed in on the equator at 178 west: the view is 1.8 degrees wide, so all of it is east of the date
        // line. A leg from 170 east to 170 west is laid out running on past the map's right edge, so the part of
        // it seen here belongs to the copy of the world one to the west, which no corner of the view is on.
        let center = MapProjection.point(for: place(0, -178))
        let map = MadeUpMap(center: center, origin: CGPoint(x: 500, y: 300), worldWidth: 200_000, degrees: 0)
        let projection = try XCTUnwrap(map.projection())
        XCTAssertEqual(projection.copies(touching: view), 0...0)
        let leg = MapProjection.unwrapped([170.0, 180.0, -170.0].map { MapProjection.point(for: place(0, $0)) })
        let pieces = projection.pieces(of: leg, in: view)
        XCTAssertEqual(pieces.count, 1)
        let piece = pieces.first ?? []
        XCTAssertEqual(Double(piece.map(\.x).min() ?? -1), 0, accuracy: 1e-6)
        XCTAssertEqual(Double(piece.map(\.x).max() ?? -1), 1000, accuracy: 1e-6)
        for point in piece { XCTAssertEqual(Double(point.y), 300, accuracy: 1e-6) }
    }

    func test_pieces_zoomedFarIn_staysInsideTheView() throws {
        let center = MapProjection.point(for: place(40, -100))
        let map = MadeUpMap(center: center, origin: CGPoint(x: 500, y: 300), worldWidth: 200_000_000, degrees: 0)
        let projection = try XCTUnwrap(map.projection())
        // A leg along the 40th parallel passes straight through the middle of the view.
        let leg = MapProjection.unwrapped([-120.0, -100.0, -80.0].map { MapProjection.point(for: place(40, $0)) })
        let pieces = projection.pieces(of: leg, in: view)
        XCTAssertEqual(pieces.count, 1)
        let piece = pieces.first ?? []
        assertInside(piece, view)
        XCTAssertEqual(Double(piece.map(\.x).min() ?? -1), 0, accuracy: 1e-6)
        XCTAssertEqual(Double(piece.map(\.x).max() ?? -1), 1000, accuracy: 1e-6)
        for point in piece { XCTAssertEqual(Double(point.y), 300, accuracy: 0.01) }
    }
}
