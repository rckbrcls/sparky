//
//  FocusSessionView.swift
//  sparky
//

import SwiftUI

struct FocusSessionView: View {
    @ObservedObject var timer: FocusTimer
    /// Mind for the active memory session header (optional).
    var activeMind: Mind? = nil
    /// Dismisses presentation without ending the session.
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            FocusCanvasView(
                timer: timer,
                selectedWorkMinutes: .constant(
                    min(60, timer.activeRecipe?.workDurationMinutes ?? 60)
                ),
                onStartQuick: { },
                onEnd: {
                    timer.endSession()
                    onClose()
                },
                activeMind: activeMind
            )
            .background(Color.Theme.secondaryBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        onClose()
                    }
                    .accessibilityLabel("Close Focus")
                }
            }
        }
    }
}
