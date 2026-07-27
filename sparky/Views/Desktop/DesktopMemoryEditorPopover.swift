#if os(macOS)

import SwiftUI

struct DesktopMemoryEditorPopover: View {
    @EnvironmentObject private var environment: AppEnvironment

    let route: MemoryEditorRoute

    @ViewBuilder
    var body: some View {
        Group {
            switch route.mode {
            case let .create(mind, template):
                MemoryEditorView(
                    environment: environment,
                    mode: .create(mind: mind, template: template),
                    initialTitle: route.initialTitle,
                    initialScheduleConfig: route.initialScheduleConfig,
                    presentationStyle: .desktopPopover
                )
            case let .preview(memory):
                MemoryEditorView(
                    environment: environment,
                    mode: .edit(memory: memory),
                    startEditing: false,
                    presentationStyle: .desktopPopover
                )
            case let .edit(memory):
                MemoryEditorView(
                    environment: environment,
                    mode: .edit(memory: memory),
                    startEditing: route.startEditing,
                    presentationStyle: .desktopPopover
                )
            }
        }
        .frame(width: 480, height: 620)
    }
}

extension View {
    func desktopMemoryEditorPopover(
        item: Binding<MemoryEditorRoute?>,
        arrowEdge: Edge? = .bottom
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
