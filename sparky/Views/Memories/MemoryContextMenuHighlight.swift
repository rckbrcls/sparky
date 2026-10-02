#if os(macOS)
import AppKit
import SwiftUI

struct MemoryContextMenuHighlight: NSViewRepresentable {
    func makeNSView(context: Context) -> HighlightView {
        HighlightView()
    }

    func updateNSView(_ nsView: HighlightView, context: Context) {}

    final class HighlightView: NSView {
        private weak var trackedMenu: NSMenu?

        init() {
            super.init(frame: .zero)
            wantsLayer = true
            layer?.cornerRadius = 24
            NotificationCenter.default.addObserver(
                self, selector: #selector(menuDidBeginTracking(_:)),
                name: NSMenu.didBeginTrackingNotification, object: nil
            )
            NotificationCenter.default.addObserver(
                self, selector: #selector(menuDidEndTracking(_:)),
                name: NSMenu.didEndTrackingNotification, object: nil
            )
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        @objc private func menuDidBeginTracking(_ notification: Notification) {
            guard trackedMenu == nil,
                  let menu = notification.object as? NSMenu,
                  menu.supermenu == nil,
                  let window, window == NSApp.keyWindow,
                  bounds.contains(convert(window.mouseLocationOutsideOfEventStream, from: nil))
            else { return }

            trackedMenu = menu
            effectiveAppearance.performAsCurrentDrawingAppearance {
                layer?.borderColor = NSColor.controlAccentColor.cgColor
            }
            layer?.borderWidth = 2
        }

        @objc private func menuDidEndTracking(_ notification: Notification) {
            guard let menu = notification.object as? NSMenu, menu === trackedMenu else { return }
            trackedMenu = nil
            layer?.borderWidth = 0
        }
    }
}
#endif
