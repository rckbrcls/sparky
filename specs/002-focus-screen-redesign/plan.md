# Implementation Plan: Focus Screen Visual Redesign

**Branch**: `002-focus-screen-redesign` | **Date**: 2026-07-18 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/002-focus-screen-redesign/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

Redesign the Focus tab into an immersive, reference-inspired experience: **idle** = centered duration dial + presets + Start; **active** = calm hero ring, large countdown, pause/resume, **+1 min**, end. Extend `FocusTimer` only where product requires it (Quick Focus work override, extend phase, optional wall-clock window). Keep pomodoro recipes, Memory targets, replace gate, and notifications from `001-focus-tab-pomodoro`. Ambient audio and reference-app chrome stay out of scope. iPhone is primary; Mac compiles with shared views / existing deferral.

## Technical Context

**Language/Version**: Swift (Xcode / SwiftUI), `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`

**Primary Dependencies**: SwiftUI (gestures, menus, materials), Combine (existing timer), semantic theme tokens

**Storage**: No new SwiftData entities. Idle selected duration is ephemeral UI state (optionally remember last Quick Focus minutes in `UserDefaults` — see research). Globals remain `FocusSettings`; Memory recipes unchanged.

**Testing**: Swift Testing for `extendCurrentPhase`, `beginQuickSession(workDurationMinutes:)`, progress/end-date invariants; manual UI validation via quickstart (dial, presets, a11y, light/dark)

**Target Platform**: **iPhone primary** for full dial/session chrome; Mac shares domain + may render same views in window without blocking release

**Project Type**: Native multiplatform Apple app (shared `sparky/` sources)

**Performance Goals**: 1 Hz timer ticks only; dial drag updates local `@State` without service churn; Memory list lazy if present; no image decode on critical path (SF Symbol / lightweight asset)

**Constraints**: Semantic theme only; Reduce Motion; Dynamic Type; one active session; Memory recipe wins over idle dial; no ambient audio; do not fork a second timer engine

**Scale/Scope**: ~1 tab root refactor, 3–6 focused view files under `Views/Focus` + `Focus/`, small `FocusTimer` API surface, 2–4 unit tests; no schema migration

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*
*Source: `.specify/memory/constitution.md` (Sparky Constitution)*

- [x] **I. HIG / native feel**: Immersive Focus is product-intentional but uses system menus, SF Symbols, continuous corners, safe areas, tab spacer, Dynamic Type, Reduce Motion; Mac not forced into unfinished phone-only chrome
- [x] **II. Semantic theme**: Surfaces/text/accents via `Color.Theme.*` / accent; no hardcoded reference hex in feature views; light/dark/system via `ThemeManager`
- [x] **III. Modern SwiftUI**: Split idle dial, active session, preset menu, Memory entry into small views; `@State` for ephemeral duration; `@ObservedObject` timer/environment; no `@Observable`; presentation (Memory sheet / replace alert) owned by tab root
- [x] **IV. Performance**: No heavy work in `body`; dial math is cheap; lazy Memory list; timer path unchanged cadence
- [x] **V. Local-first architecture**: No backend; session still `AppEnvironment.focusTimer`; Memory start still service/recipe resolve; no durable model writes from views except existing start paths
- [x] **VI. One code, two builds**: Shared Focus views/domain; iPhone-first interaction polish; Mac safe compile / optional same layout
- [x] **Complexity**: No new architecture layers — UI composition + minimal timer commands only

**Post-design re-check**: PASS — design confined to Focus UI module + thin timer extensions (`work override`, `extend`, published end/start times). No schema change. Contracts document UI + session deltas without parallel engines.

## Project Structure

### Documentation (this feature)

```text
specs/002-focus-screen-redesign/
├── plan.md                 # This file
├── research.md             # Phase 0
├── data-model.md           # Phase 1
├── quickstart.md           # Phase 1
├── contracts/
│   ├── focus-session-extensions.md
│   └── focus-redesign-ui.md
└── tasks.md                # Phase 2 (/speckit.tasks — not created here)
```

### Source Code (repository root)

```text
sparky/
├── Focus/
│   ├── FocusTimer.swift              # + beginQuickSession(workDurationMinutes:)
│   │                                 # + extendCurrentPhase(byMinutes:)
│   │                                 # + expose phase window (endsAt / startedAt)
│   ├── FocusSessionView.swift        # Refactor: tab uses redesigned content;
│   │                                 # cover path shares active chrome
│   ├── FocusRecipe.swift             # Unchanged resolve rules; quick override at begin
│   ├── FocusSettings.swift           # Seed default idle minutes only
│   └── FocusNotificationService.swift # Unchanged
├── Views/Focus/
│   ├── FocusTabView.swift            # Idle ↔ active orchestration, replace gate
│   ├── FocusIdleSetupView.swift      # NEW — title, dial, presets entry, Start
│   ├── FocusDurationDial.swift       # NEW — circular drag + tick marks
│   ├── FocusDurationPresetsMenu.swift # NEW — 5/10/15/30/45/60 (+ dial = custom)
│   ├── FocusActiveSessionView.swift  # NEW — hero, countdown, +1, pause, end
│   ├── FocusHeroRing.swift           # NEW — progress arc + center artwork
│   └── FocusMemoryTargetsSection.swift # NEW or sheet — secondary Memory starts
├── AppEnvironment.swift              # startQuickFocus() passes selected minutes if API moves up
├── ContentView.swift                 # Prefer shared active chrome for cover if easy
└── Utilities/Color+Theme.swift       # Only if a new semantic token is truly required

sparkyTests/
└── Focus/
    ├── FocusTimerExtendTests.swift   # NEW
    └── FocusQuickDurationTests.swift # NEW (or extend FocusTimerTests)
```

**Structure Decision**: Keep domain in `sparky/Focus/`. All redesign chrome under `sparky/Views/Focus/` with one type per file. Reuse the tab shell and `FocusTimer` singleton from 001; do not create parallel managers.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Immersive custom dial (beyond stock Stepper/Slider) | Spec/reference require circular duration control as product identity | Stepper-only idle fails SC-001 visual direction and FR-001/003 |
| Mac full dial polish deferred | Spec FR-023 / iPhone primary | Blocking on Mac pointer fine-tuning delays the visual delivery user asked for |

## Phase 0 → research.md

See [research.md](./research.md).

## Phase 1 → design artifacts

- [data-model.md](./data-model.md)
- [contracts/focus-session-extensions.md](./contracts/focus-session-extensions.md)
- [contracts/focus-redesign-ui.md](./contracts/focus-redesign-ui.md)
- [quickstart.md](./quickstart.md)

## Implementation approach (planning only)

1. **Timer extensions** (test first):  
   - `beginQuickSession(workDurationMinutes: Int? = nil)` — snapshot globals into `FocusRecipe`, override work minutes (clamped 1…120), start work.  
   - `extendCurrentPhase(byMinutes: Int = 1)` — only when `isSessionActive` and phase is work/break; increase remaining + phase total + `phaseEndsAt` if running; no-op when idle/waiting without a configured phase total.  
   - Publish or compute `phaseEndsAt` / `phaseStartedAt` (or `expectedEndDate`) for start→end label.

2. **Idle UI**: `FocusIdleSetupView` with `@Binding`/`@State` `selectedWorkMinutes` defaulting from `focusSettings.workDurationMinutes`. Dial + menu write the same binding. Start → replace-gate → `beginQuickSession(workDurationMinutes: selected)`.

3. **Active UI**: Replace list-like `FocusSessionContent` usage in tab with `FocusActiveSessionView` (hero ring, large time, +1, pause/resume, end, next-phase CTA). Keep phase color language (accent work / success break) via theme.

4. **Memory targets**: Secondary section under fold **or** toolbar/sheet “From Memories” — prefer collapsible section below Start on idle to avoid extra navigation unless list is long; sheet if density suffers. Memory start ignores dial (recipe wins).

5. **Shared cover path**: `FocusSessionView` (fullScreenCover) should embed the same active chrome so notification/editor entry matches tab.

6. **A11y / motion**: Labels on dial (“Focus duration, N minutes”), Start, pause, +1, end; decorative hero `accessibilityHidden(true)` if redundant with time/phase; Reduce Motion disables ornamental arc spring, keeps progress value updates.

7. **Theme**: Background `Color.Theme.background`; secondary chips `secondaryBackground` / glass if already used in app; no raw purple hex — use `Color.accentColor` / theme accents.

8. **Tests + quickstart**: extend/override unit tests; manual scenarios A–F in quickstart.

## Agent context

No `update-agent-context` script under `.specify/scripts` in this repo. Feature pointer: `.specify/feature.json` → `specs/002-focus-screen-redesign`. Runtime guidance remains `CLAUDE.md` + constitution.
