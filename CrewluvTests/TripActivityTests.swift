//
//  TripActivityTests.swift
//  CrewluvTests
//
//  What the pilot is doing, as the trip map draws it and says it (activity markers design §2.1, §4.2).
//

import XCTest
import CoreLocation
import SwiftUI
@testable import Crewluv

final class TripActivityTests: XCTestCase {

    private let denver = AirportMark(code: "DEN", city: "Denver",
                                     coordinate: CLLocationCoordinate2D(latitude: 39.8561, longitude: -104.6737), timeZone: nil)

    private func words(_ kind: TripActivity.Kind, at place: AirportMark? = nil) -> String {
        TripActivity(kind: kind, place: place ?? denver).words
    }

    func test_words_eachKind_readAsTheDesignSays() {
        XCTAssertEqual(words(.flying), "Flying to Denver")
        XCTAssertEqual(words(.driving), "Driving to Denver")
        XCTAssertEqual(words(.layover), "Layover in Denver")
        XCTAssertEqual(words(.turn), "Turn in Denver")
        XCTAssertEqual(words(.base), "At base in Denver")
        XCTAssertEqual(words(.home), "Home")
    }

    func test_words_aPlaceWithNoCity_isNamedByItsCode() {
        let springs = AirportMark(code: "COS", city: nil,
                                  coordinate: CLLocationCoordinate2D(latitude: 38.8058, longitude: -104.7008), timeZone: nil)
        XCTAssertEqual(words(.layover, at: springs), "Layover in COS")
    }

    func test_symbolName_eachKind_isTheDesignsSymbol() {
        XCTAssertEqual(TripActivity.Kind.allCases.map(\.symbolName),
                       ["airplane", "car.fill", "bed.double.fill", "hourglass", "briefcase.fill", "house.fill"])
    }

    func test_color_eachKind_isTheDesignsSystemColor() {
        XCTAssertEqual(TripActivity.Kind.allCases.map(\.color), [.blue, .gray, .indigo, .orange, .teal, .green])
    }

    func test_isMoving_onlyFlyingAndDriving() {
        XCTAssertEqual(TripActivity.Kind.allCases.filter(\.isMoving), [.flying, .driving])
    }
}
