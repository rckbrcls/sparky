# Tasks: Desktop Multiplatform (iPhone + Mac)

**Input**: Design documents from `/specs/003-desktop-multiplatform/`

**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/, quickstart.md

**Tests**: Not TDD-mandated by spec; include **targeted** unit tests required by plan/contracts (coordinator seams, capabilities, non-strip locationConfig). Manual validation via quickstart.md.

**Organization**: Setup → Foundational (Mac target + DI seams) → User stories US1–US5 → Polish

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete work)
- **[Story]**: US1…US5 maps to spec user stories
- Paths are repo-relative

## Path Conventions

- Shared: `sparky/`
- Mac entry: `sparkyMac/`
- Tests: `sparkyTests/`
- Project: `sparky.xcodeproj/project.pbxproj`
- No parallel `ios/` + `macos/` feature trees

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Branch/docs alignment and Mac target skeleton so work has a home

- [X] T001 Confirm branch `003-desktop-multiplatform` and feature pointer in `.specify/feature.json` → `specs/003-desktop-multiplatform`
- [X] T002 [P] Add `sparky/Views/Desktop/` directory placeholder (`.gitkeep` if needed) for Mac shell sources per plan.md
- [X] T003 [P] Add `sparkyMac/` directory for Mac `@main` entry per plan.md
- [X] T004 Document intended scheme names (`sparky`, `sparkyMac`) and destinations in `specs/003-desktop-multiplatform/quickstart.md` if target names differ after Xcode creation

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Dual-target project, platform capability helper, optional location executor, Mac app boots with environment — **blocks all user stories**

**⚠️ CRITICAL**: No US work until Mac target builds a window and iOS still builds/tests green

- [X] T005 Create macOS app target `sparkyMac` (macOS 26.0) in `sparky.xcodeproj/project.pbxproj` with shared source membership strategy from research.md §1
- [X] T006 Add Mac entry `sparkyMac/sparkyMacApp.swift` (`@main` `WindowGroup`, inject `AppEnvironment` + `ThemeManager`, `.task { bootstrap() }`)
- [X] T007 Wire shared core into Mac target membership: `DataController`, models, drafts, `MemoryService`, `MindService`, export/import services, `Focus/*`, `ThemeManager`, `Color+Theme`, `SettingsStore`, `MemoryAttachmentStore` via `sparky.xcodeproj/project.pbxproj`
- [X] T008 Exclude iOS-only UIKit bridges from Mac target membership in `sparky.xcodeproj/project.pbxproj`: `sparky/Views/Shared/CustomTabBar.swift`, `sparky/Views/Memories/Editor/Components/MemoryEditorCameraCaptureView.swift`, `sparky/Views/Memories/Editor/Components/AudioRecorderSheet.swift`, `sparky/Managers/AppIconManager.swift` (extend list as compile errors dictate)
- [X] T009 [P] Implement `sparky/Utilities/PlatformCapabilities.swift` mirroring `specs/003-desktop-multiplatform/contracts/platform-capability-matrix.md`
- [X] T010 Refactor `sparky/Executors/TriggerExecutorCoordinator.swift` so `LocationTriggerExecutor` is optional / iOS-only construction per `contracts/trigger-executor-seams.md`
- [X] T011 Update `sparky/AppEnvironment.swift` to construct coordinator without location execution on Mac; keep notification delegate + pending open publishers shared
- [X] T012 Ensure `sparky/Services/MemoryService.swift` sync/unregister paths tolerate missing location executor (no force-unwrap of location API)
- [X] T013 Gate or exclude `sparky/Executors/LocationTriggerExecutor.swift` from Mac target (membership and/or `#if os(iOS)`)
- [X] T014 Provide minimal `sparky/Views/Desktop/DesktopRootView.swift` placeholder hosted by `sparkyMacApp` (title “Sparky” + proof environment loads) so Mac target links
- [X] T015 Keep iOS entry `sparky/sparkyApp.swift` + `sparky/ContentView.swift` as iOS root only (target membership or `#if os(iOS)` so Mac does not compile phone tab shell as `@main`)
- [ ] T016 Verify iOS build still succeeds: `xcodebuild -scheme sparky -destination 'platform=iOS Simulator,name=iPhone 16' build`
- [ ] T017 Verify Mac build succeeds: `xcodebuild -scheme sparkyMac -destination 'platform=macOS' build`
- [X] T018 [P] Add `sparkyTests/Platform/PlatformCapabilitiesTests.swift` asserting Mac flags (location execute/camera/mic/icon false; schedule/sidebar true) and iOS flags per contract
- [ ] T019 [P] Add `sparkyTests/Executors/TriggerExecutorCoordinatorMacSeamsTests.swift` (or capability-injected) proving location-only memories sync without requiring CoreLocation auth

**Checkpoint**: Foundation ready — iOS green, Mac launches shell placeholder, coordinator seams + capabilities exist

---

## Phase 3: User Story 1 - Mac desk companion (Priority: P1) 🎯 MVP

**Goal**: Desktop-idiomatic shell with Calendar / Mind / Focus / Me; create-edit-complete-search Memories and Minds; theme; resize; local persistence

**Independent Test**: quickstart Scenario A (+ F theme subset) on Mac-only install

### Implementation for User Story 1

- [X] T020 [US1] Implement `sparky/Views/Desktop/DesktopNavigationState.swift` (section enum, per-section `NavigationPath`, editor/composer/quick routes) per `contracts/desktop-shell-navigation.md`
- [X] T021 [US1] Implement `sparky/Views/Desktop/DesktopSidebar.swift` listing Calendar, Mind, Focus, Me with selection binding
- [X] T022 [US1] Expand `sparky/Views/Desktop/DesktopRootView.swift` to `NavigationSplitView` hosting sidebar + detail and observing `AppEnvironment`
- [X] T023 [US1] Embed existing Calendar/timeline root into Desktop Calendar detail (reuse current calendar tab root view file(s) under `sparky/Views/` — wire without copying domain)
- [X] T024 [US1] Embed existing Minds root into Desktop Mind detail (reuse `sparky/Views/Minds/*` entry)
- [X] T025 [US1] Embed Focus feature root into Desktop Focus detail (reuse `sparky/Views/Focus/*` or `sparky/Focus/*` session entry)
- [X] T026 [US1] Embed Me/settings root into Desktop Me detail (reuse `sparky/Views/Settings/*` entry)
- [X] T027 [US1] Replace phone-only `fullScreenCover` assumptions for Memory editor presentation on Mac with sheet/detail route from `DesktopNavigationState` in `DesktopRootView.swift`
- [X] T028 [US1] Wire create Memory / create Mind actions to toolbar buttons on Mac shell in `DesktopRootView.swift` / section toolbars
- [X] T029 [US1] Ensure Mind assignment, checklist, pin/status, search/filter use existing services unchanged from Mac-presented editor/list flows
- [X] T030 [US1] Apply `.withAppTheme()` / `ThemeManager` on Mac scene in `sparkyMac/sparkyMacApp.swift`; verify light/dark/system via semantic tokens only
- [X] T031 [US1] Make `sparky/Extensions/LiquidGlassModifier.swift` (and `.tabBarSpacer()` if defined there or related) no-op or Mac-safe padding so lists are not iPhone-tab-offset on desktop
- [X] T032 [US1] Validate window resize usability (~800×600 → full screen) for sidebar collapse + detail reachability; fix layout breakpoints in Desktop shell views as needed
- [ ] T033 [US1] Manual checkpoint: quickstart Scenario A on `sparkyMac`

**Checkpoint**: US1 MVP — Mac is a usable local desk app for core CRUD/browse

---

## Phase 4: User Story 2 - Capture without phone dead ends (Priority: P1)

**Goal**: Editor works on Mac with file/image/link attachments; camera/mic record omitted; keyboard/pointer primary actions; previews Mac-safe

**Independent Test**: quickstart Scenario D

### Implementation for User Story 2

- [X] T034 [US2] Gate camera entry in `sparky/Views/Memories/Editor/MemoryEditorView.swift` (and `MemoryEditorView+Sheets.swift` / attachments card) with `PlatformCapabilities` / `#if os(iOS)` — hide on Mac
- [X] T035 [US2] Gate audio record entry in editor attachments UI (`MemoryEditorAttachmentsCard.swift` or equivalent) — hide on Mac; keep playback path
- [X] T036 [US2] Ensure Mac image add uses existing `PhotosPicker` and/or `fileImporter` paths in `MemoryEditorView.swift` / attachments card; security-scoped copy into `sparky/Managers/MemoryAttachmentStore.swift`
- [X] T037 [US2] Ensure file + link attachment add/open works on Mac from editor components under `sparky/Views/Memories/Editor/Components/`
- [X] T038 [US2] Provide Mac-safe file preview path replacing UIKit `FilePreviewController.swift` (exclude from Mac; add SwiftUI/open-in-default-app fallback used by editor)
- [X] T039 [US2] Provide Mac-safe link row fallback when `LinkPreviewView.swift` UIKit LP bridge excluded (`#if os` or alternate view)
- [X] T040 [US2] Replace or dual-path `UITextField` autofocus wrappers in `sparky/Views/Memories/Editor/QuickMemorySheet.swift` and `sparky/Views/Minds/MindComposerView.swift` with SwiftUI `TextField` + `@FocusState` on Mac (keep iOS behavior)
- [X] T041 [US2] Guard `AVAudioSession` usage in `sparky/Views/Memories/Editor/Components/AudioPlayerSheet.swift` so playback compiles/runs on Mac without iOS-only session categories
- [X] T042 [US2] Confirm primary editor actions (save/cancel/add checklist/schedule) are explicit buttons/toolbar on Mac — no haptic/long-press-only dependency in editor chrome
- [ ] T043 [US2] Manual checkpoint: quickstart Scenario D on `sparkyMac`; spot-check iOS camera/record still present

**Checkpoint**: US2 — capture/edit on Mac without dead-end phone controls

---

## Phase 5: User Story 3 - Focus and scheduled reminders (Priority: P1)

**Goal**: Focus quick + memory-bound on Mac; scheduled notifications fire and deep-link to Memory

**Independent Test**: quickstart Scenarios B + C

### Implementation for User Story 3

- [X] T044 [US3] Verify Focus start/pause/resume/end from Desktop Focus section using shared `sparky/Focus/FocusTimer.swift` and Focus views; fix any iOS-only presentation wrappers
- [X] T045 [US3] Wire Memory-bound Focus start from Mac lists/editor to existing replace-gate / recipe resolve paths (AppEnvironment or Focus helpers)
- [X] T046 [US3] Confirm session continuity when switching Desktop sidebar sections while app running (state on `FocusTimer` / environment)
- [X] T047 [US3] Ensure `ScheduledTriggerExecutor` registration runs on Mac after Memory schedule save via existing `MemoryService` → coordinator path
- [X] T048 [US3] Request notification permission on Mac onboarding/settings only when needed (`sparky/Views/Onboarding/*` and/or settings); copy appropriate for Mac
- [X] T049 [US3] Handle `pendingMemoryOpenRequest` in `DesktopRootView.swift` / `DesktopNavigationState.swift` (select section + open Memory) per desktop-shell-navigation contract
- [X] T050 [US3] Handle `pendingFocusOpenRequest` on Mac shell (select Focus + start/present per existing rules)
- [X] T051 [US3] Missing Memory on notification open → safe empty/not-found; clear pending request
- [ ] T052 [US3] Manual checkpoint: quickstart Scenarios B + C; do not claim Focus-after-Quit

**Checkpoint**: US3 — desk Focus + time reminders trustworthy on Mac

---

## Phase 6: User Story 4 - Honest platform limits (Priority: P2)

**Goal**: Location config preserved and labeled iPhone-only; no Mac geofence arming; hide alternate icon; iPhone flows unbroken

**Independent Test**: quickstart Scenarios E + H

### Implementation for User Story 4

- [X] T053 [US4] Mac location UI: read-only disclosure or hide create/arm controls in `sparky/Views/Memories/Editor/Triggers/` (e.g. `LocationPickerView.swift`, `TriggersCard.swift`) using `PlatformCapabilities.supportsLocationExecution`
- [X] T054 [US4] Guarantee editor/service save on Mac never nils `locationConfig` solely due to platform (`MemoryEditorViewModel.swift` / draft commit path)
- [X] T055 [US4] Hide alternate app icon controls on Mac in settings views under `sparky/Views/Settings/` (gate `AppIconManager` usage)
- [X] T056 [US4] Strip/avoid Mac prompts for Always/When-In-Use location when only geofence would need them (onboarding + settings copy under `sparky/Views/Onboarding/` and Settings)
- [ ] T057 [US4] Regression pass on iOS: tabs (`ContentView.swift`), location executor sync, camera, audio record still available
- [ ] T058 [US4] Manual checkpoint: quickstart Scenarios E + H

**Checkpoint**: US4 — honest limits; iPhone parity protected

---

## Phase 7: User Story 5 - Local-first independence (Priority: P2)

**Goal**: Clear per-device data story; export/import path on Mac; offline P1; onboarding messaging

**Independent Test**: quickstart Scenarios G + F messaging + offline smoke

### Implementation for User Story 5

- [X] T059 [US5] Mac onboarding copy states data stays on this Mac in `sparky/Views/Onboarding/` (platform-specific strings via `#if os` or capability)
- [X] T060 [US5] Expose import/export UI on Mac Me/settings using existing `sparky/Services/DataExportService.swift` and `DataImportService.swift`
- [X] T061 [US5] Verify import on Mac preserves `locationConfig` in exported payloads (`sparky/Model/Export/SparkyExportFormat.swift` path) without arming geofences
- [X] T062 [US5] Confirm no iCloud/App Group sync wiring introduced in `sparky/Data/DataController.swift` or entitlements (`sparky/sparky.entitlements` / Mac entitlements file)
- [ ] T063 [US5] Offline smoke: airplane mode Mac CRUD + Focus while running + browse
- [ ] T064 [US5] Manual checkpoint: quickstart Scenario G

**Checkpoint**: US5 — independent local brain + manual snapshot continuity

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Docs, a11y, performance, final matrix, optional reviewer

- [X] T065 [P] Update `AGENTS.md` Build & Run section with Mac scheme/destination and dual-target note
- [X] T066 [P] Update `CLAUDE.md` and/or `README.md` deployment matrix when present (iOS + Mac) per constitution follow-up
- [ ] T067 [P] Accessibility pass on Mac shell: sidebar labels, editor save/cancel, Focus controls (`DesktopSidebar.swift`, Focus views, editor)
- [ ] T068 [P] Dynamic Type / Reduce Motion smoke on Mac primary flows
- [ ] T069 Performance pass: lazy lists on timeline/minds under Desktop detail; no main-thread attachment decode; non-blocking `sync` after saves
- [X] T070 [P] Theme audit: no ad-hoc colors in new Desktop files; only `Color.Theme` / shared modifiers
- [ ] T071 Run full quickstart.md scenarios A–I; record gaps as follow-ups
- [ ] T072 Final dual build + iOS tests: `xcodebuild` sparky (iOS sim test) + sparkyMac (macOS build/test)
- [X] T073 Optional: one `reviewer` subagent on material diff (pbxproj, AppEnvironment, coordinator, Desktop shell, editor gates) before merge

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 Setup** → start immediately
- **Phase 2 Foundational** → after Setup; **blocks all US phases**
- **Phase 3 US1** → after Foundational (MVP)
- **Phase 4 US2** → after US1 shell can present editor (depends on T027)
- **Phase 5 US3** → after US1 Focus section embedded (T025); notifications need T011 pending publishers
- **Phase 6 US4** → after US2 editor gates helpful; can overlap late US3
- **Phase 7 US5** → after US1 Me section (T026); import/export independent of Focus
- **Phase 8 Polish** → after desired stories complete

### User Story Dependencies

| Story | Depends on | Notes |
|-------|------------|-------|
| US1 | Phase 2 | MVP desk shell + CRUD |
| US2 | US1 editor presentation (T027) | Attachment/editor polish |
| US3 | US1 Focus embed (T025) + Phase 2 notifications | Can start partial after T025 |
| US4 | US2 editor + Phase 2 location seams | iPhone regression last |
| US5 | US1 Me embed | Messaging + export |

### Parallel Opportunities

- T002–T004 parallel in Setup
- T009, T018, T019 parallel once coordinator API shape known (T018/T019 after T009–T010)
- Within US1: T023–T026 section embeds parallel after T022 shell exists
- US4 settings hide (T055) || US5 onboarding copy (T059) after Me exists
- Polish T065–T068, T070 parallel

---

## Parallel Example: Foundational

```text
# After T005–T008 membership baseline:
T009 PlatformCapabilities.swift
# Then:
T010 Coordinator optional location
T011 AppEnvironment wiring
T013 LocationTriggerExecutor membership
# Parallel tests after T009–T011:
T018 PlatformCapabilitiesTests
T019 TriggerExecutorCoordinatorMacSeamsTests
```

## Parallel Example: User Story 1

```text
# After T022 DesktopRootView split:
T023 Embed Calendar detail
T024 Embed Mind detail
T025 Embed Focus detail
T026 Embed Me detail
```

## Parallel Example: User Story 2

```text
T034 Gate camera
T035 Gate audio record
T038 File preview fallback
T039 Link preview fallback
# Then integrate T036–T037 attachment happy paths
```

---

## Implementation Strategy

### MVP First (US1 only)

1. Phase 1 + Phase 2 (dual target green)
2. Phase 3 US1 (shell + CRUD + theme)
3. **STOP** — validate quickstart A
4. Demo Mac as local desk companion

### Incremental delivery

1. US1 MVP → desk browse/CRUD  
2. US2 → safe attachments/editor  
3. US3 → Focus + notifications  
4. US4 → honest location/icon + iOS regression  
5. US5 → independence messaging + export  
6. Polish → docs/a11y/perf/matrix  

### Subagent policy (user-mandated heavy refactor)

| Tasks | Agent |
|-------|--------|
| T005–T008, compile blockers | `scout` then parent |
| T010–T013 seams | parent (`architect` only if API split disputes) |
| T020–T032 shell | parent or `worker` with Desktop/* ownership |
| T034–T042 editor gates | `worker` bounded to Editor/* |
| T073 | one `reviewer` |

Do not nest subagents; parent integrates.

---

## Notes

- No SwiftData schema tasks — data-model forbids migration
- Do not implement cloud sync, Mac geofences, camera/mic record, multi-window, menu bar agent
- Prefer target membership exclusion over large `#if` forests; use `#if os` inside shared files only at edges
- Commit after each phase checkpoint
- Format: every task uses `- [ ] Txxx ...` with path references

---

## Task summary

| Phase | Tasks | Count |
|-------|-------|-------|
| Setup | T001–T004 | 4 |
| Foundational | T005–T019 | 15 |
| US1 MVP | T020–T033 | 14 |
| US2 | T034–T043 | 10 |
| US3 | T044–T052 | 9 |
| US4 | T053–T058 | 6 |
| US5 | T059–T064 | 6 |
| Polish | T065–T073 | 9 |
| **Total** | T001–T073 | **73** |

**MVP scope**: T001–T033 (Setup + Foundational + US1)  
**Format validation**: checklist + ID + optional [P] + story labels on US tasks + file paths — yes
