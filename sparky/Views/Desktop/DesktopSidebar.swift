#if os(macOS)
//
//  DesktopSidebar.swift
//  sparky
//

import SwiftUI

struct DesktopSidebar: View {
    @Binding var selection: DesktopSection

    var body: some View {
        List(selection: $selection) {
            ForEach(DesktopSection.allCases) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
                    .accessibilityLabel(section.title)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Sparky")
    }
}

#endif
