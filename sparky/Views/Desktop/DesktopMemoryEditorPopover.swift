#if os(macOS)

import SwiftUI

struct DesktopMemoryEditorPopover: View {
    @EnvironmentObject private var environment: AppEnvironment

    let route: MemoryEditorRoute

    @ViewBuilder
    var body: some View {
        if case let .create(mind, template) = route.mode {
            MemoryEditorView(
                environment: environment,
                mode: .create(mind: mind, template: template),
                initialTitle: route.initialTitle,
                initialScheduleConfig: route.initialScheduleConfig,
                presentationStyle: .desktopPopover
            )
            .frame(width: 480, height: 620)
        }
    }
}

extension View {
    func desktopMemoryEditorPopover(
        item: Binding<MemoryEditorRoute?>,
        arrowEdge: Edge? = nil
    ) -> some View {
        popover(
            item: item,
            attachmentAnchor: .rect(.bounds),
            arrowEdge: arrowEdge
        ) { route in
            DesktopMemoryEditorPopover(route: route)
        }
    }
}

#endif
