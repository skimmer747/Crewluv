//
//  FlightOnGround.swift
//  CrewLuve
//
//  A flight between its gates whose real plane is on the ground now, as the line under the timeline names it in place
//  of "Flying to" (which plane design §4, landed before the gate design §3, air return design §3).
//

nonisolated enum FlightOnGround {
    /// Still at its departure airport after the plan's takeoff time: "On the ground in Rockford".
    case stillIn(AirportMark)
    /// Back at its departure airport after an air return: "Returned to Rockford".
    case returnedTo(AirportMark)
    /// Down at its arrival airport, before the gate: "Landed in Anchorage".
    case landedIn(AirportMark)

    /// The airport it's on the ground at.
    var airport: AirportMark {
        switch self {
        case .stillIn(let airport), .returnedTo(let airport), .landedIn(let airport): airport
        }
    }
}
