//
//  AtDeparture.swift
//  CrewLuve
//
//  How a flight on the ground at its departure airport is told (live or scheduled design §3, §4.2).
//

nonisolated enum AtDeparture: Equatable, Sendable {
    /// Known by the schedule alone, before the schedule's takeoff: "Scheduled to take off about 3:14 PM L".
    case due
    /// Its real plane seen there before the plan's takeoff: "On the ground in Louisville".
    case atGate
    /// Seen there after it: "Still on the ground in Louisville" (which plane design §4).
    case stillAtGate
    /// Back there after an air return: "Returned to Rockford" (air return design §3).
    case returned

    /// Whether it's the real plane seen at its departure airport, not the schedule's: the list leaves it out until it
    /// takes off.
    var isSeen: Bool { self != .due }
}
