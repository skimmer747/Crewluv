//
//  TripMapClearance.swift
//  CrewLuve
//
//  What covers the map: the facts sheet or side panel on the full screen (Stage 2 spec §6.1, §6.2), and the chips on
//  the card (base waits and card framing design §4.1). The map keeps clear of it in its layout margins. MapKit puts
//  Apple's logo and Legal link inside them and fits the camera's rectangle inside them too, so the margins alone keep
//  both clear. The clearance is measured from the screen's edges, so the safe area under it is counted only once.
//

import UIKit

nonisolated struct TripMapClearance: Equatable {
    /// From the map's top edge to the bottom of the card's top chip, its gap included.
    let top: CGFloat
    /// From the map's leading edge to the panel's trailing edge, padding included.
    let leading: CGFloat
    /// From the map's bottom edge to the top of the sheet, or of the card's bottom chip and its gap.
    let bottom: CGFloat

    static let none = TripMapClearance()

    init(top: CGFloat = 0, leading: CGFloat = 0, bottom: CGFloat = 0) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
    }

    /// What the clearance adds to the map's layout margins: the part of each beyond the safe area, since UIKit
    /// already puts the safe area in the margins.
    func marginsBeyondSafeArea(_ safeArea: UIEdgeInsets, isRightToLeft: Bool) -> NSDirectionalEdgeInsets {
        let leadingSafeArea = isRightToLeft ? safeArea.right : safeArea.left
        return NSDirectionalEdgeInsets(top: max(0, top - safeArea.top), leading: max(0, leading - leadingSafeArea),
                                       bottom: max(0, bottom - safeArea.bottom), trailing: 0)
    }
}
