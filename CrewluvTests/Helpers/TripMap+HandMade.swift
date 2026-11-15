//
//  TripMap+HandMade.swift
//  CrewluvTests
//
//  The facts' tests make maps by hand, with no ground legs from CrewLu. This keeps them as they were before `TripMap`
//  kept its ground stops (activity markers design §2.2).
//

import Foundation
@testable import Crewluv

extension TripMap {
    init(mode: Mode, legs: [MapLeg], home: AirportMark?, span: DateInterval, tripDays: Int?) {
        self.init(mode: mode, legs: legs, groundStops: [], home: home, base: nil, isWaitingAtBase: false, span: span,
                  tripDays: tripDays)
    }
}
