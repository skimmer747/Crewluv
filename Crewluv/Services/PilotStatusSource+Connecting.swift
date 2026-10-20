//
//  PilotStatusSource+Connecting.swift
//  CrewLuve
//
//  How this device's connection changes: joining, Disconnect, and sharing ending
//

import Foundation

extension PilotStatusSource {
    /// The pilot stopped sharing with this device, as Crewlu Cloud told the push registration:
    /// forget the connection, and tell the screen. A refusal Disconnect's own leave caused ends nothing.
    func endSharing() {
        guard !device.isDisconnecting else { return }
        device.forget()
        noteSharingEnded()
        report(PilotStatusUpdate(outcome: .sharingEnded, readAt: Date()))
    }

    /// Switches this device to what a join joined (spec §7.2), then lets the device it replaced leave
    /// and reads the new connection. False when the key couldn't be saved; then nothing changes.
    func connect(_ joined: CrewluCloudDevice.Joined, keepingAlerts: Bool) async -> Bool {
        guard let replaced = switchConnection(to: joined, keepingAlerts: keepingAlerts) else { return false }
        await device.leave(replaced)
        _ = await refresh()
        return true
    }

    /// The switch itself, for a join, a key a reinstall left or the move-over (spec §7.2, §8.2): the
    /// key, an iCloud share forgotten quietly, the note gone and the push token sent. For another pilot,
    /// what the alerts kept of the last goes first. All of it changes before anything waits, so no read
    /// sees half a switch. Nil when the key couldn't be saved; then nothing changes.
    func switchConnection(to joined: CrewluCloudDevice.Joined, keepingAlerts: Bool) -> CrewluCloudDevice.Replaced? {
        guard let replaced = device.switchTo(joined) else { return nil }
        if !keepingAlerts {
            connection.forgetPilot()
        }
        connection.leaveICloud(forgetShare: forgetICloudShare)
        connection.sharingEndedWith = nil
        sharingEndedWith = nil
        reading = nil
        didConnect()
        return replaced
    }

    /// Disconnect (spec §7.5): this device leaves, then forgets its key, the connection, the pilot and
    /// any iCloud share, with no note. False when Crewlu Cloud couldn't be reached; then the device
    /// stays connected. A join that switched this device meanwhile keeps its new connection.
    func disconnect() async -> Bool {
        do {
            guard try await device.disconnect() else { return true }
        } catch {
            return false
        }
        forgetPilot()
        connection.leaveICloud(forgetShare: forgetICloudShare)
        report(PilotStatusUpdate(outcome: .notConnected, readAt: Date()))
        return true
    }

    /// Sharing with this device ended: the welcome screen's note names the pilot last seen, if any,
    /// and the pilot is forgotten (spec §7.6).
    func noteSharingEnded() {
        connection.sharingEndedWith = connection.pilotName
        sharingEndedWith = connection.pilotName
        forgetPilot()
    }

    func forgetPilot() {
        reading = nil
        connection.forgetPilot()
    }
}
