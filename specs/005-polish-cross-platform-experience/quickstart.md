# Quickstart: Validate Cross-Platform Experience Polish

## Prerequisites

- Xcode with the iOS 26 and macOS 26 SDKs
- An iPhone 16 simulator
- Notification permission available for manual enabled-state checks
- Audio output available on iPhone and Mac
- Fixtures covering no Memories, active-only Memories, populated completions,
  scheduled occurrences, and long Calendar Day content

## Static Checks

From the repository root:

```bash
git diff --check
git status --short
rg -n "primaryContentMaxWidth|scrollIndicatorVisibility: \\.never" sparky
rg -n "notificationsEnabled|soundsEnabled|focusCompletionSound|breakCompletionSound" sparky/Focus
rg -n "checkmark.circle.fill|contentShape\\(Circle" sparky/Views
file sparky/Resources/FocusSounds/*.caf
```

Expected:

- no whitespace errors;
- one shared 880-point desktop content token;
- desktop Calendar Day requests permanent indicator hiding;
- Focus preferences and status symbols are present in their scoped files.
- all eight Focus assets are valid Core Audio Format files.

## Automated Validation

Run locally:

```bash
xcodebuild -scheme sparky -destination 'platform=iOS Simulator,name=iPhone 16' test
xcodebuild -scheme sparky -destination 'platform=iOS Simulator,name=iPhone 16' build
xcodebuild -scheme sparkyMac -destination 'platform=macOS' build
```

Expected:

- existing tests remain green;
- new navigation, Me presentation, Focus feedback, and preview-state tests pass;
- shared AVFoundation and Focus code compiles for both destinations.

## Scenario 1: Desktop Width and Navigation

1. Open the Mac app at 980×680, 1100×720, and full screen.
2. Compare Calendar Day, Mind overview, a nested Mind detail, Focus, and Me.
3. Confirm their main columns are centered and never wider than Calendar Day.
4. Confirm Calendar Month still fills the available grid width.
5. Navigate more than one level into Mind and reselect Mind once.
6. Navigate from Me into Settings and reselect Me once.
7. Change Calendar date and mode, then reselect Calendar.
8. Start or pause Focus, then reselect Focus.

Expected:

- Mind and Me return to root in one click;
- Calendar keeps date and mode;
- Focus keeps the exact session state;
- reselection at root is harmless.

## Scenario 2: Calendar Day Scrollbar

1. Check an empty Day, a short Day, and a long Day on Mac.
2. Scroll the long Day with a mouse, trackpad, and keyboard.

Expected:

- scrolling remains responsive;
- no vertical scrollbar appears in any Day state;
- Month and iPhone Calendar behavior are unchanged.

If the native `.never` visibility still exposes a scroller at runtime, record
the exact macOS version and List state before introducing the documented thin
AppKit fallback.

## Scenario 3: Me Dashboard

On both iPhone and Mac, open Me with:

1. no Memories;
2. active but uncompleted Memories;
3. populated recent completion history;
4. scheduled Memories with no elapsed occurrence;
5. tied or insufficient rhythm data.

Expected:

- all three cards always appear;
- visible copy matches
  [me-and-memory-preview.md](contracts/me-and-memory-preview.md);
- unavailable values show `—`, never a fabricated `0%`;
- valid zero counts remain zero;
- VoiceOver announces complete chart details and `Not available` for dashes.

## Scenario 4: Focus Feedback

Test all four combinations:

| Notifications | Sounds |
|---|---|
| Off | Off |
| Off | On |
| On | Off |
| On | On |

For each relevant combination:

1. Start, pause, resume, and explicitly end a session.
2. Complete a Focus phase and a Break phase.
3. Repeat with auto-continue off.
4. Extend a phase and change duration settings.
5. Test both completion-sound pickers.
6. Deny notification permission and repeat with sounds enabled.
7. Relaunch and confirm preferences persist.
8. Use Reset to Defaults.

Expected:

- behavior matches [focus-feedback.md](contracts/focus-feedback.md);
- every effective event produces at most one cue;
- internal stop, no-op, duration, and extension actions are silent;
- timer state never depends on feedback success;
- defaults return to Notifications on, Sounds on, Glass, and Bell.

## Scenario 5: Desktop Memory Preview

1. Open an active Memory in the Mac preview.
2. Click the center and then the visible edge of each round action.
3. Complete the Memory from the status circle.
4. Close and reopen the preview.
5. Reopen the Memory with the same control.
6. Exercise a forced save failure if the test environment supports it.

Expected:

- all visible circular surfaces are clickable;
- active uses `circle`;
- completed uses `checkmark.circle.fill`;
- successful state persists after reopening;
- failed state returns to authoritative data and shows the existing save error.

## Appearance and Accessibility

Repeat changed surfaces in light, dark, and system appearance. Verify keyboard
focus on desktop tabs and preview actions, Dynamic Type on iPhone, VoiceOver
labels, and reduced-motion behavior.

## Implementation Validation Boundary

This Codex implementation run performs source parsing, focused type-checking,
asset inspection, and documentation checks only. It does not build, launch,
preview, or execute the app. Run the commands above locally for full
destination and interaction validation.
