# Data Model: Cross-Platform Experience Polish

This feature adds no SwiftData entity and requires no persistent-store
migration. Durable additions are local `UserDefaults` values owned by
`FocusSettings`; the remaining entities are transient UI or event models.

## FocusFeedbackPreferences

Local user preferences for Focus-only feedback.

| Field | Type | Default | Storage key | Validation |
|---|---|---:|---|---|
| `notificationsEnabled` | `Bool` | `true` | `focus.notificationsEnabled` | Missing key resolves to `true` |
| `soundsEnabled` | `Bool` | `true` | `focus.soundsEnabled` | Missing key resolves to `true` |
| `focusCompletionSound` | `FocusSoundChoice` | `.glass` | `focus.focusCompletionSound` | Unknown raw value falls back to `.glass` |
| `breakCompletionSound` | `FocusSoundChoice` | `.bell` | `focus.breakCompletionSound` | Unknown raw value falls back to `.bell` |

### Relationships

- Owned by the existing `FocusSettings` observable object.
- Read by `FocusFeedbackService`.
- Edited by `FocusSettingsView`.
- Reset together with existing Focus duration and auto-continue defaults.
- Independent from `SettingsStore.notificationSoundEnabled`, which remains the
  Memory notification sound preference.

## FocusSoundChoice

A persisted, shared enumeration for selectable phase-completion cues.

| Case | Display name | Asset role |
|---|---|---|
| `.glass` | `Glass` | Default Focus completion |
| `.bell` | `Bell` | Default Break completion |
| `.chime` | `Chime` | Optional completion cue |
| `.ping` | `Ping` | Optional completion cue |
| `.pop` | `Pop` | Optional completion cue |

Rules:

- Raw values are stable English identifiers.
- Display names are concise English UI strings.
- Each case resolves to one bundled audio resource available in both targets.
- Asset lookup or playback failure is non-fatal and has no fallback beep.

## FocusFeedbackEvent

A transient effective timer transition.

| Event | Sound | Notification |
|---|---|---|
| `.startOrResume` | Fixed Start cue | None |
| `.pause` | Fixed Pause cue | None |
| `.end` | Fixed End cue | None |
| `.focusComplete` | `focusCompletionSound` | Silent Focus-complete banner |
| `.breakComplete` | `breakCompletionSound` | Silent Break-complete banner |

### Validation rules

- Emit only after the underlying command changes timer state.
- Emit at most once for one effective transition.
- `.focusComplete` and `.breakComplete` are the only notification-producing
  events.
- Previewing a sound is not a timer event and cannot mutate timer state.
- Failures in feedback adapters do not throw into timer state transitions.

## Focus Timer State Transitions

```text
idle -- start ----------------------> work/running
work/running -- pause --------------> work/paused
work/paused -- start ---------------> work/running
work -- complete -------------------> break/running or break/waiting
break -- complete ------------------> work/running or work/waiting
waiting -- start next phase --------> current phase/running
active session -- explicit end -----> idle
```

Feedback rules:

- `start` and `start next phase` emit `.startOrResume`.
- `pause` emits `.pause`.
- `explicit end` emits `.end`.
- Work completion emits `.focusComplete`.
- Break completion emits `.breakComplete`.
- Internal reset, session replacement, automatic continuation, duration
  changes, and phase extension do not add a second event.

## MeMetricDisplayState

A presentation concept that preserves the distinction between measured zero
and unavailable data.

```swift
enum MeMetricDisplayState<Value> {
    case measured(Value)
    case unavailable
}
```

The implementation may use focused computed properties instead of introducing
this generic type, provided the contract is preserved.

| Metric | Measured zero valid? | Unavailable rule | Visible unavailable value |
|---|---:|---|---|
| Weekly completions | Yes | Never; seven-day window always exists | N/A |
| Active days | Yes | Never; seven-day window always exists | N/A |
| Streak | Yes | Never; zero is meaningful | N/A |
| All-time completions | Yes | Never; zero is meaningful | N/A |
| Scheduled completion | No denominator means unavailable | `scheduledOccurrences == 0` | `—` |
| Most active period | No | Insufficient sample or tie | `—` |
| Best completion day | No | Insufficient sample or tie | `—` |

Accessibility maps `—` to `Not available`.

## DesktopTabRoot

Transient navigation state owned by `DesktopNavigationState`.

| Destination | Root transition on reselection | Preserved state |
|---|---|---|
| Calendar | No navigation mutation | `calendarMode`, `calendarAnchorDate` |
| Mind | Clear `mindsPath`; clear transient Mind context/search | User data |
| Focus | No navigation mutation | Entire `FocusTimer` session |
| Me | Clear `mePath` | Dashboard metrics and preferences |

The operation is idempotent when the destination is already at root.

## DesktopMemoryPreviewStatus

Presentation of existing `MemoryStatus`.

| Persisted status | Symbol | Action label | Next successful state |
|---|---|---|---|
| `.active` | `circle` | `Complete Memory` | `.completed` |
| `.completed` | `checkmark.circle.fill` | `Reopen Memory` | `.active` |

The optimistic state may appear immediately, but a failed save restores the
previous authoritative status and checklist drafts while retaining the
existing error message.
