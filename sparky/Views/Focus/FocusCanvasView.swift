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
    /// Mind bound to the active memory session (icon next to the title).
    var activeMind: Mind? = nil

    @ScaledMetric(relativeTo: .largeTitle) private var titleFontSize: CGFloat = 44

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                sessionHeader
                    .padding(.top, 72)
                    .padding(.horizontal, 28)
                    .accessibilityLabel(headerAccessibilityLabel)

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
                    Button(role: .destructive, action: onEnd) {
                        Text("End session")
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.Theme.destructive)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .padding(.top, 18)
                    .accessibilityLabel("End Focus session")
                }

                Spacer(minLength: 32)
            }
            #if os(macOS)
            .frame(maxWidth: DesktopLayoutMetrics.primaryContentMaxWidth)
            #endif
            .frame(maxWidth: .infinity)
            .padding(.bottom, 32)
        }
    }

    private var isMemorySession: Bool {
        timer.isSessionActive && timer.activeMemoryID != nil
    }

    private var headerTitle: String {
        if timer.isSessionActive && timer.phase == .break {
            return "Break"
        }
        if isMemorySession {
            let title = (timer.activeMemoryTitle ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return title.isEmpty ? "Focus" : title
        }
        return "Focus"
    }

    private var headerAccessibilityLabel: String {
        if isMemorySession, timer.phase != .break {
            return "Memory \(headerTitle)"
        }
        return "Phase \(headerTitle)"
    }

    private var mindIconName: String {
        activeMind?.iconName ?? "brain.head.profile"
    }

    private var mindColor: Color {
        if let hex = activeMind?.colorHex, let color = Color(hex: hex) {
            return color
        }
        return Color.Theme.textSecondary
    }

    @ViewBuilder
    private var sessionHeader: some View {
        HStack(spacing: 12) {
            if isMemorySession, timer.phase != .break {
                Image(systemName: mindIconName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(mindColor)
                    .frame(width: 36, height: 36)
                    .glassEffect(
                        .regular.tint(mindColor.opacity(0.15)),
                        in: .circle
                    )
                    .accessibilityHidden(true)
            }

            Text(headerTitle)
                .font(.system(size: titleFontSize, weight: .regular, design: .serif))
                .foregroundStyle(Color.Theme.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.55)
        }
    }

    private var phaseColor: Color {
        timer.phase == .break ? Color.Theme.success : Color.accentColor
    }

    @ViewBuilder
    private var primaryControl: some View {
        Button(action: performPrimaryAction) {
            primaryLabel
                .frame(minWidth: 154, minHeight: 22)
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
        .foregroundStyle(
            usesProminentPrimaryControl
                ? Color.Theme.accentForeground
                : Color.Theme.textPrimary
        )
        .glassEffect(
            usesProminentPrimaryControl
                ? .regular.interactive().tint(phaseColor)
                : .regular.interactive(),
            in: .capsule
        )
        .accessibilityLabel(primaryAccessibilityLabel)
    }

    /// Start, next-phase, and resume use the accent tint; pause stays neutral.
    private var usesProminentPrimaryControl: Bool {
        !timer.isSessionActive || timer.isWaitingForManualStart || !timer.isRunning
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
        } else if timer.isRunning {
            HStack(spacing: 10) {
                Text("Pause")
                    .font(.headline)
                Image(systemName: "pause.fill")
                    .font(.subheadline.weight(.semibold))
            }
        } else {
            HStack(spacing: 10) {
                Text("Resume")
                    .font(.headline)
                Image(systemName: "play.fill")
                    .font(.subheadline.weight(.semibold))
            }
        }
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
    return FocusTimer(
        settings: settings,
        feedback: NoOpFocusFeedbackHandler()
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
