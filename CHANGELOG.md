# Changelog

## [0.0.24] - 2026-10-03

### Fixed

- Advance a weekday reminder to the next selected day when that day's time has already passed. A bounded weekday series was scheduling the same instant up to 48 times instead of stopping at the series end.

### Added

- Decide scheduled notifications and location geofences in planners, then let the executors apply that plan. The suites cover one-time and repeating schedules, weekday masks, focus notifications, geofence selection, arrival and departure copy, and the create, update, duplicate, complete, delete, and reactivate lifecycle.
- Bring the main Mac window forward when a memory or Focus notification is waiting, including a cold launch. The main scene has a stable identifier so Settings and Logs stay out of the way.

### Preserved

- Notification permission, the notification center, and GPS monitoring stay in the executors. Mac still does not arm geofences.
- Completing a memory still unregisters its triggers before the following sync. Reactivating a memory only syncs.

### Validation

- `ScheduleOccurrenceTests`, `ScheduledTriggerPlannerTests`, `LocationGeofencePlannerTests`, and `TriggerSyncLifecycleTests` passed on the iOS Simulator (iPhone 17).
- The Mac window reveal was not exercised in this pass.

## [0.0.23] - 2026-10-02

### Fixed

- Report a remote command only after that sync cycle has uploaded the mirror. The app was marking the command done and then pushing the mirror, so a client that waited for `done` still read the previous memory and the next patch conflicted on a stale `baseVersion`.

### Preserved

- A failed mirror upload does not report the batch. The local receipt stays pending, and the next cycle uploads the mirror before reporting leftover results.
- Failed and conflict results wait for the same upload. An unchanged mirror still skips the upload when its content matches the last push.

### Validation

- Reviewed the sync cycle order in `RemoteSyncService`. Tests and browser validation were not run.

## [0.0.22] - 2026-10-02

### Fixed

- Decode a remote recurrence when `weekdays` is omitted. Non-weekly schedules encode without that key, and the synthesized decoder required it, so mirror round-trips and remote updates failed for minutely, hourly, daily, monthly, and yearly. A missing `weekdays` key now decodes as an empty list. Weekly schedules still send their weekdays, and the memberwise initializer stays available because the decoder lives in an extension.
- Complete a non-recurring memory from its checklist only when `autoCompleteOnChecklistCompletion` is on. Closing every item no longer marks the memory completed while that flag is off, in both the saved memory and the editor. Recurring occurrence completion is unchanged.
- Keep a schedule's focus settings when the schedule is inactive. Saving a draft no longer forces `focusEnabled` off just because the schedule itself is off.

### Changed

- Expect hours 0 and 5 to fall in Early Morning in the calendar period test, matching the 00:00–05:59 range. Night stays 22:00–23:59. The app intervals are unchanged.

### Preserved

- The server still rejects `weekdays` on a non-weekly recurrence, so those payloads continue to omit the key.
- Recurring memories still complete an occurrence when its checklist closes, including when auto-completion of the whole memory is off.
- No data migration.

### Validation

- `RemoteMirrorBuilderTests`, `RemoteCommandExecutorTests`, and `CalendarQuickMemoryTargetTests` passed on the iOS Simulator (iPhone 17 Pro).
- Browser validation was not run.

## [0.0.21] - 2026-10-02

### Added

- Add an Early Morning calendar section for 00:00–05:59 before Morning on iOS and macOS, using the moon icon and existing Night color.
- Add native macOS tooltips to calendar period badges showing their time ranges; All Day describes memories without a specific time. Preserve expand/collapse accessibility hints and use the system hover delay.
- Suggest 01:00 on the selected date when creating a memory from the empty Early Morning section, with the prompt "Plan an early morning memory".

### Fixed

- Limit Night to 22:00–23:59 so early-morning memories appear at the beginning of their calendar date instead of after the evening section.
- Keep the other periods unchanged: Morning 06:00–11:59, Afternoon 12:00–17:59, and Evening 18:00–21:59.

### Preserved

- Preserve existing dates, notifications, recurrence, GPT integration, and Me activity metrics; no data migration is required.

### Validation

- Local iOS Simulator and macOS Debug builds succeeded, and `git diff --check` passed.
- Inspected period boundaries, chronological section order, and creation on the selected date.
- Opened the updated local macOS app; tooltip hover behavior and timing have not been independently verified.
- Automated tests and browser validation were not run.

## [0.0.20] - 2026-10-02

### Fixed

- Replace the native macOS daily calendar list with a scroll view and lazy vertical stack to remove the rectangular context-menu outline around the entire row.
- Draw a 24-point rounded accent outline directly on the memory card while its context menu is tracking, and remove the outline when the menu closes.
- Match memory card and list-button interaction shapes to the card's 24-point corners, with rounded context-menu previews on iOS.

### Preserved

- Keep calendar period spacing, collapsible sections, empty-period actions, scroll indicators, and bottom content clearance.
- Keep context-menu actions, completion controls, multi-selection, recurring occurrence context, and the native iOS calendar list.
- Leave the shared card styling unchanged.

### Validation

- The local macOS Debug build succeeded, and `git diff --check` passed.
- The updated local app was opened for inspection; the final visual behavior has not been independently verified.
- Automated tests and browser validation were not run.

## [0.0.19] - 2026-10-02

### Improved

- Make button interaction shapes explicit across calendar navigation and day controls, focus controls, memory editor menus and fields, quick creation, checklist completion, trigger selection, map actions, settings, expandable memory lists, and onboarding.
- Reorganize the desktop memory editor: place Close, Edit, and Done in the header; keep Delete available while editing; and provide Start Focus and a labeled completion action in the preview footer.
- Show processing feedback while completing or reopening a memory, prevent overlapping status actions, and reveal Reopen when a completed memory's action is hovered or focused.
- Open remote sync logs in a dedicated, resizable macOS window with selectable text, individual and bulk copy actions, context-menu copying, temporary copy feedback, and empty-state-aware toolbar actions.
- Improve remote sync configuration transitions, clear field focus when disabling sync, and respect Reduce Motion.

### Fixed

- Include `weekdays` in remote recurrence payloads only for weekly schedules.

### Validation

- The local macOS Debug build succeeded, and `git diff --check` passed.
- Local application launch failed; visual behavior has not been verified.
- Automated tests and browser validation were not run.
