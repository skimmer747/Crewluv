//
//  Milestone.swift
//  CrewLuve
//
//  A moment worth a line on a flight (Stage 2 spec §4.3): crossing into a new country, state or province, out over a
//  named sea, halfway, and the closest point to home. Each leads the headline for 5 minutes.
//

import Foundation

nonisolated struct Milestone: Equatable, Sendable {

    nonisolated enum Kind: Equatable, Sendable {
        /// A new country, or a new state or province in the same country: "Just crossed into Kansas".
        case crossedInto(String)
        /// From land onto a named water: "Out over the Atlantic".
        case outOver(String)
        case halfway
        /// The closest the route comes to home, to the nearest 5 mi.
        case closestToHome(miles: Int)
    }

    let kind: Kind
    let time: Date
    /// Nobody saw the plane where this happened, so it's a best guess from where the plan has the plane, and its
    /// time reads "about" (best guesses design §2).
    let isEstimate: Bool

    init(kind: Kind, time: Date, isEstimate: Bool = false) {
        self.kind = kind
        self.time = time
        self.isEstimate = isEstimate
    }

    /// How long a milestone leads the headline.
    static let headlineDuration: TimeInterval = 5 * 60

    /// A flight's milestones in time order, from its story and the leg's own times: the real plane's along a real
    /// path, else the schedule's. Where nobody saw the real plane, on a stretch with no coverage or past the last
    /// place it was seen, a milestone is a best guess from where the plan has the plane, and says so
    /// (`isEstimate`). Halfway is half the path's whole length, flown and ahead.
    static func milestones(on leg: MapLeg, story: LegStory) -> [Milestone] {
        var found: [(kind: Kind, distance: Double)] = []
        // The state or province the plane is in, kept across a stretch where only the country is known.
        var region = story.stretches.first.flatMap { isRegion($0.place) ? $0.place.name : nil }
        for (previous, next) in zip(story.stretches, story.stretches.dropFirst()) {
            let isSameCountry = next.place.country == previous.place.country
            defer {
                if isRegion(next.place) {
                    region = next.place.name
                } else if !isSameCountry {
                    region = nil
                }
            }
            // Back into the state it was already in, after such a gap, is no crossing.
            if isRegion(next.place), isSameCountry, next.place.name == region { continue }
            if let kind = crossingKind(from: previous.place, to: next.place) {
                found.append((kind, next.start * story.length))
            }
        }
        found.append((.halfway, leg.pathLength / 2))
        if let closest = story.closestToHome {
            found.append((.closestToHome(miles: roundedMiles(closest.meters)), closest.fraction * story.length))
        }
        return found.enumerated()
            .sorted { ($0.element.distance, $0.offset) < ($1.element.distance, $1.offset) }
            .compactMap { item in
                let time = item.element.kind == .halfway ? leg.halfwayTime : leg.time(atDistance: item.element.distance)
                return time.map {
                    Milestone(kind: item.element.kind, time: $0, isEstimate: !leg.isSeen(atDistance: item.element.distance))
                }
            }
    }

    /// To the nearest 5 mi, and never under 5.
    static func roundedMiles(_ meters: Double) -> Int {
        max(5, Int((meters / GreatCircle.metersPerMile / 5).rounded()) * 5)
    }

    // MARK: - Private

    /// A state or province: land that isn't a whole country.
    private static func isRegion(_ place: Geography.Place) -> Bool {
        !place.isWater && place.kind != .country
    }

    /// What moving from one place to the next means, if anything.
    private static func crossingKind(from previous: Geography.Place, to next: Geography.Place) -> Kind? {
        if next.isWater {
            // One sea into another changes the "below" row but isn't a milestone.
            return previous.isWater ? nil : .outOver(next.name)
        }
        if next.country != previous.country {
            // An international border, or landfall, names the country.
            return .crossedInto(next.country ?? next.name)
        }
        // The same country: a new state or province counts. A gap between two, where only the country is known, doesn't.
        return next.kind == .country ? nil : .crossedInto(next.name)
    }
}
