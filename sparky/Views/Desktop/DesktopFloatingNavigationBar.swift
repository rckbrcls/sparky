#if os(macOS)

import SwiftUI

struct DesktopFloatingNavigationBar: View {
    @Binding var selection: DesktopSection
    @Binding var createMemoryRoute: MemoryEditorRoute?

    let makeCreateMemoryRoute: () -> MemoryEditorRoute
    let onReselect: (DesktopSection) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hoveredSection: DesktopSection?
    @State private var isCreateHovered = false

    private let segmentWidth: CGFloat = 72
    private let navigationHeight: CGFloat = 55

    var body: some View {
        ZStack {
            navigationControl

            HStack {
                Spacer()
                createMemoryButton
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var navigationControl: some View {
        HStack(spacing: 0) {
            ForEach(DesktopSection.allCases) { section in
                Button {
                    guard selection != section else {
                        onReselect(section)
                        return
                    }

                    if reduceMotion {
                        selection = section
                    } else {
                        withAnimation(.snappy(duration: 0.24)) {
                            selection = section
                        }
                    }
                } label: {
                    VStack(spacing: 3) {
                        navigationIcon(for: section)

                        Text(section.title)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .symbolVariant(.fill)
                    .foregroundStyle(tint(for: section))
                    .frame(width: segmentWidth, height: navigationHeight)
                    .background {
                        if selection == section {
                            Capsule()
                                .fill(Color.Theme.tabSelectionBackground)
                                .padding(2)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(
                    KeyEquivalent(Character(String(sectionShortcut(for: section)))),
                    modifiers: [.command]
                )
                .help(section.title)
                .accessibilityLabel(section.title)
                .accessibilityAddTraits(selection == section ? .isSelected : [])
                .onHover { isHovered in
                    hoveredSection = isHovered ? section : nil
                }
            }
        }
        .frame(
            width: segmentWidth * CGFloat(DesktopSection.allCases.count),
            height: navigationHeight
        )
        .glassEffect(.regular.interactive(), in: .capsule)
        .contentShape(Capsule())
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.14),
            value: hoveredSection
        )
    }

    private var createMemoryButton: some View {
        Button {
            createMemoryRoute = makeCreateMemoryRoute()
        } label: {
            Image(systemName: "brain.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.Theme.accentForeground)
                .frame(width: 52, height: 52)
                .background(Color.accentColor, in: Circle())
                .overlay {
                    Circle()
                        .stroke(Color.Theme.elementBorder, lineWidth: 1)
                }
                .scaleEffect(isCreateHovered ? 1.04 : 1)
        }
        .buttonStyle(.plain)
        .keyboardShortcut("n", modifiers: [.command])
        .help("New Memory")
        .accessibilityLabel("Create new memory")
        .desktopMemoryEditorPopover(item: $createMemoryRoute)
        .onHover { isCreateHovered = $0 }
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.14),
            value: isCreateHovered
        )
    }

    @ViewBuilder
    private func navigationIcon(for section: DesktopSection) -> some View {
        if section.usesAssetIcon {
            Image(section.iconName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(height: 24)
        } else {
            Image(systemName: section.iconName)
                .font(.title3)
        }
    }

    private func tint(for section: DesktopSection) -> Color {
        if selection == section {
            return Color.Theme.textPrimary
        }

        return hoveredSection == section
            ? Color.Theme.textPrimary
            : Color.Theme.textSecondary
    }

    private func sectionShortcut(for section: DesktopSection) -> Int {
        switch section {
        case .calendar: return 1
        case .mind: return 2
        case .focus: return 3
        case .me: return 4
        }
    }
}

#endif
