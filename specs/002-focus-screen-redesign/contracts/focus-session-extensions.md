# Contract: Focus Session Extensions (Redesign)

**Feature**: `002-focus-screen-redesign`  
**Surface**: `FocusTimer` + `AppEnvironment` quick-start façade  
**Base**: Supersedes call shapes from `001` only where listed; all other `001` session contracts remain in force.

## 1. Quick Focus with work override

### `FocusTimer.beginQuickSession(workDurationMinutes: Int? = nil)`

| | |
|--|--|
| **Pre** | Prefer caller ran replace-gate if another identity is active |
| **Args** | `workDurationMinutes`: optional; if nil, use `FocusSettings.workDurationMinutes` |
| **Clamp** | `1...120` |
| **Effect** | Build `FocusRecipe.from(settings:)`, set `workDurationMinutes` to clamped override, bind `activeRecipe`, `activeMemoryID = nil`, title `"Quick Focus"`, configure work phase for `recipe.workDurationSeconds`, `start()` |
| **No-op** | Same as today if quick session already active (optional keep); must not steal a Memory session without prior `endSession` |

### `AppEnvironment.startQuickFocus(workDurationMinutes: Int? = nil)`

| | |
|--|--|
| **Effect** | Optional replace policy (current env may auto-end — tab UI should gate before call). Then `focusTimer.beginQuickSession(workDurationMinutes:)` |
| **Default** | nil minutes → global work default (backward compatible) |

## 2. Extend current phase

### `FocusTimer.extendCurrentPhase(byMinutes: Int = 1)`

| | |
|--|--|
| **Pre** | `isSessionActive` and `phase` is `.work` or `.break` and `!isWaitingForManualStart` |
| **Args** | `byMinutes >= 1` (UI sends 1); ignore or clamp non-positive |
| **Effect** | `delta = byMinutes * 60` seconds; `remainingSeconds += delta`; `currentPhaseTotalSeconds += delta`; if `isRunning`, `phaseEndsAt = (phaseEndsAt ?? Date()) + delta`; if paused, leave `phaseEndsAt` nil (resume rebuilds from remaining as today) |
| **Progress** | Must remain in `0...1`; elapsed unchanged ⇒ progress decreases slightly (more total) — acceptable |
| **No-op** | Idle, no recipe, or waiting-for-manual-start |

### Query

```text
canExtendPhase: Bool
  // isSessionActive
  // && (phase == work || phase == break)
  // && !isWaitingForManualStart
```

## 3. Phase time window

### Published / readable

```text
phaseStartedAt: Date?     // set on configurePhase
phaseEndsAt: Date?        // set on configurePhase / running extend; nil when paused (existing pause clears endsAt)
```

### Derived helpers (timer or view)

```text
displayEndDate: Date?
  // if isRunning: phaseEndsAt
  // else if remainingSeconds >= 0 && isSessionActive && !isWaitingForManualStart:
  //   Date().addingTimeInterval(TimeInterval(remainingSeconds))
  // else: nil

displayStartDate: Date?
  // phaseStartedAt
```

UI formats short local times; omits row if either side missing.

## 4. Unchanged commands (reference)

Still required with 001 semantics:

- `beginSession(memoryID:title:recipe:)`
- `start` / `pause` / `startNextPhase`
- `resetCurrentSession` / `endSession`
- `wouldReplaceSession(withMemoryID:)`
- `refreshFromWallClock`
- notifications on phase complete
- single active session

## 5. Invariants

1. Extending does not change `activeRecipe` stored break/work defaults for **future** phases — only current phase totals/remaining.
2. Override work minutes affect **first** work phase and subsequent work phases only through `activeRecipe.workDurationMinutes` (override is stored on bound recipe).
3. `progress = clamp((total - remaining) / total)` with `total > 0`.
4. Memory begin APIs never read idle dial state (UI responsibility).

## 6. Tests (contract acceptance)

| Test | Expect |
|------|--------|
| beginQuick(work: 15) | first phase total 900s; recipe.work 15; breaks from globals |
| beginQuick(nil) | work = settings.work |
| beginQuick(0) / 999 | clamp 1 / 120 |
| extend +1 running | remaining +60; endsAt +60; total +60 |
| extend while waiting manual | no-op |
| extend while idle | no-op |
| Memory begin after dial at 45 | session work = memory recipe, not 45 |
