# Tasks: Cross-Platform Experience Polish

**Input**: Design documents from
`/specs/005-polish-cross-platform-experience/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`,
`contracts/`, `quickstart.md`

**Tests**: The specification and plan require behavioral coverage. Test tasks
appear before their corresponding implementation tasks and use Swift Testing
unless a manual platform interaction is required.

**Organization**: Tasks are grouped by user story so each story can be
implemented and validated independently.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel after its stated prerequisites are complete
- **[Story]**: Maps the task to its user story
- Every task includes the exact affected file path or paths

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Protect the active feature context and confirm how new shared
files and resources join the existing Xcode targets.

- [X] T001 Confirm `.specify/feature.json` still selects `specs/005-polish-cross-platform-experience` and inspect `git status --short` before editing so unrelated workspace changes are preserved
- [X] T002 [P] Confirm `sparky.xcodeproj/project.pbxproj` still uses `PBXFileSystemSynchronizedRootGroup` for `sparky/` and `sparkyTests/`, including automatic membership for planned Swift files and `sparky/Resources/FocusSounds/`

---

## Phase 2: Foundational (Blocking Guard)

**Purpose**: Establish a clean static baseline before any story changes.

**⚠️ CRITICAL**: Complete this guard before beginning a user story.

- [X] T003 Run `git diff --check`, inspect the currently modified files, and record any pre-existing static blocker in `specs/005-polish-cross-platform-experience/quickstart.md` without building or launching the app

**Checkpoint**: The current feature scope and validation boundary are known.
No shared model, migration, backend, dependency, or theme infrastructure is
required before the stories can proceed.

---

## Phase 3: User Story 1 - Predictable Desktop Navigation and Layout (Priority: P1) 🎯 MVP

**Goal**: Give Calendar Day, Mind, Focus, and Me one centered desktop content
width; return Mind and Me to root on tab reselection; preserve Calendar and
Focus state; hide the Calendar Day scrollbar without disabling scrolling.

**Independent Test**: On Mac at 980×680, 1100×720, and full screen, compare all
scoped content columns, navigate deeply into Mind and Me, reselect each tab,
preserve non-default Calendar and active Focus state, and scroll a long
Calendar Day without seeing a vertical scrollbar.

### Tests for User Story 1

> Write these tests first. The user-run Xcode command in `quickstart.md`
> confirms the expected failing behavior before implementation.

- [X] T004 [US1] Extend `sparkyTests/DesktopNavigationStateTests.swift` with full-path reset, idempotent root, transient Mind search/context cleanup, Calendar date/mode preservation, and Focus no-mutation cases

### Implementation for User Story 1

- [X] T005 [US1] Add `DesktopLayoutMetrics.primaryContentMaxWidth = 880` in `sparky/Views/Desktop/DesktopLayoutMetrics.swift`
- [X] T006 [US1] Implement `returnToRoot(of:)` and its Mind, Me, Calendar, and Focus state rules in `sparky/Views/Desktop/DesktopNavigationState.swift`
- [X] T007 [US1] Route new selections and same-tab reselections through the navigation state while preserving animation and keyboard shortcuts in `sparky/Views/Desktop/DesktopFloatingNavigationBar.swift` and `sparky/Views/Desktop/DesktopRootView.swift`
- [X] T008 [P] [US1] Apply the shared width to Calendar Day and pass permanent vertical indicator visibility without changing the Month grid or iPhone default in `sparky/Views/Desktop/Calendar/DesktopDayCalendarView.swift` and `sparky/Views/Memories/Calendar/CalendarDayContentView.swift` (depends on T005)
- [X] T009 [P] [US1] Apply the shared centered width, including internal padding, to Mind overview and detail in `sparky/Views/Minds/MindsTab.swift` and `sparky/Views/Minds/MindDetailView.swift` (depends on T005)
- [X] T010 [P] [US1] Apply the shared centered width to the desktop Focus canvas without constraining its full-window background in `sparky/Views/Focus/FocusCanvasView.swift` (depends on T005)
- [X] T011 [P] [US1] Replace the Me width literal and correct padding/frame order so the full desktop content footprint stays within 880 points in `sparky/Views/Settings/MeView.swift` (depends on T005)

**Checkpoint**: User Story 1 has focused tests and static source validation, and
the Mac runtime acceptance steps can be handed to the user from
`quickstart.md`.

---

## Phase 4: User Story 2 - Read the Me Dashboard Without Explanatory Copy (Priority: P1)

**Goal**: Keep the three Me cards visible in every data state, remove visible
explanatory prose, and distinguish unavailable metrics from measured zero on
iPhone and Mac.

**Independent Test**: Open Me with no Memories, active-only Memories, populated
completion history, no eligible scheduled occurrence, insufficient rhythm,
and tied rhythm; confirm the same card structure remains, unavailable values
show `—`, and VoiceOver retains full descriptions.

### Tests for User Story 2

> Write these tests first. The user-run Xcode command in `quickstart.md`
> confirms the expected failing presentation assertions before implementation.

- [X] T012 [US2] Add presentation assertions for valid zero, unavailable scheduled completion, insufficient rhythm, and tied rhythm in `sparkyTests/MeMetricsTests.swift`

### Implementation for User Story 2

- [X] T013 [US2] Add focused display helpers for percentage, period, weekday, dash, and `Not available` accessibility text in `sparky/Views/Settings/MeMetrics+Presentation.swift`
- [X] T014 [P] [US2] Change Weekly Spark to `N completed`, keep Scheduled completion visible, and render `—` for an unavailable rate in `sparky/Views/Settings/WeeklySparkCard.swift` (depends on T013)
- [X] T015 [P] [US2] Remove the visible selected-day sentence while preserving the seven-day chart, selection affordance, legend, and per-day accessibility values in `sparky/Views/Settings/WeeklyActivityCard.swift`
- [X] T016 [P] [US2] Always render Most active period and Best completion day, use `—` for unavailable values, and remove learning, insight, and duplicate scheduled-completion prose in `sparky/Views/Settings/WeeklyRhythmCard.swift` (depends on T013)
- [X] T017 [US2] Remove the page subtitle and update compact card inputs while preserving all three cards and the US1 desktop width in `sparky/Views/Settings/MeView.swift` (depends on T011, T014, T015, T016)
- [X] T018 [US2] Update no-memory, active-only, unavailable-rate, tied-rhythm, and populated SwiftUI fixtures in `sparky/Views/Settings/MeView.swift`, `sparky/Views/Settings/WeeklySparkCard.swift`, and `sparky/Views/Settings/WeeklyRhythmCard.swift`

**Checkpoint**: User Story 2 is independently testable on iPhone and Mac with a
stable three-card hierarchy and no replacement empty state.

---

## Phase 5: User Story 3 - Hear and Control Focus Feedback (Priority: P1)

**Goal**: Provide independent Focus notification and sound controls, separate
testable completion sounds, and exactly one non-blocking cue for each effective
timer event on iPhone and Mac.

**Independent Test**: Exercise all four notification/sound toggle combinations,
start, pause, resume, end, complete Focus and Break phases, test both pickers,
deny notification permission, relaunch, and reset defaults without changing
timer behavior.

### Tests for User Story 3

> Write these tests first. Use spies and isolated `UserDefaults` suites; do not
> post real notifications or play real audio in unit tests. The user-run Xcode
> command in `quickstart.md` confirms the initial failing state.

- [X] T019 [P] [US3] Create defaults, persistence, invalid-raw-value fallback, and Reset to Defaults coverage in `sparkyTests/Focus/FocusSettingsFeedbackTests.swift`
- [X] T020 [P] [US3] Create the four-toggle matrix, selected sound, preview, exactly-once, and adapter-failure coverage with sound and notification spies in `sparkyTests/Focus/FocusFeedbackServiceTests.swift`
- [X] T021 [P] [US3] Add silent notification-content and Focus-specific enablement coverage in `sparkyTests/Focus/FocusNotificationServiceTests.swift`
- [X] T022 [P] [US3] Create start/resume, pause, end, phase completion, manual-next-phase, no-op, extension, duration-change, replacement, and auto-continue-off event coverage in `sparkyTests/Focus/FocusTimerFeedbackTests.swift`, and replace concrete notification dependencies in `sparkyTests/Focus/FocusTimerTests.swift`, `sparkyTests/Focus/FocusQuickDurationTests.swift`, `sparkyTests/Focus/FocusSessionReplaceTests.swift`, and `sparkyTests/Focus/FocusTimerExtendTests.swift`

### Implementation for User Story 3

- [X] T023 [P] [US3] Define the shared event, sound catalog, and injected protocol contracts in `sparky/Focus/FocusFeedbackEvent.swift`, `sparky/Focus/FocusSoundChoice.swift`, `sparky/Focus/FocusFeedbackHandling.swift`, `sparky/Focus/FocusSoundPlaying.swift`, and `sparky/Focus/FocusNotificationSending.swift`
- [X] T024 [P] [US3] Persist Focus-only notification, sound, Focus-completion, and Break-completion preferences with Glass/Bell defaults and reset behavior in `sparky/Focus/FocusSettings.swift`
- [X] T025 [P] [US3] Add original, brief, non-looping `start.caf`, `pause.caf`, `end.caf`, `glass.caf`, `bell.caf`, `chime.caf`, `ping.caf`, and `pop.caf` assets in `sparky/Resources/FocusSounds/`
- [X] T026 [P] [US3] Implement cross-platform AVFoundation playback, ambient iPhone mixing, preparation, single-player ownership, preview, and non-fatal failure logging in `sparky/Focus/FocusSoundService.swift` (depends on T023, T025)
- [X] T027 [P] [US3] Refactor Focus completion notifications behind `FocusNotificationSending`, gate only on Focus preferences, and force silent notification content in `sparky/Focus/FocusNotificationService.swift` (depends on T023, T024)
- [X] T028 [US3] Implement exactly-once event coordination, toggle independence, sound selection, silent completion banners, and preview dispatch in `sparky/Focus/FocusFeedbackService.swift` (depends on T023, T024, T026, T027)
- [X] T029 [US3] Inject `FocusFeedbackHandling`, separate silent internal stop/reset/replacement mechanics from public commands, and emit only effective feedback events in `sparky/Focus/FocusTimer.swift` (depends on T023, T028)
- [X] T030 [US3] Construct and retain the sound, notification, and feedback services and update timer/preview dependency wiring in `sparky/AppEnvironment.swift` and `sparky/Views/Focus/FocusCanvasView.swift` (depends on T026, T027, T028, T029)
- [X] T031 [US3] Add concise Feedback toggles, completion pickers, Test actions, disabled sound controls, preview wiring, and reset integration on both settings entry points in `sparky/Views/Settings/FocusSettingsView.swift`, `sparky/Views/Settings/SettingsView.swift`, `sparky/Views/Settings/MeView.swift`, and `sparky/Views/Desktop/DesktopSettingsView.swift` (depends on T024, T030)

**Checkpoint**: User Story 3 is independently complete when settings persist,
the timer emits the expected event sequence, feedback failures remain isolated,
and the user can perform the runtime audio/notification matrix from
`quickstart.md`.

---

## Phase 6: User Story 4 - Complete a Memory Reliably From Desktop Preview (Priority: P1)

**Goal**: Match mobile completion symbols, make the complete visible circle
clickable, and prevent failed saves from leaving a misleading preview state.

**Independent Test**: From a Mac preview, click the center and outer visible
edge of every round action, complete and reopen a Memory, reopen the preview to
confirm persistence, and force a save failure to verify authoritative rollback.

### Tests for User Story 4

> Write these tests first. The user-run Xcode command in `quickstart.md`
> confirms the current icon mapping and failure behavior do not satisfy them.

- [X] T032 [P] [US4] Add active/completed symbol and accessibility-action mapping coverage in `sparkyTests/DesktopMemoryPreviewStatusTests.swift`
- [X] T033 [P] [US4] Add optimistic status/checklist toggle, successful persistence, repeat-activation blocking, and failure recovery coverage in `sparkyTests/MemoryEditorViewModelStatusTests.swift`

### Implementation for User Story 4

- [X] T034 [P] [US4] Refactor all action-bar buttons to a reusable 44×44 circular label and matching `contentShape(Circle())` while preserving disabled, focus, help, role, and accessibility behavior in `sparky/Views/Desktop/DesktopPopoverActionBar.swift`
- [X] T035 [US4] Add a ViewModel-owned optimistic toggle-and-save operation that snapshots status/checklist drafts and reloads or restores authoritative state on failure in `sparky/ViewModels/MemoryEditorViewModel.swift`
- [X] T036 [US4] Map active to `circle` and completed to `checkmark.circle.fill`, call the transactional ViewModel operation, and retain existing error presentation in `sparky/Views/Memories/Editor/MemoryEditorView.swift` (depends on T034, T035)

**Checkpoint**: User Story 4 is independently testable from the desktop preview
without changing the iPhone preview or broader editor flow.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Apply the constitutional UI, accessibility, performance, and
multiplatform gates across the completed stories.

- [X] T037 [P] Audit semantic colors, Dynamic Type, reduced motion, accessible labels/values/traits, keyboard focus, and pointer affordances in `sparky/Views/Desktop/DesktopFloatingNavigationBar.swift`, `sparky/Views/Desktop/DesktopPopoverActionBar.swift`, `sparky/Views/Settings/MeView.swift`, `sparky/Views/Settings/WeeklySparkCard.swift`, `sparky/Views/Settings/WeeklyActivityCard.swift`, `sparky/Views/Settings/WeeklyRhythmCard.swift`, and `sparky/Views/Settings/FocusSettingsView.swift`
- [X] T038 [P] Add or verify the required iPhone-only AVAudioSession guards, keep AVAudioPlayer shared, and confirm all sound assets remain in both synchronized app targets in `sparky/Focus/FocusSoundService.swift`, `sparky/AppEnvironment.swift`, and `sparky.xcodeproj/project.pbxproj`
- [X] T039 [P] Review Calendar Day virtualization and input behavior plus Focus audio preparation and failure paths for main-thread or repeated-work regressions in `sparky/Views/Memories/Calendar/CalendarDayContentView.swift`, `sparky/Views/Desktop/Calendar/DesktopDayCalendarView.swift`, and `sparky/Focus/FocusSoundService.swift`
- [X] T040 Re-run source-only checks, `git diff --check`, focused identifier searches, and the Spec Kit prerequisite check, then update any stale expected result in `specs/005-polish-cross-platform-experience/quickstart.md`
- [X] T041 Prepare the final handoff with the unexecuted iPhone test/build and Mac build commands plus manual window, scrollbar, Me, Focus, preview, appearance, keyboard, and VoiceOver scenarios from `specs/005-polish-cross-platform-experience/quickstart.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies.
- **Foundational Guard (Phase 2)**: Depends on Phase 1 and blocks story edits.
- **User Stories (Phases 3–6)**: Start after T003.
- **Polish (Phase 7)**: Starts after every story selected for delivery is
  complete.

### User Story Dependencies

- **US1 (P1)**: Starts after T003. T005 precedes the four parallel width tasks;
  T006 precedes T007.
- **US2 (P1)**: Starts after T003. T013 precedes T014 and T016; T017 integrates
  the card changes. If US1 is also active, T011 precedes T017 because both touch
  `MeView.swift`.
- **US3 (P1)**: Starts after T003 and has no behavioral dependency on another
  story. Tests T019–T022 come first; contracts/settings/assets T023–T025 can
  then proceed in parallel; adapters T026–T027 precede coordinator T028; T029
  and T030 complete timer integration before T031. If US2 is active, merge T017
  before T031 because both touch `MeView.swift`.
- **US4 (P1)**: Starts after T003 and has no dependency on another story.
  Tests T032–T033 come first; T034 and T035 can then proceed in parallel before
  T036 integrates them.

### Story Completion Order

```text
Setup -> Foundational Guard
                    ├── US1 Desktop shell ──┐
                    ├── US2 Me dashboard ───┤
                    ├── US3 Focus feedback ─┼── Polish
                    └── US4 Memory preview ─┘
```

US1 and US2 require file-level coordination only for `MeView.swift`; their
acceptance behavior remains independently testable.

### Within Each User Story

- Write the listed tests first; the user confirms red/green behavior with the
  Xcode commands in `quickstart.md`.
- Add value types and protocols before services.
- Add adapters before integration wiring.
- Complete core behavior before previews and manual handoff.
- Stop at the checkpoint and validate the story independently.

## Parallel Opportunities

- T002 can run independently from T001.
- After T005, T008–T011 can run in parallel.
- After T013, T014–T016 can run in parallel.
- T019–T022 can be authored in parallel.
- After those test tasks, T023–T025 can run in parallel.
- After T023–T025, T026 and T027 can run in parallel.
- T032 and T033 can run in parallel; T034 and T035 can run in parallel after
  their tests.
- T037–T039 can run in parallel after the selected stories are complete.
- US1, US3, and US4 can run concurrently after T003. US2 can also run
  concurrently if the `MeView.swift` ownership boundary with T011 is agreed.

## Parallel Example: User Story 1

```text
After T005:
Task T008: Calendar Day width and indicator visibility
Task T009: Mind overview and detail width
Task T010: Focus canvas width
Task T011: Me dashboard width
```

## Parallel Example: User Story 2

```text
After T013:
Task T014: Weekly Spark presentation
Task T015: Activity presentation
Task T016: Rhythm presentation
```

## Parallel Example: User Story 3

```text
First test wave:
Task T019: Focus settings persistence tests
Task T020: Feedback coordinator tests
Task T021: Notification content tests
Task T022: Timer event tests

After T023-T025:
Task T026: AVFoundation sound adapter
Task T027: UserNotifications adapter
```

## Parallel Example: User Story 4

```text
First test wave:
Task T032: Status symbol contract tests
Task T033: Transactional status persistence tests

Implementation wave:
Task T034: Circular action hit areas
Task T035: ViewModel transaction and recovery
```

## Implementation Strategy

### MVP First: User Story 1

1. Complete T001–T003.
2. Complete T004–T011.
3. Stop and validate the desktop width, navigation, preserved state, and
   scrollbar behavior independently.
4. Hand the Mac runtime checks in `quickstart.md` to the user.

### Incremental Delivery

1. **US1**: Stabilize the desktop shell.
2. **US2**: Simplify Me without changing metric calculation.
3. **US3**: Add Focus preferences, adapters, timer events, and settings UI.
4. **US4**: Correct desktop preview hit areas and durable completion feedback.
5. Complete Phase 7 and hand off both destination commands and manual checks.

Each story remains a usable increment. All are P1 in the specification; the
order above minimizes shared-file conflicts and integration risk.

### Parallel Team Strategy

After T003:

- Stream A: US1, then the `MeView.swift` portion of US2.
- Stream B: US3 through T030, then T031 after Stream A releases
  `MeView.swift`.
- Stream C: US4.
- US2 card work can proceed independently while Stream A owns `MeView.swift`.

## Notes

- Do not add a new backend, account, data migration, third-party package, or
  parallel iPhone/Mac feature tree.
- Keep app strings, identifiers, logs, comments, tests, and technical docs in
  English.
- Preserve the approved centered desktop navigation and bottom-right
  `brain.fill` creation action.
- Do not replace `List` unless `.scrollIndicators(.never)` fails the documented
  runtime check; a thin AppKit adapter is the fallback, not the initial task.
- Do not run build, launch, serve, preview, or app-execution commands in the
  agent workflow. Use the exact user-run commands in `quickstart.md`.
- Preserve unrelated dirty-worktree changes and make the smallest safe edit in
  mixed files.
