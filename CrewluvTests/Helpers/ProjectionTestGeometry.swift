//
//  ProjectionTestGeometry.swift
//  CrewluvTests
//
//  Plain geometry for `MapProjection`'s tests, ported from CrewLu's FlatMapFitTests: the view they draw into,
//  places, squares, the area inside an outline, and whether an outline stays inside a rectangle.
//

import XCTest
import CoreGraphics
import CoreLocation

enum ProjectionTestGeometry {

    /// The view every test draws into.
    static let view = CGRect(x: 0, y: 0, width: 1000, height: 600)

    static func place(_ latitude: Double, _ longitude: Double) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// The area inside a closed outline, by the shoelace rule.
    static func area(_ outline: [CGPoint]) -> Double {
        guard outline.count >= 3 else { return 0 }
        var sum = 0.0
        for index in outline.indices {
            let a = outline[index]
            let b = outline[(index + 1) % outline.count]
            sum += Double(a.x * b.y - b.x * a.y)
        }
        return abs(sum) / 2
    }

    static func square(_ x: Double, _ y: Double, _ side: Double) -> [CGPoint] {
        [CGPoint(x: x, y: y), CGPoint(x: x + side, y: y), CGPoint(x: x + side, y: y + side), CGPoint(x: x, y: y + side)]
    }

    static func assertInside(_ outline: [CGPoint], _ rect: CGRect, file: StaticString = #filePath, line: UInt = #line) {
        for point in outline {
            XCTAssertTrue(point.x >= rect.minX && point.x <= rect.maxX && point.y >= rect.minY && point.y <= rect.maxY,
                          "\(point) is outside \(rect)", file: file, line: line)
        }
    }
}
