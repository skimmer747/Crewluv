//
//  GroundStop.swift
//  CrewLuve
//
//  One of CrewLu's own ground legs, which the trip map keeps to name each wait (activity markers design §2.2): a
//  layover, a turn, or a stay at base or at home, at its scheduled times. A delay moves the flights, never these.
//

import Foundation

nonisolated struct GroundStop {
    /// `.layover`, `.turn`, `.base` or `.home`.
    let kind: TripActivity.Kind
    let start: Date
    let end: Date
}

nonisolated extension GroundStop {
    /// The stop for CrewLu's layover, turn, base or home leg; nil for a flight, a drive or anything else.
    init?(leg: TripLeg) {
        let kind: TripActivity.Kind
        switch leg.type {
        case .layover: kind = .layover
        case .turn: kind = .turn
        case .base: kind = .base
        case .home: kind = .home
        case .flight, .drive, .reserve, .hotStandby, .event, .unknown: return nil
        }
        self.init(kind: kind, start: leg.startTime, end: leg.endTime)
    }
}
