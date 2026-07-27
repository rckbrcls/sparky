//
//  View+ToolbarItemStyle.swift
//  sparky
//

import SwiftUI

extension View {
    func neutralToolbarItemStyle(
        _ color: Color = Color.Theme.textPrimary
    ) -> some View {
        self
            .foregroundStyle(color)
            .tint(color)
    }

    func confirmationToolbarItemStyle() -> some View {
        self
            .foregroundStyle(Color.accentColor)
            .tint(Color.accentColor)
    }
}
