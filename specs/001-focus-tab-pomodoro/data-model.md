# Data Model: Focus Tab & Memory Pomodoro Configuration

**Feature**: `001-focus-tab-pomodoro`  
**Date**: 2026-07-18

## Overview

Focus configuration is schedule-scoped. Global defaults stay outside SwiftData. Runtime sessions are ephemeral (in-memory on `FocusTimer`).

```text
FocusSettings (UserDefaults)
        │ seed on enable
        ▼
ScheduleConfig ──1:1── Memory
  focusEnabled
  focus recipe fields
        │ resolve
        ▼
   FocusRecipe (value)
        │ bind on start
        ▼
   FocusSession (FocusTimer state)
```

## Entities

### 1. Global Focus Defaults (`FocusSettings`)

| Field | Type | Default | Validation |
|-------|------|---------|------------|
| workDurationMinutes | Int | 25 | 1…120 |
| shortBreakDurationMinutes | Int | 5 | 1…60 |
| longBreakDurationMinutes | Int | 15 | 1…60 |
| pomodorosUntilLongBreak | Int | 4 | 1…12 |
| autoContinue | Bool | true | — |

**Storage**: `UserDefaults` keys `focus.*` (existing).  
**Role**: Quick Focus recipe and seed when enabling Memory Focus.

### 2. Memory Focus Configuration (on `ScheduleConfig` / draft)

Extends existing schedule primary.

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| focusEnabled | Bool | false | Existing |
| focusWorkDurationMinutes | Int | 0 | 0 = unset → resolve from globals |
| focusShortBreakDurationMinutes | Int | 0 | 0 = unset |
| focusLongBreakDurationMinutes | Int | 0 | 0 = unset |
| focusPomodorosUntilLongBreak | Int | 0 | 0 = unset |
| focusAutoContinue | Bool | true | Meaningful when `focusRecipeConfigured == true` |
| focusRecipeConfigured | Bool | false | true once seeded/customized |

**Chosen for implementation**: On enable, **always seed a full concrete recipe** from globals. A Focus-enabled configuration with any zero duration is invalid and cannot start.

**Relationships**:
- `ScheduleConfig.memory` → `Memory` (existing)
- Focus recipe has no independent identity

**Draft**: `ScheduleConfigDraft` mirrors the same Focus fields; `toModel` / `from` round-trip.

### 3. FocusRecipe (value type, non-persisted)

| Field | Type | Validation |
|-------|------|------------|
| workDurationMinutes | Int | 1…120 |
| shortBreakDurationMinutes | Int | 1…60 |
| longBreakDurationMinutes | Int | 1…60 |
| pomodorosUntilLongBreak | Int | 1…12 |
| autoContinue | Bool | — |

**Factories**:
- `FocusRecipe.from(settings: FocusSettings)`
- `FocusRecipe.resolve(schedule: ScheduleConfig, settings: FocusSettings) -> FocusRecipe?`  
  returns `nil` if `!focusEnabled || !schedule.isActive` (for target listing use `Memory.hasFocus`)
- `FocusRecipe.resolve(draft: ScheduleConfigDraft, settings: FocusSettings) -> FocusRecipe?`

**Derived**:
- work/short/long duration seconds

### 4. Focus Session (runtime on `FocusTimer`)

| Field | Type | Notes |
|-------|------|-------|
| phase | idle / work / break | Existing |
| remainingSeconds | Int | Display; prefer derived from deadline |
| phaseEndsAt | Date? | NEW wall-clock end |
| isRunning | Bool | |
| isWaitingForManualStart | Bool | |
| completedPomodoros | Int | Work blocks finished this session |
| activeMemoryID | UUID? | nil = Quick Focus |
| activeMemoryTitle | String? | Display; “Quick Focus” when nil memory |
| activeRecipe | FocusRecipe? | Bound for session lifetime |
| isSessionActive | Bool | Existing computed |

**State transitions**:

```text
idle
  ├─ beginQuickSession / beginSession(recipe) → work + running
  └─ (no-op if already active same memory)

work + running
  ├─ pause → work + paused
  ├─ tick/deadline → break (+ auto or waiting)
  └─ endSession → idle

break + running
  ├─ pause → break + paused
  ├─ tick/deadline → work (+ auto or waiting)
  └─ endSession → idle

* + waitingForManualStart
  └─ startNextPhase → same phase running

any active
  └─ resetCurrentSession → idle counters, keep memory binding (existing)
  └─ endSession → full clear
```

**Replace rule**: If `isSessionActive` and new target identity differs (`memoryID` optional equality), require user confirmation before `endSession` + begin.

### 5. Focus Target (read model)

Not persisted. Projection for Focus tab list:

| Field | Source |
|-------|--------|
| id | Memory.id |
| title | Memory.title |
| fireDate / next occurrence | ScheduleConfig (optional subtitle) |
| recipe summary | resolved FocusRecipe (e.g. “25/5”) |

**Eligibility**: `Memory.hasFocus` == `scheduleConfig?.isActive == true && focusEnabled` (existing). Do not require fire time to be due for tab start (tab is on-demand; editor due-gate may remain for secondary editor button).

## Validation rules

1. Duration steppers clamp to the same ranges as global settings UI.
2. `pomodorosUntilLongBreak >= 1`.
3. Enabling Focus requires an active schedule draft/config (existing editor constraint).
4. Saving Memory persists recipe fields through `MemoryService` schedule `toModel` path.
5. Disabling Focus sets `focusEnabled = false` without wiping recipe fields (re-enable restores).
6. Export includes the complete recipe; import rejects an incomplete enabled recipe.

## Memory.hasFocus

Unchanged semantic:

```text
scheduleConfig.isActive && scheduleConfig.focusEnabled
```

Optional helper:

```text
func focusRecipe(settings: FocusSettings) -> FocusRecipe?
```

## Entity changelog (implementation touch list)

| Type | Change |
|------|--------|
| `ScheduleConfig` | + recipe fields |
| `ScheduleConfigDraft` | + recipe fields, converters, equality for `hasChanges` |
| `FocusRecipe` | NEW |
| `FocusTimer` | + activeRecipe, beginQuickSession, wall clock, recipe-based durations |
| `FocusSettings` | unchanged keys (seed source) |
| `SparkyExportFormat` schedule/trigger DTO | + optional recipe fields |
| `MemoryEditorViewModel` | seed/update recipe; hasChanges includes recipe |
| `MemoryService` | preserve fields on copy/update helpers |
