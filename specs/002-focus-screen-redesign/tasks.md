---
description: "Task list for Focus Screen Visual Redesign"
---

# Tasks: Focus Screen Visual Redesign

**Input**: Design documents from `/specs/002-focus-screen-redesign/`

**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/, quickstart.md

**Tests**: Included — plan.md and `contracts/focus-session-extensions.md` require Swift Testing for Quick Focus work override and `extendCurrentPhase` invariants.

**Organization**: Tasks grouped by user story for independent implementation and validation.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete work)
- **[Story]**: User story label (`[US1]`…`[US4]`) on story-phase tasks only
- Paths are repo-relative from project root

## Path Conventions

- Shared app sources: `sparky/`
- Tests: `sparkyTests/`
- Feature docs: `specs/002-focus-screen-redesign/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Scaffold Focus redesign view files and test stubs; ensure Xcode target membership

- [x] T001 Create redesign view stubs under `sparky/Views/Focus/`: `FocusIdleSetupView.swift`, `FocusDurationDial.swift`, `FocusDurationPresetsMenu.swift`, `FocusActiveSessionView.swift`, `FocusHeroRing.swift`, `FocusMemoryTargetsSection.swift` (empty `View` placeholders compiling)
- [x] T002 [P] Create test stubs `sparkyTests/Focus/FocusQuickDurationTests.swift` and `sparkyTests/Focus/FocusTimerExtendTests.swift` with placeholder `@Test` functions
- [x] T003 Add new Swift files from T001–T002 to `sparky.xcodeproj` target membership (`sparky` / `sparkyTests`) so the project compiles with stubs

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Timer/session API extensions required by idle start, active +1 min, and time window UI

**⚠️ CRITICAL**: User story UI that starts Quick Focus with dial duration or shows +1/end window depends on this phase

- [x] T004 Extend `FocusTimer.beginQuickSession(workDurationMinutes: Int? = nil)` to snapshot globals into `FocusRecipe`, clamp override to 1…120, bind quick session, start work phase in `sparky/Focus/FocusTimer.swift` per `specs/002-focus-screen-redesign/contracts/focus-session-extensions.md`
- [x] T005 Implement `FocusTimer.extendCurrentPhase(byMinutes: Int = 1)` (+ internal total/remaining/`phaseEndsAt` updates) and `canExtendPhase` in `sparky/Focus/FocusTimer.swift` per contract (no-op when idle or `isWaitingForManualStart`)
- [x] T006 Expose phase window fields: publish or readable `phaseStartedAt` / `phaseEndsAt`, set `phaseStartedAt` in `configurePhase`, and add `displayStartDate` / `displayEndDate` helpers in `sparky/Focus/FocusTimer.swift` per `specs/002-focus-screen-redesign/data-model.md`
- [x] T007 Update `AppEnvironment.startQuickFocus(workDurationMinutes: Int? = nil)` to forward the optional override into `focusTimer.beginQuickSession(workDurationMinutes:)` in `sparky/AppEnvironment.swift`
- [x] T008 [P] Add Swift Testing for quick work override + clamp (0→1, 999→120, 15→900s first phase) in `sparkyTests/Focus/FocusQuickDurationTests.swift`
- [x] T009 [P] Add Swift Testing for extend +1 running/paused, no-op idle/waiting, progress/total invariants in `sparkyTests/Focus/FocusTimerExtendTests.swift`

**Checkpoint**: Timer can start Quick Focus at arbitrary work minutes and extend the current phase; unit tests green for foundation

---

## Phase 3: User Story 1 — Immersive idle Focus setup (Priority: P1) 🎯 MVP

**Goal**: Focus tab idle is a calm, centered setup with duration dial, presets, and Start that begins Quick Focus at the selected length.

**Independent Test**: Open Focus with no session → see dial hero (not list-first) → pick preset/drag dial → Start → work phase matches selected minutes (quickstart A–B).

### Implementation for User Story 1

- [x] T010 [P] [US1] Implement circular `FocusDurationDial` (drag → minutes 1…120 step 1; visual arc `min(m,60)/60`; tick marks 15/30/45/60; center value + MINS; semantic colors; a11y adjustable) in `sparky/Views/Focus/FocusDurationDial.swift` per `contracts/focus-redesign-ui.md` and `research.md`
- [x] T011 [P] [US1] Implement `FocusDurationPresetsMenu` (5/10/15/30/45/60) as system `Menu` content binding `selectedWorkMinutes` in `sparky/Views/Focus/FocusDurationPresetsMenu.swift`
- [x] T012 [US1] Compose `FocusIdleSetupView` with centered “Focus” title, dial, Start CTA, top-trailing presets entry, `selectedWorkMinutes` state seeded from `focusSettings.workDurationMinutes` in `sparky/Views/Focus/FocusIdleSetupView.swift`
- [x] T013 [US1] Wire Start → replace-gate → `environment.startQuickFocus(workDurationMinutes: selectedWorkMinutes)` with a11y `Start Quick Focus, {n} minutes` in `sparky/Views/Focus/FocusIdleSetupView.swift` / `FocusTabView.swift`
- [x] T014 [US1] Replace list-first idle body in `sparky/Views/Focus/FocusTabView.swift` with `FocusIdleSetupView` as hero when `!timer.isSessionActive`; keep replace-alert infrastructure
- [x] T015 [US1] Minimize idle nav chrome (inline/hidden large title as needed) so in-canvas “Focus” reads as hero in `sparky/Views/Focus/FocusTabView.swift`
- [x] T016 [US1] Apply semantic theme full-bleed background and `.tabBarSpacer()` on idle content in `sparky/Views/Focus/FocusTabView.swift` / `FocusIdleSetupView.swift`

**Checkpoint**: US1 MVP — immersive idle + dial/presets + Quick Focus at chosen duration

---

## Phase 4: User Story 2 — Calm active session experience (Priority: P1)

**Goal**: Active session uses calm hero ring, large countdown, optional start→end window, pause/resume, +1 min, end; waiting-for-next-phase keeps one clear CTA.

**Independent Test**: Start any session → calm active layout → pause/resume → +1 min bumps remaining/end → End returns to idle; phase/break still clear (quickstart C, F).

### Implementation for User Story 2

- [x] T017 [P] [US2] Implement `FocusHeroRing` (phase progress arc, center SF Symbol hourglass/phase mark, reduce-motion-safe updates, decorative a11y hidden when redundant) in `sparky/Views/Focus/FocusHeroRing.swift`
- [x] T018 [US2] Implement `FocusActiveSessionView` layout: phase label, title, optional time window from `displayStartDate`/`displayEndDate`, hero, large `formattedTime`, +1 when `canExtendPhase`, pause/resume, end, waiting next-phase CTA in `sparky/Views/Focus/FocusActiveSessionView.swift` per `contracts/focus-redesign-ui.md`
- [x] T019 [US2] Wire controls to `FocusTimer` (`pause`/`start`/`extendCurrentPhase(byMinutes: 1)`/`endSession`/`startNextPhase`) with a11y labels in `sparky/Views/Focus/FocusActiveSessionView.swift`
- [x] T020 [US2] Switch Focus tab active branch from old `FocusSessionContent` stack to `FocusActiveSessionView` in `sparky/Views/Focus/FocusTabView.swift`
- [x] T021 [US2] Refactor `FocusSessionView` cover path to embed `FocusActiveSessionView` (Close dismisses presentation; End ends session) in `sparky/Focus/FocusSessionView.swift` so deep links match tab chrome
- [x] T022 [US2] Apply work=accent / break=`Color.Theme.success` phase treatment and large readable countdown typography in `sparky/Views/Focus/FocusActiveSessionView.swift`
- [x] T023 [US2] Hide or no-op +1 while `isWaitingForManualStart`; show explicit next-phase button only in that state in `sparky/Views/Focus/FocusActiveSessionView.swift`

**Checkpoint**: US2 — active session matches calm redesign; +1/pause/end/next-phase work; cover parity

---

## Phase 5: User Story 3 — Memory-bound Focus without breaking calm UI (Priority: P2)

**Goal**: Focus-enabled Memories remain startable without replacing the idle dial hero; Memory sessions use Memory recipe and same active chrome; replace gate preserved.

**Independent Test**: Dial at 45 → start Memory with different work → session uses Memory recipe + title; empty state caption when none; replace confirm when switching targets (quickstart D–E).

### Implementation for User Story 3

- [x] T024 [P] [US3] Implement `FocusMemoryTargetsSection` (lazy rows: title, recipe summary, play affordance; empty caption) in `sparky/Views/Focus/FocusMemoryTargetsSection.swift`
- [x] T025 [US3] Place Memory section **below** Start on idle (secondary, not first-screen hero) inside `FocusIdleSetupView` or `FocusTabView` in `sparky/Views/Focus/FocusIdleSetupView.swift` / `FocusTabView.swift`
- [x] T026 [US3] Wire Memory row tap → existing replace-gate → `beginSession(memoryID:title:recipe:)` via `environment.focusRecipe(for:)` / timer APIs — **ignore** `selectedWorkMinutes` — in `sparky/Views/Focus/FocusTabView.swift`
- [x] T027 [US3] Confirm Memory-bound active UI shows `activeMemoryTitle` and shared `FocusActiveSessionView` (no separate dense layout) in `sparky/Views/Focus/FocusActiveSessionView.swift` / `FocusTabView.swift`
- [x] T028 [US3] Preserve replace-alert copy and behavior from 001 when starting different identity in `sparky/Views/Focus/FocusTabView.swift`

**Checkpoint**: US3 — Memories discoverable without killing calm idle; recipe integrity + replace gate intact

---

## Phase 6: User Story 4 — Continuity, accessibility, and platform polish (Priority: P2)

**Goal**: Tab blur keeps session; VoiceOver/Dynamic Type/Reduce Motion solid; light/dark legible; Mac safe compile.

**Independent Test**: Mid-session tab switch returns live state; VoiceOver labels on primary controls; Reduce Motion still updates time; light mode contrast OK (quickstart G–H).

### Implementation for User Story 4

- [x] T029 [US4] Verify leaving Focus tab does not call `endSession`; active state restores from `focusTimer` on return in `sparky/Views/Focus/FocusTabView.swift` / `sparky/ContentView.swift` (fix any accidental teardown)
- [x] T030 [P] [US4] Complete VoiceOver labels/traits on dial, presets menu, Start, pause/resume, +1, end, next phase, Memory rows in `sparky/Views/Focus/FocusDurationDial.swift`, `FocusIdleSetupView.swift`, `FocusActiveSessionView.swift`, `FocusMemoryTargetsSection.swift`
- [x] T031 [P] [US4] Honor `@Environment(\.accessibilityReduceMotion)` for non-essential arc/hero animation only in `sparky/Views/Focus/FocusDurationDial.swift` and `FocusHeroRing.swift`
- [x] T032 [US4] Dynamic Type pass: reflow idle/active so Start/pause/end remain reachable at accessibility sizes in `sparky/Views/Focus/FocusIdleSetupView.swift` and `FocusActiveSessionView.swift`
- [x] T033 [US4] Light/dark/system contrast pass using only `Color.Theme.*` / accent (no hardcoded `#000`) in all new Focus views under `sparky/Views/Focus/`
- [x] T034 [US4] Ensure shared Focus redesign files compile for Mac destination (availability/`#if os` only if required; no crash if tab hidden) touching `sparky/Views/Focus/*.swift` and shell wiring in `sparky/ContentView.swift` as needed
- [x] T035 [US4] Confirm notification/editor focus open still presents redesigned active chrome via `FocusSessionView` + tab selection paths in `sparky/ContentView.swift` / `sparky/AppEnvironment.swift`

**Checkpoint**: US4 — continuity + a11y + theme + multiplatform safety

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Cleanup, validation, and residual 001 regression confidence

- [x] T036 Remove or thin obsolete dense controls from unused `FocusSessionContent` paths in `sparky/Focus/FocusSessionView.swift` if fully superseded (keep file compiling; avoid dead duplicate chrome)
- [x] T037 [P] Optional: persist last Quick Focus minutes to `UserDefaults` key `focus.lastQuickWorkMinutes` and seed idle dial when present in `sparky/Views/Focus/FocusIdleSetupView.swift` / small helper (only if low-risk; skip if time-boxed)
- [x] T038 [P] Sweep SF Symbol weights/scales and spacing against reference calm density in `sparky/Views/Focus/FocusIdleSetupView.swift` and `FocusActiveSessionView.swift`
- [x] T039 Run unit test target for Focus override/extend suites in `sparkyTests/Focus/FocusQuickDurationTests.swift` and `FocusTimerExtendTests.swift`; fix regressions
- [x] T040 Execute manual scenarios A–G (and H–I if entry points in scope) from `specs/002-focus-screen-redesign/quickstart.md` on iPhone Simulator; note gaps
- [x] T041 Confirm 001 regressions: global Focus settings still seed new defaults; Memory recipes unchanged by dial; single-session gate; phase notifications still fire (smoke via existing paths)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Start immediately
- **Foundational (Phase 2)**: Depends on Setup — **blocks** US1 Start wiring and US2 +1/time window
- **US1 (Phase 3)**: Depends on Foundational (needs `startQuickFocus(workDurationMinutes:)`)
- **US2 (Phase 4)**: Depends on Foundational (extend + window); can start view shells in parallel with US1 after T004–T006, but tab integration after US1 idle swap is cleaner sequentially
- **US3 (Phase 5)**: Depends on US1 idle composition (place section under Start); active title depends on US2 chrome
- **US4 (Phase 6)**: Depends on US1–US3 UI existing for a11y/theme pass
- **Polish (Phase 7)**: Depends on stories intended to ship

### User Story Dependencies

| Story | Depends on | Independently testable? |
|-------|------------|-------------------------|
| US1 Idle setup (P1) | Phase 2 | Yes — dial + Start Quick Focus alone |
| US2 Active calm (P1) | Phase 2; best after US1 tab host | Yes — can force-start session in tests/UI even if idle is old |
| US3 Memory secondary (P2) | US1 layout slot; US2 active chrome | Yes — Memory start + recipe check |
| US4 Continuity/a11y (P2) | US1–US3 surfaces | Yes — checklist against built UI |

### Parallel Opportunities

- T001 view stubs vs T002 test stubs
- T008 and T009 foundation tests after T004–T006
- T010 dial ∥ T011 presets menu
- T017 hero ring ∥ early US1 work (different files)
- T024 Memory section ∥ late US2 polish
- T030 ∥ T031 a11y/motion
- T037 ∥ T038 polish

---

## Parallel Example: User Story 1

```bash
# After Phase 2 checkpoint:
Task: "T010 Implement FocusDurationDial in sparky/Views/Focus/FocusDurationDial.swift"
Task: "T011 Implement FocusDurationPresetsMenu in sparky/Views/Focus/FocusDurationPresetsMenu.swift"

# Then serial compose + wire:
Task: "T012 Compose FocusIdleSetupView"
Task: "T013–T016 Wire Start, swap FocusTabView idle, theme/nav"
```

## Parallel Example: User Story 2

```bash
Task: "T017 Implement FocusHeroRing in sparky/Views/Focus/FocusHeroRing.swift"
# After hero + Phase 2:
Task: "T018–T023 FocusActiveSessionView + tab/cover integration"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1 Setup  
2. Phase 2 Foundational (timer APIs + tests)  
3. Phase 3 US1 idle dial/presets/Start  
4. **STOP & VALIDATE** quickstart A–B  
5. Demo immersive Quick Focus setup even if active chrome is still 001-style briefly

### Incremental Delivery

1. Setup + Foundational → engine ready  
2. **US1** → immersive idle MVP  
3. **US2** → calm active +1/pause/end (+ cover parity)  
4. **US3** → Memory secondary without hero regression  
5. **US4** + Polish → a11y/theme/quickstart sign-off  

### Suggested MVP scope

**US1 + foundational timer override** is the minimum lovable slice.  
**Ship recommendation**: US1 + US2 together (idle without calm active feels unfinished vs references). US3–US4 required before calling the delivery done against full spec.

---

## Notes

- Do **not** implement ambient “Tune in” audio (spec out of scope)
- Do **not** copy reference tab bar/mascot
- Do **not** write dial minutes into `FocusSettings` or Memory `ScheduleConfig`
- Reuse `FocusTimer` singleton from `AppEnvironment` — no second engine
- One type per new file; `final class` only where reference types already used
- Semantic theme only (`Color.Theme.*`, accent)
- Commit after each task or tight group; keep `FocusTabView` orchestration thin

---

## Task count summary

| Phase | Tasks | Count |
|-------|-------|-------|
| Setup | T001–T003 | 3 |
| Foundational | T004–T009 | 6 |
| US1 Idle | T010–T016 | 7 |
| US2 Active | T017–T023 | 7 |
| US3 Memory | T024–T028 | 5 |
| US4 Continuity/a11y | T029–T035 | 7 |
| Polish | T036–T041 | 6 |
| **Total** | T001–T041 | **41** |

| Story | Task IDs | Count |
|-------|----------|-------|
| US1 | T010–T016 | 7 |
| US2 | T017–T023 | 7 |
| US3 | T024–T028 | 5 |
| US4 | T029–T035 | 7 |

**Format validation**: All tasks use `- [ ]`, sequential `Tnnn`, optional `[P]`, story labels only on US phases, and concrete repo paths.
