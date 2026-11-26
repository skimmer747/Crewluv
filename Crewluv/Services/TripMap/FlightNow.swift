//
//  FlightNow.swift
//  CrewLuve
//
//  What the line under the timeline names of the flight between its gates now, in place of the activity's words
//  (which plane design §4, landed before the gate design §3, air return design §3, live or scheduled design §4).
//

nonisolated enum FlightNow {
    /// Its real plane at its departure airport, before or after the plan's takeoff time: "On the ground in Rockford".
    case stillIn(AirportMark)
    /// Back at its departure airport after an air return: "Returned to Rockford".
    case returnedTo(AirportMark)
    /// Down at its arrival airport, before the gate: "Landed in Anchorage".
    case landedIn(AirportMark)
    /// By the schedule alone, before the schedule's takeoff: "Scheduled to fly to Honolulu".
    case dueTo(AirportMark)
    /// By the schedule alone, after it: "Should be flying to Honolulu".
    case shouldBeFlyingTo(AirportMark)

    /// The airport it names.
    var airport: AirportMark {
        switch self {
        case .stillIn(let airport), .returnedTo(let airport), .landedIn(let airport), .dueTo(let airport),
             .shouldBeFlyingTo(let airport): airport
        }
    }
}
