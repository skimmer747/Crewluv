//
//  PilotDisplayStatus.swift
//  CrewLuve
//
//  Type-safe replacement for the stringly-typed `displayStatus` field that
//  flows from Duty as a free-form `String`. The CloudKit / persistence
//  boundary remains string-encoded (`rawDisplayString`); this enum is the
//  in-app representation that lets the compiler enforce exhaustive handling.
//

import Foundation

nonisolated enum PilotDisplayStatus: Equatable, Hashable, Sendable {
    case home
    case base
    case commutingHome
    case drivingHome
    case drivingToWork
    case inFlight
    case turn
    case layover
    case reserve
    case hotStandby
    case training
    /// Pilot is between trips at an airport that is neither home nor base.
    /// `city` is the location to surface in the UI when known.
    case elsewhere(city: String?)
    /// Anything we did not recognize — preserve the raw string so we don't lose data.
    case unknown(String)

    // MARK: - String Bridge

    init(rawDisplayString: String) {
        switch rawDisplayString {
        case "Home":           self = .home
        case "Base":           self = .base
        case "Commuting Home": self = .commutingHome
        case "Driving Home":   self = .drivingHome
        case "Driving to Work": self = .drivingToWork
        case "In Flight":      self = .inFlight
        case "Turn":           self = .turn
        case "Layover":        self = .layover
        case "Reserve":        self = .reserve
        case "Hot Standby":    self = .hotStandby
        case "Training":       self = .training
        case "Off":            self = .elsewhere(city: nil)
        default:               self = .unknown(rawDisplayString)
        }
    }

    var rawDisplayString: String {
        switch self {
        case .home:           "Home"
        case .base:           "Base"
        case .commutingHome:  "Commuting Home"
        case .drivingHome:    "Driving Home"
        case .drivingToWork:  "Driving to Work"
        case .inFlight:       "In Flight"
        case .turn:           "Turn"
        case .layover:        "Layover"
        case .reserve:        "Reserve"
        case .hotStandby:     "Hot Standby"
        case .training:       "Training"
        case .elsewhere:      "Off"
        case .unknown(let s): s
        }
    }

    // MARK: - Semantic Groups

    /// Pilot is settled at a known reporting location (home or base).
    /// Replaces every `["Home", "Base"].contains(...)` site.
    var isSettled: Bool {
        switch self {
        case .home, .base: true
        default: false
        }
    }

    /// Status that drives a layover-style progress ring (sitting at a fixed
    /// airport waiting for the next leg). Replaces `["Layover", "Base"].contains(...)`.
    var isLayoverLike: Bool {
        switch self {
        case .layover, .base: true
        default: false
        }
    }

    /// Status that drives a duty-period progress ring (timed on-call window).
    /// Replaces `["Reserve", "Hot Standby", "Training"].contains(...)`.
    var isDutyPeriod: Bool {
        switch self {
        case .reserve, .hotStandby, .training: true
        default: false
        }
    }
}

// MARK: - Codable

/// Single-value String container. Existing JSON / UserDefaults storage shapes
/// for any wrapping `Codable` type (e.g. `SharedPilotStatus`, `PilotSnapshot`)
/// remain byte-identical to the previous `displayStatus: String` form.
///
/// `nonisolated` is required because the project builds with
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`: without it, the conformance in
/// this extension would be inferred `@MainActor`-isolated (extensions take the
/// module default, not the `nonisolated` enum's isolation), and `Codable` use
/// from a nonisolated context (e.g. `JSONEncoder`) would fail to compile.
nonisolated extension PilotDisplayStatus: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = PilotDisplayStatus(rawDisplayString: raw)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawDisplayString)
    }
}
