//
//  Geography.swift
//  CrewLuve
//
//  What's under a point on the earth (Stage 2 spec §4.1): a US state or Canadian province, else a country, else a
//  named sea or ocean, and any city of a million or more within 40 mi. Land within 5 mi beats water or nothing (the
//  coast snap), since the simplified coastlines can be a few miles off. Read from the bundled geography.json, which
//  scripts/build-geography.mjs makes from Natural Earth.
//

import CoreLocation

nonisolated struct Geography: Decodable, Sendable {

    nonisolated enum Kind: String, Decodable, Sendable {
        case state, province, country, water
    }

    /// What's under a point, named as the facts read it: "Kansas", "the Netherlands", "the Labrador Sea".
    nonisolated struct Place: Equatable, Sendable {
        let name: String
        let kind: Kind
        /// The country a state or province is in, or the country itself. Nil over water.
        let country: String?

        var isWater: Bool { kind == .water }

        /// One of the five oceans: past 2 hours out of tracking range, the only places wide enough to be named under
        /// a guessed plane (long gap design §3).
        var isOcean: Bool { isWater && Self.oceanNames.contains(name) }

        /// The five oceans, by the names geography.json gives them.
        static let oceanNames: Set<String> = ["the Pacific", "the Atlantic", "the Indian Ocean", "the Arctic Ocean", "the Southern Ocean"]
    }

    nonisolated struct Area: Decodable, Sendable {
        let name: String
        let kind: Kind
        /// For a state or province, its country.
        let country: String?
        /// West, south, east and north edges, in degrees.
        let box: [Double]
        /// Each ring as longitude, latitude, longitude, latitude, …
        let rings: [[Double]]

        var place: Place {
            Place(name: name, kind: kind, country: kind == .water ? nil : (country ?? name))
        }

        /// Inside when an odd number of the rings hold the point, so a hole (Lesotho in South Africa) is outside.
        func contains(latitude: Double, longitude: Double) -> Bool {
            guard box.count == 4, longitude >= box[0], latitude >= box[1], longitude <= box[2], latitude <= box[3] else { return false }
            let holding = rings.filter { Self.ring($0, containsLatitude: latitude, longitude: longitude) }.count
            return holding % 2 == 1
        }

        /// Whether the point is within `meters` of the area's box, a cheap test before `distanceToEdge`.
        func isNear(latitude: Double, longitude: Double, within meters: Double) -> Bool {
            guard box.count == 4 else { return false }
            let latitudeMargin = meters / Self.metersPerDegree
            let longitudeMargin = latitudeMargin / max(cos(latitude * .pi / 180), 0.01)
            return longitude >= box[0] - longitudeMargin && latitude >= box[1] - latitudeMargin
                && longitude <= box[2] + longitudeMargin && latitude <= box[3] + latitudeMargin
        }

        /// About how far the point is from the nearest edge of any ring, in meters, on a flat map around the point:
        /// close enough over the few miles the coast snap looks.
        func distanceToEdge(latitude: Double, longitude: Double) -> Double {
            let eastScale = cos(latitude * .pi / 180) * Self.metersPerDegree
            var nearest = Double.infinity
            for ring in rings {
                let count = ring.count / 2
                guard count >= 2 else { continue }
                var previous = count - 1
                for current in 0..<count {
                    let start = (x: (ring[2 * previous] - longitude) * eastScale, y: (ring[2 * previous + 1] - latitude) * Self.metersPerDegree)
                    let end = (x: (ring[2 * current] - longitude) * eastScale, y: (ring[2 * current + 1] - latitude) * Self.metersPerDegree)
                    nearest = min(nearest, Self.distanceFromOrigin(toSegmentFrom: start, to: end))
                    previous = current
                }
            }
            return nearest
        }

        /// One degree of latitude, in meters, on `GreatCircle`'s earth.
        private static let metersPerDegree = GreatCircle.earthRadius * .pi / 180

        private static func distanceFromOrigin(toSegmentFrom start: (x: Double, y: Double), to end: (x: Double, y: Double)) -> Double {
            let dx = end.x - start.x
            let dy = end.y - start.y
            let lengthSquared = dx * dx + dy * dy
            let share = lengthSquared > 0 ? min(max(-(start.x * dx + start.y * dy) / lengthSquared, 0), 1) : 0
            let x = start.x + share * dx
            let y = start.y + share * dy
            return (x * x + y * y).squareRoot()
        }

        /// Even-odd ray casting on longitude and latitude, which works for rings that don't cross the date line:
        /// Natural Earth splits its shapes there.
        private static func ring(_ ring: [Double], containsLatitude latitude: Double, longitude: Double) -> Bool {
            let count = ring.count / 2
            guard count >= 3 else { return false }
            var isInside = false
            var previous = count - 1
            for current in 0..<count {
                let currentLongitude = ring[2 * current], currentLatitude = ring[2 * current + 1]
                let previousLongitude = ring[2 * previous], previousLatitude = ring[2 * previous + 1]
                if (currentLatitude > latitude) != (previousLatitude > latitude) {
                    let crossing = (previousLongitude - currentLongitude) * (latitude - currentLatitude)
                        / (previousLatitude - currentLatitude) + currentLongitude
                    if longitude < crossing { isInside.toggle() }
                }
                previous = current
            }
            return isInside
        }
    }

    nonisolated struct City: Decodable, Sendable {
        let name: String
        let lat: Double
        let lon: Double

        var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lon) }
    }

    /// A city of a million or more this close adds "near Montréal" (§4.1).
    static let cityRadius: Double = 40 * GreatCircle.metersPerMile

    /// Land this close beats water or nothing (§4.1): the simplified coastlines can be a few miles off, which would
    /// put New York over the Atlantic.
    static let coastSnap: Double = 5 * GreatCircle.metersPerMile

    let areas: [Area]
    let cities: [City]
    private let regions: [Area]
    private let countries: [Area]
    private let waters: [Area]

    init(areas: [Area], cities: [City]) {
        self.areas = areas
        self.cities = cities
        regions = areas.filter { $0.kind == .state || $0.kind == .province }
        countries = areas.filter { $0.kind == .country }
        waters = areas.filter { $0.kind == .water }
    }

    private enum CodingKeys: String, CodingKey {
        case areas, cities
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(areas: try container.decode([Area].self, forKey: .areas),
                  cities: try container.decodeIfPresent([City].self, forKey: .cities) ?? [])
    }

    init(data: Data) throws {
        self = try JSONDecoder().decode(Geography.self, from: data)
    }

    /// The app's copy, or nil (logged) if it's missing or unreadable.
    static func loadBundled(from bundle: Bundle = .main) -> Geography? {
        guard let url = bundle.url(forResource: "geography", withExtension: "json") else {
            debugLog("Geography: geography.json isn't in the bundle")
            return nil
        }
        do {
            return try Geography(data: Data(contentsOf: url))
        } catch {
            debugLog("Geography: couldn't read geography.json: \(error)")
            return nil
        }
    }

    /// The state or province, else the country, under `coordinate`; else one within 5 mi; else the named water; else nil.
    func place(at coordinate: CLLocationCoordinate2D) -> Place? {
        let latitude = coordinate.latitude
        let longitude = Self.wrapped(coordinate.longitude)
        for land in [regions, countries] {
            if let area = land.first(where: { $0.contains(latitude: latitude, longitude: longitude) }) {
                return area.place
            }
        }
        for land in [regions, countries] {
            let nearest = land
                .filter { $0.isNear(latitude: latitude, longitude: longitude, within: Self.coastSnap) }
                .map { (area: $0, meters: $0.distanceToEdge(latitude: latitude, longitude: longitude)) }
                .filter { $0.meters <= Self.coastSnap }
                .min { $0.meters < $1.meters }
            if let nearest {
                return nearest.area.place
            }
        }
        return waters.first { $0.contains(latitude: latitude, longitude: longitude) }?.place
    }

    /// The nearest city of a million or more within 40 mi.
    func city(near coordinate: CLLocationCoordinate2D) -> City? {
        cities
            .map { (city: $0, meters: GreatCircle.distance(from: coordinate, to: $0.coordinate)) }
            .filter { $0.meters <= Self.cityRadius }
            .min { $0.meters < $1.meters }?
            .city
    }

    /// A longitude within −180..<180.
    private static func wrapped(_ longitude: Double) -> Double {
        let shifted = (longitude + 180).truncatingRemainder(dividingBy: 360)
        return (shifted < 0 ? shifted + 360 : shifted) - 180
    }
}
