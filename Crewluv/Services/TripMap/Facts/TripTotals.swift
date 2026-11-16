//
//  TripTotals.swift
//  CrewLuve
//
//  A trip's numbers (Stage 2 spec §4.8): cities, miles, time zones crossed and sunsets from the cockpit, so far or for
//  the whole trip (a recap, or a forecast of a trip ahead), and its longest flight.
//

import Foundation

nonisolated struct TripTotals: Equatable, Sendable {
    let cities: Int
    let miles: Int
    let timeZones: Int
    let cockpitSunsets: Int

    /// Up to `date`: finished flights, and the miles of the one in the air.
    /// - Parameter isReplay: `date` is a moment of the replay, not now.
    static func soFar(on tripMap: TripMap, at date: Date, sunEvents: [String: [SkyFacts.SunEvent]],
                      isReplay: Bool = false) -> TripTotals {
        let finished = tripMap.legs.filter { $0.kind == .flight && $0.end <= date }
        return TripTotals(
            cities: TripMapWording.destinations(of: finished, leavingOut: homeCodes(of: tripMap)).count,
            miles: TripMapWording.milesFlown(by: date, on: tripMap.legs, isReplay: isReplay),
            timeZones: timeZonesCrossed(by: finished),
            cockpitSunsets: sunsets(on: tripMap.legs, by: date, in: sunEvents)
        )
    }

    /// The whole trip.
    static func whole(_ tripMap: TripMap, sunEvents: [String: [SkyFacts.SunEvent]]) -> TripTotals {
        TripTotals(
            cities: TripMapWording.destinations(of: tripMap.legs, leavingOut: homeCodes(of: tripMap)).count,
            miles: TripMapWording.totalMiles(of: tripMap.legs),
            timeZones: timeZonesCrossed(by: tripMap.legs),
            cockpitSunsets: sunsets(on: tripMap.legs, by: .distantFuture, in: sunEvents)
        )
    }

    /// Each flight's change in UTC offset as a positive number, summed in seconds and rounded to the nearest hour at
    /// the end. A flight with an unknown time zone at either end adds nothing. Across the date line that's the change
    /// in offset, not the zones flown over: Tokyo to Anchorage counts 18.
    static func timeZonesCrossed(by legs: [MapLeg]) -> Int {
        let seconds = legs.filter { $0.kind == .flight }.reduce(0) { total, leg in
            guard let from = leg.origin.timeZone, let to = leg.destination.timeZone else { return total }
            return total + abs(to.secondsFromGMT(for: leg.end) - from.secondsFromGMT(for: leg.start))
        }
        return Int((Double(seconds) / 3600).rounded())
    }

    /// The flight with the most miles, along its real path where it has one.
    static func longestFlight(of legs: [MapLeg]) -> MapLeg? {
        legs.filter { $0.kind == .flight }.max { $0.pathLength < $1.pathLength }
    }

    // MARK: - Private

    private static func sunsets(on legs: [MapLeg], by date: Date, in sunEvents: [String: [SkyFacts.SunEvent]]) -> Int {
        legs.reduce(0) { count, leg in
            count + (sunEvents[leg.id] ?? []).filter { $0.kind == .sunset && $0.time <= date }.count
        }
    }

    private static func homeCodes(of tripMap: TripMap) -> Set<String> {
        Set([tripMap.home?.code].compactMap { $0 })
    }
}
