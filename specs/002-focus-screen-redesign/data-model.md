# Data Model: Focus Screen Visual Redesign

**Feature**: `002-focus-screen-redesign`  
**Date**: 2026-07-18

## Overview

No new SwiftData `@Model` types. This delivery extends **runtime session** fields and adds **ephemeral UI state** for idle duration selection. Durable Focus configuration remains exactly as in `001-focus-tab-pomodoro` (`FocusSettings`, `ScheduleConfig` recipe fields, `FocusRecipe`).

```text
FocusSettings (UserDefaults)
        │ seed idle selectedWorkMinutes
        ▼
FocusIdleSetupState (UI, ephemeral)
  selectedWorkMinutes
  presetsMenuPresented?
        │ Start Quick Focus
        ▼
FocusRecipe (work overridden for quick only)
        │ bind
        ▼
FocusSession / FocusTimer
  + phaseStartedAt
  + phaseEndsAt (exposed)
  + extendCurrentPhase
        │
        ├── Quick: dial minutes
        └── Memory: ScheduleConfig recipe (unchanged)
```

## Entities

### 1. Global Focus Defaults (`FocusSettings`) — unchanged

| Field | Type | Default | Validation |
|-------|------|---------|------------|
| workDurationMinutes | Int | 25 | 1…120 |
| shortBreakDurationMinutes | Int | 5 | 1…60 |
| longBreakDurationMinutes | Int | 15 | 1…60 |
| pomodorosUntilLongBreak | Int | 4 | 1…12 |
| autoContinue | Bool | true | — |

**Role this feature**: Seed idle dial; fill non-work fields of Quick Focus recipe.

### 2. FocusRecipe — unchanged shape

| Field | Type | Validation |
|-------|------|------------|
| workDurationMinutes | Int | 1…120 |
| shortBreakDurationMinutes | Int | 1…60 |
| longBreakDurationMinutes | Int | 1…60 |
| pomodorosUntilLongBreak | Int | 1…12 |
| autoContinue | Bool | — |

**Quick Focus construction**:
1. `base = FocusRecipe.from(settings:)`
2. If UI provides override `W`: `base.workDurationMinutes = clamp(W, 1…120)`
3. Bind as `activeRecipe`

**Memory construction**: existing `FocusRecipe.resolve(schedule:settings:)` — **ignore** idle dial.

### 3. Focus Idle Setup State (ephemeral UI)

Not persisted in SwiftData.

| Field | Type | Rules |
|-------|------|-------|
| selectedWorkMinutes | Int | 1…120; step 1 |
| isPresetMenuOpen | Bool | UI only |

**Initialization**:
- On enter idle: `selectedWorkMinutes = focusSettings.workDurationMinutes` (clamped).
- If optional `focus.lastQuickWorkMinutes` exists and is in range, may prefer that (plan optional).

**Presets** (constant list, not stored entities):

| ID | Minutes | Label |
|----|---------|-------|
| m5 | 5 | 5 min |
| m10 | 10 | 10 min |
| m15 | 15 | 15 min |
| m30 | 30 | 30 min |
| m45 | 45 | 45 min |
| m60 | 60 | 1 hr |

Selecting a preset sets `selectedWorkMinutes` only.

**Validation**:
- Dial drag clamps to 1…120.
- Invalid values never reach `beginQuickSession`.

### 4. Focus Session (runtime on `FocusTimer`) — extended

Existing fields remain. Additions/exposures:

| Field | Type | Notes |
|-------|------|-------|
| phase | idle / work / break | Existing |
| remainingSeconds | Int | Existing |
| currentPhaseTotalSeconds | Int | Existing (internal); used in extend |
| phaseEndsAt | Date? | **Expose** for UI end time |
| phaseStartedAt | Date? | **New** — set on `configurePhase` |
| isRunning | Bool | Existing |
| isWaitingForManualStart | Bool | Existing |
| completedPomodoros | Int | Existing |
| activeMemoryID | UUID? | Existing |
| activeMemoryTitle | String? | Existing |
| activeRecipe | FocusRecipe? | Existing |
| isSessionActive | Bool | Existing |

**Derived for UI**:

| Derived | Definition |
|---------|------------|
| expectedEndDate | `phaseEndsAt` if running; else if remaining known: `Date() + remaining` while paused (or nil) |
| timeWindowLabel | format `phaseStartedAt` → `expectedEndDate` if both non-nil |
| progress | `elapsed / currentPhaseTotalSeconds` where `elapsed = total - remaining` (unchanged formula; extend bumps both remaining and total) |
| canExtendPhase | `isSessionActive && (phase == .work \|\| phase == .break) && !isWaitingForManualStart` |
| formattedTime | Existing mm:ss |

### 5. Duration preset (catalog value)

Not a persisted model — static catalog in UI layer (see table above).

### 6. Memory Focus target — unchanged

Listing still: `Memory.hasFocus` + resolved recipe summary. No new fields.

## State transitions

### Idle setup

```text
[Enter Focus tab, !session]
  → selectedWorkMinutes = defaults (or last quick)
  → user drags dial / picks preset
  → selectedWorkMinutes updates
  → Start (+ replace gate)
  → beginQuickSession(workDurationMinutes: selected)
  → Active(work)
```

### Active session (existing + extend)

```text
Active(work|break) + running
  → pause → Active paused
  → resume → Active running
  → extend +1 → remaining+=60, total+=60, endsAt+=60 if running
  → phase complete → break or work (recipe) or wait manual
  → end → Idle setup
```

### Memory start

```text
Idle → pick Memory → replace gate → beginSession(id,title,recipe)
  → Active (title = Memory; recipe from Memory)
  // dial value ignored
```

## Validation summary

| Rule | Enforcement |
|------|-------------|
| Work minutes 1…120 | clamp on dial, presets, beginQuick override |
| Extend only mid-phase | `canExtendPhase` |
| One session | existing `wouldReplaceSession` |
| Memory recipe integrity | no dial write into ScheduleConfig |
| No negative remaining | `max(0, …)` after clock sync; extend only adds |

## Migration

**None.** No SwiftData schema version bump. The optional UserDefaults key for last quick minutes is additive.

## Export / import

**Unchanged.** Redesign does not alter export DTOs.
