# Data Model: Desktop Multiplatform (iPhone + Mac)

**Feature**: `003-desktop-multiplatform`  
**Date**: 2026-07-18

## Overview

**No new SwiftData `@Model` types and no schema migration** for v1. Multiplatform work reuses the existing local-first graph. What changes is **runtime capability**, **navigation state (ephemeral)**, and **which executors arm side effects** on each OS.

```text
                    ┌─────────────────────────────┐
                    │     Local Install (device)   │
                    │  SwiftData + Attachments +   │
                    │  Settings / FocusSettings    │
                    └──────────────┬──────────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              ▼                    ▼                    ▼
         Mind / Tag            Memory (+ drafts)    FocusSettings
              │                    │
              │         ┌──────────┼──────────┐
              │         ▼          ▼          ▼
              │   scheduleConfig  locationConfig  attachments
              │         │          │               │
              │         ▼          ▼               ▼
              │   ScheduledExec  LocationExec*   File store
              │   (iOS + Mac)    (iOS only*)     (both)
              │
              └── shared hierarchy on both builds

* locationConfig rows still persist on Mac; executor does not arm geofences.
```

## Durable entities (unchanged shapes)

### Memory

| Concern | Behavior on Mac | Behavior on iPhone |
|---------|-----------------|--------------------|
| CRUD fields (title, note, status, pin, checklist, mind, tags) | Full | Full |
| `scheduleConfig` | Full edit + scheduled notifications | Full |
| `locationConfig` | **Persist / import / display**; no live arming | Persist + geofence execution |
| `focusEnabled` (via schedule) | Start Focus from Memory | Same |
| Attachments refs | Image/file/link add; audio play; no record/camera | Full capture set |
| Completion dates / recurrence semantics | Same domain rules | Same |

Draft: `MemoryDraft` remains the editor boundary on both platforms.

### Mind / Tag / CheckItem / ScheduleConfig / LocationConfig / MemoryAttachmentReference / MemoryCompletionDate

Unchanged field-level contracts. Cascade rules unchanged. Export format (`SparkyExportFormat` v2 and related) **must continue to round-trip `locationConfig`** even when imported on Mac.

### FocusSettings / Focus session runtime

- Durable: `FocusSettings` (UserDefaults) shared semantics.
- Runtime: `FocusTimer` session state ephemeral; not a cross-device record.
- Mac: no durable “session continues after quit” entity.

## Ephemeral / UI state (new)

### DesktopNavigationState (Mac only, in-memory)

| Field | Type | Purpose |
|-------|------|---------|
| selectedSection | enum calendar \| mind \| focus \| me | Sidebar selection |
| calendarPath | NavigationPath | Drill-in stack |
| mindsPath | NavigationPath | Drill-in stack |
| mePath | NavigationPath | Drill-in stack |
| editorRoute | optional Memory editor route | Present editor |
| mindComposerRequest | optional | Present mind composer |
| quickMemoryRequest | optional | Quick capture |
| focusCover/session presentation | optional | If Mac uses sheet for Focus overlay |

**Validation**: Section changes clear ephemeral sheets only when dismissing is user-safe (no silent discard of dirty editor without confirm—reuse existing dirty gates).

### PlatformCapability (compile-time + tiny runtime helper)

Not persisted. Logical flags:

| Flag | iOS | Mac |
|------|-----|-----|
| supportsTabShell | true | false |
| supportsSidebarShell | false | true |
| supportsLocationExecution | true | false |
| supportsCameraCapture | true | false |
| supportsMicrophoneRecord | true | false |
| supportsScheduledNotifications | true | true |
| supportsAlternateAppIcon | true | false |
| supportsLiveFocusWhileRunning | true | true |
| supportsFocusAfterQuit | unspecified / best-effort iOS | false (not promised) |

## State transitions

### Trigger arming after Memory save

```text
Memory saved with active scheduleConfig
  → ScheduledTriggerExecutor.sync (iOS + Mac)

Memory saved with active locationConfig
  → iOS: LocationTriggerExecutor.sync
  → Mac: no-op execution; config remains stored

Memory imported with both configs
  → Same as above per platform
```

### Notification open

```text
UN notification tap (memoryID)
  → AppEnvironment.pendingMemoryOpenRequest
  → iOS ContentView opens editor/tab
  → Mac DesktopRootView selects section + opens Memory
```

### Install lifecycle

```text
Fresh Mac install → empty local store (not cloned from iPhone)
Export on A → file → Import on B → snapshot restore per existing import rules
```

## Validation rules (multiplatform-specific)

1. Saving a Memory on Mac MUST NOT clear `locationConfig` merely because execution is unavailable.
2. Mac UI MUST NOT present a control that sets location monitoring “on” with the expectation of desktop geofence firing.
3. Attachment files MUST remain under the same relative store layout so export/import stays compatible.
4. No new required fields on durable models for “platform of origin.”
5. Settings keys that are iOS-only MAY remain in UserDefaults unused on Mac; they MUST NOT crash reads.

## Migration

- **Schema migration**: none.
- **Data migration**: none.
- **Trigger migration**: existing `migrateTriggersIfNeeded` unchanged; runs on both if still version-gated.
- **Code migration**: target membership + coordinator optionality only.

## Relationship to prior features

| Feature | Impact |
|---------|--------|
| 001 Focus pomodoro | Shared engine; Mac runs while app open |
| 002 Focus redesign | Shared views adapt layout; no schema |
| Legacy triggers → config | Unchanged; Mac scheduled path uses scheduleConfig |
