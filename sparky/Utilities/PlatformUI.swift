//
//  PlatformUI.swift
//  sparky
//
//  Thin cross-platform UI helpers (haptics, images, open URL).
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

enum PlatformHaptics {
    static func impactMedium() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }
}

enum PlatformOpen {
    static func open(_ url: URL) {
        #if os(iOS)
        UIApplication.shared.open(url)
        #elseif os(macOS)
        NSWorkspace.shared.open(url)
        #endif
    }

    static func resignFirstResponder() {
        #if os(iOS)
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
        #endif
    }
}

enum PlatformImageFactory {
    static func image(data: Data) -> Image? {
        #if canImport(UIKit) && os(iOS)
        guard let ui = UIImage(data: data) else { return nil }
        return Image(uiImage: ui)
        #elseif canImport(AppKit)
        guard let ns = NSImage(data: data) else { return nil }
        return Image(nsImage: ns)
        #else
        return nil
        #endif
    }
}

/// Shared geofence limit constant (execution is iOS-only; limit still used in copy).
enum LocationGeofenceLimits {
    static let maxGeofences = 20
}

extension View {
    @ViewBuilder
    func hidePhoneNavigationBar() -> some View {
        #if os(iOS)
        self.toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }

    @ViewBuilder
    func clearPhoneNavigationBarBackground() -> some View {
        #if os(iOS)
        self.toolbarBackground(.clear, for: .navigationBar)
        #else
        self
        #endif
    }

    @ViewBuilder
    func phonePageTabStyle() -> some View {
        #if os(iOS)
        self.tabViewStyle(.page(indexDisplayMode: .never))
        #else
        self.tabViewStyle(.automatic)
        #endif
    }

    @ViewBuilder
    func inlinePhoneNavigationTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    @ViewBuilder
    func platformCover<Content: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        #if os(iOS)
        self.fullScreenCover(isPresented: isPresented, onDismiss: onDismiss, content: content)
        #else
        self.popover(
            isPresented: isPresented,
            attachmentAnchor: .rect(.bounds),
            content: content
        )
        #endif
    }

    @ViewBuilder
    func platformCover<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        #if os(iOS)
        self.fullScreenCover(item: item, onDismiss: onDismiss, content: content)
        #else
        self.popover(
            item: item,
            attachmentAnchor: .rect(.bounds),
            content: content
        )
        #endif
    }

    @ViewBuilder
    func platformSheet<Content: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        #if os(iOS)
        self.sheet(isPresented: isPresented, onDismiss: onDismiss, content: content)
        #else
        self.popover(
            isPresented: isPresented,
            attachmentAnchor: .rect(.bounds),
            content: content
        )
        #endif
    }

    @ViewBuilder
    func platformSheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        #if os(iOS)
        self.sheet(item: item, onDismiss: onDismiss, content: content)
        #else
        self.popover(
            item: item,
            attachmentAnchor: .rect(.bounds),
            content: content
        )
        #endif
    }

    @ViewBuilder
    func macPopoverFrame(width: CGFloat, height: CGFloat) -> some View {
        #if os(macOS)
        self.frame(width: width, height: height)
        #else
        self
        #endif
    }

    @ViewBuilder
    func compactPhoneListSections() -> some View {
        #if os(iOS)
        self.listSectionSpacing(.compact)
        #else
        self
        #endif
    }
}

/// Scrolling container for settings panes. macOS uses a plain ScrollView because the
/// system List re-creates a stacked scroll-edge blur under the toolbar on every tab switch.
struct SettingsPane<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        #if os(macOS)
        ScrollView {
            VStack(spacing: 12) {
                content
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 28)
            .padding(.top, 20)
            .padding(.bottom, 44)
        }
        .background(Color.Theme.secondaryBackground.ignoresSafeArea())
        #else
        List {
            Section {
                content
            }
            .listRowInsets(.init(top: 6, leading: 20, bottom: 6, trailing: 20))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
        .compactPhoneListSections()
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.Theme.secondaryBackground.ignoresSafeArea())
        #endif
    }
}
