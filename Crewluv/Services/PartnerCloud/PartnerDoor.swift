//
//  PartnerDoor.swift
//  CrewLuve
//
//  Crewlu Cloud's partner door: the calls a partner's device makes
//

import Foundation

/// Crewlu Cloud's partner door: the calls a partner's device makes with only the publishable key
/// and its own device key (CrewLu's `supabase/partner-api.md`).
protocol PartnerDoor {
    /// partner_view: the pilot's summary, trimmed for the partner whose device holds `key`.
    /// `since` is the last answer's `updatedAt`, sent back exactly as it came, so a summary that
    /// hasn't changed isn't sent again.
    func view(key: String, since: String?) async throws(PartnerDoorError) -> PartnerViewAnswer

    /// partner_set_push: this device's push token, as lower-case hex, and the Apple service it
    /// belongs to.
    func setPush(key: String, token: String, environment: PushEnvironment) async throws(PartnerDoorError)

    /// partner_join: joins the partner the pilot's invite is for, as an app device holding `key`,
    /// named `label` in the pilot's list. The same key gets the same device again.
    func join(invite: String, key: String, label: String) async throws(PartnerDoorError) -> PartnerJoinAnswer

    /// partner_handoff_redeem: joins with a code from another of the partner's devices, as join does.
    func redeem(code: String, key: String, label: String) async throws(PartnerDoorError) -> PartnerJoinAnswer

    /// partner_handoff_create: a code another of this partner's devices can join with. It replaces
    /// the partner's open code.
    func makeHandOffCode(key: String) async throws(PartnerDoorError) -> HandOffCode

    /// partner_leave: this device leaves its partner's devices.
    func leave(key: String) async throws(PartnerDoorError)
}

/// Why a partner-door call gave no answer to use.
nonisolated enum PartnerDoorError: Error, Equatable {
    /// The door answered with one of its refusals: HTTP 200 and `{"error": …}`.
    case refused(Refusal)
    /// No usable answer: no network, a timeout, an HTTP status other than 200, or an answer
    /// that doesn't decode.
    case unavailable

    /// The door's refusals (partner-api.md, "Answers").
    nonisolated enum Refusal: String, Sendable {
        /// The key, link, code or ticket isn't valid, or no longer is.
        case sharingEnded = "sharing_ended"
        case invalidInput = "invalid_input"
        /// Another partner's device has this key.
        case keyInUse = "key_in_use"
        case tooManyDevices = "too_many_devices"
        /// Too many wrong codes in the last minute.
        case tryLater = "try_later"
    }
}

/// partner_join's and partner_handoff_redeem's answer: the device this key is, and its partner.
struct PartnerJoinAnswer: Equatable, Sendable {
    let deviceID: String
    let partnerID: String
}

/// partner_view's answer.
struct PartnerViewAnswer: Sendable {

    /// What came with the partner and the time.
    enum Content: Sendable {
        case summary(CloudSummary)
        /// The pilot's CrewLu hasn't sent a summary yet.
        case noSummaryYet
        /// Nothing is newer than `since`.
        case unchanged
    }

    let partnerID: String
    /// When the summary last changed, to the millisecond, as text to send back as `since`.
    /// Nil before the first summary.
    let updatedAt: String?
    let content: Content
}
