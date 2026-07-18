//
//  FocusProgressArcShape.swift
//  sparky
//

import SwiftUI

struct FocusProgressArcShape: Shape {
    var progress: CGFloat
    let radius: CGFloat
    let lineWidth: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let clampedProgress = max(0, min(1, progress))
        guard clampedProgress > 0 else { return Path() }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        var centerline = Path()
        centerline.addArc(
            center: center,
            radius: max(0, radius),
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + 360 * Double(clampedProgress)),
            clockwise: false
        )

        return centerline.strokedPath(
            StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        )
    }
}
