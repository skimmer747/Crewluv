//
//  JoinAlerts.swift
//  CrewLuve
//
//  What joining asks, and says when a link or code didn't connect
//

import SwiftUI

/// What a join asks or says (partner links piece 4 spec §7.2, §7.3): "Switch to Sam?" when the link
/// is from another pilot, and the message when a link or code didn't connect.
struct JoinAlerts: ViewModifier {
    let joiner: PartnerJoiner

    func body(content: Content) -> some View {
        content
            .alert(joiner.switchQuestion?.title ?? "", isPresented: isAskingToSwitch, presenting: joiner.switchQuestion) { _ in
                Button("Switch") { joiner.answerSwitch(true) }
                    .keyboardShortcut(.defaultAction)
                Button("Cancel", role: .cancel) { joiner.answerSwitch(false) }
            } message: { question in
                Text(question.message)
            }
            .alert(joiner.message?.title ?? "", isPresented: isShowingMessage, presenting: joiner.message) { _ in
                Button("OK") { joiner.message = nil }
            } message: { message in
                Text(message.text)
            }
    }

    private var isAskingToSwitch: Binding<Bool> {
        Binding(
            get: { joiner.switchQuestion != nil },
            set: { isShown in
                if !isShown, joiner.switchQuestion != nil {
                    joiner.answerSwitch(false)
                }
            }
        )
    }

    private var isShowingMessage: Binding<Bool> {
        Binding(get: { joiner.message != nil }, set: { if !$0 { joiner.message = nil } })
    }
}
