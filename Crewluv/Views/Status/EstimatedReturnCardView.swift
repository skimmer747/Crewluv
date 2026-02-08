//
//  EstimatedReturnCardView.swift
//  CrewLuv
//
//  Fallback card when precise homeArrivalTime is unavailable.
//  Shows approximate days remaining based on trip progress.
//

import SwiftUI

struct EstimatedReturnCardView: View {
    let tripDayNumber: Int
    let tripTotalDays: Int

    private var daysRemaining: Int {
        max(tripTotalDays - tripDayNumber, 0)
    }

    private var displayText: String {
        if daysRemaining <= 0 {
            return "Soon"
        } else if daysRemaining == 1 {
            return "~1 day"
        } else {
            return "~\(daysRemaining) days"
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "house.fill")
                    .font(.title)
                    .foregroundColor(.green)
                Text("Home In")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.primary)

            Text(displayText)
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundColor(.green)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
    }
}

#Preview {
    VStack(spacing: 20) {
        EstimatedReturnCardView(tripDayNumber: 1, tripTotalDays: 4)
        EstimatedReturnCardView(tripDayNumber: 3, tripTotalDays: 4)
        EstimatedReturnCardView(tripDayNumber: 4, tripTotalDays: 4)
    }
    .padding()
}
