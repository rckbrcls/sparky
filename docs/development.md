# Development

This guide documents conventions that are visible in the current Sparky codebase. It is intended for engineers extending the native iOS app, not for backend, web, or package development.

## Project Shape

Sparky is a single Xcode project with one app target and two test targets:

- `sparky`: native iOS app.
- `sparkyTests`: unit tests using Swift Testing.
- `sparkyUITests`: generated UI tests using XCTest.

No third-party package manager, script runner, backend service, or CLI workflow was identified.

## Important Compiler Setting

The Xcode project sets:

```text
SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor
```

That means types are MainActor-isolated by default. Use `nonisolated` deliberately for pure functions that must be callable outside the main actor. Existing examples include date calculation helpers in `ScheduleConfig`.

## Naming and File Organization

Observed conventions:

- Keep code identifiers in English.
- Prefer one major type per file.
- Name extensions as `TypeName+Feature.swift` when they are substantial.
- Use `final class` for reference types unless there is a clear reason not to.
- Store SwiftData enum values through raw-value properties such as `statusRaw`, then expose computed wrappers like `status`.
- Keep app UI strings in English.

Some older comments are not consistently English. New documentation, comments, examples, and TODOs should be English.

## State Management

The app uses the established SwiftUI/Combine pattern:

- `ObservableObject`
- `@Published`
- `@StateObject`
- `@ObservedObject`
- `@EnvironmentObject`
- async/await for service operations

The codebase does not use the `@Observable` macro in the inspected source.

## Services First

Most mutations should go through services rather than directly editing models from views:

- Use `MemoryService` for Memory CRUD, completion, pinning, filtering, refresh, attachment replacement, and trigger sync.
- Use `MindService` for Minds and Tags.
- Use `DataExportService` and `DataImportService` for backup/restore.
- Use `TriggerExecutorCoordinator` as the shared entry point for trigger sync/unregister behavior.

This matters because `MemoryService` does more than save SwiftData models. It also updates transient attachments, rebuilds its index, refreshes cached arrays, and re-syncs notification/geofence/reminder executors.

## Draft Pattern

Editor flows should use draft structs before persisting changes:

- `MemoryDraft`
- `CheckItemDraft`
- `ScheduleConfigDraft`
- `LocationConfigDraft`
- Nested reminder fields on `ScheduleConfigDraft` / `LocationConfigDraft` (`NestedReminderPolicy`)
- `FocusSettings` / `FocusTimer` for schedule-gated Focus sessions

The pattern keeps SwiftUI editing state separate from SwiftData model instances. Convert drafts to models only at service boundaries, and prefer existing `from(...)` and `toModel(...)` helpers when adding fields.

When adding a persisted field:

1. Update the SwiftData model.
2. Update the matching draft if the field is editable.
3. Update conversion helpers.
4. Update import/export types when the field should be backed up.
5. Update tests if the field affects behavior.
6. Consider migration or backward compatibility if existing installs may already have data.

## Trigger Development

Sparky currently has three active trigger config models:

- `ScheduleConfig`
- `LocationConfig`
- `ReminderConfig`

Legacy `MemoryTriggerModel` and `MemoryTriggerLocation` remain in the SwiftData schema to avoid migration crashes and support migration from older data.

When changing trigger behavior:

- Keep `MemoryService` as the owner of trigger state changes.
- Re-sync through `TriggerExecutorCoordinator`.
- Confirm scheduled notifications, location geofences, and follow-up reminders are all considered.
- Respect the location executor's `maxGeofences = 20` limit.
- Keep notification identifiers stable enough for unregister operations to remove stale pending requests.

## Attachments

Do not store attachment payloads directly in SwiftData unless the storage strategy is intentionally redesigned.

Current behavior:

- `MemoryAttachmentReference` stores ordered attachment references.
- `MemoryAttachmentStore` writes files under Application Support in `MemoryAttachments`.
- Photos are stored as JPEG files.
- Links are stored as JSON payloads.
- Audio files preserve a preferred audio extension when possible.
- Generic files are written with a sanitized original filename.

When changing attachment handling, update both SwiftData references and file-store behavior together.

## Views and View Models

Root navigation lives in `ContentView`.

Major view areas:

- `Views/Memories/`: timeline, calendar, cards, map, search, filters, and editor.
- `Views/Minds/`: Mind hierarchy, detail, sections, composer, and Limbo view.
- `Views/Settings/`: Me, settings, theme, app icon, data management, and advanced screens.
- `Views/Onboarding/`: permission setup flow.
- `Views/Shared/`: reusable components.

Use a view model when a view needs meaningful state coordination, persistence coordination, or service orchestration. Avoid putting service mutation logic deeply inside reusable UI components.

## Testing

Use Swift Testing for new unit tests in `sparkyTests`:

```swift
import Testing
@testable import sparky

@Test func exampleBehavior() async throws {
    #expect(true)
}
```

The existing unit tests create `DataController(inMemory: true)` and `AppEnvironment(dataController:)` to exercise services without writing to the production store.

The UI test target is XCTest-based because it is generated by Xcode. Do not copy XCTest patterns into `sparkyTests` unless a specific test target requires it.

This documentation pass did not execute test or build commands.

## Adding A Feature Safely

For a new feature that affects persisted memory data:

1. Identify whether it belongs to Memory, Mind, Tag, settings, trigger configuration, or attachment storage.
2. Add or update the model/draft layer.
3. Add service methods for mutation and refresh behavior.
4. Wire the view model and views to the service layer.
5. Update import/export only if users should be able to back up and restore the new data.
6. Update notifications/geofences/reminders if trigger state changes.
7. Add focused unit tests around the service behavior.
8. Update docs when user-visible behavior, data shape, or release/privacy claims change.
