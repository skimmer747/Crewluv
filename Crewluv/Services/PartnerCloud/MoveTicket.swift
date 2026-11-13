//
//  MoveTicket.swift
//  CrewLuve
//
//  This partner's move-over ticket in the pilot's iCloud record
//

import Foundation

/// The move-over's tickets in the pilot's iCloud record (partner links piece 4 spec §8.1): CrewLu
/// writes `{iCloud user record name: ticket}` for each partner it moved to Crewlu Cloud who hasn't
/// moved over yet. A ticket joins Crewlu Cloud once, as that partner, so it's never logged (§9).
nonisolated enum MoveTicket {
    /// The record's field.
    static let recordKey = "moveTicketByPartnerJSON"

    /// The ticket for the partner whose iCloud user record name is `recordName`, or nil when there's
    /// none for them, or the field doesn't read.
    static func ticket(in tickets: Data?, for recordName: String?) -> String? {
        guard let tickets, let recordName,
              let ticketByRecordName = try? JSONDecoder().decode([String: String].self, from: tickets),
              let ticket = ticketByRecordName[recordName], !ticket.isEmpty
        else { return nil }
        return ticket
    }
}
