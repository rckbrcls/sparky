# Research: Desktop Multiplatform (iPhone + Mac)

**Feature**: `003-desktop-multiplatform`  
**Date**: 2026-07-18  
**Status**: Complete — no open NEEDS CLARIFICATION

## 1. Xcode target topology

**Decision**: Two native application targets in one project — existing `sparky` (iOS) + new `sparkyMac` (macOS). Shared source membership by default; iOS-only files excluded from Mac target (and vice versa for Mac entry/shell).

**Rationale**: Current `SDKROOT = iphoneos` and multiple UIKit representables make a single multiplatform target a big-bang red compile. Dual targets keep iOS green while Mac membership expands phase-by-phase.

**Alternatives considered**:
- Single multiplatform target — rejected for v1 (compile cliff).
- Mac Catalyst / Designed for iPad — rejected (constitution: native Mac chrome).
- Separate repo or SPM app packages — rejected (overkill; dual maintenance).

## 2. Deployment targets

**Decision**: iOS **26.0** (unchanged) + macOS **26.0** for the Mac target.

**Rationale**: Aligns with existing iOS 26 / Liquid Glass assumptions; minimizes availability sprawl. Constitution and product already target current OS generation.

**Alternatives considered**:
- macOS 14/15 for wider install base — only if distribution requirement appears; would force large availability audits.
- Catalyst deployment — rejected (see §1).

## 3. Root shell architecture

**Decision**: Keep `ContentView` as **iOS-only** root (tabs + existing covers). Add `DesktopRootView` + `DesktopNavigationState` + sidebar for **Mac**. Thin shared composition only where identical (environment injection, bootstrap `.task`).

**Rationale**: Spec FR-002/003; architect recommendation. ContentView is already navigation/presentation hub with UIKit tab bar and phone covers—forking via `#if` inside it is high regression risk.

**Alternatives considered**:
- One `AppShell` with heavy `#if` — rejected for v1 maintainability.
- Force `NavigationSplitView` on iPhone — rejected (breaks phone HIG / existing UX).

## 4. Location / geofence execution

**Decision**: Do not construct `LocationTriggerExecutor` on Mac. `TriggerExecutorCoordinator.sync` runs **scheduled only** on Mac. Persist and import/export `locationConfig` unchanged; Mac UI discloses iPhone-only execution and blocks arming new live geofences.

**Rationale**: Spec FR-012; CoreLocation background geofence product value is iPhone-first; avoids Always-location prompts on Mac.

**Alternatives considered**:
- Null-object location executor still linking CoreLocation — extra surface, no user value.
- Strip locationConfig on Mac open/save — **forbidden** (data loss).
- Full Mac geofence v1 — out of scope / reliability unproven for product promise.

## 5. UIKit bridge strategy (first wave)

**Decision**: **Compile-out / target-exclude** first; introduce protocol adapters only when two real implementations exist or tests need fakes.

| Surface | Mac v1 approach |
|---------|-----------------|
| `CustomTabBar` | iOS-only; Mac uses sidebar |
| Camera `UIImagePicker` | Exclude; use PhotosPicker/fileImporter |
| `AudioRecorderSheet` + AVAudioSession record | Exclude control |
| `AudioPlayerSheet` | Shared playback without forcing AVAudioSession category APIs that are iOS-only—guard session config |
| `FilePreviewController` (UIKit QL) | Exclude; Open In / SwiftUI preview fallback |
| `LinkPreviewView` (LPLinkView) | Fallback link row on Mac if bridge not ported |
| `UITextField` autofocus wrappers | `@FocusState` + SwiftUI `TextField` on Mac |
| `AppIconManager` | iOS-only settings row |

**Rationale**: Bridges are presentation edges, not domain ports. Premature protocols slow the compile-green path.

**Alternatives considered**:
- Protocolize every bridge before Mac boots — rejected (abstraction without second impl).
- Rewrite all editors before shell — rejected (bounds risk).

## 6. Attachments on Mac

**Decision**: Reuse existing `PhotosPicker` + `fileImporter` + security-scoped copy into `MemoryAttachmentStore` (`Application Support/MemoryAttachments/...`). Hide “Take Photo” and “Record Audio”. Playback of existing audio allowed.

**Rationale**: Editor already has picker/importer paths; matches FR-007–009; store layout stays identical for export/import.

**Alternatives considered**:
- AppKit `NSOpenPanel` only — only if fileImporter UX fails validation.
- Separate Mac attachment directory scheme — rejected (breaks export parity).

## 7. Notifications & deep links

**Decision**: Keep `UNUserNotificationCenter` delegate on `AppEnvironment` with `pendingMemoryOpenRequest` / `pendingFocusOpenRequest`. Mac shell observes the same published intents and selects sidebar section + pushes/presents detail. No custom URL scheme in v1. Add `NSApplicationDelegateAdaptor` only if cold-start tap delivery fails in validation.

**Rationale**: Buffering already exists; minimizes new IPC. Spec SC-003.

**Alternatives considered**:
- Parallel Mac-only notification stack — rejected (drift).
- URL scheme deep links first — unnecessary for v1.

## 8. Focus on Mac

**Decision**: Share `FocusTimer` / recipes / Focus UI modules. Sessions run while app is foreground/running. Do not promise Focus after Quit or cross-device handoff. Notifications for Focus phase may fire if permission granted (same service), but continuity after quit is non-goal.

**Rationale**: Spec User Story 3 / out-of-scope list.

**Alternatives considered**:
- Menu-bar Focus mini player — out of scope.
- Disable Focus entirely on Mac — rejected (desk is primary Focus context).

## 9. Data locality & identity

**Decision**: Each install = independent SwiftData store + attachments + UserDefaults/settings. Same Apple ID does not sync. Export/import remains manual snapshot path. Bundle ID: prefer distinct Mac bundle suffix if side-by-side with iOS Mac-Catalyst-less installs collide; final ID chosen at target creation without changing data format.

**Rationale**: Constitution V; Spec FR-013/014; empty entitlements (no iCloud).

**Alternatives considered**:
- App Group shared container iPhone↔Mac — implies continuum product and conflict UX; out of scope.
- CloudKit — requires constitution amendment.

## 10. Theme & chrome modifiers

**Decision**: Shared semantic theme. `.tabBarSpacer()` becomes zero/minimal on Mac. Liquid Glass used where available on both; no second visual system. Mac may use slightly denser spacing via size-class / platform checks inside shared modifiers—not forked feature colors.

**Rationale**: Constitution I–II.

## 11. Implementation ordering (compile-green ladder)

**Decision**:

1. iOS baseline green  
2. Mac target + empty/minimal shell compiles  
3. Shared domain/DI on Mac  
4. Sidebar + read-only browse  
5. Editor CRUD without banned capture  
6. Attachments pickers  
7. Notifications deep link  
8. Tests + docs matrix  

Never flip the existing iOS target to macOS SDK.

**Rationale**: Architect phased plan; minimizes “nothing runs” windows.

## 12. Testing strategy

**Decision**:

- Unit: coordinator scheduled-only on Mac capability; platform capability flags; existing Focus/Memory tests must remain shared and Mac-safe (no UIKit imports in domain tests).
- Build: iOS Simulator + macOS destinations Debug; Release compile Mac.
- Manual: quickstart scenarios A–H.
- UI tests: optional Mac smoke later; not gate for first green Mac.

**Rationale**: Spec success criteria + constitution quality gates.

## Resolved unknowns

| Former unknown | Resolution |
|----------------|------------|
| Single vs dual target | Dual app targets (§1) |
| macOS deployment | 26.0 (§2) |
| Shell sharing | Separate Mac root (§3) |
| Location on Mac | No executor; preserve data (§4) |
| Bridge abstraction depth | Compile-out first (§5) |
| Sync between devices | None (§9) |

No remaining NEEDS CLARIFICATION for planning.
