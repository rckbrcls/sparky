# Research: Focus Tab & Memory Pomodoro Configuration

**Feature**: `001-focus-tab-pomodoro`  
**Date**: 2026-07-18

## 1. Per-Memory Focus storage shape

**Decision**: Persist concrete Focus recipe fields on `ScheduleConfig` (alongside existing `focusEnabled`), mirrored on `ScheduleConfigDraft`. Introduce a non-persisted value type `FocusRecipe` for runtime resolution and timer binding.

**Fields (persisted when Focus enabled / once customized)**:
- `focusWorkDurationMinutes: Int` (default 0 → treat as unset)
- `focusShortBreakDurationMinutes: Int` (0 → unset)
- `focusLongBreakDurationMinutes: Int` (0 → unset)
- `focusPomodorosUntilLongBreak: Int` (0 → unset)
- `focusAutoContinue: Bool?` via sentinel: store `focusAutoContinueStored: Bool` + `focusAutoContinueIsSet: Bool`, **or** simpler: always write concrete values when enabling Focus (recommended).

**Recommended write rule**: On `setFocusEnabled(true)`, if recipe unset, copy all five values from `FocusSettings`. Thereafter editor edits concrete values. On disable, keep stored values but `focusEnabled = false` (re-enable restores last recipe).

**Rationale**: Avoids a new SwiftData entity and keeps export data on the schedule payload.

**Alternatives considered**:
| Alternative | Why rejected |
|-------------|--------------|
| Only global settings forever | Fails FR-004–FR-008 (per-Memory config) |
| Separate `FocusConfig` `@Model` 1:1 | Extra relationship for five scalars |
| Store recipe JSON blob | Harder to query/export; inconsistent with schedule field style |

## 2. Incomplete recipe handling

**Decision**: `FocusRecipe.resolve(schedule:)`

- If `focusEnabled == false` → no recipe / not a target.
- If enabled and any duration is `0` → no recipe / invalid target.
- If enabled and all set → use stored values only.

**Rationale**: New Focus configurations are seeded completely when enabled, so runtime fallback is unnecessary.

## 3. FocusTimer session configuration

**Decision**: Bind an immutable-for-session `FocusRecipe` (or copy) when a session begins. APIs:
- `beginQuickSession()` → recipe from current `FocusSettings` snapshot; `activeMemoryID = nil`; title = “Quick Focus” (or localized equivalent).
- `beginSession(memoryID:memoryTitle:recipe:)` → bound memory + recipe.
- Running session reads durations from bound recipe, not live `FocusSettings` publishers (except when idle with no session).

**Rationale**: Spec requires Memory sessions to honor Memory config; mid-session global edits must not scramble remaining phase totals unexpectedly.

**Alternatives considered**:
| Alternative | Why rejected |
|-------------|--------------|
| Always read `FocusSettings` | Breaks per-Memory durations |
| Mutate `FocusSettings` temporarily per session | Racey; corrupts user globals |

## 4. Background timekeeping

**Decision**: Prefer **wall-clock deadline** (`phaseEndsAt: Date`) set on start/resume; UI `remainingSeconds` derived from `max(0, deadline - now)` on each tick and on `scenePhase` → `.active`. Keep 1s display refresh. On fire, advance phase once (idempotent).

**Rationale**: Current pure decrement-on-`Timer` drifts/pauses heavily in background; phase completion notifications already exist but remaining time on resume can be wrong.

**Alternatives considered**: `BGTaskScheduler` — overkill for local countdown; still need wall clock. Pure Timer only — fails SC reliability when backgrounded.

## 5. Focus tab information architecture

**Decision**: Add `CustomTab.focus` (“Focus”, SF Symbol `timer` or `brain.head.profile` — prefer `timer` to match existing Focus iconography). Tab root states:
1. **Idle**: primary Quick Focus button; section “From Memories” listing Focus-ready items (`Memory.hasFocus`).
2. **Active**: session chrome (shared with `FocusSessionView` content) + End session; optional “Running” affordance.

Deep links (notification Start Focus, editor Focus):
- Ensure session started with recipe.
- Select Focus tab.
- Prefer **in-tab** session UI; keep `fullScreenCover` only when needed for interruption hierarchy.

**Rationale**: Spec P1 stories center on tab discovery; Converge uses a dedicated pomodoro surface.

**Alternatives considered**: Settings-only entry — fails tab requirement. Cover-only session — weak tab continuity (FR-018).

## 6. Close vs End session

**Decision**:
- **End session**: stops timer, clears binding, returns idle.
- **Leave tab / navigate away**: does **not** end session.
- Current `FocusSessionView` toolbar “Close” that calls `endSession()` must be split: in cover context, “Close” may dismiss cover **without** ending if session should continue in tab; provide explicit **End**.

**Rationale**: FR-018 and SC-005; current Close-ends conflicts with tab continuity.

## 7. Single active session replace policy

**Decision**: Before starting a different target (other Memory or Quick Focus) while `focusTimer.isSessionActive`:
- Present confirmation: continue current vs end & start new.
- Same Memory ID re-start while active: bring UI to current session (no reset) — matches existing `beginSession` early return.

**Rationale**: FR-009 / SC-006.

## 8. Editor Focus form UX

**Decision**: Reuse stepper patterns/ranges from `FocusSettingsView` (work 1…120, breaks 1…60, until long 1…12, auto-continue toggle). Show only when schedule Focus toggle on. Caption may change from “Starts from the schedule notification” to also mention Focus tab.

**Rationale**: Consistency; FR-004.

## 9. Export / import

**Decision**: Extend exported schedule/trigger DTO with optional recipe fields. Older files without fields import as enabled-only (resolver fills globals). Export writes concrete stored values when present.

**Rationale**: Round-trip FR-006/SC-003 for backup users.

## 10. Mac / multiplatform

**Decision**: Domain + timer shared. Focus tab and editor Focus steppers ship for iOS; Mac build either omits tab case in shell or shows Me → Focus settings only. No crash if `FocusTimer` APIs called.

**Rationale**: User mobile-only scope + constitution VI fallback.

## 11. Testing strategy

**Decision**: Swift Testing unit tests for:
- `FocusRecipe.resolve` incomplete + full custom
- `FocusTimer` first phase duration equals recipe work minutes
- Replace guard / same-id no-op
- Draft ↔ model recipe round-trip

UI: manual quickstart on simulator (no mandatory UITest in this plan unless time permits).

## 12. Resolved clarifications

| Topic | Resolution |
|-------|------------|
| NEEDS CLARIFICATION in Technical Context | None remaining |
| Quick Focus persistence | Not a Memory (assumption) |
| Parallel sessions | Forbidden |
| Location-only Focus | Out of scope; schedule-only |

## References (in-repo)

- `sparky/Focus/*` — current engine (Converge port)
- `sparky/Views/Settings/FocusSettingsView.swift` — global UX
- `sparky/Views/Memories/Editor/Triggers/Shared/TriggersCard.swift` — Focus toggle
- `sparky/Model/Triggers/ScheduleConfig.swift` — `focusEnabled`
- `/Users/erickpatrickbarcelos/codes/migration/converge/converge/Views/PomodoroView.swift` — IA baseline
