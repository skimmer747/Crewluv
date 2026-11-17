//
//  TripMapCornerLayout.swift
//  CrewLuve
//
//  Lays out `TripMapCorner`'s views where `TripMapCornerPlacement` puts them (which plane design §2): the latest
//  event's banner, a hidden copy of it with the widest "when" it could show, which the key goes by, and the key to
//  the two planes. Each view says which it is with `role(_:)`.
//

import SwiftUI

struct TripMapCornerLayout: Layout {

    enum Role {
        case banner
        /// The banner with the widest "when", hidden: measured, never seen.
        case widestBanner
        case key
    }

    /// `role(_:)` sets it.
    fileprivate struct RoleKey: LayoutValueKey {
        static let defaultValue = Role.banner
    }

    /// The banner is centred, as under the full-screen map's pill. Else it's at the leading edge.
    var isCentered = false

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? naturalWidth(of: subviews)
        return CGSize(width: width, height: placement(width: width, subviews: subviews).height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let placement = placement(width: bounds.width, subviews: subviews)
        for subview in subviews {
            let frame = subview[RoleKey.self] == .key ? placement.key : placement.banner
            guard let frame else { continue }
            // The hidden banner sits where the banner does, at its own size.
            let size = subview[RoleKey.self] == .widestBanner ? subview.sizeThatFits(widthOnly(bounds.width)) : frame.size
            subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: ProposedViewSize(size))
        }
    }

    // MARK: - Private

    private func placement(width: CGFloat, subviews: Subviews) -> TripMapCornerPlacement {
        let proposal = widthOnly(width)
        func size(of role: Role) -> CGSize? {
            subviews.first { $0[RoleKey.self] == role }?.sizeThatFits(proposal)
        }
        return TripMapCornerPlacement(width: width, banner: size(of: .banner), reservedWidth: size(of: .widestBanner)?.width ?? 0,
                                      isCentered: isCentered, key: size(of: .key))
    }

    /// The banner and the key side by side, as wide as they'd like to be, for a proposal with no width.
    private func naturalWidth(of subviews: Subviews) -> CGFloat {
        func width(of roles: Set<Role>) -> CGFloat {
            subviews.filter { roles.contains($0[RoleKey.self]) }.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        }
        return width(of: [.banner, .widestBanner]) + TripMapCornerPlacement.gap + width(of: [.key])
    }

    private func widthOnly(_ width: CGFloat) -> ProposedViewSize {
        ProposedViewSize(width: width, height: nil)
    }
}

extension View {
    /// Which of `TripMapCornerLayout`'s views this is.
    func role(_ role: TripMapCornerLayout.Role) -> some View {
        layoutValue(key: TripMapCornerLayout.RoleKey.self, value: role)
    }
}
