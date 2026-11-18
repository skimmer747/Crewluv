//
//  TripMapCornerPlacement.swift
//  CrewLuve
//
//  Where the latest event's banner and the key to the two planes go along the map's top in flight (which plane design
//  §2): the banner at the leading edge on the card, or centred under the full-screen map's pill, and the key at the
//  trailing edge, beside the banner where the two fit with a gap, else just under it, still at the trailing edge.
//  Sizes only, so it's tested apart from SwiftUI.
//

import CoreGraphics

nonisolated struct TripMapCornerPlacement: Equatable {
    /// The room between the banner and the key, beside it or under it.
    static let gap: CGFloat = 6

    /// The banner's frame, in the corner's own space. Nil with no banner.
    let banner: CGRect?
    /// The key's frame. Nil with no key.
    let key: CGRect?

    /// How far down the banner and the key reach.
    var height: CGFloat {
        max(banner?.maxY ?? 0, key?.maxY ?? 0)
    }

    /// - Parameters:
    ///   - width: the corner's width: the map's, less its insets.
    ///   - banner: the banner's size, or nil with none.
    ///   - reservedWidth: the widest the banner can be while the same event shows, with the widest "when" it could
    ///     show: the key goes by it, so it doesn't move as "Just now" grows to "About 1 h 5 min ago".
    ///   - isCentered: the banner is centred, as under the full-screen map's pill. Else it's at the leading edge.
    ///   - key: the key's size, or nil with none.
    init(width: CGFloat, banner: CGSize?, reservedWidth: CGFloat = 0, isCentered: Bool = false, key: CGSize?) {
        let bannerFrame = banner.map {
            CGRect(origin: CGPoint(x: isCentered ? (width - $0.width) / 2 : 0, y: 0), size: $0)
        }
        self.banner = bannerFrame
        guard let key else {
            self.key = nil
            return
        }
        let keyLeadingEdge = width - key.width
        guard let bannerFrame else {
            self.key = CGRect(origin: CGPoint(x: keyLeadingEdge, y: 0), size: key)
            return
        }
        let reserved = max(reservedWidth, bannerFrame.width)
        let bannerTrailingEdge = isCentered ? (width + reserved) / 2 : reserved
        let fitsBeside = bannerTrailingEdge + Self.gap <= keyLeadingEdge
        self.key = CGRect(origin: CGPoint(x: keyLeadingEdge, y: fitsBeside ? 0 : bannerFrame.maxY + Self.gap), size: key)
    }
}
