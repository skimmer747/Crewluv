//
//  TripMapClearance.swift
//  CrewLuve
//
//  What the facts sheet or side panel covers of the full-screen map (Stage 2 spec §6.1, §6.2), and how the map keeps
//  clear of it: in its layout margins, where MapKit puts Apple's logo and Legal link, and in the padding the camera
//  frames inside. Both are measured from the screen's edges, so the safe area under them is counted only once.
//

import UIKit

nonisolated struct TripMapClearance: Equatable {
    /// From the map's leading edge to the panel's trailing edge, padding included.
    let leading: CGFloat
    /// From the map's bottom edge to the top of the sheet.
    let bottom: CGFloat

    static let none = TripMapClearance(leading: 0, bottom: 0)

    /// What the clearance adds to the map's layout margins: the part of each beyond the safe area, since UIKit
    /// already puts the safe area in the margins.
    func marginsBeyondSafeArea(_ safeArea: UIEdgeInsets, isRightToLeft: Bool) -> NSDirectionalEdgeInsets {
        let leadingSafeArea = isRightToLeft ? safeArea.right : safeArea.left
        return NSDirectionalEdgeInsets(top: 0, leading: max(0, leading - leadingSafeArea),
                                       bottom: max(0, bottom - safeArea.bottom), trailing: 0)
    }

    /// The padding the camera frames the trip inside: the safe area, or the sheet and the panel where they reach
    /// further. Left and right, as MapKit takes it.
    func framingPadding(safeArea: UIEdgeInsets, isRightToLeft: Bool) -> UIEdgeInsets {
        var padding = safeArea
        padding.bottom = max(safeArea.bottom, bottom)
        if isRightToLeft {
            padding.right = max(safeArea.right, leading)
        } else {
            padding.left = max(safeArea.left, leading)
        }
        return padding
    }
}
