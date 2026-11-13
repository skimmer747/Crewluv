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
