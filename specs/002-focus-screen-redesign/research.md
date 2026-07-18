# Research: Focus Screen Visual Redesign

**Feature**: `002-focus-screen-redesign`  
**Date**: 2026-07-18  
**Status**: Complete — no open NEEDS CLARIFICATION

## 1. Idle duration source of truth

**Decision**: Ephemeral `@State selectedWorkMinutes` on Focus tab idle, initialized from `FocusSettings.workDurationMinutes` when idle appears / settings change while idle. Optionally persist last Quick Focus pick under `UserDefaults` key `focus.lastQuickWorkMinutes` (nice-to-have; not required for MVP).

**Rationale**: Spec says default idle duration matches global work default; dial must not mutate global settings or Memory recipes on drag.

**Alternatives considered**:
- Writing dial changes into `FocusSettings.workDurationMinutes` — rejected (surprising global side effect while “just starting once”).
- Separate SwiftData entity for focus preferences — rejected (overkill; globals already exist).

## 2. Quick Focus vs Memory duration

**Decision**: Dial/presets apply **only** to Quick Focus via `beginQuickSession(workDurationMinutes:)`. Memory-bound starts use `FocusRecipe.resolve(schedule:settings:)` unchanged. Idle dial is not shown as authoritative when launching a Memory (Memory row/sheet shows its own summary).

**Rationale**: Spec FR-013; avoids silent recipe override.

**Alternatives considered**:
- “Apply dial as work override on Memory too” — rejected without explicit user control.
- Disabling dial when Memories exist — rejected; Quick Focus remains primary hero.

## 3. Circular dial interaction

**Decision**: Custom SwiftUI dial: ring track + accent arc proportional to `minutes / maxMinutes`, drag gesture maps angle (from 12 o’clock, clockwise) to clamped minutes with 1-minute steps. Tick labels at 15 / 30 / 45 / 60 (and imply scale to max 120 with arc filling proportionally, or cap visual scale at 60 with values >60 still allowed via drag past full ring / preset 60 + continue — **prefer**: visual full ring = 60 minutes for reference parity; values above 60 available via continuing drag with center value >60 up to 120, or presets only up to 60 plus global default 25).  

**Concrete rule**:
- Presets: 5, 10, 15, 30, 45, 60.
- Dial range: 1…120, step 1.
- Visual arc: `min(minutes, 60) / 60` for the thick reference-style arc so 15 looks like the screenshot; when minutes > 60, arc stays full and center shows e.g. 90.

**Rationale**: Matches reference feel for common 5–60 range while honoring existing 1…120 settings bounds.

**Alternatives considered**:
- `Slider` only — fails visual success criteria.
- `UICircularSlider` UIKit bridge — unnecessary; pure SwiftUI gesture is enough.
- Snap only to presets — weaker than FR-003 direct manipulation.

## 4. Preset menu chrome

**Decision**: SwiftUI `Menu` or anchored popover from a top trailing compact control (clock / “Duration”) listing presets with minute icons; selecting sets `selectedWorkMinutes`. No separate Custom sheet — dial is custom.

**Rationale**: Reference menu IA; system `Menu` is HIG-native and accessible.

**Alternatives considered**:
- Full-screen picker — heavier than needed.
- Segmented control — poor for 6+ values.

## 5. +1 minute semantics

**Decision**: `FocusTimer.extendCurrentPhase(byMinutes: 1)`:
- Requires active session and phase ∈ {work, break} with `currentPhaseTotalSeconds > 0`.
- `remainingSeconds += 60` (clamp max remaining if desired — none required).
- `currentPhaseTotalSeconds += 60` so progress = elapsed/total stays continuous (elapsed unchanged).
- If `isRunning` and `phaseEndsAt != nil`, `phaseEndsAt! += 60 seconds`.
- Allowed while paused (only remaining + total bump; end date recomputed on resume from remaining).
- No-op when `isWaitingForManualStart` with zero remaining edge cases — if waiting between phases, +1 is hidden or no-ops (prefer **hide** +1 while waiting for manual start).

**Rationale**: Spec FR-008; keeps `progress` meaningful; wall-clock end stays honest.

**Alternatives considered**:
- Only bump remaining without total → progress jumps backward (acceptable UX but messier).
- Extend entire recipe future phases — out of scope.

## 6. Start → end time window

**Decision**: Expose on timer:
- `phaseEndsAt: Date?` (already private — publish or mirror as `var expectedEndDate: Date?`)
- `phaseStartedAt: Date?` set in `configurePhase` as `Date()` (or `phaseEndsAt - total`).

Active UI shows `started → ended` with `DateFormatter` `.short` time when both available; omit if nil.

**Rationale**: Spec FR-010 optional but high visual match to reference.

**Alternatives considered**:
- Compute only end from `Date() + remaining` each body pass — drifts label while paused; prefer stored endsAt + startedAt.

## 7. Active hero artwork

**Decision**: v1 uses composed SF Symbol (`hourglass` / phase-specific symbol) inside soft circular fill + progress arc/chip. Optional asset later; do not block on 3D hourglass render.

**Rationale**: Native, Dynamic Type-adjacent, no asset pipeline; still calm and centered.

**Alternatives considered**:
- Bundled photoreal PNG — nicer match, higher cost/maintenance, light/dark variants.
- Lottie — new dependency, rejected.

## 8. Memory targets placement

**Decision**: Idle layout: hero dial + Start first; below, a compact **From Memories** section (lazy list) **or** a single “Choose Memory” control presenting a sheet when count > 3. Default implementation target: **section under Start** with max height / lazy stack; if empty, one-line caption only.

**Rationale**: FR-012 without killing calm hero; minimal new navigation.

**Alternatives considered**:
- Toolbar-only Memories — slightly harder to discover.
- Keep 001 list-first — fails redesign.

## 9. Sharing active chrome with cover

**Decision**: Extract redesigned active UI into `FocusActiveSessionView` used by `FocusTabView` and `FocusSessionView` cover. Deprecate dense control layout inside old `FocusSessionContent` or rewrite it in place.

**Rationale**: FR-016 single experience.

## 10. Theme / immersive black

**Decision**: Use `Color.Theme.background` full bleed; do **not** hardcode `#000`. Accent arc uses `Color.accentColor`. Work/break distinction keeps accent vs `Color.Theme.success` (existing). Light mode: same structure on light semantic background (may look less “OLED black” — acceptable per FR-017).

**Rationale**: Constitution II.

## 11. Ambient audio

**Decision**: Out of scope (spec FR-020). No AVAudioSession work.

## 12. Testing strategy

**Decision**:
- Unit: quick begin override minutes; extend math; wouldReplace unchanged; progress after extend.
- Manual: dial, presets, light/dark, VoiceOver labels, Reduce Motion, Memory start, tab continuity.

**Rationale**: UI dial geometry is brittle in unit tests; behavior belongs on timer.

## 13. Mac

**Decision**: Shared views compile. Dial works with pointer drag. Tab visibility follows existing 001 shell rules. No separate Mac design pass as gate.

---

## Resolved unknowns

| Topic | Resolution |
|-------|------------|
| Persist dial? | Optional last-quick; default from globals |
| Dial max visual | Arc saturates at 60m; value to 120 |
| +1 while waiting | Hide / no-op |
| Custom preset row | Dial substitutes |
| Hero asset | SF Symbol v1 |
| Schema migration | None |
