//
//  FocusTimerRing.swift
//  sparky
//

import SwiftUI

struct FocusTimerRing: View {
    @Binding var selectedMinutes: Int

    let countdownSeconds: Int?
    let phase: FocusPhase
    let allowsAdjustment: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDragging = false
    @ScaledMetric(relativeTo: .largeTitle) private var timerFontSize: CGFloat = 62

    private static let interactiveRange = FocusRecipe.workRange

    private var displaySeconds: Int {
        max(0, countdownSeconds ?? selectedMinutes * 60)
    }

    private var ringProgress: CGFloat {
        let seconds = min(displaySeconds, Self.interactiveRange.upperBound * 60)
        return CGFloat(seconds) / CGFloat(Self.interactiveRange.upperBound * 60)
    }

    private var formattedTime: String {
        let minutes = displaySeconds / 60
        let seconds = displaySeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var ringColor: Color {
        phase == .break ? Color.Theme.success : Color.accentColor
    }

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let ringGeometry = RingGeometry(side: side, progress: ringProgress)

            ZStack(alignment: .topLeading) {
                Circle()
                    .strokeBorder(
                        Color.Theme.tertiaryBackground,
                        lineWidth: ringGeometry.lineWidth
                    )
                    .frame(width: side, height: side)

                progressTicks(geometry: ringGeometry)

                progressSurface(geometry: ringGeometry)

                Text(formattedTime)
                    .font(
                        .system(
                            size: min(timerFontSize, side * 0.22),
                            weight: .medium,
                            design: .serif
                        )
                    )
                    .monospacedDigit()
                    .foregroundStyle(Color.Theme.textPrimary)
                    .contentTransition(reduceMotion ? .identity : .numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .fixedSize(horizontal: true, vertical: true)
                    .position(ringGeometry.center)
                    .accessibilityHidden(true)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Circle())
            .highPriorityGesture(
                dragGesture(in: CGSize(width: side, height: side)),
                including: allowsAdjustment ? .all : .none
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(allowsAdjustment ? "Focus duration" : "Focus time remaining")
        .accessibilityValue(formattedTime)
        .accessibilityAdjustableAction { direction in
            guard allowsAdjustment else { return }
            switch direction {
            case .increment:
                selectedMinutes = min(Self.interactiveRange.upperBound, selectedMinutes + 1)
            case .decrement:
                selectedMinutes = max(Self.interactiveRange.lowerBound, selectedMinutes - 1)
            @unknown default:
                break
            }
        }
        .sensoryFeedback(.selection, trigger: selectedMinutes) { _, _ in
            allowsAdjustment && isDragging
        }
    }

    @ViewBuilder
    private func progressSurface(geometry: RingGeometry) -> some View {
        if #available(iOS 26.0, *) {
            ZStack(alignment: .topLeading) {
                Color.clear
                    .frame(width: geometry.side, height: geometry.side)
                    .glassEffect(.regular.tint(ringColor), in: .circle)
                    .mask(progressMask(geometry: geometry))

                Color.clear
                    .frame(
                        width: geometry.knobDiameter,
                        height: geometry.knobDiameter
                    )
                    .glassEffect(
                        .regular.tint(ringColor).interactive(allowsAdjustment),
                        in: .circle
                    )
                    .overlay {
                        Circle()
                            .stroke(Color.Theme.elementBorder.opacity(0.72), lineWidth: 1)
                    }
                    .position(geometry.knobCenter)
            }
            .frame(width: geometry.side, height: geometry.side)
        } else {
            ZStack(alignment: .topLeading) {
                progressArc(geometry: geometry)
                    .fill(ringColor)

                Circle()
                    .fill(ringColor)
                    .frame(
                        width: geometry.knobDiameter,
                        height: geometry.knobDiameter
                    )
                    .overlay {
                        Circle()
                            .stroke(Color.Theme.elementBorder.opacity(0.72), lineWidth: 1)
                    }
                    .position(geometry.knobCenter)
            }
            .frame(width: geometry.side, height: geometry.side)
        }
    }

    private func progressTicks(geometry: RingGeometry) -> some View {
        return ZStack {
            ForEach(Self.interactiveRange, id: \.self) { tick in
                let fraction = CGFloat(tick) / CGFloat(Self.interactiveRange.upperBound)
                Capsule(style: .continuous)
                    .fill(
                        Color.Theme.accentForeground.opacity(
                            fraction <= ringProgress ? 0.28 : 0
                        )
                    )
                    .frame(width: 1.25, height: geometry.lineWidth * 0.34)
                    .offset(y: -geometry.radius)
                    .rotationEffect(.degrees(Double(fraction) * 360))
            }
        }
        .frame(width: geometry.side, height: geometry.side)
        .accessibilityHidden(true)
    }

    private func progressArc(geometry: RingGeometry) -> FocusProgressArcShape {
        FocusProgressArcShape(
            progress: ringProgress,
            radius: geometry.radius,
            lineWidth: geometry.lineWidth
        )
    }

    private func progressMask(geometry: RingGeometry) -> some View {
        progressArc(geometry: geometry)
            .fill(.white)
            .frame(width: geometry.side, height: geometry.side)
    }

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard allowsAdjustment else { return }
                isDragging = true
                let nextMinutes = minutes(from: value.location, in: size)
                if nextMinutes != selectedMinutes {
                    selectedMinutes = nextMinutes
                }
            }
            .onEnded { _ in
                isDragging = false
            }
    }

    private func minutes(from location: CGPoint, in size: CGSize) -> Int {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y
        var angle = atan2(dy, dx) + .pi / 2
        if angle < 0 { angle += 2 * .pi }

        let fraction = angle / (2 * .pi)
        let rawMinutes = Int(
            (fraction * Double(Self.interactiveRange.upperBound)).rounded()
        )
        let minutes = rawMinutes == 0 ? Self.interactiveRange.upperBound : rawMinutes
        return min(
            Self.interactiveRange.upperBound,
            max(Self.interactiveRange.lowerBound, minutes)
        )
    }

    private struct RingGeometry {
        let side: CGFloat
        let progress: CGFloat

        var lineWidth: CGFloat {
            max(20, side * 0.095)
        }

        var radius: CGFloat {
            max(0, (side - lineWidth) / 2)
        }

        var center: CGPoint {
            CGPoint(x: side / 2, y: side / 2)
        }

        var knobDiameter: CGFloat {
            lineWidth * 1.08
        }

        var knobCenter: CGPoint {
            CGPoint(
                x: center.x + CGFloat(cos(endAngle)) * radius,
                y: center.y + CGFloat(sin(endAngle)) * radius
            )
        }

        private var endAngle: Double {
            Double(progress) * 2 * Double.pi - Double.pi / 2
        }
    }
}

#Preview("Focus Ring · Idle") {
    @Previewable @State var minutes = 25

    FocusTimerRing(
        selectedMinutes: $minutes,
        countdownSeconds: nil,
        phase: .idle,
        allowsAdjustment: true
    )
    .frame(width: 280, height: 280)
    .padding(32)
    .background(Color.Theme.secondaryBackground)
}

#Preview("Focus Ring · Running") {
    @Previewable @State var minutes = 15

    FocusTimerRing(
        selectedMinutes: $minutes,
        countdownSeconds: 14 * 60 + 51,
        phase: .work,
        allowsAdjustment: false
    )
    .frame(width: 280, height: 280)
    .padding(32)
    .background(Color.Theme.secondaryBackground)
}

#Preview("Focus Ring · Break") {
    @Previewable @State var minutes = 5

    FocusTimerRing(
        selectedMinutes: $minutes,
        countdownSeconds: 4 * 60 + 32,
        phase: .break,
        allowsAdjustment: false
    )
    .frame(width: 280, height: 280)
    .padding(32)
    .background(Color.Theme.secondaryBackground)
}

#Preview("Focus Ring · Idle · Dark") {
    @Previewable @State var minutes = 25

    FocusTimerRing(
        selectedMinutes: $minutes,
        countdownSeconds: nil,
        phase: .idle,
        allowsAdjustment: true
    )
    .frame(width: 280, height: 280)
    .padding(32)
    .background(Color.Theme.secondaryBackground)
    .preferredColorScheme(.dark)
}
