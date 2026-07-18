# Implementation Plan: Focus Tab & Memory Pomodoro Configuration

**Branch**: `001-focus-tab-pomodoro` | **Date**: 2026-07-18 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-focus-tab-pomodoro/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

Ship a first-class **Focus tab** on iPhone and upgrade Memory Focus from a boolean toggle to a full per-Memory pomodoro recipe (work / short break / long break / cycles until long break / auto-continue). Quick Focus uses global `FocusSettings`; Memory-bound sessions use persisted schedule Focus fields. Reuse and extend the existing Converge-ported engine (`FocusTimer`, `FocusSessionView`, notifications) rather than introducing a second timer stack. Mac Focus chrome is explicitly deferred; shared domain stays safe.

## Technical Context

**Language/Version**: Swift (Xcode / SwiftUI), `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`

**Primary Dependencies**: SwiftUI, SwiftData, Combine, UserNotifications (existing Focus + schedule paths)

**Storage**: SwiftData `ScheduleConfig` extended with per-Memory Focus recipe fields; global defaults remain `UserDefaults` via `FocusSettings`

**Testing**: Swift Testing for Focus recipe resolution, timer session config binding, single-session replace rules; manual/UI validation via quickstart

**Target Platform**: **iPhone primary** this delivery; Mac destination compiles with Focus tab deferred/hidden (constitution VI + spec FR-017)

**Project Type**: Native multiplatform Apple app (single Xcode project / shared `sparky/` sources)

**Performance Goals**: Focus tab list lazy; timer ticks must not stall other tabs; filtering Focus-ready Memories O(n) over in-memory `MemoryService` index is acceptable at current scale

**Constraints**: Local-first; semantic theme only; drafts for editor writes; active `scheduleConfig` path (not legacy `triggers`); one active Focus session app-wide; no network

**Scale/Scope**: ~1 new tab root + editor Focus form expansion + FocusTimer session-config API + ScheduleConfig/Draft/export/migration touchpoints; ~4–6 core types touched, 1–2 new view files

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*
*Source: `.specify/memory/constitution.md` (Sparky Constitution)*

- [x] **I. HIG / native feel**: iPhone tab + editor nested Focus controls; Mac tab deferred with documented fallback (no stretched phone UI requirement this release)
- [x] **II. Semantic theme**: Focus tab/session/editor controls use `Color.Theme.*` / existing session chrome patterns; no ad-hoc hex
- [x] **III. Modern SwiftUI**: `FocusTabView` small composition; editor keeps draft path (`ScheduleConfigDraft`); presentation owned by `ContentView` / tab root; `ObservableObject` stack unchanged
- [x] **IV. Performance**: Lazy list for Focus targets; timer remains lightweight publisher; no attachment/decode work on Focus paths
- [x] **V. Local-first architecture**: Persist via `MemoryService` + SwiftData schedule config; globals via `FocusSettings`; no backend
- [x] **VI. One code, two builds**: Shared domain (`ScheduleConfig` Focus recipe, `FocusTimer` session config); iPhone-only tab registration / shell wiring with `#if os(iOS)` or equivalent adaptive hide on Mac
- [x] **Complexity**: No unjustified new layers — extend existing Focus module + schedule draft; see Complexity Tracking for intentional Mac deferral

**Post-design re-check**: PASS — design stays inside `Focus/`, `ScheduleConfig*`, editor triggers card, `ContentView` tabs, export DTO; single session coordinator remains `AppEnvironment.focusTimer`.

## Project Structure

### Documentation (this feature)

```text
specs/001-focus-tab-pomodoro/
├── plan.md              # This file
├── research.md          # Phase 0
├── data-model.md        # Phase 1
├── quickstart.md        # Phase 1
├── contracts/           # Phase 1
│   ├── focus-session.md
│   └── focus-tab-ui.md
└── tasks.md             # Phase 2 (/speckit.tasks — not created here)
```

### Source Code (repository root)

```text
sparky/
├── ContentView.swift                 # CustomTab + Focus tab host; session presentation
├── AppEnvironment.swift              # startFocus / pending open; replace-session gate
├── Focus/
│   ├── FocusSettings.swift           # Global defaults (unchanged keys; source for seed)
│   ├── FocusTimer.swift              # Session-scoped recipe + quick/memory begin APIs
│   ├── FocusSessionView.swift        # Reused/adapted for tab + cover
│   ├── FocusNotificationService.swift
│   └── FocusRecipe.swift             # NEW value type: resolved pomodoro parameters
├── Model/Triggers/
│   ├── ScheduleConfig.swift          # Persist per-Memory Focus recipe fields
│   └── ScheduleConfigDraft.swift     # Editor draft fields + converters
├── Model/Export/SparkyExportFormat.swift  # Export/import recipe fields
├── Model/Memory/Memory.swift         # hasFocus / recipe accessors if needed
├── ViewModels/MemoryEditorViewModel.swift # setFocusEnabled seeds recipe; mutators
├── Views/Memories/Editor/Triggers/Shared/TriggersCard.swift  # Inline Focus form
├── Views/Focus/                      # NEW
│   ├── FocusTabView.swift            # Idle / active / targets
│   └── FocusMemoryPickerSection.swift (or inline)
├── Views/Settings/FocusSettingsView.swift  # Global defaults (keep)
├── Views/Shared/CustomTabBar.swift   # 4th tab item
├── Data/DataController.swift         # Lightweight field defaults / optional migration note
└── Services/MemoryService.swift      # Copy/update schedule preserves recipe

sparkyTests/
└── Focus/                            # NEW tests: recipe resolve, timer binding, replace rules
```

**Structure Decision**: Extend existing `sparky/Focus` + schedule trigger models. New UI under `sparky/Views/Focus/`. No parallel timer service. Mac: shared models compile; tab case may exist but shell shows Focus tab only on iOS this delivery.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Mac Focus tab deferred (partial VI surface) | User scoped delivery to mobile-only | Shipping unfinished Mac tab chrome would violate HIG (I) more than deferring with explicit fallback |
| Session UI dual surface (tab root + existing fullScreenCover) | Keep notification/editor deep-link without ripping cover path in same PR | Cover-only blocks “tab as home for Focus”; tab-only breaks existing open-request UX mid-migration |

## Phase 0 → research.md

See [research.md](./research.md) for decisions on recipe storage shape, timer config injection, tab IA, single-session replace, background timekeeping, and export.

## Phase 1 → design artifacts

- [data-model.md](./data-model.md)
- [contracts/focus-session.md](./contracts/focus-session.md)
- [contracts/focus-tab-ui.md](./contracts/focus-tab-ui.md)
- [quickstart.md](./quickstart.md)

## Implementation approach (planning only)

1. **Domain**: Introduce `FocusRecipe` (value type) with work/short/long minutes, pomodorosUntilLongBreak, autoContinue. Resolve `ScheduleConfig` → recipe with fallback to `FocusSettings` when fields unset (legacy toggle-only rows).
2. **Persistence**: Add optional/defaulted Int/Bool fields on `ScheduleConfig` + mirror on `ScheduleConfigDraft`; `setFocusEnabled(true)` copies current globals into draft; disable clears or leaves values (prefer keep last values but `focusEnabled = false`).
3. **Timer**: `FocusTimer.beginQuickSession()` and `beginSession(memoryID:title:recipe:)` bind an active `FocusRecipe` for the session lifetime; ignore global settings mid-session except optional future “apply defaults” (out of scope). Prefer wall-clock end date on start/resume for background accuracy.
4. **Editor UI**: Under schedule Focus toggle, show steppers aligned with `FocusSettingsView` ranges when enabled.
5. **Focus tab**: `CustomTab.focus`; idle = Quick Focus CTA + list of `memory.hasFocus`; active = session controls (embed `FocusSessionView` content or shared subview). Replace-session confirmation before starting different target.
6. **Shell**: `AppEnvironment.startFocus` loads recipe from memory; pending open switches to Focus tab and/or presents session; Close on cover should not always end session if tab owns it — define: **End** ends session; **Close/minimize** returns to tab with session still running (adjust current Close-ends behavior for tab continuity — see research).
7. **Export**: Extend exported schedule/trigger payload with recipe fields; import maps missing → nil/defaults.
8. **Tests**: Recipe resolution, beginSession uses recipe durations, single active session guard, draft round-trip.

## Agent context

No `update-agent-context` script is present under `.specify/scripts` in this project. Feature state is tracked via `.specify/feature.json` → `specs/001-focus-tab-pomodoro`. Runtime guidance remains `CLAUDE.md` + constitution; no AGENTS.md rewrite required for this plan.
