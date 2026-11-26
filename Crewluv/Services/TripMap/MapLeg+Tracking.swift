//
//  MapLeg+Tracking.swift
//  CrewLuve
//
//  How the flight between its gates is known now, and whether it's on the ground at its departure airport (live or
//  scheduled design §2, §3), as the website's flightTracking.ts. Every word that says where a flight comes from reads
//  these. Now only: a replay's moment shows the plane the map draws.
//

import Foundation

nonisolated extension MapLeg {

    /// When the schedule's plane takes off: the gate departure plus the taxi allowance (`FlightProgress`).
    var scheduledTakeoff: Date {
        FlightProgress.scheduledTakeoff(departure: start, arrival: end)
    }

    /// How the flight is known at `date` (live or scheduled design §2).
    func tracking(at date: Date) -> FlightTracking {
        guard let flight, flight.live != nil else { return isAwaitingLive ? .waiting : .notTracked }
        switch flight.progress(at: date).phase {
        case .notLive: return .notTracked
        case .estimated: return .bestGuess
        case .onGround, .returned, .inAir, .landed, .elsewhere: return .live
        }
    }

    /// Whether the flight, between its gates at `date`, is on the ground at its departure airport, and how that's
    /// told (live or scheduled design §3). Nil in the air, out of sight, down, outside its gate times, and for a drive.
    /// A plane on the ground at departure never reads "Over …", "In the air now" or "Flying into the night", and has
    /// passed nothing yet.
    func atDeparture(at date: Date) -> AtDeparture? {
        guard kind == .flight, isMoving(at: date) else { return nil }
        let isDue = date < scheduledTakeoff
        guard let flight, !flight.isNotLive(at: date) else { return isDue ? .due : nil }
        return flight.seenAtDeparture(at: date)
    }
}
