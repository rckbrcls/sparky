---
description: "Task list for Focus Tab & Memory Pomodoro Configuration"
---

# Tasks: Focus Tab & Memory Pomodoro Configuration

**Input**: Design documents from `/specs/001-focus-tab-pomodoro/`

**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/, quickstart.md

**Tests**: Included — plan.md calls for Swift Testing on recipe resolve, timer recipe binding, and single-session replace rules.

**Organization**: Tasks grouped by user story for independent implementation and validation.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete work)
- **[Story]**: User story label (`[US1]`…`[US4]`) on story-phase tasks only
- Paths are repo-relative from project root

## Path Conventions

- Shared app sources: `sparky/`
- Tests: `sparkyTests/`
- Feature docs: `specs/001-focus-tab-pomodoro/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Scaffold files and Xcode membership so later phases only fill behavior

- [x] T001 Create directory `sparky/Views/Focus/` for tab UI
- [x] T002 [P] Create stub `sparky/Focus/FocusRecipe.swift` with empty `FocusRecipe` struct placeholder
- [x] T003 [P] Create stub `sparky/Views/Focus/FocusTabView.swift` with empty `FocusTabView` placeholder accepting `AppEnvironment`
- [x] T004 [P] Create directory `sparkyTests/Focus/` and stub `sparkyTests/Focus/FocusRecipeTests.swift`
- [x] T005 Add new Swift files from T002–T004 to `sparky.xcodeproj` target membership (`sparky` / `sparkyTests`) so the project compiles with stubs

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Domain recipe, persistence fields, and session engine APIs required by every story

**⚠️ CRITICAL**: No user story UI work depends on incomplete foundation

- [x] T006 Implement `FocusRecipe` value type (minutes fields, seconds helpers, range clamps) in `sparky/Focus/FocusRecipe.swift` per `specs/001-focus-tab-pomodoro/data-model.md` and `contracts/focus-session.md`
- [x] T007 Implement `FocusRecipe.from(settings:)` and `FocusRecipe.resolve(schedule:settings:)` / `resolve(draft:settings:)` (legacy 0-duration → globals) in `sparky/Focus/FocusRecipe.swift`
- [x] T008 Extend `ScheduleConfig` with focus recipe persisted fields (`focusWorkDurationMinutes`, `focusShortBreakDurationMinutes`, `focusLongBreakDurationMinutes`, `focusPomodorosUntilLongBreak`, `focusAutoContinue`) and init wiring in `sparky/Model/Triggers/ScheduleConfig.swift`
- [x] T009 Mirror Focus recipe fields on `ScheduleConfigDraft` including `toModel` / `from` / defaults in `sparky/Model/Triggers/ScheduleConfigDraft.swift`
- [x] T010 Preserve Focus recipe fields in schedule copy/update helpers in `sparky/Services/MemoryService.swift` (search existing `ScheduleConfigDraft` reconstructions)
- [x] T011 Extend export/import DTO optional Focus recipe fields and mapping in `sparky/Model/Export/SparkyExportFormat.swift`
- [x] T012 Refactor `FocusTimer` to bind `activeRecipe`, add `beginQuickSession()` and `beginSession(memoryID:memoryTitle:recipe:)`, drive phase durations from recipe (not live globals mid-session) in `sparky/Focus/FocusTimer.swift`
- [x] T013 Add wall-clock `phaseEndsAt` (or equivalent) so pause/resume/background restore accurate `remainingSeconds` in `sparky/Focus/FocusTimer.swift`
- [x] T014 Update `AppEnvironment.startFocus(for:)` to resolve `FocusRecipe` from memory schedule + `focusSettings` before `beginSession` in `sparky/AppEnvironment.swift`
- [x] T015 [P] Add Swift Testing coverage for recipe resolve (legacy + custom) in `sparkyTests/Focus/FocusRecipeTests.swift`
- [x] T016 [P] Add Swift Testing coverage for timer first-phase duration from recipe and quick session in `sparkyTests/Focus/FocusTimerTests.swift`

**Checkpoint**: Recipe persists on schedule models; timer can start quick/memory sessions with bound recipe; unit tests green for foundation

---

## Phase 3: User Story 1 — Configure pomodoro on a Memory (Priority: P1) 🎯 MVP

**Goal**: Enabling Focus on a scheduled Memory exposes editable pomodoro recipe controls seeded from globals; values save with the Memory and drive Memory-bound sessions.

**Independent Test**: Enable Focus on a scheduled Memory, change work/break values, save, reopen editor → same values; start Focus for that Memory → first phase uses Memory work duration (quickstart Scenario B + start path).

### Tests for User Story 1

- [x] T017 [P] [US1] Add Swift Testing for `ScheduleConfigDraft` ↔ `ScheduleConfig` Focus recipe round-trip in `sparkyTests/Focus/ScheduleConfigFocusRecipeTests.swift`

### Implementation for User Story 1

- [x] T018 [US1] Extend `MemoryEditorViewModel.hasChanges` and load/save paths to include Focus recipe draft fields in `sparky/ViewModels/MemoryEditorViewModel.swift`
- [x] T019 [US1] Update `setFocusEnabled(_:)` to seed full recipe from `environment.focusSettings` when enabling and keep stored values when disabling (`focusEnabled = false` only) in `sparky/ViewModels/MemoryEditorViewModel.swift`
- [x] T020 [US1] Add mutators for per-field Focus recipe edits (work/short/long/untilLong/autoContinue) with clamps matching `FocusSettingsView` ranges in `sparky/ViewModels/MemoryEditorViewModel.swift`
- [x] T021 [US1] Replace Focus toggle-only UI with nested steppers + auto-continue when Focus is on in `sparky/Views/Memories/Editor/Triggers/Shared/TriggersCard.swift`
- [x] T022 [US1] Update Focus caption copy to mention Focus tab + schedule notification in `sparky/Views/Memories/Editor/Triggers/Shared/TriggersCard.swift`
- [x] T023 [US1] Ensure editor Focus start path (`canStartFocusFromEditor` / `environment.startFocus`) uses resolved Memory recipe via foundational `AppEnvironment.startFocus` in `sparky/Views/Memories/Editor/MemoryEditorView.swift` (verify only; fix call site if still bypassing recipe)
- [x] T024 [US1] Optional helper `Memory.focusRecipe(settings:)` (or equivalent) beside `hasFocus` in `sparky/Model/Memory/Memory.swift` if it simplifies editor/service call sites

**Checkpoint**: US1 MVP — per-Memory Focus recipe configurable and persisted; legacy toggle-only still resolves via globals

---

## Phase 4: User Story 2 — Focus tab with quick start (Priority: P1)

**Goal**: New Focus tab idle/active surfaces support Quick Focus using global defaults with full session controls (pause/resume/reset/end).

**Independent Test**: Open Focus tab → Quick Focus → countdown/phase controls → leave tab and return still running → End → idle (quickstart Scenario A).

### Tests for User Story 2

- [x] T025 [P] [US2] Extend timer tests for auto-continue off → `isWaitingForManualStart` after phase end in `sparkyTests/Focus/FocusTimerTests.swift`

### Implementation for User Story 2

- [x] T026 [US2] Add `CustomTab.focus` (label `Focus`, symbol `timer`) and tab order Calendar · Mind · Focus · Me in `sparky/ContentView.swift`
- [x] T027 [US2] Register Focus `Tab` hosting `FocusTabView` with `.tabBarSpacer()` in `sparky/ContentView.swift` (iPhone; guard/hide on Mac per plan)
- [x] T028 [US2] Ensure custom tab bar enumerates the new tab (symbols/labels) in `sparky/ContentView.swift` `CustomTabBarView` and `sparky/Views/Shared/CustomTabBar.swift` if needed
- [x] T029 [US2] Implement Focus tab **idle** state UI: primary Quick Focus CTA, semantic theme, a11y label `Start Quick Focus` in `sparky/Views/Focus/FocusTabView.swift`
- [x] T030 [US2] Wire Quick Focus action to `focusTimer.beginQuickSession()` (recipe from `focusSettings`) in `sparky/Views/Focus/FocusTabView.swift`
- [x] T031 [US2] Extract or reuse session chrome from `sparky/Focus/FocusSessionView.swift` into a shared content view usable by tab and cover (e.g. `FocusSessionContent` in same file or `sparky/Views/Focus/`)
- [x] T032 [US2] Implement Focus tab **active** state embedding session content with explicit **End** (does not end on mere tab switch) in `sparky/Views/Focus/FocusTabView.swift`
- [x] T033 [US2] Fix cover/session dismiss so “Close” does not silently destroy a session the tab should keep — split End vs dismiss in `sparky/Focus/FocusSessionView.swift` and `sparky/ContentView.swift` presentation handlers
- [x] T034 [US2] Honor reduce motion / Dynamic Type on primary Focus controls in `sparky/Views/Focus/FocusTabView.swift` and shared session content

**Checkpoint**: US2 — Focus tab exists; Quick Focus full loop works from tab without any Memory

---

## Phase 5: User Story 3 — Start Focus from a configured Memory via the Focus tab (Priority: P1)

**Goal**: Focus-ready Memories listed on the tab; starting one binds title + Memory recipe; replace confirmation when another session is active; existing notification/editor entry points land on same session model.

**Independent Test**: Focus-enabled Memory appears in list; start → title + custom work duration; try second target → confirm replace (quickstart C–D, F).

### Tests for User Story 3

- [x] T035 [P] [US3] Add Swift Testing for session identity / replace predicate (quick vs memory, A vs B, same id no-op) in `sparkyTests/Focus/FocusSessionReplaceTests.swift`

### Implementation for User Story 3

- [x] T036 [US3] Build Focus target list from `memoryService` memories where `hasFocus` (lazy list, stable ids) in `sparky/Views/Focus/FocusTabView.swift` (or `sparky/Views/Focus/FocusMemoryPickerSection.swift`)
- [x] T037 [US3] Show empty-state hint when no Focus-ready Memories in `sparky/Views/Focus/FocusTabView.swift`
- [x] T038 [US3] On row tap, resolve recipe via `FocusRecipe.resolve` + `beginSession(memoryID:memoryTitle:recipe:)` in `sparky/Views/Focus/FocusTabView.swift`
- [x] T039 [US3] Implement replace-session confirmation alert (Keep current / End & Start) when target identity differs in `sparky/Views/Focus/FocusTabView.swift` per `contracts/focus-tab-ui.md`
- [x] T040 [US3] Add `AppEnvironment` helpers if useful (`canStartNewFocusTarget`, recipe resolve wrapper) without bypassing UI confirm in `sparky/AppEnvironment.swift`
- [x] T041 [US3] Route `pendingFocusOpenRequest` to select Focus tab and join/start session without ending on dismiss in `sparky/ContentView.swift`
- [x] T042 [US3] Verify notification Start Focus + editor Focus still call `startFocus` / pending open and present Focus experience consistently in `sparky/AppEnvironment.swift` and `sparky/ContentView.swift`
- [x] T043 [US3] Optional row subtitle with recipe summary (e.g. work minutes) in Focus target list UI under `sparky/Views/Focus/`

**Checkpoint**: US3 — Memory-bound Focus from tab; single-session replace safe; deep links aligned

---

## Phase 6: User Story 4 — Manage active session and discover Focus in navigation (Priority: P2)

**Goal**: Focus is an obvious first-class tab; active sessions remain reachable after switching tabs; global settings only affect new sessions / newly seeded recipes.

**Independent Test**: Tab bar shows Focus; start session → other tab → back → same session; change global defaults mid-session does not rewrite active recipe (quickstart A continuity + Scenario G smoke).

### Implementation for User Story 4

- [x] T044 [US4] Polish tab bar discoverability (symbol rendering, selection state, accessibility label “Focus”) in `sparky/ContentView.swift` / `sparky/Views/Shared/CustomTabBar.swift`
- [x] T045 [US4] Confirm active session survives `activeTab` changes without reset (regression check; fix any onAppear restart) in `sparky/Views/Focus/FocusTabView.swift` and `sparky/ContentView.swift`
- [x] T046 [US4] Document/verify `FocusSettingsView` only seeds new configs — no write-through to active `FocusTimer.activeRecipe` — in `sparky/Views/Settings/FocusSettingsView.swift` and `sparky/Focus/FocusTimer.swift` (remove settings sink mutations during active session if any remain)
- [x] T047 [US4] Mac fallback: omit or hide Focus tab chrome on non-iOS while keeping shared domain compiling (`#if os(iOS)` or idiom check) in `sparky/ContentView.swift`
- [x] T048 [US4] Optional subtle active-session affordance when user is on another tab (badge/dot only if low-risk; skip if conflicts with custom tab bar) in `sparky/ContentView.swift`

**Checkpoint**: US4 — navigation + continuity feel native on iPhone; Mac safe

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Quality gates across stories

- [x] T049 [P] Semantic theme pass on Focus tab + session + editor Focus form (`Color.Theme.*`, no ad-hoc chrome) in `sparky/Views/Focus/` and `sparky/Views/Memories/Editor/Triggers/Shared/TriggersCard.swift`
- [x] T050 [P] Accessibility pass: VoiceOver labels on Quick Focus, pause/resume, end, phase status, Memory rows; Dynamic Type non-clip in `sparky/Views/Focus/FocusTabView.swift` and session content
- [x] T051 Performance pass: lazy Focus target list; timer ticks must not block other tabs — review `sparky/Focus/FocusTimer.swift` and Focus tab list
- [x] T052 Reduce-motion pass on ring/phase animations in Focus session UI files under `sparky/Focus/` and `sparky/Views/Focus/`
- [x] T053 Run unit test target for Focus tests under `sparkyTests/Focus/` via `xcodebuild test` (or Xcode) and fix failures
- [x] T054 Execute manual quickstart scenarios A–G in `specs/001-focus-tab-pomodoro/quickstart.md` on iPhone Simulator and note gaps
- [x] T055 [P] Update feature status notes if needed in `specs/001-focus-tab-pomodoro/spec.md` (Status → Ready for implementation complete / keep Draft until ship)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 Setup** → no deps
- **Phase 2 Foundational** → depends on Setup; **blocks all user stories**
- **Phase 3 US1** → after Foundational (MVP)
- **Phase 4 US2** → after Foundational; tab shell can start in parallel with US1 UI if foundation done (file conflict risk on `ContentView` vs editor — prefer US1 then US2 if solo)
- **Phase 5 US3** → after US2 tab idle/active shell exists (needs `FocusTabView` + timer APIs); benefits from US1 persisted recipes for real targets
- **Phase 6 US4** → after US2 (tab present) and ideally US3 (session continuity with Memory targets)
- **Phase 7 Polish** → after desired stories complete

### User Story Dependencies

| Story | Depends on | Independently testable? |
|-------|------------|-------------------------|
| US1 Configure Memory Focus | Foundational | Yes — editor + save + startFocus recipe |
| US2 Quick Focus tab | Foundational (+ tab stubs) | Yes — Quick Focus only, empty Memory list OK |
| US3 Memory targets on tab | Foundational + US2 shell; US1 for rich fixtures | Yes with any `hasFocus` memory (legacy toggle enough) |
| US4 Navigation polish | US2 (+ US3 for full continuity) | Yes as navigation/regression pass |

### Within Each Story

- Tests marked before/with implementation should fail until behavior lands
- ViewModel/domain before editor UI (US1)
- Tab enum/shell before idle/active UI (US2)
- List/replace after active session chrome (US3)

### Parallel Opportunities

- T002–T004 stubs in parallel after T001
- T015–T016 foundation tests in parallel after T012–T013
- T017 parallel once T009 done
- T025 / T035 tests parallel with their story UI once timer APIs stable
- T049–T050–T055 polish items in parallel

---

## Parallel Example: Foundational

```bash
# After T006–T009:
Task: "T015 FocusRecipeTests in sparkyTests/Focus/FocusRecipeTests.swift"
Task: "T016 FocusTimerTests in sparkyTests/Focus/FocusTimerTests.swift"
Task: "T011 Export fields in sparky/Model/Export/SparkyExportFormat.swift"
```

## Parallel Example: User Story 2

```bash
# After T026 tab enum:
Task: "T029 Idle UI in sparky/Views/Focus/FocusTabView.swift"
Task: "T031 Extract session content in sparky/Focus/FocusSessionView.swift"
# Then T030/T032 integrate
```

## Parallel Example: User Story 3

```bash
# After US2 active shell:
Task: "T035 Replace predicate tests in sparkyTests/Focus/FocusSessionReplaceTests.swift"
Task: "T036–T037 List + empty state in sparky/Views/Focus/"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1 Setup  
2. Phase 2 Foundational (CRITICAL)  
3. Phase 3 US1 — per-Memory pomodoro configuration  
4. **STOP and VALIDATE** with editor save/reopen + startFocus duration check  
5. Demo MVP value even before Focus tab ships  

### Incremental Delivery

1. Setup + Foundational → engine ready  
2. **US1** → configurable Memory Focus (MVP)  
3. **US2** → Focus tab + Quick Focus  
4. **US3** → Memory targets + replace + deep links  
5. **US4** → navigation polish + Mac fallback  
6. Polish + quickstart A–G  

### Solo Agent Strategy

Prefer strict order: Setup → Foundational → US1 → US2 → US3 → US4 → Polish to avoid `ContentView` / `FocusTimer` merge thrash.

---

## Notes

- Do not introduce a second timer stack; extend `sparky/Focus/*`
- Writes go through drafts + `MemoryService`, not direct model edits in views
- One active session app-wide; UI owns replace confirmation
- Mobile/iPhone acceptance surface; Mac tab deferred with compile-safe guards
- Commit after each task or tight group; stop at checkpoints
- Checklist format required for all tasks above: `- [ ] Txxx ... path`
