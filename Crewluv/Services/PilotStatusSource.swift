//
//  PilotStatusSource.swift
//  CrewLuve
//
//  The one place that reads the pilot's status
//

import Foundation
import Observation

extension Notification.Name {
    /// A read ended, or sharing ended outside one: the source's `lastUpdate` says how it went.
    /// Posted on the main actor.
    static let pilotStatusDidUpdate = Notification.Name("pilotStatusDidUpdate")
}

/// How a read went, for the screen, whoever asked for the read.
nonisolated struct PilotStatusUpdate: Equatable, Sendable {
    let outcome: RefreshOutcome
    /// When the read began, for the screen's "Synced" line.
    let readAt: Date
}

/// How a refresh ended.
nonisolated enum RefreshOutcome: Equatable, Sendable {
    /// A status the source hadn't read before.
    case newStatus
    /// The same status as last time.
    case unchanged
    /// On Crewlu Cloud, but the pilot's CrewLu hasn't sent a status yet.
    case noStatusYet
    /// No accepted share, and no Crewlu Cloud connection.
    case notConnected
    /// The pilot stopped sharing with this device, which has forgotten the connection.
    case sharingEnded
    /// The read failed. The message says why, for the sync line.
    case failed(String)
}

/// What hears of each new status: the alerts.
nonisolated protocol StatusNotifying: Sendable {
    func evaluateChanges(
        old: SharedPilotStatus?,
        new: SharedPilotStatus,
        pilotName: String,
        newEffectiveDelay: Int?,
        resolvedHomeArrivalTime: Date?
    ) async
}

extension StatusChangeNotifier: StatusNotifying {}

/// The one place that reads the pilot's status, whoever asks: the screen, a push or the background
/// refresh (partner links piece 4 spec §5.1). It reads Crewlu Cloud once this device is connected
/// there, and iCloud otherwise, as before. Each new status goes to the alerts once, from here.
@Observable
final class PilotStatusSource {
    static let shared = PilotStatusSource()

    /// What was last read, or nil before the first read and after sharing ends.
    private(set) var reading: PilotReading?
    /// How the last read went, or how sharing ended outside a read.
    private(set) var lastUpdate: PilotStatusUpdate?
    /// This device's partner id on Crewlu Cloud, or nil while it follows its pilot through iCloud.
    private(set) var crewluCloudPartnerID: String?

    var isOnCrewluCloud: Bool { crewluCloudPartnerID != nil }

    /// The name the pilot set for this partner, for the screen's title: the reading's, or the saved
    /// one while an iCloud read can't look it up, as the alerts use.
    var displayName: String? {
        guard let reading else { return nil }
        return reading.isDisplayNameKnown ? reading.displayName : defaults.string(forKey: Self.displayNameKey)
    }

    @ObservationIgnored private let iCloud: ICloudStatusFetching
    @ObservationIgnored private let door: PartnerDoor
    @ObservationIgnored private let keys: DeviceKeyStore
    @ObservationIgnored private let connection: PartnerConnection
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let notifier: StatusNotifying
    @ObservationIgnored private let iCloudShareEnded: @MainActor () -> Void
    @ObservationIgnored private let periodicCheck: RepeatingRefresh
    /// The screens in front, each with what says whether it shows the demo. iPad can show several.
    @ObservationIgnored private var screensInFront: [ObjectIdentifier: () -> Bool] = [:]
    /// Runs when this device connects to Crewlu Cloud, to send its push token (spec §6.1).
    @ObservationIgnored private let didConnect: @MainActor () -> Void
    /// The last Crewlu Cloud answer's `updatedAt`, sent back as `since` within this run of the app.
    /// The first read after a launch sends none, since the app doesn't keep the summary.
    @ObservationIgnored private var since: String?
    @ObservationIgnored private var readUnderWay: Task<RefreshOutcome, Never>?
    /// The read that starts once the one under way ends, shared by every refresh asked for meanwhile.
    @ObservationIgnored private var queuedRead: Task<RefreshOutcome, Never>?
    /// Goes up each time the connection is forgotten, so a read begun before then brings nothing back.
    @ObservationIgnored private var connectionGeneration = 0

    /// Where the alerts' title name is kept, as before.
    private static let displayNameKey = "ResolvedPilotDisplayName"
    /// What the alerts compare against. Sharing ending forgets it, as `resetShareData()` does.
    private static let snapshotKey = "LastSeenPilotSnapshot"
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
        didConnect: @escaping @MainActor () -> Void = { Task { await PushRegistrar.shared.register() } }
    ) {
        self.iCloud = iCloud
        self.door = door
        self.keys = keys
        self.defaults = defaults
        self.notifier = notifier
        self.iCloudShareEnded = iCloudShareEnded
        self.periodicCheck = periodicCheck
        self.didConnect = didConnect
        connection = PartnerConnection(defaults: defaults)
        crewluCloudPartnerID = connection.partnerID
    }

    // MARK: - Refreshing

    /// Whether a read waits for the one under way to end.
    var isReadQueued: Bool { queuedRead != nil }

    /// Reads the status from wherever this device follows its pilot. A refresh asked for while a
    /// read is under way, say for a push that came mid-read, reads again once that read ends, since
    /// that read may have missed what the push was for. Every refresh asked for meanwhile shares that
    /// one read.
    func refresh() async -> RefreshOutcome {
        if let queuedRead {
            return await queuedRead.value
        }
        guard let readUnderWay else {
            return await runRead()
        }
        let next = Task {
            _ = await readUnderWay.value
            return await self.runRead()
        }
        queuedRead = next
        return await next.value
    }

    /// Runs one read, and tells the screen how it went before anyone waiting on it carries on.
    private func runRead() async -> RefreshOutcome {
        queuedRead = nil
        let read = Task {
            let readAt = Date()
            let outcome = await self.read()
            self.report(PilotStatusUpdate(outcome: outcome, readAt: readAt))
            return outcome
        }
        readUnderWay = read
        let outcome = await read.value
        if readUnderWay == read {
            readUnderWay = nil
        }
        return outcome
    }

    private func report(_ update: PilotStatusUpdate) {
        lastUpdate = update
        NotificationCenter.default.post(name: .pilotStatusDidUpdate, object: self)
    }

    /// The pilot stopped sharing with this device, as Crewlu Cloud told the push registration:
    /// forget the connection, and tell the screen.
    func endSharing() {
        forgetConnection()
        report(PilotStatusUpdate(outcome: .sharingEnded, readAt: Date()))
    }

    /// iCloud's share data was reset, by Reset Share Data or the share ending: an iCloud reading
    /// is no longer the pilot's status. The screen clears itself on the same reset.
    func forgetICloudReading() {
        guard case .iCloud? = reading else { return }
        reading = nil
    }

    /// Forgets this device's key and its Crewlu Cloud connection, as today's iCloud reset forgets
    /// the share (spec §7.6).
    private func forgetConnection() {
        connectionGeneration += 1
        keys.forgetDeviceKey()
        connection.partnerID = nil
        crewluCloudPartnerID = nil
        since = nil
        reading = nil
        defaults.removeObject(forKey: Self.displayNameKey)
        defaults.removeObject(forKey: Self.snapshotKey)
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
        let storedKey: String?
        do {
            storedKey = try keys.deviceKey()
        } catch {
            // The connection stays: the key is most likely there, and readable after an unlock.
            return .failed(Self.keyUnreadable)
        }
        guard let key = storedKey else {
            connection.partnerID = nil
            crewluCloudPartnerID = nil
            reading = nil
            since = nil
            return .notConnected
        }
        let generation = connectionGeneration
        let answer: PartnerViewAnswer
        do {
            answer = try await door.view(key: key, since: since)
        } catch .refused(.sharingEnded) {
            forgetConnection()
            return .sharingEnded
        } catch {
            guard generation == connectionGeneration else { return .sharingEnded }
            since = nil
            return .failed(Self.unreachable)
        }
        // Sharing ended while the door answered, say through the push registration: the answer
        // is for a connection that's gone.
        guard generation == connectionGeneration else { return .sharingEnded }
        return await take(answer)
    }

    /// A key with no Crewlu Cloud connection saved is what a reinstall leaves: iOS keeps an app's
    /// Keychain items, not its settings (spec §5.3). It's tried on every refresh until Crewlu
    /// Cloud answers, or the Keychain can be read. Nil carries on with iCloud.
    private func adoptLeftoverKey() async -> RefreshOutcome? {
        guard let key = try? keys.deviceKey() else { return nil }
        let answer: PartnerViewAnswer
        do {
            answer = try await door.view(key: key, since: nil)
        } catch .refused(.sharingEnded) {
            keys.forgetDeviceKey()
            return nil
        } catch {
            return nil
        }
        if case .noSummaryYet = answer.content, connection.hasICloudShare {
            return nil
        }
        connection.partnerID = answer.partnerID
        crewluCloudPartnerID = answer.partnerID
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
            since = answer.updatedAt
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
            reading = nil
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
        _ = keepDisplayName(of: newReading)
        reading = newReading
    }

    // MARK: - A New Reading

    /// Makes `newReading` the reading and hands it to the alerts once. The screen hears of it when
    /// the read ends.
    private func adopt(_ newReading: PilotReading) async -> RefreshOutcome {
        let previous = reading
        let name = keepDisplayName(of: newReading)
        logLegChanges(from: previous, to: newReading)
        reading = newReading
        await alert(newReading, titledWith: name)
        return .newStatus
    }

    /// Saves the reading's name for the alerts' titles, and gives the name to title them with now.
    /// When an iCloud read couldn't look the name up, the saved one stays.
    private func keepDisplayName(of reading: PilotReading) -> String? {
        guard reading.isDisplayNameKnown else {
            return defaults.string(forKey: Self.displayNameKey)
        }
        if let name = reading.displayName {
            defaults.set(name, forKey: Self.displayNameKey)
        } else {
            defaults.removeObject(forKey: Self.displayNameKey)
        }
        return reading.displayName
    }

    /// Hands a new status to the alerts, titled with `name` or else the pilot's first name, with what
    /// they compare: the effective delay and the resolved home arrival, worked out as the screen
    /// used to.
    private func alert(_ reading: PilotReading, titledWith name: String?) async {
        let now = Date()
        let status = reading.status(at: now)
        let homeArrival = TripStateResolver.resolveHomeArrival(
            legs: status.tripLegs, homeAirportCode: status.homeAirportCode, at: now
        )?.arrivalTime
        await notifier.evaluateChanges(
            old: nil,
            new: status,
            pilotName: name ?? status.pilotFirstName,
            newEffectiveDelay: status.effectiveFlightDelayMinutes,
            resolvedHomeArrivalTime: homeArrival ?? status.homeArrivalTime
        )
    }

    // MARK: - Diagnostic Logging

    /// Logs legs that appeared or disappeared between two readings, to catch disappearing legs.
    private func logLegChanges(from old: PilotReading?, to new: PilotReading) {
        let now = Date()
        let oldLegs = old?.status(at: now).tripLegs ?? []
        let newLegs = new.status(at: now).tripLegs
        let oldIds = Set(oldLegs.map(\.id))
        let newIds = Set(newLegs.map(\.id))
        guard oldIds != newIds else { return }

        debugLog("[TripLegDiff] === LEG CHANGE DETECTED ===")
        debugLog("[TripLegDiff] Count: \(oldLegs.count) → \(newLegs.count)")
        debugLog("[TripLegDiff] Record mod date: \(new.recordModifiedAt?.formatted(date: .abbreviated, time: .standard) ?? "unknown")")
        for leg in oldLegs where !newIds.contains(leg.id) {
            debugLog("[TripLegDiff] REMOVED: \(Self.describe(leg))")
        }
        for leg in newLegs where !oldIds.contains(leg.id) {
            debugLog("[TripLegDiff] ADDED: \(Self.describe(leg))")
        }
    }

    private static func describe(_ leg: TripLeg) -> String {
        let route = leg.type == .flight
            ? "\(leg.departureAirport ?? "?")→\(leg.arrivalAirport ?? "?")"
            : leg.airportCode ?? "?"
        let trip = leg.tripId.map { "trip:\($0)" } ?? "standalone"
        let start = leg.startTime.formatted(date: .abbreviated, time: .shortened)
        let end = leg.endTime.formatted(date: .abbreviated, time: .shortened)
        return "[\(leg.type.rawValue)] \(route) (\(trip)) \(start)–\(end)"
    }
}
