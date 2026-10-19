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

    // MARK: - Calls

    /// Posts one RPC and decodes its answer, or the door's refusal.
    private func call<Answer: Decodable>(
        _ name: String, _ parameters: some Encodable
    ) async throws(PartnerDoorError) -> Answer {
        var request = URLRequest(url: Self.rpcURL.appending(path: name), timeoutInterval: Self.timeout)
        request.httpMethod = "POST"
        request.setValue(Self.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: Data
        do {
            request.httpBody = try JSONEncoder().encode(parameters)
            let (data, response) = try await transport(request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw PartnerDoorError.unavailable }
            body = data
        } catch {
            throw .unavailable
        }

        let decoder = CloudSummary.decoder()
        if let refusal = try? decoder.decode(RefusalAnswer.self, from: body) {
            guard let reason = PartnerDoorError.Refusal(rawValue: refusal.error) else { throw .unavailable }
            throw .refused(reason)
        }
        guard let answer = try? decoder.decode(Answer.self, from: body) else { throw .unavailable }
        return answer
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

    enum CodingKeys: String, CodingKey {
        case key = "p_key"
        case token = "p_token"
        case environment = "p_env"
    }
}

private struct RefusalAnswer: Decodable {
    let error: String
}

private struct OKAnswer: Decodable {
    let ok: Bool
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
