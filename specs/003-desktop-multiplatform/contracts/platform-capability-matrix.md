# Contract: Platform Capability Matrix

**Feature**: `003-desktop-multiplatform`  
**Consumers**: Mac/iOS shells, Memory editor chrome, Settings/onboarding, TriggerExecutorCoordinator, tests  
**Status**: v1 normative

## Purpose

Define which user-facing capabilities exist on each build so UI and executors fail closed (omit or disclose) instead of crashing or silently no-oping.

## Matrix

| Capability ID | iPhone | Mac v1 | User-visible rule |
|---------------|--------|--------|-------------------|
| `shell.tabs` | yes | no | Mac MUST use sidebar shell |
| `shell.sidebar` | no | yes | iPhone MUST keep tabs |
| `memory.crud` | yes | yes | Full domain parity |
| `memory.schedule` | yes | yes | Edit + arm notifications |
| `memory.location.persist` | yes | yes | Never strip on save |
| `memory.location.execute` | yes | **no** | Mac: disclose iPhone-only |
| `memory.location.createUI` | yes | **no** (or read-only) | No arming UX on Mac |
| `attachment.photosPicker` | yes | yes | |
| `attachment.fileImporter` | yes | yes | |
| `attachment.camera` | yes | **no** | Hide control |
| `attachment.audioRecord` | yes | **no** | Hide control |
| `attachment.audioPlay` | yes | yes | If file present |
| `attachment.link` | yes | yes | Preview may be simpler on Mac |
| `focus.quick` | yes | yes | While app running |
| `focus.memoryBound` | yes | yes | While app running |
| `focus.afterQuit` | best-effort | **not promised** | No Mac marketing claim |
| `notifications.scheduled` | yes | yes | Permission-gated |
| `notifications.openMemory` | yes | yes | Via pending open intent |
| `settings.alternateIcon` | yes | **no** | Hide row |
| `settings.theme` | yes | yes | system/light/dark |
| `data.exportImport` | yes | yes | Manual snapshot only |
| `data.cloudSync` | no | no | Out of scope |
| `haptics` | yes | no | Visual feedback only |

## API shape (logical)

```text
enum AppPlatform { iPhone, mac }

struct PlatformCapabilities {
  static var current: PlatformCapabilities { get } // resolved at runtime from OS
  var supportsLocationExecution: Bool
  var supportsCameraCapture: Bool
  var supportsMicrophoneRecord: Bool
  var supportsAlternateAppIcon: Bool
  var supportsTabShell: Bool
  var supportsSidebarShell: Bool
  // …mirrors matrix
}
```

Implementation may be a small `enum`/`struct` with `#if os` defaults; tests may inject overrides.

## Invariants

1. UI entry points for a capability with `no` MUST be omitted or disabled with explanation—never crash.
2. Executors MUST NOT register OS monitors for capabilities marked `no`.
3. Persistence layer MUST NOT use this matrix to delete user configuration.
4. Changing a cell from `no` → `yes` requires spec amendment (especially location execute).

## Test hooks

- Unit: `PlatformCapabilities.mac.supportsLocationExecution == false`
- Unit: saving Memory with locationConfig on Mac leaves config non-nil
- UI smoke: camera/record controls absent on Mac editor
