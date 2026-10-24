//
//  NotificationService.swift
//  CrewluveAlerts
//
//  The alert pushes' helper: writes what happened over an alert push's "New update"
//

import UserNotifications

/// iOS runs this for each alert push from Crewlu Cloud, whatever state Crewluve is in (alert pushes spec §6.1). The push
/// carries only its kind, "New update" and its sound. This writes the kind's words from the pilot's status, or the plain
/// line when there's no status to use or iOS's time runs out, and keeps the push's sound. A kind this Crewluve doesn't
/// know keeps the push as it came. Nonisolated, since iOS calls it on a thread of its choosing; the writer runs on the
/// main actor, as the app's door and Keychain code do.
nonisolated final class NotificationService: UNNotificationServiceExtension {
    private let pending = PendingAlertPush()

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        let push = request.content
        guard let kind = AlertPushWriter.kind(of: push.userInfo) else {
            contentHandler(push)
            return
        }
        pending.start { words in
            contentHandler(AlertPushWriter.content(of: push, with: words))
        }
        Task { @MainActor [pending] in
            let writer = AlertPushWriter(door: LivePartnerDoor(), keys: KeychainDeviceKeyStore())
            pending.hold(writer.plainLine(for: kind))
            pending.finish(with: await writer.words(for: kind))
        }
    }

    override func serviceExtensionTimeWillExpire() {
        pending.expire()
    }
}
