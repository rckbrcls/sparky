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
- [x] T024 Make every desktop destination, toolbar, and bottom chrome inherit
  the shared secondary background.
- [x] T025 Make Day/Month compact and keep global toolbar actions trailing.
- [x] T026 Reuse the mobile `mind` and `me` assets in the centered navigation.
- [x] T027 Use three Mind columns on Mac while preserving two on iPhone.

## Calendar

- [x] T007 Add Day/Month-only desktop mode and shared anchor date.
- [x] T008 Add a locale-aligned Day selector and fixed 42-cell Month calculations.
- [x] T009 Add lazy occurrence loading and concrete occurrence queries.
- [x] T010 Reuse the mobile period-based daily content in the desktop Day mode.
- [x] T011 Implement 42-cell Month with compact events and overflow.
- [x] T012 Add period-based Day and all-day Month quick-add targets.
- [x] T013 Remove the superseded Week grid, exact timestamp target, and layout tests.

## Profile and Settings

- [x] T014 Add full-library Memory search popover.
- [x] T015 Reuse Me as a direct primary dashboard without a menu or sheet.
- [x] T016 Add native Settings tabs without App Icon and open them from Me.

## Tests and documentation

- [x] T017 Add layout, DST, year-boundary, mode, quick-add, occurrence, and
  desktop navigation tests.
- [x] T018 Add this superseding specification and contract.
- [ ] T019 Run the Mac and iPhone build/test matrix locally.
- [ ] T020 Inspect Day/Month in light/dark and required window sizes.
- [ ] T021 Complete keyboard-focus and VoiceOver acceptance.

## User Story 5 — Unified New Memory popover

**Goal**: Present the same native New Memory popover from the global
`brain.fill` action and desktop Calendar creation anchors.

**Independent test**: Open creation from the global button, every empty Day
period, and a Month day; confirm identical editor content, source-anchored
arrows, correct Calendar schedule context, Liquid Glass toggle sections, and
unchanged preview/edit and iPhone behavior.

- [x] T028 [US5] Add the shared Mac popover wrapper in `sparky/Views/Desktop/DesktopMemoryEditorPopover.swift`.
- [x] T029 [US5] Add the desktop-popover presentation mode and grouped glass container in `sparky/Views/Memories/Editor/MemoryEditorView.swift`.
- [x] T030 [P] [US5] Add the conditional interactive glass section treatment in `sparky/Extensions/View+CardStyle.swift`.
- [x] T031 [US5] Apply the conditional section treatment to schedule/location sections in `sparky/Views/Memories/Editor/Triggers/Shared/TriggersCard.swift`.
- [x] T032 [US5] Anchor the shared popover to the global create action while preserving Command-N in `sparky/Views/Desktop/DesktopFloatingNavigationBar.swift` and `sparky/Views/Desktop/DesktopRootView.swift`.
- [x] T033 [P] [US5] Route each empty Day period through the shared popover with its suggested schedule in `sparky/Views/Memories/Calendar/CalendarEmptyPeriodButton.swift`.
- [x] T034 [P] [US5] Route Month day creation through the shared popover with its all-day schedule in `sparky/Views/Desktop/Calendar/DesktopMonthDayCell.swift`.
- [x] T035 [US5] Remove the desktop Calendar `QuickMemorySheet` presentation path while preserving iPhone behavior in `sparky/Views/Desktop/DesktopRootView.swift` and `sparky/Views/Desktop/Calendar/DesktopCalendarView.swift`.
- [x] T036 [US5] Verify popover route and schedule initialization references with static source inspection across `sparky/Views/Desktop/` and `sparky/Views/Memories/Editor/`.
- [x] T037 [US5] Run allowed static parse and diff validation and record remaining manual acceptance in `specs/004-desktop-calendar-redesign/quickstart.md`.

## User Story 6 — Popover-only macOS presentation

**Goal**: Remove sheet presentation from the macOS target while preserving
iPhone presentation behavior.

- [x] T038 [US6] Route root Memory preview/edit, Mind composer, and onboarding
  through native desktop popovers.
- [x] T039 [US6] Make desktop Memory list items own their preview/edit popover
  route and Month event pills own preview routes so the arrow remains attached
  to the selected item.
- [x] T040 [US6] Convert shared editor, trigger, map, search, attachment, and
  composer presentation helpers to sheets on iPhone and popovers on macOS.
- [x] T041 [US6] Add explicit macOS popover sizing for auxiliary surfaces and
  verify direct `.sheet` calls remain iPhone-only.
- [x] T042 [US6] Move desktop New Mind presentation state to the visible button
  so its popover arrow uses the initiating control as its anchor.
- [x] T043 [US6] Remove the desktop Mind composer navigation title bar and use
  the native Liquid Glass popover material with internal glass actions.
- [x] T044 [US6] Move New Mind to a `plus` toolbar item matching iPhone and keep
  its composer popover anchored to that toolbar button.

## Dependencies

- T028-T031 establish the reusable popover and visual mode.
- T032 depends on T028-T030.
- T033 and T034 depend on T028-T031.
- T035 follows the Calendar anchor integrations.
- T036-T037 follow all implementation tasks.
- T038-T041 extend the popover contract to every macOS presentation route.

## Incremental strategy

1. Complete the shared presenter and editor presentation mode.
2. Prove the global `brain.fill` source independently.
3. Integrate Day and Month sources.
4. Remove only the superseded desktop quick-sheet path.
5. Perform static validation, then leave runtime acceptance to the local Xcode
   workflow.
