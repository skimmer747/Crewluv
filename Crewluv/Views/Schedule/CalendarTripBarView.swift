//
//  CalendarTripBarView.swift
//  CrewLuve
//
//  Canvas-based trip bar strip renderer for calendar week rows
//

import SwiftUI

struct CalendarTripBarView: View {
    let segments: [CalendarBarSegment]

    private static let barHeight: CGFloat = 6
    private static let cornerRadius: CGFloat = 3

    private static let onDutyColor = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.3, green: 0.45, blue: 0.9, alpha: 1)
            : UIColor(red: 0.1, green: 0.2, blue: 0.45, alpha: 1)
    })
    static let offDutyColor = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.55, green: 0.65, blue: 0.8, alpha: 1)
            : UIColor(red: 0.6, green: 0.75, blue: 0.92, alpha: 1)
    })

    var body: some View {
        Canvas { context, size in
            for segment in segments {
                let x = segment.startFraction / 7.0 * size.width
                let width = (segment.endFraction - segment.startFraction) / 7.0 * size.width
                let rect = CGRect(
                    x: x,
                    y: (size.height - Self.barHeight) / 2,
                    width: width,
                    height: Self.barHeight
                )

                let leadingRadius = segment.hasRoundedLeading ? Self.cornerRadius : 0
                let trailingRadius = segment.hasRoundedTrailing ? Self.cornerRadius : 0

                let path = Path(roundedRect: rect, cornerRadii: RectangleCornerRadii(
                    topLeading: leadingRadius,
                    bottomLeading: leadingRadius,
                    bottomTrailing: trailingRadius,
                    topTrailing: trailingRadius
                ))

                let color: Color = switch segment.category {
                case .onDuty: Self.onDutyColor
                case .offDuty: Self.offDutyColor
                }

                context.fill(path, with: .color(color))
            }
        }
        .frame(height: 10)
    }
}
