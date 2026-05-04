# Sparky Screenshots

This folder is reserved for product screenshots and visual evidence used by the README, App Store submission, and the companion landing site.

## Current Status

TODO: not identified in the current codebase - final screenshots have not been added to this folder.

## Capture Checklist

Capture real app states, not empty placeholder screens.

Recommended App Store / README screenshots:

- Onboarding welcome screen.
- Calendar or timeline with multiple Memories.
- Memory editor with title, note, checklist, and trigger cards.
- Quick Memory capture sheet.
- Mind hierarchy or Mind detail view.
- Schedule trigger editor with recurrence visible.
- Location trigger editor with map and arrival/departure setting.
- Memory card with attachment previews.
- Search and filter surface.
- Data Management screen showing export/import actions.
- Advanced settings with cache and app info.
- Theme or app icon settings if visual customization is part of the release story.

## File Naming

Use stable, descriptive names:

```text
01-onboarding.png
02-calendar-timeline.png
03-memory-editor.png
04-mind-detail.png
05-schedule-trigger.png
06-location-trigger.png
07-attachments.png
08-data-management.png
```

If separate device sizes are captured, include the device class:

```text
01-onboarding-iphone-67.png
01-onboarding-iphone-61.png
```

## Quality Bar

- Use English app strings.
- Avoid screenshots containing private real user data.
- Prefer realistic but safe example content.
- Keep status bar, theme, and device size consistent within a screenshot set.
- Verify that permission prompts and location examples match App Store metadata.
- Keep privacy wording aligned with `../AppStoreMetadata.md` and `../docs/security.md`.

## Suggested README Usage

Once screenshots exist, reference a small subset from the root README:

```md
![Sparky calendar timeline](screenshots/02-calendar-timeline.png)
![Sparky memory editor](screenshots/03-memory-editor.png)
```
