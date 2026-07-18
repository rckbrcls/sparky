# Contract: Trigger Executor Seams

**Feature**: `003-desktop-multiplatform`  
**Consumers**: `TriggerExecutorCoordinator`, `AppEnvironment`, `MemoryService`, Mac/iOS targets  
**Status**: v1 normative

## Purpose

Allow scheduled reminders on both platforms while ensuring location/geofence side effects never run on Mac, without deleting user configuration.

## Current state (baseline)

```text
TriggerExecutorCoordinator
  ├─ ScheduledTriggerExecutor  (always)
  └─ LocationTriggerExecutor   (always constructed today)
sync(memories) → both
```

## Target state

```text
TriggerExecutorCoordinator
  ├─ ScheduledTriggerExecutor           (always)
  └─ LocationTriggerExecuting?          (iOS: real; Mac: nil)
sync(memories):
  await scheduled.sync(...)
  await location?.sync(...)            // no-op when nil
unregister* similarly optional
```

## Behavioral contract

### `sync(memories:)`

| Platform | scheduleConfig active | locationConfig active |
|----------|----------------------|------------------------|
| iOS | Register/update UN notifications | Register geofences (existing caps) |
| Mac | Register/update UN notifications | **Do not** register regions; **do not** start CLLocationManager |

### `unregister` / `unregisterAll`

| Platform | Scheduled | Location |
|----------|-----------|----------|
| iOS | Remove pending requests | Remove geofences |
| Mac | Remove pending requests | No-op (nothing armed) |

### Construction

- Mac: `TriggerExecutorCoordinator` MUST be creatable without linking/starting location monitoring.
- iOS: behavior remains equivalent to today for scheduled + location.

### MemoryService integration

After every mutation path that today calls `triggerExecutorCoordinator.sync`:

- MUST keep calling coordinator sync on both platforms.
- MUST NOT branch service-layer domain logic on OS except through coordinator/capabilities.
- MUST NOT nil-out `memory.locationConfig` when `supportsLocationExecution == false`.

## Notification payload contract (unchanged)

Scheduled notifications continue to carry `memoryID` (and existing category actions). Mac shell consumes the same `AppEnvironment` pending open publishers.

## Permission contract

| Permission | iOS | Mac |
|------------|-----|-----|
| Notifications | Request when onboarding/schedule needs | Request when onboarding/schedule needs |
| Location When-In-Use / Always | As today for map/geofence | **Do not** request for geofencing |
| Camera / Mic | As today for capture | **Do not** request if controls hidden |

## Test contract

1. **Mac coordinator unit test** (or capability-injected): `sync` with memories that have only locationConfig does not throw and does not require CLLocation authorization.
2. **iOS regression**: memory with both configs still schedules notification + geofence (existing expectations).
3. **Persistence**: create Memory with locationConfig on iOS export → import Mac → locationConfig present → Mac sync still scheduled-only.
4. **Idempotence**: repeated `sync` on Mac does not accumulate location monitors (none exist).

## Forbidden

- Parallel `MacTriggerManager` beside coordinator
- Re-enabling legacy `Managers/GeofenceManager` path
- Writing location execution into Focus or notification services
