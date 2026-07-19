//
//  PlatformCapabilities.swift
//  sparky
//
//  Runtime/compile-time capability matrix for iPhone + Mac builds.
//  See specs/003-desktop-multiplatform/contracts/platform-capability-matrix.md
//

import Foundation

struct PlatformCapabilities: Equatable, Sendable {
    var supportsTabShell: Bool
    var supportsSidebarShell: Bool
    var supportsLocationExecution: Bool
    var supportsCameraCapture: Bool
    var supportsMicrophoneRecord: Bool
    var supportsScheduledNotifications: Bool
    var supportsAlternateAppIcon: Bool
    var supportsLiveFocusWhileRunning: Bool
    var supportsFocusAfterQuit: Bool

    static var current: PlatformCapabilities {
        #if os(macOS)
        .mac
        #else
        .iPhone
        #endif
    }

    static let iPhone = PlatformCapabilities(
        supportsTabShell: true,
        supportsSidebarShell: false,
        supportsLocationExecution: true,
        supportsCameraCapture: true,
        supportsMicrophoneRecord: true,
        supportsScheduledNotifications: true,
        supportsAlternateAppIcon: true,
        supportsLiveFocusWhileRunning: true,
        supportsFocusAfterQuit: true
    )

    static let mac = PlatformCapabilities(
        supportsTabShell: false,
        supportsSidebarShell: true,
        supportsLocationExecution: false,
        supportsCameraCapture: false,
        supportsMicrophoneRecord: false,
        supportsScheduledNotifications: true,
        supportsAlternateAppIcon: false,
        supportsLiveFocusWhileRunning: true,
        supportsFocusAfterQuit: false
    )
}
