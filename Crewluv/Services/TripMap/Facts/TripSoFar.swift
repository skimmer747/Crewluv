//
//  TripSoFar.swift
//  CrewLuve
//
//  The facts sheet dragged all the way up (Stage 2 spec §5.2, §5.5): each started flight's milestones, newest flight
//  first, then the totals.
//

nonisolated struct TripSoFar: Equatable, Sendable {

    nonisolated struct Flight: Identifiable, Equatable, Sendable {
        let id: String
        /// "UPS207 · Louisville → Cologne".
        let title: String
        /// "Crossed into Canada · 1:12 PM", in order.
        let milestones: [String]
    }

    /// Flights with at least one milestone so far.
    let flights: [Flight]
    /// "Trip so far", or "Trip recap" once a recap's trip is over.
    let totalsTitle: String
    let totals: String?
}
