//
//  PilotStatusSource.swift
//  CrewLuve
//
//  The one place that reads the pilot's status
//

import Foundation
import Observation

/// The one place that reads the pilot's status, whoever asks: the screen, a push or the background
/// refresh (partner links piece 4 spec §5.1). It reads Crewlu Cloud, through `CrewluCloudDevice`,
/// once this device is connected there, and iCloud otherwise, as before. Each new status goes to
/// the alerts once, from here.
@Observable
final class PilotStatusSource {
    static let shared = PilotStatusSource()

    /// What was last read, or nil before the first read and after sharing ends.
    private(set) var reading: PilotReading?
    /// How the last read went, or how sharing ended outside a read.
    private(set) var lastUpdate: PilotStatusUpdate?
    /// This device's partner id on Crewlu Cloud, or nil while it follows its pilot through iCloud.
    var crewluCloudPartnerID: String? { device.partnerID }

    var isOnCrewluCloud: Bool { crewluCloudPartnerID != nil }

    /// The pilot whose sharing with this device ended, as this partner saw them, for the welcome
    /// screen's note (spec §7.6). It stays until the next status, and is nil when no pilot was seen.
    private(set) var sharingEndedWith: String?

    /// The name the pilot set for this partner, for the screen's title: the reading's, or the saved
    /// one while an iCloud read can't look it up, as the alerts use.
    var displayName: String? {
        guard let reading else { return nil }
        return reading.isDisplayNameKnown ? reading.displayName : connection.savedDisplayName
    }

    /// This device on Crewlu Cloud, which joins through it (spec §7.2).
    @ObservationIgnored let device: CrewluCloudDevice
    @ObservationIgnored private let iCloud: ICloudStatusFetching
    @ObservationIgnored private let connection: PartnerConnection
    @ObservationIgnored private let notifier: StatusNotifying
    @ObservationIgnored private let iCloudShareEnded: @MainActor () -> Void
    @ObservationIgnored private let periodicCheck: RepeatingRefresh
    /// The screens in front, each with what says whether it shows the demo. iPad can show several.
    @ObservationIgnored private var screensInFront: [ObjectIdentifier: () -> Bool] = [:]
    /// Runs when this device connects to Crewlu Cloud, to send its push token (spec §6.1).
    @ObservationIgnored private let didConnect: @MainActor () -> Void
    /// Forgets the iCloud share without showing the welcome screen, once this device is on Crewlu
    /// Cloud instead (spec §7.2).
    @ObservationIgnored private let forgetICloudShare: @MainActor () -> Void
    @ObservationIgnored private let reads = ReadQueue<RefreshOutcome>()

    private static let unreachable = "No connection to Crewlu Cloud"
    private static let keyUnreadable = "This device's key couldn't be read"

    init(
        iCloud: ICloudStatusFetching = ICloudStatusFetcher(),
        door: PartnerDoor = LivePartnerDoor(),
        keys: DeviceKeyStore = KeychainDeviceKeyStore(),
        defaults: UserDefaults = .standard,
        notifier: StatusNotifying = StatusChangeNotifier.shared,
        iCloudShareEnded: @escaping @MainActor () -> Void = { CloudKitShareManager.shared.resetShareData() },
        periodicCheck: RepeatingRefresh = RepeatingRefresh(),
        didConnect: @escaping @MainActor () -> Void = { Task { await PushRegistrar.shared.register() } },
        forgetICloudShare: @escaping @MainActor () -> Void = { CloudKitShareManager.shared.forgetShareQuietly() }
    ) {
        self.iCloud = iCloud
        self.notifier = notifier
        self.iCloudShareEnded = iCloudShareEnded
        self.periodicCheck = periodicCheck
        self.didConnect = didConnect
        self.forgetICloudShare = forgetICloudShare
        connection = PartnerConnection(defaults: defaults)
        device = CrewluCloudDevice(door: door, keys: keys, connection: connection)
        sharingEndedWith = connection.sharingEndedWith
    }

    // MARK: - Refreshing

    /// Whether a read waits for the one under way to end.
    var isReadQueued: Bool { reads.isReadQueued }

    /// Reads the status from wherever this device follows its pilot, and tells the screen how it
    /// went before anyone waiting on the read carries on. A refresh asked for during a read, say
    /// for a push that came mid-read, gets one more read once that one ends (`ReadQueue`).
    func refresh() async -> RefreshOutcome {
        await reads.run { [self] in
            let readAt = Date()
            let outcome = await read()
            report(PilotStatusUpdate(outcome: outcome, readAt: readAt))
            return outcome
        }
    }

    private func report(_ update: PilotStatusUpdate) {
        lastUpdate = update
        NotificationCenter.default.post(name: .pilotStatusDidUpdate, object: self)
    }

    /// The pilot stopped sharing with this device, as Crewlu Cloud told the push registration:
    /// forget the connection, and tell the screen.
    func endSharing() {
        device.forget()
        noteSharingEnded()
        report(PilotStatusUpdate(outcome: .sharingEnded, readAt: Date()))
    }

    /// Switches this device to what a join joined (spec §7.2): the joined key becomes its key, an
    /// iCloud share is forgotten without showing the welcome screen, the push token goes to Crewlu
    /// Cloud, and the new connection is read. For another pilot, what the alerts kept of the last one
    /// goes first. False when the key couldn't be saved, and then nothing changes.
    func connect(_ joined: CrewluCloudDevice.Joined, keepingAlerts: Bool) async -> Bool {
        guard await device.switchTo(joined) else { return false }
        if !keepingAlerts {
            connection.forgetPilot()
        }
        if connection.hasICloudShare {
            forgetICloudShare()
        }
        connection.sharingEndedWith = nil
        sharingEndedWith = nil
        reading = nil
        didConnect()
        _ = await refresh()
        return true
    }

    /// iCloud's share data was reset, by Reset Share Data or the share ending: an iCloud reading
    /// is no longer the pilot's status. The screen clears itself on the same reset.
    func forgetICloudReading() {
        guard case .iCloud? = reading else { return }
        reading = nil
    }

    /// Sharing with this device ended: the welcome screen's note names the pilot last seen, if any,
    /// and the pilot is forgotten (spec §7.6).
    private func noteSharingEnded() {
        connection.sharingEndedWith = connection.pilotName
        sharingEndedWith = connection.pilotName
        reading = nil
        connection.forgetPilot()
    }

    // MARK: - The 60-Second Check

    /// `screen` is in front. While any screen is, reads every 60 seconds whenever this device is on
    /// Crewlu Cloud and a screen in front isn't showing the demo (partner links piece 4 spec §5.5).
    /// With nothing new, Crewlu Cloud answers "unchanged". Each tick asks again, so a device that
    /// connects or leaves mid-session needs no restart.
    func startPeriodicCheck(for screen: AnyObject, pausedWhile isPaused: @escaping () -> Bool) {
        screensInFront[ObjectIdentifier(screen)] = isPaused
        guard !periodicCheck.isRunning else { return }
        periodicCheck.start { [weak self] in
            guard let self, self.isOnCrewluCloud, self.screensInFront.values.contains(where: { !$0() }) else { return }
            _ = await self.refresh()
        }
    }

    /// `screen` left the front. The check stops once no screen is in front.
    func stopPeriodicCheck(for screen: AnyObject) {
        screensInFront[ObjectIdentifier(screen)] = nil
        if screensInFront.isEmpty {
            periodicCheck.stop()
        }
    }

    // MARK: - Reading

    private func read() async -> RefreshOutcome {
        if isOnCrewluCloud {
            return await readCrewluCloud()
        }
        if let outcome = await adoptLeftoverKey() {
            return outcome
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

    /// A key a reinstall left connects this device when Crewlu Cloud answers for it (spec §5.3).
    /// Nil carries on with iCloud.
    private func adoptLeftoverKey() async -> RefreshOutcome? {
        guard let answer = await device.adoptLeftoverKey() else { return nil }
        didConnect()
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

    private func readICloud() async -> RefreshOutcome {
        do {
            let fetched = try await iCloud.fetch()
            if let reading, reading.lastUpdated == fetched.status.lastUpdated {
                takeLookedUpName(from: fetched)
                return .unchanged
            }
            return await adopt(.iCloud(fetched))
        } catch ICloudFetchError.notConnected {
            return .notConnected
        } catch ICloudFetchError.shareGone {
            noteSharingEnded()
            iCloudShareEnded()
            return .sharingEnded
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// The same status, now with this partner's name looked up where it couldn't be before, or with
    /// another name: shows the name, without alerting again.
    private func takeLookedUpName(from fetched: ICloudReading) {
        guard fetched.isDisplayNameKnown, case .iCloud(let current)? = reading,
              !current.isDisplayNameKnown || current.displayName != fetched.displayName
        else { return }
        let newReading = PilotReading.iCloud(fetched)
        rememberPilot(of: newReading, named: keepDisplayName(of: newReading))
        reading = newReading
    }

    // MARK: - A New Reading

    /// Makes `newReading` the reading and hands it to the alerts once. The screen hears of it when
    /// the read ends.
    private func adopt(_ newReading: PilotReading) async -> RefreshOutcome {
        let previous = reading
        let name = keepDisplayName(of: newReading)
        rememberPilot(of: newReading, named: name)
        PilotReading.logLegChanges(from: previous, to: newReading)
        reading = newReading
        await notifier.evaluate(newReading, titledWith: name)
        return .newStatus
    }

    /// Saves the reading's name for the alerts' titles, and gives the name to title them with now.
    /// When an iCloud read couldn't look the name up, the saved one stays.
    private func keepDisplayName(of reading: PilotReading) -> String? {
        guard reading.isDisplayNameKnown else {
            return connection.savedDisplayName
        }
        connection.savedDisplayName = reading.displayName
        return reading.displayName
    }

    /// Saves the reading's pilot, by the name the alerts use or else their first name (spec §5.1). A
    /// status means a connection, so a note that sharing ended goes.
    private func rememberPilot(of reading: PilotReading, named name: String?) {
        let status = reading.status(at: Date())
        connection.pilotID = status.pilotId
        connection.pilotName = name ?? status.pilotFirstName
        connection.sharingEndedWith = nil
        sharingEndedWith = nil
    }
}
