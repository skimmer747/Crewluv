//
//  View+ClockLabelHelp.swift
//  CrewLuve
//
//  The hover tip over a time marked "L" (time labels design §3.5): on an iPad with a pointer, it names the family's
//  time zone. An iPhone has no pointer, and the key under the facts says the same.
//

import SwiftUI

extension View {
    /// The key, "L = your time (Eastern Standard Time)", as the hover tip when `text` holds a time marked "L".
    @ViewBuilder
    func clockLabelHelp(for text: String) -> some View {
        if ClockLabel.hasMark(text) {
            help(ClockLabel.key(at: .now))
        } else {
            self
        }
    }
}
