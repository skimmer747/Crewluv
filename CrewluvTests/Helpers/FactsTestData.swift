//
//  FactsTestData.swift
//  CrewluvTests
//
//  Made-up places along the equator, where a fraction of the way is a fraction of the longitude, and flights across
//  them at the March equinox: the facts' tests can then be worked out by hand (Stage 2 spec §12).
//

import CoreLocation
@testable import Crewluv

enum FactsTestData {

    /// A rectangle a degree either side of the equator.
    static func box(_ name: String, _ kind: Geography.Kind, country: String? = nil,
                    west: Double, east: Double, south: Double = -1, north: Double = 1) -> Geography.Area {
        Geography.Area(name: name, kind: kind, country: country, box: [west, south, east, north],
                       rings: [[west, south, east, south, east, north, west, north]])
    }

    /// Along the equator: Alpha to 5° E; Bravo to 12° E, with a Wedge 0.3° (about 21 mi) wide at 9° E that the hold rule
    /// drops; then the Test Sea to 21° E. Testville sits 0.3° north of 6° E.
    static let equator = Geography(
        areas: [
            box("Wedge", .country, west: 9, east: 9.3),
            box("Alpha", .country, west: -1, east: 5),
            box("Bravo", .country, west: 5, east: 12),
            box("the Test Sea", .water, west: 12, east: 21),
        ],
        cities: [Geography.City(name: "Testville", lat: 0.3, lon: 6)]
    )

    static func mark(_ code: String, latitude: Double, longitude: Double, city: String? = nil, zone: String? = nil) -> AirportMark {
        AirportMark(code: code, city: city, coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                    timeZone: zone.flatMap(TimeZone.init(identifier:)))
    }

    /// 2026-03-20 10:00 UTC, the March equinox: 6:00 AM in Louisville.
    static let equinox = Date(timeIntervalSince1970: 1_774_000_800)

    /// A flight along the equator from `west`° to `east`° longitude: 3 h 22 min from gate to gate, so in the air from
    /// 10:15 to 13:15 UTC with the taxi allowances, a tenth of the way every 18 minutes.
    static func equatorFlight(from west: Double, to east: Double, departure: Date = equinox, id: String = "eq") -> MapLeg {
        MapLeg(id: id, kind: .flight,
               origin: mark("E\(Int(west))", latitude: 0, longitude: west),
               destination: mark("E\(Int(east))", latitude: 0, longitude: east),
               start: departure, end: departure.addingTimeInterval(202 * 60), flightNumber: "TST1")
    }

    static func date(_ iso: String) -> Date {
        ISO8601DateFormatter().date(from: iso)!
    }

    private static let repository = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// The app's geography.json, read from the repository on the Mac's disk.
    static func appGeography() throws -> Geography {
        try Geography(data: Data(contentsOf: repository.appending(path: "Crewluv/Resources/TripMap/geography.json")))
    }

    static func appComparisons() throws -> ComparisonPicker {
        try ComparisonPicker(data: Data(contentsOf: repository.appending(path: "Crewluv/Resources/TripMap/comparisons.json")))
    }
}
