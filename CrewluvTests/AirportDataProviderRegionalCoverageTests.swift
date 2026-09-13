import XCTest
@testable import Crewluv

/// Regional airports that Crewlu (Duty) carries in its tables but that never
/// reached this app's copy. Without an entry, a pilot based at one of them had
/// no city name on the status and narrative cards and no pin on the route map.
/// These tests pin each entry.
final class AirportDataProviderRegionalCoverageTests: XCTestCase {

    private struct Expected {
        let iata: String
        let city: String
        let state: String
        let latitude: ClosedRange<Double>
        let longitude: ClosedRange<Double>
    }

    private let expected: [Expected] = [
        Expected(iata: "BLI", city: "Bellingham", state: "WA", latitude: 48.5...49.0, longitude: -123.0...(-122.0)),
        Expected(iata: "ATW", city: "Appleton", state: "WI", latitude: 44.0...45.0, longitude: -89.0...(-88.0)),
        Expected(iata: "BTR", city: "Baton Rouge", state: "LA", latitude: 30.0...31.0, longitude: -92.0...(-91.0)),
        Expected(iata: "AEX", city: "Alexandria", state: "LA", latitude: 31.0...32.0, longitude: -93.0...(-92.0)),
        Expected(iata: "LCH", city: "Lake Charles", state: "LA", latitude: 30.0...31.0, longitude: -94.0...(-93.0)),
        Expected(iata: "MOB", city: "Mobile", state: "AL", latitude: 30.0...31.0, longitude: -89.0...(-88.0)),
    ]

    private let provider = AirportDataProvider.shared

    func test_airportInfoForIataCode_regionalCodes_returnUSEntriesWithPlausibleCoordinates() {
        for airport in expected {
            guard let info = provider.airportInfo(forIataCode: airport.iata) else {
                XCTFail("\(airport.iata) missing from AirportDataProvider")
                continue
            }
            XCTAssertEqual(info.iata, airport.iata)
            XCTAssertEqual(info.city, airport.city, "\(airport.iata) city")
            XCTAssertEqual(info.state, airport.state, "\(airport.iata) state")
            XCTAssertEqual(info.country, "USA", "\(airport.iata) country")
            XCTAssertTrue(airport.latitude.contains(info.latitude), "\(airport.iata) latitude \(info.latitude) outside expected box")
            XCTAssertTrue(airport.longitude.contains(info.longitude), "\(airport.iata) longitude \(info.longitude) outside expected box")
        }
    }

    func test_airportInfoForIataCode_lowercaseCodes_returnSameEntries() {
        for airport in expected {
            XCTAssertEqual(provider.airportInfo(forIataCode: airport.iata.lowercased())?.iata, airport.iata)
        }
    }

    func test_airportInfoForCity_regionalCities_resolveToExactlyOneCode() {
        for airport in expected {
            let codes = provider.airportInfo(forCity: airport.city).map(\.iata)
            XCTAssertEqual(codes, [airport.iata], "\(airport.city) should map to exactly \(airport.iata)")
        }
    }
}
