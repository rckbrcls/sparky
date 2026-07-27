# Implementation Plan: Desktop Calendar Redesign

**Branch**: `master` | **Date**: 2026-07-27 | **Spec**: [spec.md](spec.md)

**Input**: Extend the implemented desktop shell so global and Calendar New
Memory creation share one native popover modeled on Apple Reminders and
Calendar.

## Summary

Keep the existing shared `MemoryEditorView`, drafts, services, Calendar target,
and desktop shell. Add one Mac-specific New Memory popover presentation that
can be attached to either the bottom `brain.fill` action or a Calendar
date/time creation anchor. Introduce a desktop-popover visual mode in the
shared editor: the native popover provides the root material, while editable
toggle sections use grouped interactive Liquid Glass instead of opaque cards.

## Technical Context

**Language/Version**: Swift 6, SwiftUI 26, default MainActor isolation  
**Primary Dependencies**: SwiftUI, SwiftData, Combine; no new dependency  
**Storage**: Existing SwiftData models and local attachment store; no schema change  
**Testing**: Swift Testing plus manual macOS presentation acceptance  
**Target Platform**: macOS 26 for this presentation edge; shared iPhone code unchanged  
**Project Type**: Native multiplatform Apple app in one Xcode project  
**Performance Goals**: Popover opens immediately; editor scrolling and Calendar
interaction remain responsive  
**Constraints**: Native `.popover`, existing `MemoryEditorRoute`,
`CalendarQuickMemoryTarget`, semantic theme, draft/service save path, no AppKit bridge  
**Scale/Scope**: One reusable popover surface, two source families (global and
Calendar), existing editor sections and schedule draft

## Constitution Check

- [x] **I. HIG / native feel**: native macOS popover and Liquid Glass; pointer,
      keyboard, accessibility, light/dark, and window fit are acceptance gates.
- [x] **II. Semantic theme**: existing semantic colors remain; no ad-hoc fill
      replaces the native popover material.
- [x] **III. Modern SwiftUI**: source controls emit a create route; the shared
      editor retains draft ownership and service-mediated save.
- [x] **IV. Performance**: popover content is created only while presented;
      Calendar occurrence loading is unchanged.
- [x] **V. Local-first architecture**: no model, service, executor, backend, or
      persistence change.
- [x] **VI. One code, two builds**: presentation divergence is Mac-only;
      editor logic remains shared and iPhone behavior is explicitly preserved.
- [x] **Complexity**: no constitutional violation or waiver required.

Post-design check: passed. The design uses the existing editor, route, schedule
draft, and service path, with one justified Mac presentation wrapper.

## Existing Architecture Preserved

- `DesktopRootView` remains the desktop presentation coordinator.
- `DesktopFloatingNavigationBar` remains the anchor for the global action.
- `DesktopCalendarView` keeps Week/Month state and `CalendarDataManager`.
- `CalendarQuickMemoryTarget.scheduleDraft()` remains the only conversion from
  a clicked Calendar location to an initial schedule draft.
- `MemoryEditorViewModel` and `MemoryService` remain the only durable save path.
- Memory preview/edit remains on `nav.editorRoute` sheets.
- iPhone continues using its current quick-add and editor presentation.

## Planned Presentation Architecture

### 1. One popover content implementation

Add a focused Mac-only `DesktopMemoryEditorPopover` view (or equivalently
scoped presentation modifier) that accepts:

- `AppEnvironment`
- an existing `MemoryEditorRoute` in create mode
- the preferred native arrow behavior for its source

It embeds `MemoryEditorView` with a desktop-popover presentation style and owns
only presentation chrome. It must not duplicate editor fields, validation, or
save logic.

### 2. Two anchor families, one editor

| Source | Initial route | Native anchor behavior |
|---|---|---|
| Bottom `brain.fill` / Command-N | Blank create route with current Mind context | Attached to the bottom action; opens above when space allows |
| Week hour cell | Create route with exact `scheduleDraft()` timestamp | Attached to the clicked hour cell; system selects the viable side |
| Month day add | Create route with all-day `scheduleDraft()` | Attached to the clicked day affordance; system selects the viable side |

Each source holds only the minimal ephemeral route needed for its own anchor.
All sources render the same `DesktopMemoryEditorPopover`.

### 3. Calendar flow replacement

Replace the desktop path:

```text
Calendar anchor -> DesktopRootView -> QuickMemorySheet -> optional editor
```

with:

```text
Calendar anchor -> create MemoryEditorRoute with CalendarQuickMemoryTarget
                -> DesktopMemoryEditorPopover at that anchor
                -> MemoryEditorViewModel save -> MemoryService
```

The iPhone `QuickMemorySheet` remains available and unchanged.

### 4. Popover-specific editor surface

Add an explicit presentation-style input to `MemoryEditorView`, defaulting to
the current standard behavior. In the Mac popover style:

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

### 5. Size and interaction

- Use a dense inspector-like width near 480 pt.
- Bound vertical size for the supported desktop window range and keep the
  editor content scrollable.
- Keep Cancel and Create visible through the existing toolbar.
- Focus the title for a new draft.
- Outside-click and Cancel dismiss without saving.
- Create dismisses only after the existing save succeeds.
- Command-N opens the global anchor; Calendar clicks open only their own anchor.

## Project Structure

```text
sparky/
├── Extensions/
│   └── View+CardStyle.swift
├── Views/
│   ├── Desktop/
│   │   ├── DesktopFloatingNavigationBar.swift
│   │   ├── DesktopMemoryEditorPopover.swift       # planned
│   │   ├── DesktopRootView.swift
│   │   └── Calendar/
│   │       ├── DesktopCalendarHourCell.swift
│   │       └── DesktopMonthDayCell.swift
│   └── Memories/Editor/
│       ├── MemoryEditorView.swift
│       └── Triggers/Shared/TriggersCard.swift
└── ...

sparkyTests/
└── DesktopNavigationStateTests.swift              # route/state coverage as useful
```

## Implementation Phases

1. **Shared presenter**
   - Add the reusable Mac popover content/presentation wrapper.
   - Define the editor presentation style with the current behavior as default.
2. **Global source**
   - Anchor the popover to `brain.fill`.
   - Preserve current Mind context, tooltip, accessibility label, and Command-N.
3. **Calendar sources**
   - Route Week-hour and Month-day creation directly to the shared popover.
   - Seed the schedule from `CalendarQuickMemoryTarget.scheduleDraft()`.
   - Remove only the desktop Calendar dependency on `QuickMemorySheet`.
4. **Liquid Glass sections**
   - Remove opaque section fills only in the Mac popover mode.
   - Group interactive glass surfaces in one `GlassEffectContainer`.
5. **Validation**
   - Add focused route/schedule tests where logic changes.
   - Perform static parse/reference/diff checks in-agent.
   - Leave build, tests, launch, and visual acceptance to Erick per repository rules.

## Validation Boundary

The implementation agent may inspect files, run static parsing, lint where
allowed, and use `git diff --check`. It must not build, test, launch, serve, or
preview the app. Erick should run the exact Xcode commands and visual scenarios
in [quickstart.md](quickstart.md).

## Complexity Tracking

No violations. A single Mac presentation wrapper is smaller and safer than
duplicating the editor for the global and Calendar sources or introducing an
AppKit panel.
