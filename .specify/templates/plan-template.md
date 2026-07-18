# Implementation Plan: [FEATURE]

**Branch**: `[###-feature-name]` | **Date**: [DATE] | **Spec**: [link]

**Input**: Feature specification from `/specs/[###-feature-name]/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

[Extract from feature spec: primary requirement + technical approach from research]

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: Swift (Xcode / SwiftUI), MainActor default isolation

**Primary Dependencies**: SwiftUI, SwiftData, Combine, UserNotifications, CoreLocation/MapKit (as needed), AVFoundation/PhotosUI/UTTypes (attachments)

**Storage**: SwiftData + local Application Support attachment store (local-first)

**Testing**: Swift Testing (`import Testing`) for unit/domain; XCTest UI targets as needed

**Target Platform**: iPhone (iOS) + Mac (macOS) — one shared codebase, two build destinations

**Project Type**: Native multiplatform Apple app (single Xcode project / shared sources)

**Performance Goals**: Instant capture/scroll under real memory volume; non-blocking trigger sync/import/export; fluid window resize on Mac

**Constraints**: Offline-capable; no mandatory account/backend; semantic theme only; platform APIs availability-guarded

**Scale/Scope**: [feature-specific screen/entity count]

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*
*Source: `.specify/memory/constitution.md` (Sparky Constitution)*

- [ ] **I. HIG / native feel**: iPhone and Mac each get idiomatic navigation,
      materials, typography, a11y, reduce-motion; no stretched phone UI on Mac
- [ ] **II. Semantic theme**: only `Color.Theme` / shared modifiers; no ad-hoc
      chrome colors; light/dark/system via `ThemeManager`
- [ ] **III. Modern SwiftUI**: small views; correct state wrappers; drafts for
      editors; service commits; container-owned presentation
- [ ] **IV. Performance**: lazy lists/tables; no heavy `body` work; async
      attachments/triggers; stable row IDs; non-blocking UI
- [ ] **V. Local-first architecture**: service-mediated writes; SwiftData +
      drafts; active trigger configs; no parallel backend/auth
- [ ] **VI. One code, two builds**: shared domain/UI by default; divergence only
      via `#if os`, availability, size class, or thin adapters; both destinations
      specified (or explicit platform limitation + fallback)
- [ ] **Complexity**: any violation listed in Complexity Tracking with rejected
      simpler alternative

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)
<!--
  ACTION REQUIRED: Replace the placeholder tree below with the concrete layout
  for this feature. Delete unused options and expand the chosen structure with
  real paths (e.g., apps/admin, packages/something). The delivered plan must
  not include Option labels.
-->

```text
sparky/                         # Shared multiplatform app sources (DEFAULT)
├── sparkyApp.swift             # App entry
├── AppEnvironment.swift        # DI / bootstrap
├── ContentView.swift           # Root shell (adaptive iPhone + Mac)
├── Data/                       # SwiftData + migrations
├── Model/                      # Models, drafts, export types
├── Services/                   # Memory/Mind/import-export services
├── Executors/                  # Notification / location / reminder
├── Managers/                   # Theme, attachments, settings helpers
├── ViewModels/                 # Editor and feature VMs
├── Views/                      # SwiftUI surfaces (shared + adaptive)
├── Extensions/                 # View modifiers (card, glass, etc.)
├── Utilities/                  # Theme colors, helpers
└── Focus/                      # Focus session support

sparkyTests/                    # Swift Testing unit/domain tests
sparkyUITests/                  # UI tests (per destination as needed)
```

**Structure Decision**: Shared `sparky/` sources for iPhone + Mac. Platform
divergence stays in-file (`#if os`, availability, adaptive SwiftUI) or thin
adapters — not parallel `ios/` + `macos/` feature trees. Adjust the tree above
only when the feature adds real paths.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |
