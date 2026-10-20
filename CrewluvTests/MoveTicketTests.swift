//
//  MoveTicketTests.swift
//  CrewluvTests
//
//  This partner's move-over ticket in the pilot's iCloud record (partner links piece 4 spec §8.1)
//

import Foundation
import Testing
@testable import Crewluv

struct MoveTicketTests {
    /// As CrewLu writes it: `{iCloud user record name: ticket}`, with sorted keys.
    private static let tickets = Data(#"{"_0a1b":"ticket-for-mom","_2c3d":"ticket-for-ruthanne"}"#.utf8)

    @Test func test_thisPartnersTicket() {
        #expect(MoveTicket.ticket(in: Self.tickets, for: "_2c3d") == "ticket-for-ruthanne")
    }

    @Test func test_noTicketForThisPartner() {
        #expect(MoveTicket.ticket(in: Self.tickets, for: "_4e5f") == nil)
    }

    @Test func test_withoutThisPartnersRecordName_noTicket() {
        #expect(MoveTicket.ticket(in: Self.tickets, for: nil) == nil)
    }

    @Test func test_noField_orOneThatDoesntRead_givesNoTicket() {
        #expect(MoveTicket.ticket(in: nil, for: "_2c3d") == nil)
        #expect(MoveTicket.ticket(in: Data("not tickets".utf8), for: "_2c3d") == nil)
        #expect(MoveTicket.ticket(in: Data(#"{"_2c3d":""}"#.utf8), for: "_2c3d") == nil)
    }

    @Test func test_theRecordsField() {
        #expect(MoveTicket.recordKey == "moveTicketByPartnerJSON")
    }
}
