//
//  GeographyTests.swift
//  CrewluvTests
//
//  What's under a point (Stage 2 spec §4.1).
//

import XCTest
import CoreLocation
@testable import Crewluv

final class GeographyTests: XCTestCase {

    private func at(_ latitude: Double, _ longitude: Double) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func test_place_aStateInsideItsCountry_givesTheState() {
        let geography = Geography(areas: [
            FactsTestData.box("Delta", .country, west: 0, east: 10),
            FactsTestData.box("North", .state, country: "Delta", west: 0, east: 5),
        ], cities: [])
        XCTAssertEqual(geography.place(at: at(0, 2)), Geography.Place(name: "North", kind: .state, country: "Delta"))
        XCTAssertEqual(geography.place(at: at(0, 7)), Geography.Place(name: "Delta", kind: .country, country: "Delta"))
    }

    func test_place_landBeforeWater() {
        let geography = Geography(areas: [
            FactsTestData.box("the Sea", .water, west: 0, east: 10),
            FactsTestData.box("Island", .country, west: 4, east: 6),
        ], cities: [])
        XCTAssertEqual(geography.place(at: at(0, 5))?.name, "Island")
        XCTAssertEqual(geography.place(at: at(0, 8)), Geography.Place(name: "the Sea", kind: .water, country: nil))
    }

    func test_place_justOffTheCoast_snapsToTheLand() {
        let geography = Geography(areas: [
            FactsTestData.box("Coast", .state, country: "Land", west: 0, east: 5),
            FactsTestData.box("Land", .country, west: 0, east: 5),
            FactsTestData.box("the Sea", .water, west: 5, east: 15),
        ], cities: [])
        // 0.05° east of the coast is about 3.5 mi; 0.1° is about 6.9 mi.
        XCTAssertEqual(geography.place(at: at(0, 5.05))?.name, "Coast")
        XCTAssertEqual(geography.place(at: at(0, 5.1))?.name, "the Sea")
    }

    func test_place_nearLandOverNothing_snapsToTheLand() {
        let geography = Geography(areas: [FactsTestData.box("Island", .country, west: 0, east: 1)], cities: [])
        XCTAssertEqual(geography.place(at: at(0, 1.05))?.name, "Island")
        XCTAssertNil(geography.place(at: at(0, 1.2)))
    }

    func test_appGeography_coastalCitiesAndSmallCountries() throws {
        let geography = try FactsTestData.appGeography()
        XCTAssertEqual(geography.place(at: at(40.71, -74.01))?.name, "New York", "Manhattan")
        XCTAssertEqual(geography.place(at: at(25.76, -80.19))?.name, "Florida", "Miami")
        XCTAssertEqual(geography.place(at: at(32.30, -64.78))?.name, "Bermuda")
        XCTAssertEqual(geography.place(at: at(35.90, 14.45))?.name, "Malta")
    }

    func test_place_outsideEverything_isNil() {
        XCTAssertNil(FactsTestData.equator.place(at: at(10, 5)))
    }

    func test_place_inAHole_isOutside() {
        let ringed = Geography.Area(name: "Ring", kind: .country, country: nil, box: [0, -5, 10, 5],
                                    rings: [[0, -5, 10, -5, 10, 5, 0, 5], [4, -1, 6, -1, 6, 1, 4, 1]])
        let geography = Geography(areas: [ringed], cities: [])
        XCTAssertEqual(geography.place(at: at(0, 2))?.name, "Ring")
        XCTAssertNil(geography.place(at: at(0, 5)), "the hole")
    }

    func test_place_twoSeparateRings_bothCount() {
        let twoParts = Geography.Area(name: "Islands", kind: .country, country: nil, box: [0, -1, 20, 1],
                                      rings: [[0, -1, 2, -1, 2, 1, 0, 1], [18, -1, 20, -1, 20, 1, 18, 1]])
        let geography = Geography(areas: [twoParts], cities: [])
        XCTAssertEqual(geography.place(at: at(0, 1))?.name, "Islands")
        XCTAssertEqual(geography.place(at: at(0, 19))?.name, "Islands")
        XCTAssertNil(geography.place(at: at(0, 10)))
    }

    func test_place_aLongitudePastTheDateLine_isWrapped() {
        let geography = Geography(areas: [FactsTestData.box("East", .country, west: -175, east: -165)], cities: [])
        XCTAssertEqual(geography.place(at: at(0, 190))?.name, "East")
    }

    func test_city_within40Miles_isTheNearest() {
        let geography = Geography(areas: [], cities: [
            Geography.City(name: "Near", lat: 0.3, lon: 6),
            Geography.City(name: "Nearer", lat: 0.1, lon: 6),
        ])
        XCTAssertEqual(geography.city(near: at(0, 6))?.name, "Nearer")
    }

    func test_city_farther_isNil() {
        // 0.6° of latitude is about 41 mi.
        XCTAssertNil(FactsTestData.equator.city(near: at(-0.3, 6)))
    }

    func test_init_decodesTheFileFormat() throws {
        let json = """
        {"source": "test", "areas": [{"name": "Kansas", "kind": "state", "country": "the United States",
          "box": [-102, 37, -94.6, 40], "rings": [[-102, 37, -94.6, 37, -94.6, 40, -102, 40]]}],
         "cities": [{"name": "Wichita", "lat": 37.69, "lon": -97.34}]}
        """
        let geography = try Geography(data: Data(json.utf8))
        XCTAssertEqual(geography.place(at: at(38.5, -98.5)), Geography.Place(name: "Kansas", kind: .state, country: "the United States"))
        XCTAssertEqual(geography.cities.map(\.name), ["Wichita"])
    }

    func test_appGeography_findsAStateACountryAndASea() throws {
        let geography = try FactsTestData.appGeography()
        XCTAssertEqual(geography.place(at: at(38.5, -98.5))?.name, "Kansas")
        XCTAssertEqual(geography.place(at: at(51.0, 10.0))?.name, "Germany")
        XCTAssertEqual(geography.place(at: at(58.0, -54.0))?.name, "the Labrador Sea")
    }

    /// The tests run inside the app, so its bundle is `Bundle.main`.
    func test_loadBundled_theAppCarriesBothFiles() {
        XCTAssertNotNil(Geography.loadBundled())
        XCTAssertNotNil(ComparisonPicker.loadBundled())
    }
}
