//
//  LivePartnerDoor.swift
//  CrewLuve
//
//  The partner door over the network
//

import Foundation

/// The partner door over HTTPS. Each call is a PostgREST RPC: a POST of its named parameters as
/// JSON, with the publishable key in the `apikey` header and nothing else (partner-api.md).
struct LivePartnerDoor: PartnerDoor {
    /// Sends a request and gives back the answer's body and response.
    typealias Transport = (URLRequest) async throws -> (Data, URLResponse)

    /// Crewlu Cloud's RPC address. A fixed, well-formed URL, so it always parses.
    static let rpcURL = URL(string: "https://corxvurxpnrzekbxdgye.supabase.co/rest/v1/rpc/")!
    /// The publishable key, as the website has it (`src/cloud.ts`). It's public by design: the
    /// partner door's own checks guard the data.
    static let publishableKey = "sb_publishable_1wBeBjIIvEmMygoM9vWA2A_ptocrFGM"
    /// How long a call may take before it counts as unavailable.
    static let timeout: TimeInterval = 20

    private let transport: Transport

    init(transport: @escaping Transport = { try await URLSession.shared.data(for: $0) }) {
        self.transport = transport
    }

    func view(key: String, since: String?) async throws(PartnerDoorError) -> PartnerViewAnswer {
        let answer: ViewAnswer = try await call("partner_view", ViewParameters(key: key, since: since))
        let content: PartnerViewAnswer.Content
        if answer.unchanged == true {
            content = .unchanged
        } else if let summary = answer.status {
            content = .summary(summary)
        } else {
            content = .noSummaryYet
        }
        return PartnerViewAnswer(partnerID: answer.partnerID, updatedAt: answer.updatedAt, content: content)
    }

    func setPush(key: String, token: String, environment: PushEnvironment) async throws(PartnerDoorError) {
        let _: OKAnswer = try await call(
            "partner_set_push", PushParameters(key: key, token: token, environment: environment.rawValue)
        )
    }

    func join(invite: String, key: String, label: String) async throws(PartnerDoorError) -> PartnerJoinAnswer {
        let answer: JoinAnswer = try await call("partner_join", JoinParameters(invite: invite, key: key, label: label))
        return answer.joined
    }

    func redeem(code: String, key: String, label: String) async throws(PartnerDoorError) -> PartnerJoinAnswer {
        let answer: JoinAnswer = try await call("partner_handoff_redeem", RedeemParameters(code: code, key: key, label: label))
        return answer.joined
    }

    func makeHandOffCode(key: String) async throws(PartnerDoorError) -> HandOffCode {
        let answer: HandOffAnswer = try await call("partner_handoff_create", KeyParameters(key: key))
        guard let expiresAt = try? Date(answer.expiresAt, strategy: .iso8601) else {
            debugLog("[PartnerDoor] partner_handoff_create's expiry didn't read")
            throw .unavailable
        }
        return HandOffCode(code: answer.code, expiresAt: expiresAt)
    }

    func leave(key: String) async throws(PartnerDoorError) {
        let _: OKAnswer = try await call("partner_leave", KeyParameters(key: key))
    }

    // MARK: - Calls

    /// Posts one RPC and decodes its answer, or the door's refusal. A failure is logged with the
    /// RPC's name and why, but never the request, which holds the key and the token.
    private func call<Answer: Decodable>(
        _ name: String, _ parameters: some Encodable
    ) async throws(PartnerDoorError) -> Answer {
        var request = URLRequest(url: Self.rpcURL.appending(path: name), timeoutInterval: Self.timeout)
        request.httpMethod = "POST"
        request.setValue(Self.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: Data
        let response: URLResponse
        do {
            request.httpBody = try JSONEncoder().encode(parameters)
            (body, response) = try await transport(request)
        } catch {
            let error = error as NSError
            debugLog("[PartnerDoor] \(name) failed: \(error.domain) \(error.code)")
            throw .unavailable
        }
        let status = (response as? HTTPURLResponse)?.statusCode
        guard status == 200 else {
            debugLog("[PartnerDoor] \(name) answered HTTP \(status.map(String.init) ?? "without a status")")
            throw .unavailable
        }

        let decoder = CloudSummary.decoder()
        if let refusal = try? decoder.decode(RefusalAnswer.self, from: body) {
            guard let reason = PartnerDoorError.Refusal(rawValue: refusal.error) else {
                debugLog("[PartnerDoor] \(name) refused for a reason this app doesn't know: \(refusal.error)")
                throw .unavailable
            }
            throw .refused(reason)
        }
        do {
            return try decoder.decode(Answer.self, from: body)
        } catch {
            debugLog("[PartnerDoor] \(name)'s answer didn't decode: \(Self.describe(error))")
            throw .unavailable
        }
    }

    /// Where an answer failed to decode, and why.
    private static func describe(_ error: any Error) -> String {
        let context: DecodingError.Context
        switch error as? DecodingError {
        case .typeMismatch(_, let found)?, .valueNotFound(_, let found)?, .keyNotFound(_, let found)?,
             .dataCorrupted(let found)?:
            context = found
        default:
            return String(describing: type(of: error))
        }
        let path = context.codingPath.map(\.stringValue).joined(separator: ".")
        return "\(path.isEmpty ? "the answer" : path): \(context.debugDescription)"
    }
}

// MARK: - What Goes Out and Comes Back

private struct ViewParameters: Encodable {
    let key: String
    /// Left out when nil, so the door sends the whole summary.
    let since: String?

    enum CodingKeys: String, CodingKey {
        case key = "p_key"
        case since = "p_since"
    }
}

private struct PushParameters: Encodable {
    let key: String
    let token: String
    let environment: String
    /// Crewluve shows alert pushes from 1.3, so every registration says so (alert pushes spec §6.3).
    let alerts = true

    enum CodingKeys: String, CodingKey {
        case key = "p_key"
        case token = "p_token"
        case environment = "p_env"
        case alerts = "p_alerts"
    }
}

/// Crewluve joins as an app device, which gets pushes. The website joins as a web one.
private struct JoinParameters: Encodable {
    let invite: String
    let key: String
    let kind = "app"
    let label: String

    enum CodingKeys: String, CodingKey {
        case invite = "p_invite"
        case key = "p_device_key"
        case kind = "p_kind"
        case label = "p_label"
    }
}

private struct RedeemParameters: Encodable {
    let code: String
    let key: String
    let kind = "app"
    let label: String

    enum CodingKeys: String, CodingKey {
        case code = "p_token"
        case key = "p_device_key"
        case kind = "p_kind"
        case label = "p_label"
    }
}

private struct KeyParameters: Encodable {
    let key: String

    enum CodingKeys: String, CodingKey {
        case key = "p_key"
    }
}

private struct RefusalAnswer: Decodable {
    let error: String
}

private struct OKAnswer: Decodable {
    let ok: Bool
}

private struct JoinAnswer: Decodable {
    let deviceID: String
    let partnerID: String

    var joined: PartnerJoinAnswer {
        PartnerJoinAnswer(deviceID: deviceID, partnerID: partnerID)
    }

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case partnerID = "partner_id"
    }
}

/// The expiry comes as Crewlu Cloud writes a time: ISO 8601, with up to six decimals.
private struct HandOffAnswer: Decodable {
    let code: String
    let expiresAt: String

    enum CodingKeys: String, CodingKey {
        case code
        case expiresAt = "expires_at"
    }
}

private struct ViewAnswer: Decodable {
    let partnerID: String
    let updatedAt: String?
    let unchanged: Bool?
    let status: CloudSummary?

    enum CodingKeys: String, CodingKey {
        case partnerID = "partner_id"
        case updatedAt = "updated_at"
        case unchanged
        case status
    }
}
