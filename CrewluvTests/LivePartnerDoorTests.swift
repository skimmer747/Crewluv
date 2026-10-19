//
//  LivePartnerDoorTests.swift
//  CrewluvTests
//
//  The partner door's calls and answers, against a stand-in for the network
//  (partner-api.md; partner links piece 4 spec §5.2).
//

import Foundation
import Testing
@testable import Crewluv

@MainActor
struct LivePartnerDoorTests {

    private static let partner = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
    private static let key = String(repeating: "ab", count: 32)
    private static let updatedAt = "2026-10-18T22:01:40.493+00:00"
    private static let status = #"{"pilotId": "pilot", "pilotFirstName": "Alex", "lastUpdated": 1792605600, "appVersion": "3.0"}"#

    // MARK: - The Request

    @Test func test_view_postsTheKeyWithOnlyThePublishableKey() async throws {
        let network = StandInNetwork(body: #"{"partner_id": "\#(Self.partner)", "updated_at": null, "status": null}"#)
        _ = try await network.door.view(key: Self.key, since: nil)

        let request = try #require(network.requests.first)
        #expect(network.requests.count == 1)
        #expect(request.url?.absoluteString == "https://corxvurxpnrzekbxdgye.supabase.co/rest/v1/rpc/partner_view")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "apikey") == LivePartnerDoor.publishableKey)
        #expect(LivePartnerDoor.publishableKey.hasPrefix("sb_publishable_"))
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.timeoutInterval == 20)
        #expect(try network.parameters(request) == ["p_key": Self.key])
    }

    @Test func test_view_sendsSinceBackAsItCame() async throws {
        let network = StandInNetwork(body: #"{"partner_id": "\#(Self.partner)", "updated_at": "\#(Self.updatedAt)", "unchanged": true}"#)
        _ = try await network.door.view(key: Self.key, since: Self.updatedAt)

        #expect(try network.parameters(#require(network.requests.first)) == ["p_key": Self.key, "p_since": Self.updatedAt])
    }

    @Test func test_setPush_postsTheTokenAndItsEnvironment() async throws {
        let network = StandInNetwork(body: #"{"ok": true}"#)
        try await network.door.setPush(key: Self.key, token: "0a1b2c", environment: .sandbox)

        let request = try #require(network.requests.first)
        #expect(request.url?.absoluteString == "https://corxvurxpnrzekbxdgye.supabase.co/rest/v1/rpc/partner_set_push")
        #expect(request.value(forHTTPHeaderField: "apikey") == LivePartnerDoor.publishableKey)
        #expect(try network.parameters(request) == ["p_key": Self.key, "p_token": "0a1b2c", "p_env": "sandbox"])
    }

    // MARK: - Answers

    @Test func test_view_summary() async throws {
        let network = StandInNetwork(
            body: #"{"partner_id": "\#(Self.partner)", "updated_at": "\#(Self.updatedAt)", "status": \#(Self.status)}"#
        )
        let answer = try await network.door.view(key: Self.key, since: nil)

        #expect(answer.partnerID == Self.partner)
        #expect(answer.updatedAt == Self.updatedAt)
        guard case .summary(let summary) = answer.content else {
            Issue.record("expected a summary, got \(answer.content)")
            return
        }
        #expect(summary.pilotFirstName == "Alex")
    }

    @Test func test_view_beforeTheFirstSummary() async throws {
        let network = StandInNetwork(body: #"{"partner_id": "\#(Self.partner)", "updated_at": null, "status": null}"#)
        let answer = try await network.door.view(key: Self.key, since: nil)

        #expect(answer.partnerID == Self.partner)
        #expect(answer.updatedAt == nil)
        guard case .noSummaryYet = answer.content else {
            Issue.record("expected no summary yet, got \(answer.content)")
            return
        }
    }

    @Test func test_view_unchanged() async throws {
        let network = StandInNetwork(body: #"{"partner_id": "\#(Self.partner)", "updated_at": "\#(Self.updatedAt)", "unchanged": true}"#)
        let answer = try await network.door.view(key: Self.key, since: Self.updatedAt)

        #expect(answer.updatedAt == Self.updatedAt)
        guard case .unchanged = answer.content else {
            Issue.record("expected unchanged, got \(answer.content)")
            return
        }
    }

    @Test func test_setPush_ok() async throws {
        try await StandInNetwork(body: #"{"ok": true}"#).door.setPush(key: Self.key, token: "0a1b2c", environment: .production)
    }

    @Test(arguments: [
        ("sharing_ended", PartnerDoorError.refused(.sharingEnded)),
        ("invalid_input", .refused(.invalidInput)),
        ("key_in_use", .refused(.keyInUse)),
        ("too_many_devices", .refused(.tooManyDevices)),
        ("try_later", .refused(.tryLater)),
        ("a_refusal_from_a_newer_door", .unavailable),
    ])
    func test_refusals(error: String, expected: PartnerDoorError) async {
        let network = StandInNetwork(body: #"{"error": "\#(error)"}"#)

        await #expect(throws: expected) { try await network.door.view(key: Self.key, since: nil) }
        await #expect(throws: expected) { try await network.door.setPush(key: Self.key, token: "0a1b2c", environment: .sandbox) }
    }

    @Test(arguments: [400, 401, 404, 500, 503])
    func test_anHTTPStatusOtherThan200_isUnavailable(status: Int) async {
        let network = StandInNetwork(status: status, body: #"{"partner_id": "\#(Self.partner)", "updated_at": null, "status": null}"#)

        await #expect(throws: PartnerDoorError.unavailable) { try await network.door.view(key: Self.key, since: nil) }
    }

    @Test func test_noNetwork_isUnavailable() async {
        let network = StandInNetwork(error: URLError(.notConnectedToInternet))

        await #expect(throws: PartnerDoorError.unavailable) { try await network.door.view(key: Self.key, since: nil) }
        await #expect(throws: PartnerDoorError.unavailable) {
            try await network.door.setPush(key: Self.key, token: "0a1b2c", environment: .sandbox)
        }
    }

    @Test(arguments: [
        "<html>Bad gateway</html>",
        #"{"updated_at": null, "status": null}"#,
        #"{"partner_id": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa", "updated_at": null, "status": {"pilotFirstName": "Alex"}}"#,
    ])
    func test_anAnswerThatDoesntDecode_isUnavailable(body: String) async {
        let network = StandInNetwork(body: body)

        await #expect(throws: PartnerDoorError.unavailable) { try await network.door.view(key: Self.key, since: nil) }
    }
}

// MARK: - A Stand-in for the Network

/// Records each request and answers every one with the same status and body, or fails them all.
@MainActor
private final class StandInNetwork {
    private(set) var requests: [URLRequest] = []
    private let answer: Result<(status: Int, body: Data), any Error>

    init(status: Int = 200, body: String) {
        answer = .success((status, Data(body.utf8)))
    }

    init(error: any Error) {
        answer = .failure(error)
    }

    var door: LivePartnerDoor {
        LivePartnerDoor(transport: { request in try await self.send(request) })
    }

    /// A request's JSON body.
    func parameters(_ request: URLRequest) throws -> [String: String] {
        try JSONDecoder().decode([String: String].self, from: #require(request.httpBody))
    }

    private func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        let (status, body) = try answer.get()
        let url = try #require(request.url)
        let response = try #require(HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/2", headerFields: nil))
        return (body, response)
    }
}
