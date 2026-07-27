# Implementation Plan: Cross-Platform Experience Polish

**Branch**: `master` | **Date**: 2026-07-27 | **Spec**: [spec.md](spec.md)

**Feature Context**: `005-polish-cross-platform-experience`

**Input**: Feature specification from
`/specs/005-polish-cross-platform-experience/spec.md`

## Summary

Polish the shared iPhone and Mac experience while preserving Sparky's
local-first architecture. The implementation will establish one 880-point
desktop content-width token, make desktop tab reselection clear only the
selected destination's navigation path, permanently hide the Calendar Day
scroll indicator, simplify Me to stable metric cards, add independently
configurable Focus notifications and sounds, and make the desktop Memory
preview status action reliable across its full circular hit area.

Focus feedback will be coordinated through injected notification and sound
adapters. Completion notifications remain silent so the selected in-app sound
is the only audible completion cue. Cross-platform sounds will use short
bundled assets through AVFoundation rather than macOS-only system sound names.

## Technical Context

**Language/Version**: Swift with the Xcode 26 toolchain; SwiftUI;
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`

**Primary Dependencies**: SwiftUI, Combine, SwiftData, UserNotifications,
AVFoundation; no new third-party dependency

**Storage**: Existing SwiftData store remains unchanged. New Focus feedback
preferences persist in `UserDefaults` through `FocusSettings`.

**Testing**: Swift Testing (`import Testing`) for settings, feedback dispatch,
timer transitions, metrics presentation, and desktop navigation; existing
XCTest UI target plus manual iPhone and Mac acceptance checks

**Target Platform**: iPhone on iOS 26.0+ and Mac on macOS 26.0+

**Project Type**: Native multiplatform Apple app with shared sources in one
Xcode project and separate `sparky` and `sparkyMac` destinations

**Performance Goals**: Tab reselection and preview feedback appear within one
second; Focus feedback never blocks timer transitions; Calendar Day scrolling
remains fluid at representative local data volume

**Constraints**: Offline-capable; no account or backend; semantic theme only;
no change to the approved desktop shell; no SwiftData migration; no hidden Me
dashboard; desktop-only behavior must not alter the iPhone shell

**Scale/Scope**: Four desktop destinations, three Me cards, five Focus feedback
events, five selectable completion sounds, two persisted completion-sound
choices, and one desktop preview action bar

## Constitution Check

*GATE: Passed before Phase 0 and re-checked after Phase 1 design.*

### Pre-Research Gate

- [x] **I. HIG / native feel**: Layout remains adaptive; desktop pointer,
      keyboard, and focus behavior is explicit; iPhone keeps its native shell.
- [x] **II. Semantic theme**: No new chrome colors are required. Existing
      `Color.Theme` tokens and modifiers remain the visual source of truth.
- [x] **III. Modern SwiftUI**: Navigation stays container-owned, views remain
      declarative, and durable Memory writes remain service-mediated.
- [x] **IV. Performance**: Calendar keeps `List`; feedback adapters fail softly;
      no heavy work moves into a view body.
- [x] **V. Local-first architecture**: Only `UserDefaults` preferences and
      existing local services are used; no backend or schema migration is added.
- [x] **VI. One code, two builds**: Me and Focus remain shared. Mac-specific
      width, tab, scrollbar, and pointer behavior stays at the desktop edge.
- [x] **Complexity**: The design extends existing settings, timer, navigation,
      and action-bar structures without a parallel architecture.

### Post-Design Gate

- [x] Shared Focus protocols isolate UserNotifications and AVFoundation without
      duplicating timer logic by platform.
- [x] Bundled audio assets provide the same named choices on iPhone and Mac;
      no private system sound names or undocumented IDs are used.
- [x] Native `ScrollIndicatorVisibility.never` is used before considering any
      platform bridge, preserving `List` behavior and minimizing complexity.
- [x] Me changes remain presentation-only; existing metric calculation and
      accessibility data stay intact.
- [x] Preview completion uses the existing ViewModel and `MemoryService`, with
      rollback or authoritative reload on failure.

## Project Structure

### Documentation (this feature)

```text
specs/005-polish-cross-platform-experience/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── desktop-experience.md
│   ├── focus-feedback.md
│   └── me-and-memory-preview.md
└── tasks.md                         # Generated later by speckit-tasks
```

### Source Code (repository root)

```text
sparky/
├── AppEnvironment.swift
├── Focus/
│   ├── FocusFeedbackEvent.swift     # Planned shared event vocabulary
│   ├── FocusFeedbackHandling.swift  # Planned timer-facing protocol
│   ├── FocusFeedbackService.swift   # Planned single dispatch coordinator
│   ├── FocusNotificationSending.swift
│   ├── FocusNotificationService.swift
│   ├── FocusSettings.swift
│   ├── FocusSoundChoice.swift       # Planned persisted sound catalog
│   ├── FocusSoundPlaying.swift
│   ├── FocusSoundService.swift      # Planned AVFoundation adapter
│   └── FocusTimer.swift
├── Resources/
│   └── FocusSounds/                 # Planned short cross-platform assets
├── ViewModels/
│   └── MemoryEditorViewModel.swift
└── Views/
    ├── Desktop/
    │   ├── DesktopFloatingNavigationBar.swift
    │   ├── DesktopLayoutMetrics.swift
    │   ├── DesktopNavigationState.swift
    │   ├── DesktopPopoverActionBar.swift
    │   └── Calendar/DesktopDayCalendarView.swift
    ├── Focus/
    │   ├── FocusCanvasView.swift
    │   └── FocusTabView.swift
    ├── Memories/
    │   ├── Calendar/CalendarDayContentView.swift
    │   └── Editor/MemoryEditorView.swift
    ├── Minds/
    │   ├── MindDetailView.swift
    │   └── MindsTab.swift
    └── Settings/
        ├── FocusSettingsView.swift
        ├── MeMetrics+Presentation.swift
        ├── MeView.swift
        ├── WeeklyActivityCard.swift
        ├── WeeklyRhythmCard.swift
        └── WeeklySparkCard.swift

sparkyTests/
├── DesktopNavigationStateTests.swift
├── MeMetricsTests.swift
└── Focus/
    ├── FocusFeedbackServiceTests.swift
    ├── FocusSettingsFeedbackTests.swift
    └── FocusTimerFeedbackTests.swift
```

**Structure Decision**: Keep all domain behavior and shared UI in `sparky/`.
New platform divergence is limited to existing desktop views and one desktop
layout token. File-system-synchronized Xcode groups allow new shared Swift and
resource files to join both app destinations without parallel project trees.

## Design Overview

### Desktop shell

- Centralize `880` as `DesktopLayoutMetrics.primaryContentMaxWidth`.
- Apply the token to Calendar Day, Mind overview/detail, Focus, and Me after
  internal padding; leave Month, chrome, Settings, and popovers unchanged.
- Route destination taps through an explicit selection callback. Reselecting
  Mind clears `mindsPath` and transient Mind context; reselecting Me clears
  `mePath`; Calendar and Focus are idempotent no-ops.
- Pass `.never` for the desktop Calendar Day vertical scroll indicator while
  preserving the current `List` and all scrolling input.

### Me dashboard

- Keep Weekly Spark, Activity, and Your rhythm visible for every data state.
- Remove the header subtitle, selected-day sentence, learning copy, and
  narrative insight.
- Render measured zero as zero and unavailable scheduled/rhythm values as `—`.
- Keep full accessibility values, using “Not available” for the dash.

### Focus feedback

- Add persisted toggles and separate completion-sound selections to
  `FocusSettings`.
- Dispatch effective timer events through one `FocusFeedbackService`.
- Keep notification requests silent and let `FocusSoundService` produce at
  most one cue.
- Split public timer commands from silent internal stop/reset transitions so
  no-op commands, automatic transitions, extension, and duration changes do
  not generate duplicate cues.
- Expose concise picker and Test controls from `FocusSettingsView`.

### Desktop Memory preview

- Use `circle` for active and `checkmark.circle.fill` for completed.
- Give every round action a 44×44 circular interactive shape matching its
  visible surface.
- Persist an optimistic status toggle through the ViewModel; on failure,
  restore authoritative data while retaining the existing error presentation.

## Verification Strategy

- Unit-test pure state and event contracts with spies instead of real
  notifications or audio.
- Keep existing metric calculation tests and add presentation-value assertions.
- Validate desktop layout, permanent indicator hiding, circular hit targets,
  VoiceOver, and audio behavior manually on both destinations.
- Run `git diff --check` and inspect the final diff before build validation.
- Build and runtime commands are documented in [quickstart.md](quickstart.md);
  they are not executed during planning.

## Complexity Tracking

No constitutional violations require an exception.

The Spec Kit installation in this checkout does not contain
`.specify/scripts/bash/update-agent-context.sh`. The required update was
attempted but could not run; the existing `AGENTS.md` already documents the
shared AppEnvironment, Focus, AVFoundation, MainActor, and multiplatform
constraints used by this plan.
