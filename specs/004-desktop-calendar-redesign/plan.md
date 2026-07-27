# Implementation Plan: Desktop Calendar Redesign

**Branch**: `master` | **Date**: 2026-07-27 | **Spec**: [spec.md](spec.md)

**Input**: Align the desktop Calendar with the mobile Day experience while
preserving the implemented native Memory editor popover and removing remaining
sheet presentations from the macOS target.

## Summary

Replace the desktop Week grid with a Day surface that reuses the shared mobile
period sections. Keep Month unchanged, retain one shared anchor date, and
continue presenting the implemented `DesktopMemoryEditorPopover` from the
global `brain.fill`, each empty Day period, and each Month-day add control.

## Technical Context

**Language/Version**: Swift 6, SwiftUI 26, default MainActor isolation  
**Primary Dependencies**: SwiftUI, SwiftData, Combine; no new dependency  
**Storage**: Existing SwiftData models and local attachment store; no schema change  
**Testing**: Swift Testing plus manual macOS presentation acceptance  
**Target Platform**: macOS 26 for this presentation edge; shared iPhone code unchanged  
**Project Type**: Native multiplatform Apple app in one Xcode project  
**Performance Goals**: Day switching and popover presentation remain immediate;
daily list scrolling and Month interaction remain responsive
**Constraints**: Native `.popover`, existing `MemoryEditorRoute`,
`CalendarQuickMemoryTarget`, semantic theme, draft/service save path, no AppKit bridge  
**Scale/Scope**: Two desktop Calendar modes, one shared daily content surface,
one reusable popover, and existing editor sections and schedule draft

## Constitution Check

- [x] **I. HIG / native feel**: native macOS popover and Liquid Glass; pointer,
      keyboard, accessibility, light/dark, and window fit are acceptance gates.
- [x] **II. Semantic theme**: existing semantic colors remain; no ad-hoc fill
      replaces the native popover material.
- [x] **III. Modern SwiftUI**: source controls emit a create route; the shared
      editor retains draft ownership and service-mediated save.
- [x] **IV. Performance**: popover content is created only while presented;
      Day loads one selected month and Month retains its existing range.
- [x] **V. Local-first architecture**: no model, service, executor, backend, or
      persistence change.
- [x] **VI. One code, two builds**: presentation divergence is Mac-only;
      editor logic remains shared and iPhone behavior is explicitly preserved.
- [x] **Complexity**: no constitutional violation or waiver required.

Post-design check: passed. The design reuses the mobile daily sections and the
existing desktop popover without an AppKit bridge or duplicated Calendar data.

## Existing Architecture Preserved

- `DesktopRootView` remains the desktop presentation coordinator.
- `DesktopFloatingNavigationBar` remains the anchor for the global action.
- `DesktopCalendarView` keeps Day/Month state and `CalendarDataManager`.
- `CalendarQuickMemoryTarget.scheduleDraft()` remains the only conversion from
  a clicked Calendar location to an initial schedule draft.
- `MemoryEditorViewModel` and `MemoryService` remain the only durable save path.
- Memory preview/edit remains on `nav.editorRoute`, presented through the
  shared desktop popover wrapper.
- iPhone continues using its current quick-add and editor presentation.

## Implementation Architecture

### 1. Shared mobile daily content

`DesktopDayCalendarView` keeps the desktop month/year header and renders a
seven-date selector aligned to the active Calendar's `firstWeekday`. Beneath
it, `CalendarDayContentView` reuses the mobile All Day, Morning, Afternoon,
Evening, and Night sections with its duplicate mobile date header and bottom
inset disabled.

The daily list is centered at a maximum width of 880 pt. Day selection updates
the shared `anchorDate`; previous/next advance one day and Today updates the
anchor without changing mode.

### 2. Platform-specific creation behavior

Shared period sections receive an explicit creation behavior:

- iPhone invokes its existing callback and continues presenting
  `QuickMemorySheet`;
- macOS creates a local `MemoryEditorRoute` and presents
  `DesktopMemoryEditorPopover`.

The route state and popover modifier live on the empty period button so the
native arrow remains attached to the clicked source.

### 3. Three anchor families, one editor

| Source | Initial route | Native anchor behavior |
|---|---|---|
| Bottom `brain.fill` / Command-N | Blank create route with current Mind context | Attached to the bottom action; opens above when space allows |
| Day period action | Create route with the period `scheduleDraft()` | Attached to the clicked period button with the shared bottom-arrow preference |
| Month day add | Create route with all-day `scheduleDraft()` | Attached to the clicked day affordance with the shared bottom-arrow preference |

Each source holds only the minimal ephemeral route needed for its own anchor.
All sources render the same `DesktopMemoryEditorPopover`.

### 4. Calendar creation flow

```text
Calendar anchor -> create MemoryEditorRoute with CalendarQuickMemoryTarget
                -> DesktopMemoryEditorPopover at that anchor
                -> MemoryEditorViewModel save -> MemoryService
```

The iPhone `QuickMemorySheet` remains available and unchanged.

### 5. Popover-specific editor surface

The implemented presentation-style input to `MemoryEditorView` defaults to the
current standard behavior. In the Mac popover style:

- do not paint `Color.Theme.secondaryBackground` across the popover root;
- keep the native popover material visible between sections;
- preserve the current title, editor content, validation, and toolbar actions;
- place all nearby toggle-driven glass sections in one
  `GlassEffectContainer(spacing: 12)`;
- render `Notes`, `Checklist`, `Media`, `Schedule`, and any editable
  switch-bearing location section with
  `.glassEffect(.regular.interactive(), in: RoundedRectangle(...))`;
- do not add opaque fills behind those glass sections;
- retain current opaque `.cardStyle()` behavior outside this presentation mode.

Non-toggle disclosure blocks, including a Mac location capability disclosure,
do not automatically become glass.

### 6. Size and interaction

- Use a dense inspector-like width near 480 pt.
- Bound vertical size for the supported desktop window range and keep the
  editor content scrollable.
- Keep Cancel and Create visible through the existing toolbar.
- Focus the title for a new draft.
- Outside-click and Cancel dismiss without saving.
- Create dismisses only after the existing save succeeds.
- Command-N opens the global anchor; Calendar clicks open only their own anchor.

### 7. Popover-only desktop presentation

- `DesktopRootView` presents Memory routes, Mind composition, and onboarding
  with native popovers.
- Shared `platformCover` and `platformSheet` helpers keep their existing iPhone
  semantics but resolve to popovers on macOS.
- Desktop Memory list items own their local preview/edit route so the popover
  arrow remains attached to the clicked card.
- Auxiliary editor popovers use explicit sizes appropriate to link, audio,
  trigger, map, photo, file-preview, search, and composer content.
- Direct `.sheet` calls remain only in iPhone-compiled source.

## Project Structure

```text
sparky/
├── Extensions/
│   └── View+CardStyle.swift
├── Views/
│   ├── Desktop/
│   │   ├── DesktopFloatingNavigationBar.swift
│   │   ├── DesktopMemoryEditorPopover.swift
│   │   ├── DesktopRootView.swift
│   │   └── Calendar/
│   │       ├── DesktopDayCalendarView.swift
│   │       └── DesktopMonthDayCell.swift
│   ├── Memories/Calendar/
│   │   └── CalendarMemoryCreationBehavior.swift
│   └── Memories/Editor/
│       ├── MemoryEditorView.swift
│       └── Triggers/Shared/TriggersCard.swift
└── ...

sparkyTests/
└── DesktopNavigationStateTests.swift              # route/state coverage as useful
```

## Implementation Phases

1. **Day mode**
   - Replace Week with Day and add the interactive seven-date selector.
   - Reuse the mobile daily sections without duplicated desktop headers.
2. **Creation behavior**
   - Keep the iPhone callback path unchanged.
   - Anchor the existing desktop popover to each empty Day period.
3. **Month integration**
   - Preserve the 42-cell Month presentation and all-day popover.
   - Open Day when the user selects a Month date.
4. **Cleanup**
   - Remove Week-grid-only views, exact timestamp target handling, and tests.
   - Update the specification and acceptance matrix.
5. **Validation**
   - Add focused route/schedule tests where logic changes.
   - Perform static parse/reference/diff checks in-agent.
   - Leave build, tests, launch, and visual acceptance to Erick per repository rules.
6. **Popover-only Mac cleanup**
   - Replace root and shared Mac sheet presentations with popovers.
   - Move Memory item preview/edit presentation state to the clicked item.
   - Verify no direct Mac sheet presentation remains.

## Validation Boundary

The implementation agent may inspect files, run static parsing, lint where
allowed, and use `git diff --check`. It must not build, test, launch, serve, or
preview the app. Erick should run the exact Xcode commands and visual scenarios
in [quickstart.md](quickstart.md).

## Complexity Tracking

No violations. One creation-behavior boundary is smaller and safer than
duplicating the mobile daily sections or attaching one inaccurate popover to
the Calendar container.
