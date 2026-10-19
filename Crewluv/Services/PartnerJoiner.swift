//
//  PartnerJoiner.swift
//  CrewLuve
//
//  Joins Crewlu Cloud with an invite link or a code
//

import Foundation
import Observation
#if canImport(UIKit)
import UIKit
#endif

/// Whether to follow another pilot's link (partner links piece 4 spec §7.2): "Switch to Sam?" /
/// "You'll stop seeing Alex's status on this iPhone."
nonisolated struct SwitchQuestion: Equatable, Sendable {
    /// The pilot the link is from, as this partner will see them.
    let newPilot: String
    /// The pilot this device follows now.
    let currentPilot: String
    /// "iPhone" or "iPad".
    let deviceModel: String

    var title: String { "Switch to \(newPilot)?" }
    var message: String { "You'll stop seeing \(currentPilot)'s status on this \(deviceModel)." }
}

/// Joins Crewlu Cloud with an invite link or a code (spec §7.2), and holds what the screen shows
/// meanwhile: the Connecting overlay, the question when the link is from another pilot, and the
/// message when it didn't connect (§7.3).
@Observable
final class PartnerJoiner {
    /// Whether a join is under way, for the Connecting overlay.
    private(set) var isConnecting = false
    /// The question a join waits on, while the link is from another pilot.
    private(set) var switchQuestion: SwitchQuestion?
    /// What the partner is told about the last join, until they dismiss it.
    var message: JoinMessage?

    /// "iPhone" or "iPad": this device's name in the pilot's list.
    @ObservationIgnored let deviceModel: String
    @ObservationIgnored private let source: PilotStatusSource
    @ObservationIgnored private let connection: PartnerConnection
    @ObservationIgnored private var switchAnswer: CheckedContinuation<Bool, Never>?

    init(source: PilotStatusSource, defaults: UserDefaults = .standard, deviceModel: String) {
        self.source = source
        connection = PartnerConnection(defaults: defaults)
        self.deviceModel = deviceModel
    }

    /// Joins with `link`, unless a join is under way. True when this device follows the link's
    /// partner afterwards; false when it didn't connect, the partner chose not to switch, or another
    /// join was under way.
    @discardableResult
    func join(_ link: PartnerLink) async -> Bool {
        guard !isConnecting else { return false }
        isConnecting = true
        defer { isConnecting = false }
        switch await outcome(of: link) {
        case .connected:
            return true
        case .cancelled:
            return false
        case .failed(let failure):
            message = failure
            return false
        }
    }

    /// The partner's answer to `switchQuestion`.
    func answerSwitch(_ shouldSwitch: Bool) {
        switchQuestion = nil
        switchAnswer?.resume(returning: shouldSwitch)
        switchAnswer = nil
    }

    private enum Outcome {
        case connected
        case cancelled
        case failed(JoinMessage)
    }

    /// Spec §7.2: the key and the call, the read, then the table.
    private func outcome(of link: PartnerLink) async -> Outcome {
        let device = source.device
        let joined: CrewluCloudDevice.Joined
        do {
            joined = try await device.join(link, label: deviceModel)
        } catch {
            return .failed(JoinMessage(error, joining: link, stillConnectedTo: followedPilotName))
        }
        // This device already: nothing changes, though a read shows anything new.
        if joined.isDeviceKey, joined.partnerID == device.partnerID {
            _ = await source.refresh()
            return .connected
        }
        let answer: PartnerViewAnswer
        do {
            answer = try await device.view(joined)
        } catch {
            return .failed(.couldntConnect)
        }
        let newPilot = Self.pilot(in: answer)
        if let newPilot, let followedPilotID, newPilot.id != followedPilotID {
            let question = SwitchQuestion(
                newPilot: newPilot.name, currentPilot: followedPilotName ?? "your pilot", deviceModel: deviceModel
            )
            guard await ask(question) else {
                await device.cancel(joined)
                return .cancelled
            }
        }
        let isSamePilot = newPilot != nil && newPilot?.id == followedPilotID
        guard await source.connect(joined, keepingAlerts: isSamePilot) else {
            return .failed(.couldntConnect)
        }
        return .connected
    }

    private func ask(_ question: SwitchQuestion) async -> Bool {
        await withCheckedContinuation { continuation in
            switchAnswer = continuation
            switchQuestion = question
        }
    }

    private var isFollowingAPilot: Bool {
        source.isOnCrewluCloud || connection.hasICloudShare
    }

    /// The pilot this device follows, on Crewlu Cloud or iCloud, by id.
    private var followedPilotID: String? {
        isFollowingAPilot ? connection.pilotID : nil
    }

    /// The pilot this device follows, as this partner sees them.
    private var followedPilotName: String? {
        isFollowingAPilot ? connection.pilotName : nil
    }

    /// The pilot whose summary a read brought, as this partner sees them. Nil before the first
    /// summary, when the pilots can't be compared.
    private static func pilot(in answer: PartnerViewAnswer) -> (id: String, name: String)? {
        guard case .summary(let summary) = answer.content else { return nil }
        return (summary.pilotId, summary.displayName(for: answer.partnerID) ?? summary.pilotFirstName)
    }
}

#if canImport(UIKit)
extension PartnerJoiner {
    /// The app's joiner. It names this device by its model, since iOS doesn't give apps the
    /// device's own name.
    static let shared = PartnerJoiner(source: .shared, deviceModel: UIDevice.current.model)
}
#endif
