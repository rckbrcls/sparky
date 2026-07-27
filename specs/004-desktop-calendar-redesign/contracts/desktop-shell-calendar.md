# Desktop Shell and Calendar Contract

## Primary destinations

| Destination | Shortcut | Deep-link responsibility |
|---|---:|---|
| Calendar | ⌘1 | Open a Memory preview |
| Mind | ⌘2 | Preserve its navigation path |
| Focus | ⌘3 | Open/start a requested Focus session |
| Me | ⌘4 | Show the shared dashboard directly |

Me is a direct desktop destination. Its gear button opens the native macOS
Settings scene; no profile menu or Profile & Insights sheet is part of the shell.

## Window chrome and creation

- The main window uses a unified toolbar without the automatic app title.
- Week/Month uses its compact intrinsic width and stays centered for Calendar.
- A flexible toolbar spacer keeps Search trailing in Calendar, Mind, and Focus.
- Search is absent from Me, whose toolbar exposes only the native Settings gear.
- The bottom navigation is a centered 288×55 pt Liquid Glass capsule with four
  fixed 72 pt vertical segments and the mobile `mind` and `me` assets.
- New Memory is a separate 52 pt bottom-trailing circle using `brain.fill`,
  24 pt from the trailing edge and 16 pt from the bottom.
- The creation action keeps Command-N, the current Mind context, tooltip, and
  accessibility label.
- The centered navigation and trailing creation button share a full-width
  bottom layout but remain geometrically independent.
- Toolbar and bottom safe-area chrome are transparent and inherit the active
  section surface: Calendar background for Calendar, secondary background for
  Mind, Focus, and Me.
- The Mind overview uses three columns on Mac; the shared iPhone view keeps two.

## Calendar state

```text
DesktopCalendarMode = week | month
anchorDate = one concrete Date shared by both modes
```

- Previous/next shift by one week or one month according to mode.
- Today assigns the current date and does not change mode.
- Selecting a Month date assigns that date and switches to Week.
- Week calculation uses the active Calendar's `firstWeekday`.

## Occurrence query

```text
occurrences(from: startDate, to: endDate) -> [MemoryOccurrence]
```

The range is half-open. Results retain every concrete occurrence, are sorted
chronologically, use stable IDs derived from Memory ID plus occurrence time,
and distinguish all-day from timed schedules.

## Quick-add target

```text
allDay(date)
scheduledDate(timestamp)
period(date, CalendarTimePeriod) // iPhone-compatible initializer
```

All three paths produce an active, non-recurring `ScheduleConfigDraft` and do
not mutate persisted data before the existing quick-create/editor flow saves.

## Unified New Memory popover

The desktop global action and desktop Calendar create actions share one
`DesktopMemoryEditorPopover` content contract.

| Source | Initial context | Anchor |
|---|---|---|
| Bottom `brain.fill` / Command-N | Current Mind, no schedule required | The `brain.fill` button |
| Week hour cell | Exact scheduled timestamp | The clicked hour cell |
| Month day add | All-day date | The clicked day add affordance |

Contract rules:

- The source creates an existing `MemoryEditorRoute` in create mode.
- Calendar sources populate `initialScheduleConfig` exclusively through
  `CalendarQuickMemoryTarget.scheduleDraft()`.
- The same editor fields, section order, actions, validation, and save behavior
  appear for every source.
- SwiftUI may choose the Calendar popover's viable arrow edge based on available
  window space, but the arrow must remain attached to the initiating control.
- Command-N presents the global source, not the last Calendar source.
- Cancel and outside-click dismissal discard the transient draft.
- Create saves through `MemoryEditorViewModel` and `MemoryService`.
- Preview and edit routes remain sheets.
- Desktop Calendar no longer presents `QuickMemorySheet`; iPhone behavior is
  unchanged.

### Surface contract

- The native popover material is the root surface.
- No app-owned opaque background covers the root material.
- Editable switch-bearing sections use interactive Liquid Glass and share one
  `GlassEffectContainer`.
- No opaque `.cardStyle()` fill sits behind those glass sections in the desktop
  popover mode.
- Standard sheets and iPhone retain their current `.cardStyle()` treatment.
