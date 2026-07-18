# Troubleshooting

This guide lists focused checks for issues that match the current Sparky architecture. It avoids generic backend, Docker, package manager, or CI advice because those systems were not identified in the repository.

## The Project Does Not Open In Xcode

Check:

- Open `sparky.xcodeproj` directly.
- Do not look for a missing `.xcworkspace`, `Package.swift`, `Podfile`, or Makefile.
- Confirm your Xcode installation supports the configured iOS `26.0` deployment target.

## Memories Do Not Persist

Start with:

- `sparky/Data/DataController.swift`
- `sparky/Model/Memory/Memory.swift`
- `sparky/Services/MemoryService.swift`

Likely causes:

- The app fell back to an in-memory SwiftData container after container creation failed.
- The Memory was edited in a draft but not submitted through `MemoryService`.
- The main context had unsaved changes that were not flushed through `DataController.save()`.
- A schema change was made without a migration path.

Useful checks:

- Look for `DataController` critical logs about ModelContainer creation.
- Confirm `MemoryService.createMemory(...)` or `updateMemory(...)` is being called.
- Confirm `MemoryService.refresh(force: true)` runs after mutation.

## Minds Or Tags Do Not Refresh

Start with:

- `sparky/Services/MindService.swift`
- `sparky/Model/Mind/Mind.swift`
- `sparky/Model/Tag/Tag.swift`

Notes:

- `MindService` maintains cached arrays and indexes.
- Refresh is TTL-based unless forced.
- Virtual Minds (`All`, `Limbo`) should not be persisted as normal Minds.

## Attachments Are Missing

Start with:

- `sparky/Managers/MemoryAttachmentStore.swift`
- `sparky/Model/Memory/MemoryAttachmentReference.swift`
- `sparky/Services/MemoryService.swift`

Likely causes:

- SwiftData references exist but files were deleted from Application Support.
- Attachment replacement was not routed through `MemoryService`.
- The Advanced settings cache clear removed attachment files.
- A file import did not preserve security-scoped access long enough to read data.

Attachment payloads are stored outside SwiftData under `Application Support/MemoryAttachments`.

## Export Fails

Start with:

- `sparky/Services/DataExportService.swift`
- `sparky/Views/Settings/DataManagementView.swift`
- `sparky/Model/Export/SparkyExportFormat.swift`

Likely causes:

- No Minds or Memories exist, which can trigger `noDataToExport`.
- Attachment data could not be loaded.
- The selected destination could not be written by the iOS file exporter.

Try exporting without attachments to isolate attachment payload issues.

## Import Fails

Start with:

- `sparky/Services/DataImportService.swift`
- `sparky/Views/Settings/DataManagementView.swift`

Likely causes:

- The file is not valid Sparky JSON.
- The export `version` is not `2.0`.
- The selected file cannot be accessed through security-scoped resource access.
- Attachment data is missing or invalid.
- A Mind or Memory validation rule rejected imported data.

Imports create new Memories with new IDs rather than overwriting existing Memories in place.

## Scheduled Notifications Do Not Fire

Start with:

- `sparky/Executors/ScheduledTriggerExecutor.swift`
- `sparky/Executors/TriggerExecutorCoordinator.swift`
- `sparky/Model/Triggers/ScheduleConfig.swift`

Check:

- Notification authorization was granted.
- The Memory is active.
- `scheduleConfig.isActive` is true.
- `fireDate` is in the future for one-time notifications.
- The app has refreshed and synced triggers.
- Notification sound is not disabled in `SettingsStore` if sound is expected.

For recurring schedules, confirm whether the behavior is weekday-mask, recurrence-rule, or interval-based, because each path schedules notifications differently.

## Location Triggers Do Not Fire

Start with:

- `sparky/Executors/LocationTriggerExecutor.swift`
- `sparky/Model/Triggers/LocationConfig.swift`
- `sparky/Views/Memories/Editor/Triggers/Location/`

Check:

- Location authorization is `authorizedAlways` for background geofence behavior.
- Region monitoring is available for `CLCircularRegion`.
- The Memory is active.
- `locationConfig.isActive` is true.
- Radius is greater than zero.
- The trigger is within the first `LocationTriggerExecutor.maxGeofences` active geofences selected by the sync order.
- The desired event matches user action: arrival vs departure.

iOS geofence behavior is system-managed and may not fire instantly in every simulator/device scenario.

## Map Search Or Location Names Do Not Resolve

Start with:

- `sparky/Views/Memories/Editor/Triggers/Location/Components/LocationPickerSearchViewModel.swift`
- `sparky/Views/Memories/Editor/Triggers/Location/Components/LocationPickerGeocoder.swift`

MapKit search and reverse geocoding can depend on Apple services, network availability, simulator location state, and user permissions.

## Link Previews Do Not Load

Start with:

- `sparky/Views/Memories/Editor/Components/LinkPreviewView.swift`
- `sparky/Views/Memories/Editor/Components/AttachmentPreviews.swift`

Likely causes:

- The URL is invalid.
- The remote page does not expose preview metadata.
- Network access is unavailable.
- `LPMetadataProvider` failed silently or returned partial metadata.

Links are stored locally as URL payloads, but preview metadata loading is handled by LinkPresentation.

## App Store Privacy Copy Drifted

Update these together:

- Native app behavior.
- `AppStoreMetadata.md`.
- `sparky/PrivacyInfo.xcprivacy`.
- `../sparky-landing` privacy, support, terms, and marketing pages.

Avoid unsupported claims such as Speech Recognition usage or blanket "zero network calls" unless the current app code and platform behavior have been verified.

## Tests Compile With The Wrong Framework

Use Swift Testing in `sparkyTests`:

- `import Testing`
- `@Test`
- `#expect`
- `Issue.record(...)`

The `sparkyUITests` target uses XCTest because it is a UI test target generated by Xcode.
