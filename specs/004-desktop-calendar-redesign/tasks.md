# Tasks: Desktop Calendar Redesign

## Shell and navigation

- [x] T001 Remove the desktop sidebar and `NavigationSplitView`.
- [x] T002 Expose Calendar, Mind, Focus, and Me through `DesktopSection`.
- [x] T003 Add the floating mobile-style navigation and Command-1 through Command-4.
- [x] T004 Add the unified toolbar and Search outside Me.
- [x] T005 Keep New Mind contextual within Mind.
- [x] T006 Preserve Memory and Focus deep-link routing.
- [x] T022 Move New Memory to a bottom-trailing `brain.fill` action while
  retaining Command-N.
- [x] T023 Remove the automatic Mac window title without removing contextual titles.
- [x] T024 Make toolbar and bottom chrome inherit the active section surface.
- [x] T025 Make Week/Month compact and keep global toolbar actions trailing.
- [x] T026 Reuse the mobile `mind` and `me` assets in the centered navigation.
- [x] T027 Use three Mind columns on Mac while preserving two on iPhone.

## Calendar

- [x] T007 Add Week/Month-only desktop mode and shared anchor date.
- [x] T008 Add locale-aligned week and fixed 42-cell month calculations.
- [x] T009 Add lazy occurrence loading and concrete occurrence queries.
- [x] T010 Implement fixed Week headers/all-day area and scrollable hourly grid.
- [x] T011 Implement 42-cell Month with compact events and overflow.
- [x] T012 Add exact timed and all-day quick-add targets.
- [x] T013 Add deterministic simultaneous-occurrence grouping.

## Profile and Settings

- [x] T014 Add full-library Memory search popover.
- [x] T015 Reuse Me as a direct primary dashboard without a menu or sheet.
- [x] T016 Add native Settings tabs without App Icon and open them from Me.

## Tests and documentation

- [x] T017 Add layout, DST, year-boundary, mode, quick-add, occurrence, and
  desktop navigation tests.
- [x] T018 Add this superseding specification and contract.
- [ ] T019 Run the Mac and iPhone build/test matrix locally.
- [ ] T020 Inspect Week/Month in light/dark and required window sizes.
- [ ] T021 Complete keyboard-focus and VoiceOver acceptance.

## User Story 5 — Unified New Memory popover

**Goal**: Present the same native New Memory popover from the global
`brain.fill` action and desktop Calendar creation anchors.

**Independent test**: Open creation from the global button, a Week hour cell,
and a Month day; confirm identical editor content, source-anchored arrows,
correct Calendar schedule context, Liquid Glass toggle sections, and unchanged
preview/edit and iPhone behavior.

- [x] T028 [US5] Add the shared Mac popover wrapper in `sparky/Views/Desktop/DesktopMemoryEditorPopover.swift`.
- [x] T029 [US5] Add the desktop-popover presentation mode and grouped glass container in `sparky/Views/Memories/Editor/MemoryEditorView.swift`.
- [x] T030 [P] [US5] Add the conditional interactive glass section treatment in `sparky/Extensions/View+CardStyle.swift`.
- [x] T031 [US5] Apply the conditional section treatment to schedule/location sections in `sparky/Views/Memories/Editor/Triggers/Shared/TriggersCard.swift`.
- [x] T032 [US5] Anchor the shared popover to the global create action while preserving Command-N in `sparky/Views/Desktop/DesktopFloatingNavigationBar.swift` and `sparky/Views/Desktop/DesktopRootView.swift`.
- [x] T033 [P] [US5] Route Week hour creation through the shared popover with its exact schedule in `sparky/Views/Desktop/Calendar/DesktopCalendarHourCell.swift`.
- [x] T034 [P] [US5] Route Month day creation through the shared popover with its all-day schedule in `sparky/Views/Desktop/Calendar/DesktopMonthDayCell.swift`.
- [x] T035 [US5] Remove the desktop Calendar `QuickMemorySheet` presentation path while preserving iPhone behavior in `sparky/Views/Desktop/DesktopRootView.swift` and `sparky/Views/Desktop/Calendar/DesktopCalendarView.swift`.
- [x] T036 [US5] Verify popover route and schedule initialization references with static source inspection across `sparky/Views/Desktop/` and `sparky/Views/Memories/Editor/`.
- [x] T037 [US5] Run allowed static parse and diff validation and record remaining manual acceptance in `specs/004-desktop-calendar-redesign/quickstart.md`.

## Dependencies

- T028-T031 establish the reusable popover and visual mode.
- T032 depends on T028-T030.
- T033 and T034 depend on T028-T031 and can be implemented in parallel.
- T035 follows the Calendar anchor integrations.
- T036-T037 follow all implementation tasks.

## Incremental strategy

1. Complete the shared presenter and editor presentation mode.
2. Prove the global `brain.fill` source independently.
3. Integrate Week and Month sources.
4. Remove only the superseded desktop quick-sheet path.
5. Perform static validation, then leave runtime acceptance to the local Xcode
   workflow.
