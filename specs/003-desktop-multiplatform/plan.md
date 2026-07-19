# Implementation Plan: Desktop Multiplatform (iPhone + Mac)

**Branch**: `003-desktop-multiplatform` | **Date**: 2026-07-18 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/003-desktop-multiplatform/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

Ship Sparky as **one shared Swift codebase with two native builds** (iPhone iOS 26 + Mac macOS 26). Keep domain, SwiftData, drafts, services, theme, Focus engine, and import/export shared. Add a **Mac app target** with a desktop shell (`NavigationSplitView` sidebar: Calendar / Mind / Focus / Me), while **iPhone keeps** `ContentView` + tabs. Bound v1 Mac: full CRUD + schedule + Focus + scheduled notifications; **no** geofence execution, live camera, or mic recording. Heavy refactor is **edge-first** (shell, UIKit compile-out, conditional executors)—not a domain rewrite.

## Technical Context

**Language/Version**: Swift 6-era toolchain (Xcode 26), `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`

**Primary Dependencies**: SwiftUI, SwiftData, Combine, UserNotifications; CoreLocation **iOS-only** for geofence; PhotosUI / `fileImporter` for attachments; AVFoundation playback shared (no `AVAudioSession` record path on Mac)

**Storage**: Existing SwiftData container + `MemoryAttachmentStore` under Application Support per install (independent local brains; no sync)

**Testing**: Swift Testing shared unit/domain; destination matrix iOS Simulator + Mac; smoke UI per shell

**Target Platform**: iPhone (iOS 26.0) + Mac (macOS 26.0) — two native app targets, shared sources

**Project Type**: Native multiplatform Apple app (single Xcode project, dual app targets)

**Performance Goals**: Non-blocking Mac window during refresh/sync/import; lazy lists; attachment I/O off critical path; scroll OK at ~thousands of memories

**Constraints**: Constitution VI (no Catalyst, no Mac fork product); semantic theme only; offline P1; platform limits disclosed; preserve iPhone behavior; empty entitlements stay minimal

**Scale/Scope**: New Mac target + ~1 desktop shell module; AppEnvironment/coordinator seams; ~10–15 UIKit/iOS-only files gated or excluded; editor attachment path trim; notification deep-link wiring on Mac shell; docs/run matrix update. No schema migration expected.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*
*Source: `.specify/memory/constitution.md` (Sparky Constitution)*

- [x] **I. HIG / native feel**: iPhone tabs retained; Mac sidebar/window/keyboard-pointer; no stretched phone tab bar on Mac
- [x] **II. Semantic theme**: shared `Color.Theme` / modifiers / `ThemeManager`; no parallel Mac palette
- [x] **III. Modern SwiftUI**: small desktop shell views; drafts + services unchanged; presentation owned by each platform root
- [x] **IV. Performance**: lazy lists retained; no heavy body work; Mac window non-blocking during trigger sync/import
- [x] **V. Local-first architecture**: SwiftData + services + active schedule/location **models**; location **execution** iOS-only; no backend/auth
- [x] **VI. One code, two builds**: shared domain/UI default; divergence via target membership, `#if os`, availability, thin adapters; both destinations specified with fallbacks
- [x] **Complexity**: dual app targets (not single multiplatform target yet) justified below; no domain rewrite

**Post-design re-check**: PASS — design adds Mac shell + compile boundaries + conditional location registration without new persistence schema, sync layer, or parallel services. Contracts document shell navigation, capability matrix, and trigger coordinator seams only.

## Project Structure

### Documentation (this feature)

```text
specs/003-desktop-multiplatform/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── platform-capability-matrix.md
│   ├── desktop-shell-navigation.md
│   └── trigger-executor-seams.md
└── tasks.md                 # /speckit.tasks — not created here
```

### Source Code (repository root)

```text
sparky.xcodeproj/            # + sparkyMac app target, shared file membership
sparky/                      # SHARED default membership (iOS + Mac)
├── sparkyApp.swift          # iOS @main entry (iOS target only)
├── AppEnvironment.swift     # Conditional trigger coordinator wiring
├── ContentView.swift        # iOS root shell (tabs) — iOS membership or #if os(iOS)
├── Data/ DataController.swift
├── Model/                   # Unchanged schema/drafts/export
├── Services/                # Memory/Mind/import-export shared
├── Executors/
│   ├── TriggerExecutorCoordinator.swift  # Optional location executor
│   ├── ScheduledTriggerExecutor.swift    # Shared
│   ├── LocationTriggerExecutor.swift     # iOS-only membership
│   └── TriggerExecutorProtocol.swift
├── Managers/                # Theme, attachments, settings; AppIconManager iOS-only
├── ViewModels/
├── Views/
│   ├── Desktop/             # NEW — Mac shell (sidebar, nav state, root)
│   │   ├── DesktopRootView.swift
│   │   ├── DesktopSidebar.swift
│   │   └── DesktopNavigationState.swift
│   ├── Memories/ …          # Shared; camera/recorder sheets iOS-only
│   ├── Minds/ …
│   ├── Focus/ …
│   ├── Settings/ …          # Hide iOS-only rows on Mac
│   ├── Onboarding/ …        # Mac copy / permission subset
│   └── Shared/              # CustomTabBar iOS-only
├── Extensions/              # tabBarSpacer no-op or iOS-only spacing on Mac
├── Focus/                   # Shared timer/recipe/notifications
└── Utilities/

sparkyMac/                   # NEW thin Mac target folder (entry only if preferred)
└── sparkyMacApp.swift       # @main WindowGroup → DesktopRootView

sparkyTests/                 # Shared Swift Testing + Mac-safe suites
sparkyUITests/               # Extend or add Mac smoke later as needed
```

**Structure Decision**: **Two native app targets** sharing `sparky/` sources. Mac gets thin `@main` + `Views/Desktop/*`. iOS keeps current entry + `ContentView`. Do **not** create parallel `ios/` + `macos/` copies of features. iOS-only files use **target membership** (preferred) and/or `#if os(iOS)` where shared files need a branch. No SPM package split in v1.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Two app targets instead of one multiplatform target | Existing UIKit-heavy iOS target cannot flip SDKROOT without a long red compile; dual targets let Mac membership grow phase-by-phase while iOS stays green | Single multiplatform target forces all UIKit bridges to compile on day 1 and risks blocking iOS delivery |
| Separate Mac root (`DesktopRootView`) vs heavy `#if` in `ContentView` | Spec requires sidebar vs tabs; ContentView already owns tabs, haptics, fullScreenCovers, UIKit tab bar | Spamming `#if os` through 500+ line ContentView increases regression risk on iPhone |
| Location executor not constructed on Mac | Spec FR-012 / no geofence execution | Always-on null object still pulls CoreLocation lifecycle complexity without product value |

## Phase 0 → research.md

See [research.md](./research.md). All technical unknowns resolved; no open NEEDS CLARIFICATION.

## Phase 1 → design artifacts

- [data-model.md](./data-model.md)
- [contracts/platform-capability-matrix.md](./contracts/platform-capability-matrix.md)
- [contracts/desktop-shell-navigation.md](./contracts/desktop-shell-navigation.md)
- [contracts/trigger-executor-seams.md](./contracts/trigger-executor-seams.md)
- [quickstart.md](./quickstart.md)

## Implementation approach (planning only)

### Phase A — Project baseline (keep iOS green)

1. Add **sparkyMac** app target (macOS 26, bundle e.g. `polterware.sparky` or `.mac` suffix if store identity requires—default same team, distinct bundle if needed for side-by-side install).
2. Share Model/Data/Services/Focus/theme/utilities first.
3. Add `sparkyMacApp.swift` → placeholder `DesktopRootView` “Sparky Mac” + environment bootstrap.
4. Exclude pure UIKit files from Mac target membership.
5. CI/local matrix: `xcodebuild` iOS Simulator **and** macOS destination.

### Phase B — DI & executors

1. `TriggerExecutorCoordinator`: inject/create `LocationTriggerExecutor` only on iOS; Mac runs scheduled-only `sync`.
2. `AppEnvironment` / `MemoryService` must not assume `coordinator.location` always exists (optional API or protocol split—see contracts).
3. Notification delegate + categories register on both; permission request text Mac-specific where shown.
4. Do not request Always-location on Mac.

### Phase C — Desktop shell

1. `DesktopNavigationState`: selected section (calendar/mind/focus/me), per-section `NavigationPath`, pending editor/composer routes, pending notification open.
2. `DesktopRootView`: `NavigationSplitView` sidebar + detail; wire `AppEnvironment` pending memory/focus opens to section + destination.
3. Reuse existing feature roots (timeline, minds list, Focus tab content, Me) inside detail columns with Mac-friendly presentation (sheet/inspector instead of phone `fullScreenCover` where needed).
4. Keyboard: ⌘N / Escape patterns for create/dismiss where natural; document in quickstart.

### Phase D — Editor & attachments

1. Shared `MemoryEditorView` compiles on Mac: hide camera + audio record entry points (`#if os` or capability flags).
2. Keep `PhotosPicker` + `fileImporter` paths; security-scoped copy into `MemoryAttachmentStore`.
3. Replace/exclude `FilePreviewController` (UIKit QL) with SwiftUI/`QLPreview` Mac path or “Open with default app”.
4. `LinkPreviewView`: SwiftUI fallback text/link button on Mac if LPKit bridge not ported in v1.
5. Autofocus: replace `UITextField` wrappers with SwiftUI `TextField` + `@FocusState` on Mac (or shared FocusState path).

### Phase E — Settings, onboarding, chrome

1. Hide alternate app icon, iOS background-location copy, camera/mic permission rows not used on Mac.
2. Onboarding: “Data stays on this Mac”; request notifications only (and photos if required by picker).
3. `LiquidGlassModifier` / `.tabBarSpacer()`: no-op or reduced padding on Mac.
4. Me metrics and import/export remain shared.

### Phase F — Hardening

1. Import preserves `locationConfig` without arming geofences on Mac.
2. Location UI in editor: read-only disclosure on Mac (“Runs on iPhone”) or hide create-new-location controls.
3. Tests: coordinator Mac sync scheduled-only; capability matrix unit flags; export/import round-trip unchanged; Focus timer shared tests still pass.
4. Update `CLAUDE.md` / `AGENTS.md` / README run matrix when target lands (constitution follow-up).

### Explicit non-goals (do not schedule in v1 tasks)

- Cloud sync, accounts, multi-window documents, menu-bar agent
- Mac geofencing, camera capture, mic record
- Migrating off Combine/`ObservableObject`
- Splitting domain into SPM packages
- Redesigning Focus visual system beyond compiling/adapting layout

## Agent context

No `update-agent-context` script under `.specify/scripts` in this repo. Feature pointer: `.specify/feature.json` → `specs/003-desktop-multiplatform`. Runtime guidance remains constitution + `AGENTS.md`; amend deployment docs when Mac target exists.

## Subagent policy for implementation

Per user request and global AGENTS: heavy refactor uses subagents—

| Phase | Agent | Role |
|-------|--------|------|
| A–B | `scout` then parent | Target membership / compile blockers |
| C | `architect` if nav trade-off reopens; else parent | Shell only |
| D | `worker` for bounded editor Mac gates | File-owned chunks |
| F | one `reviewer` | Material multi-file diff risk |

Parent keeps Speckit artifacts and final integration.
