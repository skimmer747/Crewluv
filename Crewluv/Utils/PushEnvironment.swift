//
//  PushEnvironment.swift
//  CrewLuve
//
//  Which of Apple's push services this build's tokens belong to
//

import Foundation

/// Which of Apple's push services this build's tokens belong to: `sandbox` for every build Xcode
/// installs, Debug or Release, and `production` for TestFlight and the App Store. It follows the
/// `aps-environment` entitlement that the build's provisioning profile sets (partner-api.md,
/// "Pushes"). A token sent with the wrong one is turned away by Apple and dropped.
nonisolated enum PushEnvironment: String, Sendable {
    case sandbox
    case production

    /// This build's environment.
    static var current: PushEnvironment {
        #if targetEnvironment(simulator)
        .sandbox
        #else
        from(provisioningProfile: Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision")
            .flatMap { try? Data(contentsOf: $0) })
        #endif
    }

    /// The environment a build with this embedded provisioning profile has. TestFlight and the
    /// App Store remove the profile, so none means `production`. A profile is signed data with
    /// its plist inside: ad hoc profiles say `production`, and the ones Xcode installs don't.
    static func from(provisioningProfile data: Data?) -> PushEnvironment {
        guard let data else { return .production }
        guard let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex),
              let plist = try? PropertyListSerialization.propertyList(
                  from: data[start.lowerBound..<end.upperBound], format: nil
              ) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any],
              entitlements["aps-environment"] as? String == "production"
        else { return .sandbox }
        return .production
    }
}
