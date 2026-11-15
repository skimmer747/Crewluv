//
//  LegStory.swift
//  CrewLuve
//
//  A flight's story, worked out once (Stage 2 spec §4.2): the places under its route and its closest point to home,
//  as fractions of the way along, 0 at the departure airport and 1 at the arrival. The schedule turns a fraction into
//  a time (`MapLeg.time(atFraction:)`), so a new delay moves every time without redoing the geography.
//

import CoreLocation

nonisolated struct LegStory: Sendable {

    /// A place under the route, from where it starts.
    nonisolated struct Stretch: Equatable, Sendable {
        let place: Geography.Place
        let start: Double
    }

    /// The route's closest point to home.
    nonisolated struct ClosestToHome: Equatable, Sendable {
        let fraction: Double
        let meters: Double
    }

    /// The route is looked up this often.
    static let sampleSpacing: Double = 10 * GreatCircle.metersPerMile
    static let minimumSamples = 16
    /// A place counts once the route stays in it this far, so a route along a border doesn't flicker.
    static let holdDistance: Double = 25 * GreatCircle.metersPerMile
    /// Crossings and the closest point are narrowed down to this.
    static let precision: Double = 0.1 * GreatCircle.metersPerMile
    /// Home counts when the route passes this close.
    static let homeRadius: Double = 100 * GreatCircle.metersPerMile

    /// In order. The first starts at 0. Empty without geography.
    let stretches: [Stretch]
    let closestToHome: ClosestToHome?

    init(stretches: [Stretch], closestToHome: ClosestToHome?) {
        self.stretches = stretches
        self.closestToHome = closestToHome
    }

    /// - Parameter home: where home is, or nil for a flight that starts or ends there.
    init(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, geography: Geography?, home: CLLocationCoordinate2D?) {
        let route = Route(origin: origin, destination: destination)
        stretches = geography.map { Self.stretches(along: route, in: $0) } ?? []
        closestToHome = home.flatMap { Self.closestPoint(of: route, to: $0) }
    }

    /// A flight's story. Home counts only when the flight doesn't start or end there.
    init(leg: MapLeg, geography: Geography?, home: AirportMark?) {
        let isHomeLeg = home.map { $0.code == leg.origin.code || $0.code == leg.destination.code } ?? true
        self.init(from: leg.origin.coordinate, to: leg.destination.coordinate, geography: geography,
                  home: isHomeLeg ? nil : home?.coordinate)
    }

    /// The place `fraction` of the way along.
    func place(atFraction fraction: Double) -> Geography.Place? {
        stretches.last { $0.start <= fraction }?.place
    }

    // MARK: - Private

    private struct Route {
        let origin: CLLocationCoordinate2D
        let destination: CLLocationCoordinate2D
        let length: Double
        let sampleCount: Int

        init(origin: CLLocationCoordinate2D, destination: CLLocationCoordinate2D) {
            self.origin = origin
            self.destination = destination
            length = GreatCircle.distance(from: origin, to: destination)
            sampleCount = max(LegStory.minimumSamples, Int((length / LegStory.sampleSpacing).rounded(.up)) + 1)
        }

        var step: Double { 1 / Double(sampleCount - 1) }

        func point(at fraction: Double) -> CLLocationCoordinate2D {
            GreatCircle.point(from: origin, to: destination, fraction: fraction)
        }
    }

    private struct Run {
        let place: Geography.Place
        let first: Int
        var last: Int
    }

    private static func stretches(along route: Route, in geography: Geography) -> [Stretch] {
        let places = (0..<route.sampleCount).map { geography.place(at: route.point(at: Double($0) * route.step)) }

        // Runs of one place. A sample with no place joins no run, so a gap changes nothing.
        var runs: [Run] = []
        for (index, place) in places.enumerated() {
            guard let place else { continue }
            if runs.last?.place == place {
                runs[runs.count - 1].last = index
            } else {
                runs.append(Run(place: place, first: index, last: index))
            }
        }

        // The hold rule: a run shorter than 25 mi goes, and the runs either side of it join if they're one place.
        let spacing = route.length * route.step
        var held: [Run] = []
        for run in runs where Double(run.last - run.first + 1) * spacing >= holdDistance {
            if held.last?.place == run.place {
                held[held.count - 1].last = run.last
            } else {
                held.append(run)
            }
        }

        guard let first = held.first else { return [] }
        var stretches = [Stretch(place: first.place, start: 0)]
        for (previous, next) in zip(held, held.dropFirst()) {
            let start = boundary(of: next.place, after: Double(previous.last) * route.step, before: Double(next.first) * route.step,
                                 along: route, in: geography)
            stretches.append(Stretch(place: next.place, start: start))
        }
        return stretches
    }

    /// Where `place` begins between two fractions, by bisection.
    private static func boundary(of place: Geography.Place, after low: Double, before high: Double,
                                 along route: Route, in geography: Geography) -> Double {
        var low = low
        var high = high
        while (high - low) * route.length > precision {
            let middle = (low + high) / 2
            if geography.place(at: route.point(at: middle)) == place {
                high = middle
            } else {
                low = middle
            }
        }
        return high
    }

    private static func closestPoint(of route: Route, to home: CLLocationCoordinate2D) -> ClosestToHome? {
        let distances = (0..<route.sampleCount).map { GreatCircle.distance(from: route.point(at: Double($0) * route.step), to: home) }
        guard let nearest = distances.indices.min(by: { distances[$0] < distances[$1] }),
              nearest > 0, nearest < route.sampleCount - 1 else { return nil }

        // The distance has one minimum between the nearest sample's neighbours: narrow it down by thirds.
        var low = Double(nearest - 1) * route.step
        var high = Double(nearest + 1) * route.step
        while (high - low) * route.length > precision {
            let third = (high - low) / 3
            if GreatCircle.distance(from: route.point(at: low + third), to: home) < GreatCircle.distance(from: route.point(at: high - third), to: home) {
                high -= third
            } else {
                low += third
            }
        }
        let fraction = (low + high) / 2
        let meters = GreatCircle.distance(from: route.point(at: fraction), to: home)
        return meters <= homeRadius ? ClosestToHome(fraction: fraction, meters: meters) : nil
    }
}
