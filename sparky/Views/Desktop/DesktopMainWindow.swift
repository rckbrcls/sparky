#if os(macOS)

import AppKit
import Combine
import SwiftUI

@MainActor
enum DesktopMainWindow {
    static let sceneID = "main"
    static let markerID = NSUserInterfaceItemIdentifier("sparky-main")

    private static let logsWindowID = "remote-sync-logs"
    private static var openWindowAction: OpenWindowAction?

    static func register(_ openWindow: OpenWindowAction) {
        openWindowAction = openWindow
    }

    /// Brings the main window forward. If none exists yet, waits one turn so a cold
    /// launch can create it, then opens the main scene.
    static func reveal() {
        NSApp.activate()
        if let window = existing() {
            orderFront(window)
            return
        }

        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                NSApp.activate()
                if let window = existing() {
                    orderFront(window)
                } else {
                    openWindowAction?(id: sceneID)
                }
            }
        }
    }

    static func revealOnNotification(_ environment: AppEnvironment) -> AnyCancellable {
        Publishers.Merge(
            environment.$pendingMemoryOpenRequest.map { $0 != nil },
            environment.$pendingFocusOpenRequest.map { $0 != nil }
        )
        .filter { $0 }
        .sink { _ in
            reveal()
        }
    }

    private static func existing() -> NSWindow? {
        let marked = NSApp.windows.filter { $0.identifier == markerID }
        if let window = preferred(among: marked) {
            return window
        }
        return preferred(among: NSApp.windows.filter(isUnmarkedMainCandidate))
    }

    private static func preferred(among windows: [NSWindow]) -> NSWindow? {
        if let key = windows.first(where: \.isKeyWindow) {
            return key
        }
        if let visible = windows.first(where: { $0.isVisible && !$0.isMiniaturized }) {
            return visible
        }
        if let miniaturized = windows.first(where: \.isMiniaturized) {
            return miniaturized
        }
        return windows.first
    }

    private static func orderFront(_ window: NSWindow) {
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
    }

    private static func isUnmarkedMainCandidate(_ window: NSWindow) -> Bool {
        guard window.identifier != markerID else { return false }
        guard window.parent == nil else { return false }
        guard window.canBecomeMain, window.level == .normal else { return false }
        guard !window.styleMask.contains(.utilityWindow) else { return false }
        if isLogsWindow(window) || isSettingsWindow(window) { return false }
        return true
    }

    private static func isLogsWindow(_ window: NSWindow) -> Bool {
        window.identifier?.rawValue == logsWindowID || window.title == "Logs"
    }

    private static func isSettingsWindow(_ window: NSWindow) -> Bool {
        let identifier = window.identifier?.rawValue ?? ""
        if identifier.localizedCaseInsensitiveContains("settings") {
            return true
        }
        return window.frameAutosaveName.localizedCaseInsensitiveContains("settings")
    }
}

struct DesktopMainWindowMarker: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        DesktopMainWindowMarkingRepresentable()
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                DesktopMainWindow.register(openWindow)
            }
    }
}

private struct DesktopMainWindowMarkingRepresentable: NSViewRepresentable {
    func makeNSView(context: Context) -> DesktopMainWindowMarkingView {
        DesktopMainWindowMarkingView()
    }

    func updateNSView(_ nsView: DesktopMainWindowMarkingView, context: Context) {
        nsView.window?.identifier = DesktopMainWindow.markerID
    }
}

private final class DesktopMainWindowMarkingView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.identifier = DesktopMainWindow.markerID
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

#endif
