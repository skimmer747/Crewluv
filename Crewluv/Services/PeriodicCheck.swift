//
//  PeriodicCheck.swift
//  CrewLuve
//
//  The 60-second check, while a screen is in front
//

import Foundation

/// The 60-second check's timer, which runs while any screen is in front (partner links piece 4
/// spec §5.5). iPad can show several screens, and a tick goes on only while one of them isn't
/// showing the demo.
final class PeriodicCheck {
    private let timer: RepeatingRefresh
    /// The screens in front, each with what says whether it shows the demo.
    private var screensInFront: [ObjectIdentifier: () -> Bool] = [:]

    init(timer: RepeatingRefresh = RepeatingRefresh()) {
        self.timer = timer
    }

    /// `screen` is in front: while any screen is, `tick` runs every 60 seconds whenever a screen in
    /// front isn't showing the demo. Every caller passes the same tick.
    func start(for screen: AnyObject, pausedWhile isPaused: @escaping () -> Bool, tick: @escaping () async -> Void) {
        screensInFront[ObjectIdentifier(screen)] = isPaused
        guard !timer.isRunning else { return }
        timer.start { [weak self] in
            guard let self, self.screensInFront.values.contains(where: { !$0() }) else { return }
            await tick()
        }
    }

    /// `screen` left the front. The timer stops once no screen is in front.
    func stop(for screen: AnyObject) {
        screensInFront[ObjectIdentifier(screen)] = nil
        if screensInFront.isEmpty {
            timer.stop()
        }
    }
}
