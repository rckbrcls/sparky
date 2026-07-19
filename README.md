# Sparky

> Status: Active native Apple app for iPhone and Mac.

Sparky is a local-first iPhone + Mac app for capturing memories, reminders, tasks, notes, links, audio, files, and location-aware prompts. It is designed as a private second brain: the user's content is stored on device, organized into hierarchical areas called Minds, and surfaced through calendar, timeline, search, filters, notifications, and geofence triggers.

The repository is a single Xcode project. It is not a backend, web app, CLI, monorepo, Swift package, or multi-service system.

## What Sparky Solves

Sparky gives users a private place to capture things they do not want to forget and connect them to time, place, context, and supporting material.

Core goals:

- Capture memories quickly without requiring an account or custom backend.
- Organize memories into Minds, tags, calendar views, and filters.
- Support actionable memories through checklists, completion state, reminders, and recurring schedules.
- Attach local material such as photos, audio recordings, files, and links.
- Keep import, export, and privacy concerns visible in the product and codebase.

## Main Features

- Memories: title, note/body, status, pinning, due date, checklist items, attachments, completion history, and trigger configuration.
- Minds: hierarchical organization units with color, icon, sort order, default mind support, and virtual All/Limbo views.
- Tags: lightweight classification records with display colors.
- Timeline and calendar: calendar, day, month, and period views for browsing memories over time.
- Scheduled triggers: one-time, recurring, weekday-mask, all-day, and interval-based notification scheduling.
- Location triggers: geofence-based reminders for arrival or departure from a selected place.
- Attachments: photos, links, audio recordings, and files stored in the app's local Application Support area.
- Import/export: JSON backup/restore through `SparkyExportFormat` version `2.0`, plus iCalendar export for scheduled memories.
- Settings: theme selection, app icon selection, data management, attachment cache clearing, onboarding reset, and app info.
- Onboarding: guided permission setup for notifications, location, microphone, and camera.

## Technology Stack

| Area | Technology |
| --- | --- |
| App platform | Native iOS + macOS (shared source code) |
| UI | SwiftUI |
| Persistence | SwiftData |
| State and reactivity | `ObservableObject`, `@Published`, Combine, async/await |
| Notifications | UserNotifications |
| Location | CoreLocation, MapKit |
| Attachments | FileManager, PhotosUI, AVFoundation, UniformTypeIdentifiers |
| Link previews | LinkPresentation |
| Testing | Swift Testing for unit tests, XCTest for generated UI tests |
| Project system | Xcode project (`sparky.xcodeproj`) |

No package manager files, Docker configuration, Makefile, CI workflow, backend service, or server deployment configuration were identified in the current repository.

## Architecture Overview

Sparky follows an MVVM + Services + Executors structure with `AppEnvironment` as the dependency container.

- `sparky/sparkyApp.swift` creates `AppEnvironment`, injects the SwiftData model container, wires the theme manager, and bootstraps the app.
- `sparky/AppEnvironment.swift` owns long-lived services and trigger executors.
- `sparky/Data/DataController.swift` configures SwiftData, owns the main `ModelContext`, and seeds preview data.
- `sparky/Services/MemoryService.swift` owns memory CRUD, filtering, refresh, attachment replacement, and trigger synchronization.
- `sparky/Services/MindService.swift` owns Minds and Tags.
- `sparky/Executors/TriggerExecutorCoordinator.swift` coordinates scheduled and location executors.
- `sparky/Managers/MemoryAttachmentStore.swift` stores attachment payloads outside SwiftData.
- `sparky/ViewModels/MemoryEditorViewModel.swift` bridges editor state, drafts, persisted models, and trigger configuration.
- `sparky/Views/` contains the Calendar, Mind, Me/Settings, onboarding, memory editor, map, and shared UI surfaces.

See [`docs/architecture.md`](docs/architecture.md) for the full technical walkthrough.

## Project Structure

```text
sparky/
├── sparky.xcodeproj/              # Xcode project with iOS/Mac app and test targets
├── sparky/                        # Shared app source (plus iOS entry/shell)
│   ├── sparkyApp.swift            # iOS app entry point
│   ├── AppEnvironment.swift       # Dependency container and bootstrap owner
│   ├── ContentView.swift          # Root tab/navigation shell
│   ├── Data/                      # SwiftData container
│   ├── Executors/                 # Scheduled notification and location execution
│   ├── Managers/                  # Theme, app icon, and attachment file storage
│   ├── Model/                     # SwiftData models, drafts, triggers, recurrence, export types
│   ├── Services/                  # Memory, mind, import/export, and bulk action services
│   ├── Settings/                  # UserDefaults-backed app settings
│   ├── Utilities/                 # Small helpers and extensions
│   ├── ViewModels/                # Screen/editor view models
│   └── Views/                     # Shared SwiftUI screens + Desktop shell
├── sparkyMac/                     # Thin macOS app entry
├── sparkyTests/                   # Swift Testing unit tests
├── sparkyUITests/                 # XCTest UI test targets generated by Xcode
├── docs/                          # Project documentation
├── screenshots/                   # Screenshot checklist and future visual assets
├── AppStoreMetadata.md            # App Store copy and submission notes
└── CLAUDE.md                      # Agent-focused technical guide
```

## Requirements

- macOS with Xcode installed.
- Xcode with iOS 26 and macOS 26 SDKs.
- An iOS simulator/device and/or the `My Mac` destination.
- Apple Developer signing setup for archive, TestFlight, or App Store submission.

No project-specific environment variables were identified.

## Local Development

Open the project in Xcode:

```text
sparky/sparky.xcodeproj
```

Use `sparky` for iPhone and `sparkyMac` for Mac. The project has four targets:

- `sparky`: iOS app (`polterware.sparky`).
- `sparkyMac`: macOS app (`polterware.sparky.mac`).
- `sparkyTests`: unit tests using Swift Testing (`import Testing`, `@Test`, `#expect`).
- `sparkyUITests`: generated UI test target using XCTest.

This documentation refresh did not execute build, run, simulator, or `xcodebuild` commands. The repository does not contain shell scripts or package manager scripts for local workflow.

## Build and Test Notes

Build and test flows are expected to happen through Xcode or through equivalent `xcodebuild` invocations in an environment where running builds is allowed.

Important project settings detected in `sparky.xcodeproj/project.pbxproj`:

- Bundle identifier: `polterware.sparky`
- Marketing version: `1.0`
- Current project version: `1`
- Deployment targets: iOS `26.0`, macOS `26.0`
- Development team: `VCF3DS6BTV`
- Default actor isolation: `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
- Background mode: location

## Privacy and Security Summary

Sparky has no custom backend, account system, authentication layer, analytics SDK, or tracking configuration in this repository. User-created content is stored locally through SwiftData and file-system attachment storage.

Important caveat: the app uses Apple/system frameworks such as MapKit, CoreLocation, and LinkPresentation. Features like location search, maps, reverse geocoding, and link metadata may rely on Apple or destination network services when used. The app should not be documented as having "zero network calls" unless that claim is revalidated at the platform behavior level.

See [`docs/security.md`](docs/security.md) for permissions, Privacy Manifest details, and local data risks.

## Documentation

- [`docs/index.md`](docs/index.md): documentation map.
- [`docs/getting-started.md`](docs/getting-started.md): setup and local workflow.
- [`docs/architecture.md`](docs/architecture.md): architecture and data flow.
- [`docs/development.md`](docs/development.md): development conventions.
- [`docs/database.md`](docs/database.md): SwiftData models, import/export, and attachment storage.
- [`docs/security.md`](docs/security.md): privacy, permissions, and data handling.
- [`docs/deployment.md`](docs/deployment.md): App Store release notes.
- [`docs/troubleshooting.md`](docs/troubleshooting.md): common development and runtime issues.

## Current Status

The repository contains a working native iOS app codebase, active app metadata, screenshot planning, unit tests, UI test targets, and project-specific technical guidance. Some release steps remain external to the repository, including Apple Developer configuration, App Store Connect setup, final screenshots, and TestFlight validation.

## License

No license file was identified in the current repository. Add a `LICENSE` file before distributing the code publicly or accepting external contributions.
