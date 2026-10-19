//
//  HandOffSession.swift
//  CrewLuve
//
//  Use on Another Device: a code for another of this partner's devices
//

import Foundation
import Observation

/// Use on Another Device (partner links piece 4 spec §7.5): makes a code as the sheet opens, and
/// another when the partner asks for one.
@Observable
final class HandOffSession {
    enum State: Equatable {
        case making
        case ready(HandOffCode)
        /// "Couldn't make a code. Check your connection and try again."
        case couldntMake
        /// The pilot stopped sharing with this device, so the sheet closes (§7.6).
        case sharingEnded
    }

    private(set) var state: State = .making

    @ObservationIgnored private let source: PilotStatusSource

    init(source: PilotStatusSource = .shared) {
        self.source = source
    }

    /// Makes a code, which replaces any code this partner has open.
    func makeCode() async {
        state = .making
        do {
            state = .ready(try await source.device.makeHandOffCode())
        } catch .refused(.sharingEnded) {
            source.endSharing()
            state = .sharingEnded
        } catch {
            state = .couldntMake
        }
    }
}
