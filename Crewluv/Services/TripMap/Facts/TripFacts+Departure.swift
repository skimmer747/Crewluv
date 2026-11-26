//
//  TripFacts+Departure.swift
//  CrewLuve
//
//  How the facts tell the flight between its gates while it's on the ground at either end, and while it's known by the
//  schedule alone (live or scheduled design §3, §4, §5, §6; which plane design §4; landed before the gate design §2):
//  the words in place of what's below, which times are guesses, and the list's tag. Now only: a replay reads where the
//  map has the plane.
//

import Foundation

nonisolated extension TripFacts {

    // MARK: - On the ground

    /// Whether `leg`, the leg between its gates at `date`, is on the ground at its departure airport, and how that's
    /// told (live or scheduled design §3): by the schedule before its takeoff, or its real plane seen there. The facts
    /// then say so in place of what's below, count nothing as flown, and pass nothing. Now only: a replay reads where
    /// the map has the plane.
    func atDeparture(of leg: MapLeg, at date: Date) -> AtDeparture? {
        isReplay ? nil : leg.atDeparture(at: date)
    }

    /// What the facts say in place of what's below while `atDeparture` holds (live or scheduled design §4.2):
    /// "Scheduled to take off about 3:14 PM L", "On the ground in Louisville", "Still on the ground in Louisville"
    /// (which plane design §4), or "Returned to Rockford" (air return design §3).
    func atDepartureWords(_ atDeparture: AtDeparture, on leg: MapLeg) -> String {
        switch atDeparture {
        case .due: FactsWording.scheduledTakeoff(at: leg.scheduledTakeoff, calendar: calendar, locale: locale)
        case .atGate: FactsWording.onTheGround(in: leg.origin)
        case .stillAtGate: FactsWording.stillOnGround(in: leg.origin)
        case .returned: FactsWording.returned(to: leg.origin)
        }
    }

    /// Whether the real plane of `leg`, the leg between its gates at `date`, has landed and isn't at the gate yet
    /// (landed before the gate design §2). The facts then say "Landed in Anchorage" in place of what's below, and the
    /// list's tag says "Landed". Now only: a replay reads where the map has the plane.
    func isLandedBeforeGate(_ leg: MapLeg, at date: Date) -> Bool {
        !isReplay && leg.isLandedBeforeGate(at: date)
    }

    // MARK: - Guesses

    /// Whether `leg`'s guessed times at `date` are the schedule's alone (live or scheduled design §5): it's between
    /// its gates now and known by the schedule. Its events, halfway and closest point to home then read "about", as an
    /// unseen stretch's do. Now only, and only the flight between its gates: earlier flights, the recap and a replay
    /// read as before.
    func isGuessedFromSchedule(_ leg: MapLeg, at date: Date) -> Bool {
        !isReplay && leg.isMoving(at: date) && leg.tracking(at: date).isBySchedule
    }

    /// Whether the time `leg`'s plane is `distance` meters along its path is a guess at `date`, and reads "about": on
    /// the ground at its departure airport, where it's a guess from a takeoff that hasn't happened (which plane design
    /// §4), by the schedule alone (live or scheduled design §5), or where nobody saw the plane (best guesses design §2).
    func isGuess(on leg: MapLeg, atDistance distance: Double, at date: Date) -> Bool {
        atDeparture(of: leg, at: date) != nil || isGuessedFromSchedule(leg, at: date) || !leg.isSeen(atDistance: distance)
    }

    // MARK: - The list

    /// The tag on the flight between its gates (live or scheduled design §4.1, §6): "By the schedule" for one known by
    /// the schedule alone now, or with no real path in a replay, whose events aren't marked as guesses there ("about"
    /// is now only); else "In the air now", or "In the air" in a replay.
    func flightTag(_ leg: MapLeg, at date: Date) -> String {
        // In a replay, by whether the flight has a real path: "about" and the source are now only.
        let isBySchedule = isReplay ? leg.flight?.path.isReal != true : leg.tracking(at: date).isBySchedule
        return isBySchedule ? TripMapWording.byTheSchedule : FactsWording.inTheAir(isReplay: isReplay)
    }
}
