//
//  AlertPushWriter.swift
//  CrewLuve
//
//  What an alert push says, written by the alert pushes' helper from the pilot's status
//

import Foundation

/// What an alert push says once the helper has written it: a title, empty for none, and a body.
nonisolated struct AlertPushWords: Equatable, Sendable {
    let title: String
    let body: String
}

/// The alert pushes' helper's steps (alert pushes spec §6.1). An alert push carries only its kind, so the helper reads
/// the pilot's status with this device's key and writes the kind's words from it, as the app's own alerts would. Short of
/// a status that fits the kind, it writes the kind's plain line. It only reads: it never forgets a key or changes the
/// connection, and it leaves a sharing_ended for the app to find. Both this app and the helper target build it.
struct AlertPushWriter {
    let door: PartnerDoor
    let keys: DeviceKeyStore
    var timeZone: TimeZone = .current

    /// The kind an alert push names, or nil for one this Crewluve doesn't know, which keeps the push's own words.
    nonisolated static func kind(of userInfo: [AnyHashable: Any]) -> AlertKind? {
        (userInfo["kind"] as? String).flatMap(AlertKind.init(rawValue:))
    }

    /// The kind's plain line (spec §6.4), titled with the name the app keeps beside the key (§6.2), or with no title
    /// when there's none or the Keychain can't be read yet.
    func plainLine(for kind: AlertKind) -> AlertPushWords {
        AlertPushWords(title: (try? keys.pilotName()) ?? "", body: AlertWording.plainLine(for: kind))
    }

    /// The words for `kind` from the status Crewlu Cloud has for this device at `now`, worked out as the app's own
    /// alerts work them out. The plain line instead with no key, or one the Keychain can't give yet, when the door
    /// refuses or is unavailable, before the first summary, and when the status no longer fits the kind.
    func words(for kind: AlertKind, at now: Date = Date()) async -> AlertPushWords {
        guard let key = try? keys.deviceKey() else {
            debugLog("[AlertPush] No key to read with: the plain line")
            return plainLine(for: kind)
        }
        let answer: PartnerViewAnswer
        do {
            answer = try await door.view(key: key, since: nil)
        } catch {
            debugLog("[AlertPush] partner_view gave no status (\(error)): the plain line")
            return plainLine(for: kind)
        }
        guard case .summary(let summary) = answer.content else {
            debugLog("[AlertPush] No summary yet: the plain line")
            return plainLine(for: kind)
        }
        let status = summary.pilotStatus(partnerID: answer.partnerID, at: now)
        let homeArrival = TripStateResolver.resolveHomeArrival(
            legs: status.tripLegs, homeAirportCode: status.homeAirportCode, at: now
        )
        guard let words = AlertWording.words(
            for: kind,
            name: summary.displayName(for: answer.partnerID) ?? status.pilotFirstName,
            status: status,
            effectiveDelay: status.effectiveFlightDelayMinutes(at: now) ?? 0,
            homeArrival: homeArrival?.arrivalTime ?? status.homeArrivalTime,
            timeZone: timeZone
        ) else {
            debugLog("[AlertPush] The status no longer fits \(kind.rawValue): the plain line")
            return plainLine(for: kind)
        }
        return AlertPushWords(title: words.title, body: words.body)
    }
}

/// An alert push being written, delivered once from any thread: with its words when they're ready, or, when iOS's time
/// runs out first, with the plain line, or as the push came if even that isn't ready yet.
nonisolated final class PendingAlertPush: @unchecked Sendable {
    private let lock = NSLock()
    private var deliver: OneTimeCompletion<AlertPushWords?>?
    private var plainLine: AlertPushWords?

    /// Waits to deliver the alert push with `deliver`: given its words or the plain line, or nil for the push as it came.
    func start(_ deliver: @escaping (AlertPushWords?) -> Void) {
        lock.withLock { self.deliver = OneTimeCompletion(deliver) }
    }

    /// Keeps the kind's plain line, for when iOS's time runs out.
    func hold(_ plainLine: AlertPushWords) {
        lock.withLock { self.plainLine = plainLine }
    }

    /// Delivers the words, unless the alert push was delivered already.
    func finish(with words: AlertPushWords) {
        lock.withLock { deliver }?(words)
    }

    /// iOS's time is nearly up: delivers the plain line, or the push as it came, unless it was delivered already.
    func expire() {
        let (deliver, plainLine) = lock.withLock { (deliver, plainLine) }
        deliver?(plainLine)
    }
}
