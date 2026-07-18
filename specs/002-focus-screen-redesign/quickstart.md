# Quickstart Validation: Focus Screen Visual Redesign

**Feature**: `002-focus-screen-redesign`  
**Date**: 2026-07-18  
**Purpose**: Prove idle dial/presets, active calm chrome, +1 min, Memory secondary path, and regressions against 001 behavior.

## Prerequisites

- Xcode + iOS Simulator (iPhone)
- `sparky.xcodeproj`, scheme `sparky`
- Implementation of this feature on branch / worktree
- At least one Memory with schedule + Focus enabled (for Memory scenarios)
- Optional: second Memory Focus target for replace-gate

```bash
# From repo root
xcodebuild -scheme sparky -destination 'platform=iOS Simulator,name=iPhone 16' build

# Unit tests (extend + quick duration)
xcodebuild -scheme sparky -destination 'platform=iOS Simulator,name=iPhone 16' test
```

See: [data-model.md](./data-model.md), [contracts/focus-session-extensions.md](./contracts/focus-session-extensions.md), [contracts/focus-redesign-ui.md](./contracts/focus-redesign-ui.md).

## Scenario A — Idle immersive setup

1. Launch app; open **Focus** tab with no active session.
2. **Expect**: centered “Focus” title; large circular duration dial; center minutes; **Start** primary; Memory list not dominating first screenful.
3. Confirm initial minutes match **Me → Focus** work default (e.g. 25) unless last-quick persistence is implemented.
4. Open duration presets (top trailing).
5. Choose **15 min**.
6. **Expect**: center shows 15; arc matches ~quarter of 60-scale ring.
7. Drag dial to ~30.
8. **Expect**: value tracks in 1-minute steps within 1…120.

## Scenario B — Quick Focus start with dial duration

1. Set dial to **10** minutes (preset or drag).
2. Tap **Start**.
3. **Expect**: active calm layout; countdown ≈ 10:00; title Quick Focus; hero ring visible.
4. Switch to another tab and back.
5. **Expect**: same session, time still counting (if running).

## Scenario C — Active controls (+1, pause, end)

1. From running session (Scenario B): tap **Pause**.
2. **Expect**: timer frozen; control shows Resume.
3. Tap **+1 min**.
4. **Expect**: remaining increases by 01:00; if end time shown, it moves later by one minute.
5. Resume; confirm counting continues.
6. Tap **End**.
7. **Expect**: return to idle dial setup (not blank crash).

## Scenario D — Memory-bound start ignores dial

1. Idle: set dial to **45**.
2. Under From Memories, start a Focus-enabled Memory whose work is **1** or **25** (known recipe).
3. **Expect**: session title = Memory title; first phase length = **Memory recipe**, not 45.
4. Active chrome matches Quick Focus layout family.

## Scenario E — Replace gate

1. Start Quick Focus.
2. Attempt to start a Memory (or second target).
3. **Expect**: confirmation “Focus session in progress”.
4. **Keep current** → session unchanged.
5. Repeat → **End & Start** → new session identity.

## Scenario F — Phase / waiting UX

1. Use Memory or globals with **1 min** work, auto-continue **off** (via settings/editor).
2. Start session; wait for work complete (or test hook if available).
3. **Expect**: waiting state with explicit start-next control; +1 hidden or inert.
4. Start break; **Expect**: break labeling/treatment distinct; layout still calm hero.

## Scenario G — Appearance & a11y smoke

1. Toggle light/dark (system or Me theme).
2. **Expect**: idle + active text/controls legible; no pure-black hardcoded breakage in light mode.
3. VoiceOver: focus Start, dial, pause, +1, end — labels make sense.
4. Reduce Motion on: start session — time still updates; no reliance on animation for state.
5. Larger Dynamic Type: Start/pause/end still reachable.

## Scenario H — External entry parity

1. From eligible Memory editor Focus action or schedule focus open-request (if available in build).
2. **Expect**: lands on same active chrome as tab (not old dense control stack only).

## Scenario I — Regression: globals & recipes

1. Change Me → Focus work default to 20.
2. End any session; reopen Focus idle.
3. **Expect**: dial seeds to 20 (if no last-quick override).
4. Existing Memory custom recipe unchanged in editor.

## Pass criteria

- A–C and G required for visual delivery sign-off.
- D–F and I required for 001 compatibility sign-off.
- H required if cover/deep-link paths ship in same PR; otherwise follow-up task explicitly noted.

## Unit checks (automated)

| Case | Expect |
|------|--------|
| `beginQuickSession(workDurationMinutes: 15)` | work phase 900s |
| clamp 0 / 999 | 1 / 120 |
| `extendCurrentPhase(1)` running | +60s remaining & total |
| extend when idle / waiting | no-op |
| Memory begin | independent of any UI dial state |
