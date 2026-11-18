//
//  TripMapCorner.swift
//  CrewLuve
//
//  What goes along the map's top in flight: the latest event's banner (latest event design §1) and the key to the two
//  planes (which plane design §2). The key stays at the trailing edge, beside the banner where the two fit, else just
//  under it (`TripMapCornerLayout`).
//

import SwiftUI

struct TripMapCorner: View {
    let latest: LatestEvent?
    let showsKey: Bool
    /// The banner is centred, as under the full-screen map's pill. Else it's at the leading edge, as on the card.
    var isCentered = false

    var body: some View {
        TripMapCornerLayout(isCentered: isCentered) {
            if let latest {
                LatestEventBanner(event: latest, alignment: isCentered ? .center : .leading)
                    .role(.banner)
                // The same banner with the widest "when" it could show: the key goes by it, so it doesn't move as the
                // minutes count up.
                LatestEventBanner(event: LatestEvent(title: latest.title, when: FactsWording.widestEventWhen, sentence: latest.sentence),
                                  alignment: isCentered ? .center : .leading)
                    .hidden()
                    .accessibilityHidden(true)
                    .role(.widestBanner)
            }
            if showsKey {
                PlaneKey()
                    .role(.key)
            }
        }
        // It takes no taps: on the full-screen map a tap on it goes on to the map, which pans, or closes a popup.
        .allowsHitTesting(false)
    }
}
