//
//  FocusSessionView.swift
//  sparky
//

import SwiftUI

struct FocusSessionView: View {
    @ObservedObject var timer: FocusTimer
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
                }
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
