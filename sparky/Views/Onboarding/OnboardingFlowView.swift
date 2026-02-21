//
//  OnboardingFlowView.swift
//  sparky
//
//  Created by GPT-5 Codex on 07/11/25.
//

import SwiftUI
import Combine
import CoreLocation
import AVFoundation
// MARK: - Step Definition

private enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome, notifications, location, microphone, camera

    var id: Int { rawValue }
    var next: OnboardingStep? { OnboardingStep(rawValue: rawValue + 1) }
    var isLast: Bool { next == nil }

    var icon: String? {
        switch self {
        case .welcome: return nil
        case .notifications: return "bell.badge.fill"
        case .location: return "location.fill"
        case .microphone: return "mic.fill"
        case .camera: return "camera.fill"
        }
    }

    var accentColor: Color {
        .accentColor
    }

    var title: String {
        switch self {
        case .welcome: return "Welcome to Sparky"
        case .notifications: return "Stay in the Loop"
        case .location: return "Places That Matter"
        case .microphone: return "Capture Your Voice"
        case .camera: return "Snap the Moment"
        }
    }

    var message: String {
        switch self {
        case .welcome:
            return "Your personal memory companion. Let's set up a few things so Sparky can work its magic."
        case .notifications:
            return "Get gentle reminders for your memories exactly when they matter most."
        case .location:
            return "Trigger memories automatically when you arrive at or leave a meaningful place."
        case .microphone:
            return "Record voice notes and audio memories hands-free."
        case .camera:
            return "Capture photos directly within your memories."
        }
    }

    var buttonLabel: String {
        switch self {
        case .welcome: return "Get Started"
        case .notifications: return "Allow Notifications"
        case .location: return "Allow Location"
        case .microphone: return "Allow Microphone"
        case .camera: return "Allow Camera"
        }
    }
}

// MARK: - Page Indicator

private struct StepPageIndicator: View {
    let steps: [OnboardingStep]
    let current: OnboardingStep

    var body: some View {
        HStack(spacing: 8) {
            ForEach(steps) { step in
                Capsule()
                    .fill(step == current ? Color.Theme.textPrimary : Color.Theme.textTertiary.opacity(0.4))
                    .frame(width: step == current ? 28 : 8, height: 8)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: current)
    }
}

// MARK: - Hero Icon

private struct StepHeroView: View {
    let step: OnboardingStep

    var body: some View {
        if let icon = step.icon {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 120, height: 120)
                .glassEffect(.regular.tint(Color.accentColor.opacity(0.15)), in: .circle)
        } else {
            Image("memory-character")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 160, height: 160)
        }
    }
}

// MARK: - Text Content

private struct StepContentView: View {
    let step: OnboardingStep

    var body: some View {
        VStack(spacing: 12) {
            Text(step.title)
                .appLargeTitleStyle()

            Text(step.message)
                .font(.body)
                .foregroundStyle(Color.Theme.textSecondary)
                .lineSpacing(4)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}

// MARK: - Actions

private struct StepActionsView: View {
    let step: OnboardingStep
    let isProcessing: Bool
    let onAllow: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Button(action: onAllow) {
                Group {
                    if isProcessing {
                        ProgressView()
                            .tint(Color.Theme.accentForeground)
                    } else {
                        Text(step.buttonLabel)
                    }
                }
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.Theme.accentForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .disabled(isProcessing)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }
}

// MARK: - Main View

struct OnboardingFlowView: View {
    let environment: AppEnvironment
    let onFinish: () -> Void

    @State private var currentStep: OnboardingStep = .welcome
    @State private var isProcessing = false

    var body: some View {
        Color.Theme.background
            .ignoresSafeArea()
            .overlay {
                VStack(spacing: 24) {
                    StepPageIndicator(
                        steps: OnboardingStep.allCases,
                        current: currentStep
                    )
                    .padding(.top, 24)

                    Spacer()

                    StepHeroView(step: currentStep)
                        .id(currentStep)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))

                    StepContentView(step: currentStep)
                        .id(currentStep)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            )
                        )

                    Spacer()

                    StepActionsView(
                        step: currentStep,
                        isProcessing: isProcessing,
                        onAllow: allowAction
                    )
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentStep)
    }

    private func allowAction() {
        switch currentStep {
        case .welcome:
            advance()
        case .notifications:
            Task {
                isProcessing = true
                await environment.triggerExecutorCoordinator.scheduled.requestAuthorization(force: true)
                isProcessing = false
                advance()
            }
        case .location:
            requestLocationPermission()
        case .microphone:
            Task {
                isProcessing = true
                let status = AVAudioApplication.shared.recordPermission
                if status == .undetermined {
                    _ = await AVAudioApplication.requestRecordPermission()
                }
                isProcessing = false
                advance()
            }
        case .camera:
            Task {
                isProcessing = true
                let status = AVCaptureDevice.authorizationStatus(for: .video)
                if status == .notDetermined {
                    _ = await AVCaptureDevice.requestAccess(for: .video)
                }
                isProcessing = false
                advance()
            }
        }
    }

    private func requestLocationPermission() {
        let location = environment.triggerExecutorCoordinator.location
        let currentStatus = location.authorizationStatus

        if currentStatus == .notDetermined {
            isProcessing = true
            location.requestAuthorization(always: true)

            var cancellable: AnyCancellable?
            cancellable = location.$authorizationStatus
                .dropFirst()
                .filter { $0 != .notDetermined }
                .first()
                .receive(on: DispatchQueue.main)
                .sink { [self] _ in
                    isProcessing = false
                    advance()
                    _ = cancellable
                }
        } else {
            advance()
        }
    }

    private func advance() {
        guard let next = currentStep.next else {
            onFinish()
            return
        }
        currentStep = next
    }
}

#Preview {
    OnboardingFlowView(
        environment: AppEnvironment(dataController: .preview),
        onFinish: {}
    )
}
