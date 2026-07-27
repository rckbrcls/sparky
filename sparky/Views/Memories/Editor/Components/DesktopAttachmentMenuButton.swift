#if os(macOS)

import AppKit
import SwiftUI

struct DesktopAttachmentMenuButton: NSViewRepresentable {
    let supportsCameraCapture: Bool
    let supportsMicrophoneRecord: Bool
    let onAddPhoto: () -> Void
    let onAddCamera: () -> Void
    let onAddLink: () -> Void
    let onAddAudio: () -> Void
    let onAddFile: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(actions: actions)
    }

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(frame: .zero)
        button.title = ""
        button.imagePosition = .noImage
        button.isBordered = false
        button.setButtonType(.momentaryPushIn)
        button.target = context.coordinator
        button.action = #selector(Coordinator.presentMenu(_:))
        button.toolTip = "Add Media"
        button.setAccessibilityLabel("Add Media")
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.update(actions: actions)
        button.target = context.coordinator
        button.action = #selector(Coordinator.presentMenu(_:))
    }

    private var actions: Actions {
        Actions(
            supportsCameraCapture: supportsCameraCapture,
            supportsMicrophoneRecord: supportsMicrophoneRecord,
            onAddPhoto: onAddPhoto,
            onAddCamera: onAddCamera,
            onAddLink: onAddLink,
            onAddAudio: onAddAudio,
            onAddFile: onAddFile
        )
    }

    struct Actions {
        let supportsCameraCapture: Bool
        let supportsMicrophoneRecord: Bool
        let onAddPhoto: () -> Void
        let onAddCamera: () -> Void
        let onAddLink: () -> Void
        let onAddAudio: () -> Void
        let onAddFile: () -> Void
    }

    final class Coordinator: NSObject {
        private var actions: Actions

        init(actions: Actions) {
            self.actions = actions
        }

        func update(actions: Actions) {
            self.actions = actions
        }

        @objc func presentMenu(_ sender: NSButton) {
            let menu = NSMenu()
            menu.autoenablesItems = false
            menu.addItem(
                item(
                    title: "Library",
                    systemImage: "photo",
                    action: #selector(addPhoto)
                )
            )

            if actions.supportsCameraCapture {
                menu.addItem(
                    item(
                        title: "Camera",
                        systemImage: "camera",
                        action: #selector(addCamera)
                    )
                )
            }

            menu.addItem(
                item(
                    title: "Link",
                    systemImage: "link",
                    action: #selector(addLink)
                )
            )

            if actions.supportsMicrophoneRecord {
                menu.addItem(
                    item(
                        title: "Audio",
                        systemImage: "mic",
                        action: #selector(addAudio)
                    )
                )
            }

            menu.addItem(
                item(
                    title: "File",
                    systemImage: "doc",
                    action: #selector(addFile)
                )
            )

            menu.popUp(
                positioning: nil,
                at: NSPoint(x: 0, y: sender.bounds.minY),
                in: sender
            )
        }

        private func item(
            title: String,
            systemImage: String,
            action: Selector
        ) -> NSMenuItem {
            let menuItem = NSMenuItem(
                title: title,
                action: action,
                keyEquivalent: ""
            )
            menuItem.target = self
            menuItem.image = NSImage(
                systemSymbolName: systemImage,
                accessibilityDescription: title
            )
            menuItem.isEnabled = true
            return menuItem
        }

        @objc private func addPhoto() {
            actions.onAddPhoto()
        }

        @objc private func addCamera() {
            actions.onAddCamera()
        }

        @objc private func addLink() {
            actions.onAddLink()
        }

        @objc private func addAudio() {
            actions.onAddAudio()
        }

        @objc private func addFile() {
            actions.onAddFile()
        }
    }
}

#endif
