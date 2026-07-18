# Security and Privacy

Sparky is designed as a local-first native iOS app. The current repository does not contain a custom backend, account system, authentication flow, analytics SDK, advertising SDK, tracking SDK, or cloud sync implementation.

This does not mean every feature is network-independent. The app uses Apple/system frameworks such as MapKit, CoreLocation, and LinkPresentation. Location search, map data, reverse geocoding, and link metadata previews may rely on Apple services or destination network access when the user invokes those features.

## Data Handling Model

User-created app data is stored locally:

- SwiftData stores Memories, Minds, Tags, triggers, checklist items, attachment references, and completion history.
- Attachment payloads are stored in the app's Application Support directory.
- Settings are stored in UserDefaults.
- Exports are user-selected JSON files and may include inline attachment data.

No repository code was identified that sends Sparky user content to a custom app server.

## Authentication and Authorization

No authentication or authorization layer exists in the app. There are:

- No accounts.
- No login screens.
- No access tokens.
- No custom server sessions.
- No role or permission model inside the app.

iOS system permissions are the main authorization boundary.

## iOS Permissions

The Xcode project declares usage descriptions for:

| Permission | Purpose in app |
| --- | --- |
| Camera | Capture photos for Memories |
| Photo Library | Attach existing images to Memories |
| Microphone | Record audio notes |
| Location When In Use | Select and use locations |
| Location Always | Monitor geofence reminders in the background |

The app also uses UserNotifications for scheduled and location-triggered notifications.

`UIBackgroundModes = location` is configured so geofence reminders can work after the app leaves the foreground.

Speech Recognition was not identified in the current app source or project settings.

## Privacy Manifest

`sparky/PrivacyInfo.xcprivacy` declares:

- `NSPrivacyTracking = false`
- No collected data types.
- No tracking domains.
- Accessed API categories:
  - UserDefaults with reason `CA92.1`
  - File timestamp with reason `C617.1`

Keep this file synchronized with actual framework and API usage before App Store submission.

## External Service Caveats

The app has no custom backend integration, but these framework features can involve system-managed network access:

- `MKLocalSearchCompleter` and `MKLocalSearch` for location suggestions and search.
- `CLGeocoder`/reverse geocoding behavior through location picker flows.
- `LinkPresentation` metadata loading for link previews.
- Map display and location services through Apple frameworks.

Documentation and App Store copy should say there is no custom backend, account, analytics, or tracking. Avoid claiming "zero network calls" unless that has been validated against platform behavior.

## Sensitive Data Risks

Memories can contain sensitive user content:

- Personal notes and tasks.
- Location trigger coordinates.
- Photos and files.
- Audio recordings.
- Links and link metadata.
- Checklist history and completion dates.

The most important local risks are device access, backups, exported files, and attachment files.

## Export and Import Risks

JSON exports may include:

- Memory titles and notes.
- Mind hierarchy.
- Trigger dates and recurrence rules.
- Location coordinates and place names.
- Checklist items.
- Completion dates.
- Inline attachment data when attachments are included.

Treat export files as sensitive backups. Users should store and share them carefully.

Import uses a user-selected file through the iOS file importer and security-scoped access. Invalid or unsupported export versions are rejected.

## Location Safety

Location triggers are implemented through CoreLocation geofences:

- The app monitors user-defined circular regions.
- Background location authorization is requested for geofence behavior.
- The implementation does not show continuous custom location tracking or upload location data to a custom backend.
- iOS region monitoring limits are respected by syncing only up to `LocationTriggerExecutor.maxGeofences`.

If future work adds continuous location tracking, analytics, sync, or server-side processing, update this document and App Store privacy declarations before release.

## Secret Management

No repository secrets, API keys, service tokens, or environment variables were identified in the current codebase.

If future features introduce external services, do not hard-code secrets in Swift source, project files, documentation, screenshots, or sample exports.

## Security Checklist For Future Changes

- Update `PrivacyInfo.xcprivacy` when using new required-reason APIs.
- Update App Store privacy declarations when collected data, tracking, or external service behavior changes.
- Review permission strings when adding a new OS permission.
- Version export/import format changes explicitly; only the current format is supported.
- Avoid storing large or sensitive payloads directly in SwiftData without a deliberate migration and backup strategy.
- Revalidate public privacy claims when adding networking, sync, telemetry, crash reporting, or third-party SDKs.
