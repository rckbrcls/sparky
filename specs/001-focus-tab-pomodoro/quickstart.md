# Quickstart Validation: Focus Tab & Memory Pomodoro

**Feature**: `001-focus-tab-pomodoro`  
**Date**: 2026-07-18  
**Purpose**: Manual / semi-automated checks proving the delivery end-to-end after implementation.

## Prerequisites

- Xcode with iOS Simulator (iPhone)
- Project: `sparky.xcodeproj`, scheme `sparky`
- Feature branch / worktree containing this spec’s implementation
- Notification permission: allow when prompted (for background phase checks)

```bash
# From repo root — build only (agent policy may forbid long dev servers; local ok)
xcodebuild -scheme sparky -destination 'platform=iOS Simulator,name=iPhone 16' build

# Unit tests (once Focus tests exist)
xcodebuild -scheme sparky -destination 'platform=iOS Simulator,name=iPhone 16' test
```

See also: [data-model.md](./data-model.md), [contracts/focus-session.md](./contracts/focus-session.md), [contracts/focus-tab-ui.md](./contracts/focus-tab-ui.md).

## Scenario A — Quick Focus from tab

1. Launch app (onboarded state).
2. Select **Focus** tab.
3. Confirm idle UI: **Quick Focus** CTA visible.
4. Tap **Quick Focus**.
5. **Expect**: work phase running; countdown ≈ global work minutes; title Quick Focus.
6. Pause → resume → time continues.
7. Switch to Calendar tab and back to Focus.
8. **Expect**: same session still active (not reset).
9. Tap **End**.
10. **Expect**: idle state; can start again.

## Scenario B — Configure Memory Focus recipe

1. Create/edit Memory; enable **Schedule**.
2. Enable **Focus**.
3. **Expect**: steppers appear pre-filled from Settings → Focus defaults.
4. Set work to **1** minute, short break **1**, long break **1**, until long **2**, auto-continue **off**.
5. Save Memory.
6. Reopen editor.
7. **Expect**: same Focus values persisted.
8. Open Me → Focus settings; change global work to another value.
9. Reopen Memory.
10. **Expect**: Memory still has **1** minute work (globals not overwritten).

## Scenario C — Start from Focus tab (Memory-bound)

1. With Memory from B saved and Focus enabled.
2. Focus tab → list shows Memory title.
3. Tap row → session starts.
4. **Expect**: title = Memory title; first phase duration = 1:00 (or configured work).
5. Let phase complete (or temporarily use 1 min).
6. **Expect**: waiting for manual start (auto-continue off); notification if backgrounded.
7. Start next phase → break with configured break length.

## Scenario D — Replace session guard

1. Start Quick Focus.
2. From list, start a Memory Focus target.
3. **Expect**: confirmation alert; default keeps current.
4. Confirm End & Start.
5. **Expect**: new Memory-bound session; previous discarded.

## Scenario E — Incomplete Focus recipe

1. Use a test fixture with `focusEnabled = true` and no recipe fields.
2. Start from Focus tab.
3. **Expect**: the session does not start.
4. Enable Focus through the editor so a complete recipe is seeded, then save.
5. **Expect**: subsequent sessions use saved recipe.

## Scenario F — Existing entry points

1. Schedule notification action **Start Focus** (or debug `pendingFocusOpenRequest`).
2. **Expect**: Focus session for that Memory; Focus tab/session UI reachable.
3. From editor, when Focus eligible, toolbar Focus still starts session.

## Scenario G — Theme & a11y smoke

1. Toggle system appearance light/dark; Focus tab and session remain legible.
2. VoiceOver: Quick Focus, pause/end, and a Memory row have sensible labels.
3. Increase Dynamic Type one–two steps: primary controls remain tappable.

## Scenario H — Mac compile fallback (optional)

1. Build Mac destination if target exists.
2. **Expect**: build succeeds; no Focus tab requirement; no runtime crash on launch.

## Automated checks (implementation phase)

| Test | Assert |
|------|--------|
| Recipe resolve incomplete | enabled + 0 durations → nil |
| Recipe resolve custom | stored minutes used |
| Timer begin with recipe | `remainingSeconds == work * 60` |
| Quick vs memory identity | replace required when different |
| Draft round-trip | draft → model → draft preserves recipe |

## Pass criteria

- Scenarios A–F pass on iPhone Simulator.
- Scenario G no blockers.
- Unit tests green for recipe/timer contracts.
- Spec success criteria SC-001…SC-008 qualitatively satisfied.
