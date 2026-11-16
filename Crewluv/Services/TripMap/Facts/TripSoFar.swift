//
//  TripSoFar.swift
//  CrewLuve
//
//  The facts sheet dragged all the way up (Stage 2 spec §5.2, §5.5; best guesses design §3, §4): the flight between
//  its gates, set apart, and each earlier flight, newest first. Under each, what has happened, newest first. Then
//  the totals.
//

nonisolated struct TripSoFar: Equatable, Sendable {

    /// One line of a flight's list: "Crossed into Canada · 1:12 PM".
    nonisolated struct Event: Equatable, Sendable {
        let text: String
        /// A best guess, where nobody saw the plane. Its time reads "about", and it's drawn lighter.
        let isEstimate: Bool
    }

    nonisolated struct Flight: Identifiable, Equatable, Sendable {
        let id: String
        /// "UPS207 · Louisville → Cologne".
        let title: String
        /// "In the air now" for the flight between its gates, which the list sets apart. Nil for any other.
        let tag: String?
        /// What has happened so far, newest first.
        let events: [Event]
    }

    /// The flight between its gates, and each earlier flight with at least one event so far.
    let flights: [Flight]
    /// "Trip so far", or "Trip recap" once a recap's trip is over.
    let totalsTitle: String
    /// Nil with nothing to say, and where the rows above already have a "Trip so far" row.
    let totals: String?
}
