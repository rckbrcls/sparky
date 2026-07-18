# Getting Started

Sparky is a native iOS app managed by a single Xcode project at `sparky.xcodeproj`. There is no Swift Package Manager manifest, CocoaPods setup, Makefile, Docker configuration, or local script runner in the repository.

## Requirements

- macOS with Xcode installed.
- Xcode/iOS SDK support for the configured iOS `26.0` deployment target.
- An iOS simulator or physical iOS device.
- Apple Developer signing setup only when archiving, installing on a physical device, using TestFlight, or submitting to App Store Connect.

No project-specific environment variables were identified.

## Open the Project

Open this file in Xcode:

```text
sparky.xcodeproj
```

Use the `sparky` scheme for app development.

## Targets

| Target | Purpose | Test framework |
| --- | --- | --- |
| `sparky` | Main native iOS app | Not applicable |
| `sparkyTests` | Unit tests for domain and service behavior | Swift Testing |
| `sparkyUITests` | Generated UI test target | XCTest |

The unit test target includes tests around memory CRUD, timeline filtering, schedule recurrence, location triggers, Focus, and import/export.

## Local Workflow

1. Open `sparky.xcodeproj` in Xcode.
2. Select the `sparky` scheme.
3. Choose a simulator or a signed physical device.
4. Use Xcode for app launches, previews, archives, and tests.

This documentation pass did not execute build, run, simulator, or `xcodebuild` commands. If you add command-line workflow documentation later, verify it in an environment where executing those commands is allowed.

## Important Project Settings

The following settings were detected in `sparky.xcodeproj/project.pbxproj`:

- `PRODUCT_BUNDLE_IDENTIFIER = polterware.sparky`
- `MARKETING_VERSION = 1.0`
- `CURRENT_PROJECT_VERSION = 1`
- `IPHONEOS_DEPLOYMENT_TARGET = 26.0`
- `DEVELOPMENT_TEAM = VCF3DS6BTV`
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
- `INFOPLIST_KEY_UIBackgroundModes = location`

The app target also declares usage descriptions for camera, location, microphone, and photo library access.

## Dependencies

Sparky currently depends on Apple frameworks imported directly in Swift source:

- SwiftUI
- SwiftData
- Combine
- UserNotifications
- CoreLocation
- MapKit
- LinkPresentation
- AVFoundation
- PhotosUI
- UniformTypeIdentifiers

No third-party packages were identified in the current repository.

## First Files To Read

- `sparky/sparkyApp.swift`: app entry point and environment injection.
- `sparky/AppEnvironment.swift`: dependency container and bootstrap flow.
- `sparky/ContentView.swift`: root tabs, editor presentations, onboarding, and notification-open handling.
- `sparky/Data/DataController.swift`: SwiftData schema and contexts.
- `sparky/Services/MemoryService.swift`: memory lifecycle and trigger synchronization.
- `sparky/ViewModels/MemoryEditorViewModel.swift`: editor state and draft/model conversion.

## Common Setup Notes

- If the project fails to open, confirm that `sparky.xcodeproj` is opened directly rather than an absent workspace or package.
- If signing fails, check the Apple Developer team and bundle identifier in Xcode.
- If simulator support is missing, install an iOS runtime compatible with the deployment target.
- If tests fail to compile after adding new tests, confirm whether the target uses Swift Testing or XCTest before copying patterns.
