//
//  LiveFlightSource.swift
//  CrewLuve
//
//  Asks Crewlu Cloud for the live plane while the status screen is in front
//

import Foundation
import Observation

/// The pilot's flights with live data, for one status screen (Stage 3 spec §11). It asks Crewlu Cloud's
/// partner_live once each time the screen comes to the front, and every 30 seconds while a flight's window is open.
/// The 30-second check runs only between `screenCameToFront()` and `screenLeftFront()`: the screen keeps it out of
/// the background by saying when it leaves the front. It never asks while this device follows its pilot through
/// iCloud.
@Observable
final class LiveFlightSource {

    /// A flight leg of the summary to ask about: its id, and its gate times moved by any reported delay.
    nonisolated struct Leg: Equatable, Sendable {
        let id: String
        let departure: Date
        let arrival: Date
    }

    /// How often it asks while a flight's window is open.
    static let interval: Duration = .seconds(30)

    /// Each flight Crewlu Cloud answered, by its leg's id. A leg with none has no live data.
    private(set) var flights: [String: LiveFlight] = [:]

    /// Crewlu Cloud's clock minus this device's, as of the last answer, so a wrong phone clock doesn't age a fix.
    @ObservationIgnored private(set) var clockOffset: TimeInterval = 0

    @ObservationIgnored private let door: LiveFlightDoor
    @ObservationIgnored private let keys: DeviceKeyStore
    @ObservationIgnored private let isOnCrewluCloud: () -> Bool
    @ObservationIgnored private let endSharing: () -> Void
    @ObservationIgnored private let timer: RepeatingRefresh
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var legs: [Leg] = []
    /// The last answer's cursor, sent back so only the trail points since then come.
    @ObservationIgnored private var cursor: Int?
    /// The key the flights were answered for. Another key's flights are another connection's.
    @ObservationIgnored private var answeredKey: String?
    @ObservationIgnored private var isAsking = false

    /// - Parameters:
    ///   - isOnCrewluCloud: whether this device follows its pilot through Crewlu Cloud.
    ///   - endSharing: tells the status source the pilot stopped sharing with this device.
    ///   - timer: runs the 30-second check.
    ///   - now: this device's clock.
    init(
        door: LiveFlightDoor = LivePartnerDoor(),
        keys: DeviceKeyStore = KeychainDeviceKeyStore(),
        isOnCrewluCloud: @escaping () -> Bool = { PilotStatusSource.shared.isOnCrewluCloud },
        endSharing: @escaping () -> Void = { PilotStatusSource.shared.endSharing() },
        timer: RepeatingRefresh = RepeatingRefresh(interval: LiveFlightSource.interval),
        now: @escaping () -> Date = { Date() }
    ) {
        self.door = door
        self.keys = keys
        self.isOnCrewluCloud = isOnCrewluCloud
        self.endSharing = endSharing
        self.timer = timer
        self.now = now
    }

    /// A source let go while its screen is in front takes its 30-second check with it.
    isolated deinit {
        timer.stop()
    }

    /// Crewlu Cloud's time when this device's clock says `date`. Fix ages and windows are measured against it.
    func serverTime(at date: Date) -> Date {
        date.addingTimeInterval(clockOffset)
    }

    /// The summary's flight legs, whenever they change: the 30-second check asks while one's window is open.
    func watch(_ legs: [Leg]) {
        self.legs = legs
    }

    /// The screen came to the front: asks once, then every 30 seconds while a flight's window is open.
    func screenCameToFront() async {
        timer.start { [weak self] in
            await self?.check()
        }
        await ask()
    }

    /// The screen left the front: nothing is asked until it's back.
    func screenLeftFront() {
        timer.stop()
    }

    /// Asks Crewlu Cloud once, and takes its answer. While a call is under way, another asks nothing: the one under
    /// way brings the answer. The exception is a call the 30-second check made, which ends unanswered when the check
    /// is stopped or started again: an `ask()` that found it under way gets no answer either, until the next check.
    func ask() async {
        guard !isAsking else { return }
        guard isOnCrewluCloud() else {
            forget()
            return
        }
        let key: String
        do {
            // With no key, this device is no longer on Crewlu Cloud: the status source finds that out at its next read.
            guard let stored = try keys.deviceKey() else { return }
            key = stored
        } catch {
            debugLog("[LiveFlightSource] This device's key couldn't be read, so the live plane wasn't asked for")
            return
        }
        if key != answeredKey {
            forget()
        }
        isAsking = true
        defer { isAsking = false }
        let sent = cursor
        do {
            var askedAt = now()
            let answer = try await door.live(key: key, after: sent)
            // An answer for a key this device has since replaced, say by switching, is another connection's.
            guard (try? keys.deviceKey()) == key else { return }
            if !take(answer, isWhole: sent == nil, askedAt: askedAt) {
                // A trail doesn't add up: a point reached Crewlu Cloud after one with a later id, or the flight is
                // new here and has points from before the cursor. Every point, then.
                askedAt = now()
                let whole = try await door.live(key: key, after: nil)
                guard (try? keys.deviceKey()) == key else { return }
                _ = take(whole, isWhole: true, askedAt: askedAt)
            }
            answeredKey = key
        } catch .refused(.sharingEnded) {
            // A refusal for a key this device has since replaced ends nothing.
            guard (try? keys.deviceKey()) == key else { return }
            forget()
            endSharing()
        } catch {
            // Crewlu Cloud couldn't be reached, or refused for another reason, and the door has logged why: what's
            // here stays.
        }
    }

    // MARK: - Private

    /// The 30-second check: asks while any flight's window is open. Until the first answer the windows are measured
    /// by this device's clock alone, which the ask on coming to the front soon puts right.
    private func check() async {
        let serverNow = serverTime(at: now())
        let isAnyWindowOpen = legs.contains {
            LiveWindow.isOpen(departure: $0.departure, arrival: $0.arrival, flight: flights[$0.id], at: serverNow)
        }
        guard isAnyWindowOpen else { return }
        await ask()
    }

    /// Makes `answer` the flights. One that isn't whole brings each flight's points since the cursor, which go after
    /// the points already here. False, changing nothing, when a trail then holds another number of points than
    /// Crewlu Cloud says the flight has. A whole answer is taken as it comes. `askedAt` is when its call went out, by
    /// this device's clock.
    private func take(_ answer: PartnerLiveAnswer, isWhole: Bool, askedAt: Date) -> Bool {
        var answered: [String: LiveFlight] = [:]
        for flight in answer.flights {
            let trail = isWhole ? flight.trail : (flights[flight.legID]?.trail ?? []) + flight.trail
            guard isWhole || trail.count == flight.trailCount else { return false }
            answered[flight.legID] = LiveFlight(flight, trail: trail)
        }
        if flights != answered {
            flights = answered
        }
        cursor = answer.cursor
        // Crewlu Cloud read its clock somewhere inside the call: the call's middle is the best guess of when.
        let middle = askedAt.addingTimeInterval(now().timeIntervalSince(askedAt) / 2)
        clockOffset = answer.now.timeIntervalSince(middle)
        return true
    }

    /// Forgets the flights and the cursor: they were another connection's, or sharing has ended.
    private func forget() {
        if !flights.isEmpty {
            flights = [:]
        }
        cursor = nil
        answeredKey = nil
    }
}
