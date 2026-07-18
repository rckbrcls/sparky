//
//  FocusCanvasView.swift
//  sparky
//

import Foundation
import SwiftUI

struct FocusCanvasView: View {
    @ObservedObject var timer: FocusTimer
    @Binding var selectedWorkMinutes: Int

    let onStartQuick: () -> Void
    let onEnd: () -> Void
    var showsEndButton: Bool = true

    @ScaledMetric(relativeTo: .largeTitle) private var titleFontSize: CGFloat = 44

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                Text(phaseLabel)
                    .font(.system(size: titleFontSize, weight: .regular, design: .serif))
                    .foregroundStyle(Color.Theme.textPrimary)
                    .padding(.top, 72)
                    .accessibilityLabel("Phase \(phaseLabel)")

                FocusTimerRing(
                    selectedMinutes: $selectedWorkMinutes,
                    countdownSeconds: timer.isSessionActive ? timer.remainingSeconds : nil,
                    phase: timer.isSessionActive ? timer.phase : .idle,
                    allowsAdjustment: !timer.isSessionActive
                )
                .frame(maxWidth: 280)
                .padding(.horizontal, 28)
                .padding(.top, 38)

                primaryControl
                    .padding(.top, 40)

                if timer.isSessionActive, showsEndButton {
                    Button(role: .destructive) {
                        onEnd()
                    } label: {
                        Text("End session")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.Theme.destructive)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 18)
                    .accessibilityLabel("End Focus session")
                }

                Spacer(minLength: 32)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 32)
        }
    }

    private var phaseLabel: String {
        timer.isSessionActive && timer.phase == .break ? "Break" : "Focus"
    }

    private var phaseColor: Color {
        timer.phase == .break ? Color.Theme.success : Color.accentColor
    }

    @ViewBuilder
    private var primaryControl: some View {
        Button(action: performPrimaryAction) {
            primaryLabel
                .foregroundStyle(primaryForeground)
                .frame(minWidth: 154, minHeight: 54)
                .padding(.horizontal, 28)
                .background(
                    Capsule(style: .continuous)
                        .fill(primaryBackground)
                )
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(
                            Color.Theme.border.opacity(timer.isSessionActive ? 0.45 : 0),
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(primaryAccessibilityLabel)
    }

    @ViewBuilder
    private var primaryLabel: some View {
        if !timer.isSessionActive {
            HStack(spacing: 10) {
                Text("Start")
                    .font(.headline)
                Image(systemName: "play.fill")
                    .font(.subheadline.weight(.semibold))
            }
        } else if timer.isWaitingForManualStart {
            Label(nextPhaseLabel, systemImage: nextPhaseIcon)
                .font(.headline)
        } else {
            Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                .font(.title3.weight(.semibold))
        }
    }

    private var primaryBackground: Color {
        if !timer.isSessionActive || timer.isWaitingForManualStart {
            return phaseColor
        }
        return Color.Theme.secondaryBackground
    }

    private var primaryForeground: Color {
        if !timer.isSessionActive || timer.isWaitingForManualStart {
            return Color.Theme.accentForeground
        }
        return Color.Theme.textPrimary
    }

    private var primaryAccessibilityLabel: String {
        if !timer.isSessionActive {
            return "Start Quick Focus, \(selectedWorkMinutes) minutes"
        }
        if timer.isWaitingForManualStart {
            return nextPhaseLabel
        }
        return timer.isRunning ? "Pause Focus" : "Resume Focus"
    }

    private var nextPhaseLabel: String {
        timer.phase == .break ? "Start Break" : "Start Focus"
    }

    private var nextPhaseIcon: String {
        timer.phase == .break ? "cup.and.saucer.fill" : "timer"
    }

    private func performPrimaryAction() {
        if !timer.isSessionActive {
            onStartQuick()
        } else if timer.isWaitingForManualStart {
            timer.startNextPhase()
        } else if timer.isRunning {
            timer.pause()
        } else {
            timer.start()
        }
    }
}

@MainActor
private func makeFocusCanvasPreviewTimer(suite: String) -> FocusTimer {
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    let settings = FocusSettings(defaults: defaults)
    let appSettings = SettingsStore(defaults: defaults)
    return FocusTimer(
        settings: settings,
        notifications: FocusNotificationService(settings: appSettings)
    )
}

#Preview("Focus Canvas · Idle") {
    @Previewable @State var minutes = 25
    let timer = makeFocusCanvasPreviewTimer(suite: "FocusCanvasPreview.idle")

    FocusCanvasView(
        timer: timer,
        selectedWorkMinutes: $minutes,
        onStartQuick: { },
        onEnd: { }
    )
    .background(Color.Theme.secondaryBackground)
}

#Preview("Focus Canvas · Running") {
    @Previewable @State var minutes = 15
    let timer = makeFocusCanvasPreviewTimer(suite: "FocusCanvasPreview.running")
    timer.beginQuickSession(workDurationMinutes: minutes)

    return FocusCanvasView(
        timer: timer,
        selectedWorkMinutes: $minutes,
        onStartQuick: { },
        onEnd: { }
    )
    .background(Color.Theme.secondaryBackground)
}

#Preview("Focus Canvas · Paused") {
    @Previewable @State var minutes = 15
    let timer = makeFocusCanvasPreviewTimer(suite: "FocusCanvasPreview.paused")
    timer.beginQuickSession(workDurationMinutes: minutes)
    timer.pause()

    return FocusCanvasView(
        timer: timer,
        selectedWorkMinutes: $minutes,
        onStartQuick: { },
        onEnd: { }
    )
    .background(Color.Theme.secondaryBackground)
}
