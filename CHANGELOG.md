# Changelog

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
