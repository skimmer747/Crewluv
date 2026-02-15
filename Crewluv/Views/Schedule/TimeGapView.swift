//
//  TimeGapView.swift
//  CrewLuv
//
//  Gap indicator between legs in the schedule timeline
//

import SwiftUI

struct TimeGapView: View {
    let fromLeg: TripLeg
    let toLeg: TripLeg

    var body: some View {
        HStack(spacing: 8) {
            // Dashed line connecting timeline legs across the gap
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 0, y: 20))
            }
            .stroke(gapColor.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4]))
            .frame(width: 1, height: 20)
                .padding(.leading, 18) // align with icon center (12 padding + 18 half of 36)

            Text(gapLabel)
                .font(.caption2)
                .foregroundColor(gapColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
    }

    private var gapDuration: TimeInterval {
        toLeg.startTime.timeIntervalSince(fromLeg.endTime)
    }

    private var gapType: TripLeg.LegType {
        // Infer gap type from the leg that follows
        toLeg.type
    }

    private var gapColor: Color {
        switch gapType {
        case .home:    return .green
        case .turn:    return .orange
        case .layover: return .blue
        default:       return .secondary
        }
    }

    private var gapLabel: String {
        let duration = max(gapDuration, 0)
        let label: String
        switch gapType {
        case .home:    label = "Home"
        case .turn:    label = "Turn"
        case .layover: label = "Layover"
        default:       label = "Gap"
        }
        return "\(label) \(formattedDuration(duration))"
    }

    private func formattedDuration(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let days = total / 86400
        let hours = (total % 86400) / 3600
        let minutes = (total % 3600) / 60

        if days > 0 {
            return hours > 0 ? "\(days)d \(hours)h" : "\(days)d"
        } else if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
}
