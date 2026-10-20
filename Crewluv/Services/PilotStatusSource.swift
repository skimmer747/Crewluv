//
//  PilotStatusSource.swift
//  CrewLuve
//
//  The one place that reads the pilot's status
//

import Foundation
import Observation
#if canImport(UIKit)
import UIKit
#endif

/// The one place that reads the pilot's status, whoever asks: the screen, a push or the background
/// refresh (partner links piece 4 spec §5.1). It reads Crewlu Cloud through `device` once connected
/// there, and iCloud otherwise, as before. Each new status goes to the alerts once, from here. How the
/// connection changes, by joining, Disconnect or sharing ending, is in PilotStatusSource+Connecting.
@Observable
final class PilotStatusSource {
    static let shared = PilotStatusSource()

    /// What was last read, or nil before the first read and after sharing ends. The source and its
    /// extensions set it.
    var reading: PilotReading?
    /// How the last read went, or how sharing ended outside a read.
    private(set) var lastUpdate: PilotStatusUpdate?
    /// This device's partner id on Crewlu Cloud, or nil while it follows its pilot through iCloud.
    var crewluCloudPartnerID: String? { device.partnerID }

    var isOnCrewluCloud: Bool { crewluCloudPartnerID != nil }

    /// The pilot whose sharing with this device ended, as this partner saw them, for the welcome
    /// screen's note (spec §7.6). It stays until the next status, and is nil when no pilot was seen.
    /// The source and its extensions set it.
    var sharingEndedWith: String?

    /// The name the pilot set for this partner, for the screen's title: the reading's, or the saved
    /// one while an iCloud read can't look it up, as the alerts use.
    var displayName: String? {
        guard let reading else { return nil }
        return reading.isDisplayNameKnown ? reading.displayName : connection.savedDisplayName
    }

    /// This device on Crewlu Cloud, which joins through it (spec §7.2).
    @ObservationIgnored let device: CrewluCloudDevice
    @ObservationIgnored private let iCloud: ICloudStatusFetching
    @ObservationIgnored let connection: PartnerConnection
    @ObservationIgnored private let notifier: StatusNotifying
    @ObservationIgnored private let iCloudShareEnded: @MainActor () -> Void
    @ObservationIgnored private let periodicCheck: PeriodicCheck
    /// Runs when this device connects to Crewlu Cloud, to send its push token (spec §6.1).
    @ObservationIgnored let didConnect: @MainActor () -> Void
    /// Forgets the iCloud share without showing the welcome screen (spec §7.2).
    @ObservationIgnored let forgetICloudShare: @MainActor () -> Void
    @ObservationIgnored private let reads = ReadQueue<RefreshOutcome>()
    /// Moves this device from iCloud to Crewlu Cloud by itself (spec §8).
    @ObservationIgnored private let moveOver: MoveOver

    static let unreachable = "No connection to Crewlu Cloud"
    private static let keyUnreadable = "This device's key couldn't be read"
    private static let keyUnsaved = "This device's key couldn't be saved"

    /// "iPhone" or "iPad": this device's name in the pilot's list, since iOS doesn't give apps the
    /// device's own name.
    static var deviceLabel: String {
        #if canImport(UIKit)
        UIDevice.current.model
        #else
        "iPhone"
        #endif
    }

    init(
        iCloud: ICloudStatusFetching = ICloudStatusFetcher(),
        door: PartnerDoor = LivePartnerDoor(),
        keys: DeviceKeyStore = KeychainDeviceKeyStore(),
        defaults: UserDefaults = .standard,
        notifier: StatusNotifying = StatusChangeNotifier.shared,
        iCloudShareEnded: @escaping @MainActor () -> Void = { CloudKitShareManager.shared.resetShareData() },
        periodicCheck: RepeatingRefresh = RepeatingRefresh(),
        didConnect: @escaping @MainActor () -> Void = { Task { await PushRegistrar.shared.register() } },
        forgetICloudShare: @escaping @MainActor () -> Void = { CloudKitShareManager.shared.forgetShareQuietly() },
        deviceLabel: String = PilotStatusSource.deviceLabel
    ) {
        self.iCloud = iCloud
        self.notifier = notifier
        self.iCloudShareEnded = iCloudShareEnded
        self.periodicCheck = PeriodicCheck(timer: periodicCheck)
        self.didConnect = didConnect
        self.forgetICloudShare = forgetICloudShare
        connection = PartnerConnection(defaults: defaults)
        device = CrewluCloudDevice(door: door, keys: keys, connection: connection)
        moveOver = MoveOver(door: door, keys: keys, connection: connection, device: device, label: deviceLabel)
        sharingEndedWith = connection.sharingEndedWith
    }

    // MARK: - Refreshing

    /// Whether a read waits for the one under way to end.
    var isReadQueued: Bool { reads.isReadQueued }

    /// Reads the status from wherever this device follows its pilot, and tells the screen how it
    /// went before anyone waiting on the read carries on. A refresh asked for during a read, say
    /// for a push that came mid-read, gets one more read once that one ends (`ReadQueue`). After
    /// iCloud's record is read and shown, the move-over takes its turn (spec §8.1).
    func refresh() async -> RefreshOutcome {
        await reads.run { [self] in
            let readAt = Date()
            let read = await read()
            report(PilotStatusUpdate(outcome: read.outcome, readAt: readAt))
            guard let record = read.record, let moved = await moveOverTurn(after: record) else { return read.outcome }
            report(PilotStatusUpdate(outcome: moved, readAt: Date()))
            return moved
        }
    }

    func report(_ update: PilotStatusUpdate) {
        lastUpdate = update
        NotificationCenter.default.post(name: .pilotStatusDidUpdate, object: self)
    }

    /// iCloud's share data was reset, as the share ended: an iCloud reading is no longer the pilot's
    /// status. The screen clears itself on the same reset.
    func forgetICloudReading() {
        guard case .iCloud? = reading else { return }
        reading = nil
    }

    // MARK: - The 60-Second Check

    /// `screen` is in front. While any screen is, reads every 60 seconds whenever this device is on
    /// Crewlu Cloud and a screen in front isn't showing the demo (partner links piece 4 spec §5.5).
    /// With nothing new, Crewlu Cloud answers "unchanged". Each tick asks again, so a device that
    /// connects or leaves mid-session needs no restart.
    func startPeriodicCheck(for screen: AnyObject, pausedWhile isPaused: @escaping () -> Bool) {
        periodicCheck.start(for: screen, pausedWhile: isPaused) { [weak self] in
            guard let self, self.isOnCrewluCloud else { return }
            _ = await self.refresh()
        }
    }

    /// `screen` left the front. The check stops once no screen is in front.
    func stopPeriodicCheck(for screen: AnyObject) {
        periodicCheck.stop(for: screen)
    }

    // MARK: - Reading

    /// How a read went, and iCloud's record when it brought it, for the move-over's turn.
    private struct Read {
        let outcome: RefreshOutcome
        var record: ICloudReading?
    }

    private func read() async -> Read {
        if isOnCrewluCloud {
            return Read(outcome: await readCrewluCloud())
        }
        return await readICloud()
    }

    // MARK: - Crewlu Cloud

    private func readCrewluCloud() async -> RefreshOutcome {
        switch await device.read() {
        case .answer(let answer):
            return await take(answer)
        case .keyUnreadable:
            return .failed(Self.keyUnreadable)
        case .keyGone:
            reading = nil
            return .notConnected
        case .sharingEnded:
            noteSharingEnded()
            return .sharingEnded
        case .unavailable:
            return .failed(Self.unreachable)
        case .superseded:
            return .superseded
        }
    }

    /// With no iCloud to follow, a key a reinstall left connects this device when Crewlu Cloud
    /// answers for it, with a summary or none yet (spec §5.3). It's tried on every refresh until it
    /// answers. A read that a switch overtook brings nothing back.
    private func adoptLeftoverKey() async -> RefreshOutcome {
        let generation = device.generation
        guard case .answer(let key, let answer) = await moveOver.readUnconnectedKey() else {
            return generation == device.generation ? .notConnected : .superseded
        }
        return await switchOver(to: .init(partnerID: answer.partnerID, key: key, isDeviceKey: true), answer: answer)
    }

    /// The move-over's turn, after iCloud's record was read (spec §8.1). Nil while this device stays
    /// on iCloud.
    private func moveOverTurn(after record: ICloudReading) async -> RefreshOutcome? {
        guard case .switchTo(let joined, let answer) = await moveOver.afterRead(ticket: record.moveTicket) else { return nil }
        return await switchOver(to: joined, answer: answer)
    }

    /// Switches to a key this device already holds, from within a read: a key a reinstall left, or the
    /// move-over's (spec §5.3, §8.2). It replaces no other device, since the key is this device's own,
    /// and what the alerts kept stays, since it's the same pilot. The read is Crewlu Cloud's answer, or
    /// a failure when it couldn't be reached.
    private func switchOver(to joined: CrewluCloudDevice.Joined, answer: PartnerViewAnswer?) async -> RefreshOutcome {
        guard switchConnection(to: joined, keepingAlerts: true) != nil else { return .failed(Self.keyUnsaved) }
        guard let answer else { return .failed(Self.unreachable) }
        return await take(answer)
    }

    /// Takes partner_view's answer. A summary other than the one already read, or one trimmed for
    /// another partner, becomes the reading.
    private func take(_ answer: PartnerViewAnswer) async -> RefreshOutcome {
        switch answer.content {
        case .unchanged:
            return .unchanged
        case .noSummaryYet:
            return .noStatusYet
        case .summary(let summary):
            device.since = answer.updatedAt
            if case .crewluCloud(_, let partnerID, let updatedAt)? = reading, updatedAt != nil,
               updatedAt == answer.updatedAt, partnerID == answer.partnerID {
                return .unchanged
            }
            return await adopt(.crewluCloud(summary, partnerID: answer.partnerID, updatedAt: answer.updatedAt))
        }
    }

    // MARK: - iCloud

    /// iCloud's read. One that a switch to Crewlu Cloud overtook was the old connection's: it brings
    /// nothing back, and ends nothing.
    private func readICloud() async -> Read {
        let generation = device.generation
        do {
            let fetched = try await iCloud.fetch()
            guard generation == device.generation else { return Read(outcome: .superseded) }
            if let reading, reading.lastUpdated == fetched.status.lastUpdated {
                takeLookedUpName(from: fetched)
                return Read(outcome: .unchanged, record: fetched)
            }
            return Read(outcome: await adopt(.iCloud(fetched)), record: fetched)
        } catch _ where generation != device.generation {
            return Read(outcome: .superseded)
        } catch ICloudFetchError.notConnected {
            return Read(outcome: await adoptLeftoverKey())
        } catch ICloudFetchError.shareGone {
            return Read(outcome: await iCloudShareGone())
        } catch {
            return Read(outcome: .failed(error.localizedDescription))
        }
    }

    /// iCloud's share is gone (spec §7.6, §8.4): a move under way, or another of this partner's
    /// devices, carries this device on to Crewlu Cloud. Otherwise sharing ended. A switch that
    /// overtook it, say by a join, tells instead.
    private func iCloudShareGone() async -> RefreshOutcome {
        switch await moveOver.afterShareGone() {
        case .switchTo(let joined, let answer):
            return await switchOver(to: joined, answer: answer)
        case .ended(let leftBehind):
            noteSharingEnded(leftBehind: leftBehind)
            iCloudShareEnded()
            return .sharingEnded
        case .stay:
            return .superseded
        }
    }

    /// The same status, now with this partner's name looked up where it couldn't be before, or with
    /// another name: shows the name, without alerting again.
    private func takeLookedUpName(from fetched: ICloudReading) {
        guard fetched.isDisplayNameKnown, case .iCloud(let current)? = reading,
              !current.isDisplayNameKnown || current.displayName != fetched.displayName
        else { return }
        let newReading = PilotReading.iCloud(fetched)
        _ = connection.remember(newReading)
        sharingEndedWith = nil
        reading = newReading
    }

    // MARK: - A New Reading

    /// Makes `newReading` the reading and hands it to the alerts once. The screen hears of it when
    /// the read ends.
    private func adopt(_ newReading: PilotReading) async -> RefreshOutcome {
        let previous = reading
        let name = connection.remember(newReading)
        sharingEndedWith = nil
        PilotReading.logLegChanges(from: previous, to: newReading)
        reading = newReading
        await notifier.evaluate(newReading, titledWith: name)
        return .newStatus
    }
}
