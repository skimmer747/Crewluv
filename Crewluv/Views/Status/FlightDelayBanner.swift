//
//  FlightDelayBanner.swift
//  CrewLuve
//
//  "DELAYED 45m" or "EARLY DEP 10m" under the in-flight map. Moved out of LocationCardView so the trip map's card
//  and the in-flight fallback share it.
//

import SwiftUI

struct FlightDelayBanner: View {
    /// Signed: positive late, negative early.
    let delayMinutes: Int

    var body: some View {
        let isEarly = delayMinutes < 0
        HStack(spacing: 6) {
            Image(systemName: isEarly ? "clock.badge.checkmark.fill" : "exclamationmark.triangle.fill")
                .font(.caption)
                .accessibilityHidden(true)
            Text("\(isEarly ? "EARLY DEP" : "DELAYED") \(LocationCardView.formatDelayDuration(abs(delayMinutes)))")
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(isEarly ? Color.green : Color.orange)
        .accessibilityElement(children: .combine)
    }
}
