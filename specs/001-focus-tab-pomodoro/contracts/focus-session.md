# Contract: Focus Session API

**Feature**: `001-focus-tab-pomodoro`  
**Surface**: In-app session engine (`FocusTimer` + `AppEnvironment` façade)  
**Consumers**: Focus tab, Memory editor, notification open-request, settings (indirect via globals)

## 1. FocusRecipe

Immutable value describing one pomodoro recipe.

```text
FocusRecipe
  workDurationMinutes: Int          // 1...120
  shortBreakDurationMinutes: Int    // 1...60
  longBreakDurationMinutes: Int     // 1...60
  pomodorosUntilLongBreak: Int      // 1...12
  autoContinue: Bool

  workDurationSeconds: Int          // minutes * 60
  shortBreakDurationSeconds: Int
  longBreakDurationSeconds: Int
```

### Resolve

```text
FocusRecipe.from(settings: FocusSettings) -> FocusRecipe

FocusRecipe.resolve(schedule: ScheduleConfig) -> FocusRecipe?
  // nil if !schedule.focusEnabled
  // nil if any duration field is 0
  // else: concrete schedule fields

FocusRecipe.resolve(draft: ScheduleConfigDraft) -> FocusRecipe?
  // same rules
```

## 2. FocusTimer commands

| Command | Preconditions | Effect |
|---------|---------------|--------|
| `beginQuickSession()` | none | If active session with no memory and already active → no-op keep. If other active → caller must end first. Else bind recipe from settings snapshot, title Quick Focus, phase work, start. |
| `beginSession(memoryID:UUID, memoryTitle:String, recipe:FocusRecipe)` | recipe valid | Same memory + active → no-op keep. Else bind memory/title/recipe, work phase, start. |
| `start()` | not running | Resume or start current phase |
| `pause()` | running | Stop ticks; keep deadline paused (freeze remaining) |
| `startNextPhase()` | `isWaitingForManualStart` | Clear wait; start |
| `resetCurrentSession()` | optional binding | Zero counters; keep memory binding; phase idle |
| `endSession()` | any | Full reset; clear memory + recipe |

### Queries (published)

```text
remainingSeconds: Int
formattedTime: String
progress: Double                 // 0...1 within phase
phase: idle | work | break
isRunning: Bool
isWaitingForManualStart: Bool
completedPomodoros: Int
activeMemoryID: UUID?
activeMemoryTitle: String?
activeRecipe: FocusRecipe?
isSessionActive: Bool
nextBreakDurationSeconds: Int    // from activeRecipe
isQuickSession: Bool             // active && activeMemoryID == nil && isSessionActive
```

## 3. AppEnvironment façade

```text
startFocus(for memoryID: UUID)
  // loads memory; requires memory.hasFocus
  // resolves recipe; begins session; publishes pendingFocusOpenRequest

requestFocusTabPresentation()
  // optional helper: shell selects Focus tab / presents session UI

// Replace gate (UI-owned, may live in view):
canStartNewFocusTarget(memoryID: UUID?) -> Bool
  // false when isSessionActive && identity differs
```

Identity compare:
- Quick vs Quick: same
- Quick vs Memory: different
- Memory A vs Memory B: different
- Memory A vs Memory A: same

## 4. Notifications

Unchanged category behavior for phase complete:
- Work complete → “Focus complete” / break prompt
- Break complete → “Break over” / focus prompt

Schedule notification action `startFocus` still opens Memory-bound session via `pendingFocusOpenRequest`.

## 5. Invariants

1. At most one `FocusTimer` session in the app process.
2. Active session durations come from `activeRecipe`, not live settings mutation.
3. `endSession` is the only full clear; tab navigation must not call it implicitly.
4. Phase advance is idempotent w.r.t. wall-clock overdue (single advance per crossing).

## 6. Error / edge behavior

| Case | Behavior |
|------|----------|
| startFocus memory missing / !hasFocus | no-op |
| begin while other target active without end | UI blocks; API may assert/no-op if called wrongly |
| recipe out of range | clamp at write (editor/settings) and/or resolve |
| notification permission denied | in-app timer continues; may skip banner |

## 7. Non-goals

- Persisting session history
- Multiple concurrent timers
- Syncing session across devices
