//
//  NarrativeFlight.swift
//  CrewLuve
//
//  How the status sentence tells the flight under way (live or scheduled design §4), in place of three Booleans: by
//  its real plane where Crewlu Cloud sees it, else by the schedule, saying so.
//

nonisolated enum NarrativeFlight: Equatable, Sendable {
    /// In the air, seen or a best guess: "Alex is flying to Honolulu …", as before.
    case flying
    /// Its real plane at its gate before the plan's takeoff: "Alex is on the ground in Louisville …" (§4.2).
    case atGate
    /// Still there after it: "Alex is still on the ground in Louisville …" (which plane design §4).
    case stillAtGate
    /// Back there after an air return: "Alex has returned to Rockford …" (air return design §3).
    case returned
    /// Down at the arrival airport, before the gate: "Alex has landed in Anchorage …" (landed before the gate design §3).
    case landed
    /// By the schedule alone, before the schedule's takeoff: "Alex is due to take off from Louisville …" (§4.2).
    case dueToTakeOff
    /// By the schedule alone, after it: "Alex should be flying to Honolulu … — not tracked live — …", without "not
    /// tracked live" while Crewlu Cloud's first answer is on its way (§2, §4.1).
    case shouldBeFlying(saysNotTracked: Bool)
}
