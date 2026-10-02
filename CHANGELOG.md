# Changelog

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
