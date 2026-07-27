//
//  CalendarEmptyPeriodButtonStyle.swift
//  sparky
//
//  Press feedback for the calendar period quick-add button.
//

import SwiftUI

struct CalendarEmptyPeriodButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
