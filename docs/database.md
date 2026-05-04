# Data and Persistence

Sparky does not use a server database. Its persistence layer is local SwiftData plus file-system attachment storage. This document uses "database" to describe the app's local data model and backup format.

## Storage Overview

| Data | Storage mechanism | Owner |
| --- | --- | --- |
| Memories, Minds, Tags, triggers, checklist items, references | SwiftData | `DataController` |
| Attachment payloads | File system under Application Support | `MemoryAttachmentStore` |
| App preferences | UserDefaults | `SettingsStore`, `ThemeManager` |
| Export/import backups | JSON files selected by the user | `DataExportService`, `DataImportService` |
| iCalendar export | Generated `.ics`-style text | `ICalExportFormat` |

## SwiftData Stack

`sparky/Data/DataController.swift` creates the SwiftData `ModelContainer` and exposes the main `ModelContext`.

Production data uses:

```swift
DataController.shared
```

SwiftUI previews use:

```swift
DataController.preview
```

The preview controller uses an in-memory store and seeds sample data.

The main context has:

```text
autosaveEnabled = true
```

If container creation fails, `DataController` logs the failure and falls back to an in-memory store. That fallback protects app startup, but data in the fallback store is not durable.

## Persisted Schema

The schema in `DataController` includes:

| Model | Responsibility |
| --- | --- |
| `Mind` | Hierarchical organization areas for memories |
| `Memory` | Core user-created item |
| `Tag` | Lightweight labels with colors |
| `CheckItemModel` | Checklist items attached to a Memory |
| `ScheduleConfig` | Date/time and recurrence configuration |
| `LocationConfig` | Geofence configuration |
| `ReminderConfig` | Follow-up reminders after a primary trigger |
| `MemoryTriggerModel` | Legacy trigger model retained for migration safety |
| `MemoryTriggerLocation` | Legacy trigger location model retained for migration safety |
| `MemoryAttachmentReference` | Ordered references to attachment payloads |
| `MemoryCompletionDate` | Completion history for recurring memories |

Models generally use `@Attribute(.unique)` UUID identifiers and explicit relationship delete rules.

## Core Relationships

- A `Memory` may belong to one `Mind`.
- A `Mind` may have child Minds through its self-referential hierarchy.
- A `Memory` may have many `CheckItemModel` records.
- A `Memory` has optional 1:1 `ScheduleConfig`, `LocationConfig`, and `ReminderConfig` relationships.
- A `Memory` has many `MemoryAttachmentReference` records.
- A `Memory` has many `MemoryCompletionDate` records.
- Legacy trigger records remain related to Memory but should not be used for new behavior.

`Mind.allMinds` and `Mind.limbo` are virtual sentinels. They are created through static factory properties and should not be persisted as normal Mind records.

## Memory Data Model

`Memory` stores:

- Identity and display data: `id`, `title`, `body`.
- State: `statusRaw`, `isPinned`, `priorityRaw`, `dueDate`, `userOrder`.
- Timestamps: `createdAt`, `updatedAt`.
- Checklist behavior: `checkItems`, `autoCompleteOnChecklistCompletion`.
- Trigger configuration: `scheduleConfig`, `locationConfig`, `reminderConfig`.
- Legacy migration support: `triggers`.
- Attachment references: `attachmentReferences`.
- Recurrence completion history: `completionDateEntries`.
- Transient loaded attachments: `attachments`.

`attachments` is marked transient and is populated by `MemoryService` using `MemoryAttachmentStore`.

## Trigger Migration

The current migration is version-gated by:

```text
sparky.triggerMigrationVersion
```

The current migration version is `1`.

`DataController.migrateTriggersIfNeeded()` fetches persisted Memories and copies active legacy trigger data into the newer config models:

- legacy scheduled trigger -> `ScheduleConfig`
- legacy location trigger -> `LocationConfig`

Sequential triggers are intentionally not migrated because that behavior is being removed from the active model.

After a successful migration, the version is stored in UserDefaults. If a future schema change requires another migration, increment the migration version and keep older model classes in the schema until existing data can be handled safely.

## Attachment Storage

`MemoryAttachmentStore` is an actor that stores attachment payloads under:

```text
Application Support/MemoryAttachments/<memory-id>/
```

Current file conventions:

- Photos: `<attachment-id>.jpg`
- Links: `<attachment-id>.json` containing the URL payload
- Audio: `<attachment-id>.<audio-extension>`
- Files: `<attachment-id>_file_<sanitized-filename>`

The store can:

- Load attachments for a Memory.
- Replace all attachments for a Memory.
- Delete all attachments for a Memory.
- Calculate total attachment storage size.
- Delete the entire attachment store.

Important: clearing the attachment cache deletes attachment files. SwiftData references may still need service-level handling if the product behavior changes from cache clearing to full attachment deletion.

## UserDefaults Storage

`SettingsStore` persists:

- Default timeline filter.
- Notification sound preference.
- Onboarding completion.
- User display name.

`ThemeManager` persists the selected app theme.

The Privacy Manifest declares UserDefaults access with reason `CA92.1`.

## JSON Export Format

`DataExportService` produces a `SparkyExportFormat` JSON payload.

Current format:

- `version`: currently `1.0`
- `exportedAt`
- `appVersion`
- `minds`
- `memories`
- optional `attachments`
- optional `attachmentsMode`
- optional `attachmentsDirectory`

Available export options:

- Full export.
- Without attachments.
- Active only.
- Active only without attachments.

When attachments are included, they are exported inline through the JSON format. That can make export files sensitive and large.

## JSON Import Behavior

`DataImportService` imports only `SparkyExportFormat` version `1.0`.

During import it:

- Decodes and validates the JSON.
- Imports Mind hierarchy.
- Maps old Mind IDs to new or existing Minds.
- Creates new Memories from exported data.
- Converts exported triggers into schedule, location, and reminder drafts.
- Recreates checklist items.
- Imports attachment payloads and remaps attachment IDs.
- Refreshes Mind and Memory services after import.

Import does not overwrite Memories in place. It creates new Memories with new IDs.

## iCalendar Export

`ICalExportFormat` converts scheduled Memories into iCalendar text.

Current scope:

- Exports active schedule configs.
- Produces `VTODO` entries.
- Includes title, description, status, completion date, due date, start date, recurrence rule, created date, and last modified date when available.
- Does not export location triggers.
- Does not export follow-up reminder configs.

Use the JSON export for full-fidelity Sparky backup/restore.

## Changing The Data Model

Before changing persisted models:

- Check whether SwiftData migration is needed.
- Keep legacy models in the schema if existing installs might still contain them.
- Update draft conversion paths.
- Update import/export types if the data should be backed up.
- Update tests around service behavior.
- Review privacy and App Store metadata if new sensitive data or permissions are introduced.
