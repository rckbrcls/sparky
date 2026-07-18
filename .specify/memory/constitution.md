<!--
Sync Impact Report
- Version change: 1.0.0 → 1.1.0
- Modified principles:
  - I. Native Beauty & Human Interface Guidelines
    → I. Native Beauty & Apple HIG (iPhone + Mac)
  - V. Local-First Swift Architecture
    → clarified as shared multiplatform app-local stack (not iOS-only)
- Added sections / principles:
  - VI. Shared Multiplatform Codebase (One Code, Two Builds) (NON-NEGOTIABLE)
  - Technology stack: iOS + macOS dual destination
  - Quality gate: multiplatform adaptive UI / availability
- Removed sections: none
- Templates requiring updates:
  - .specify/templates/plan-template.md ✅ updated
  - .specify/templates/spec-template.md ✅ updated
  - .specify/templates/tasks-template.md ✅ updated
  - .specify/templates/checklist-template.md ✅ updated
  - .specify/templates/commands/*.md ⚠ N/A (directory not present)
  - docs/development.md ⚠ pending (add multiplatform pointer)
  - CLAUDE.md / README.md ⚠ pending (still describe iOS-first status quo;
    amend when Mac target lands)
- Follow-up TODOs:
  - When Mac target is added to Xcode: update CLAUDE.md, README.md,
    docs/architecture.md, docs/development.md deployment targets and run matrix
-->

# Sparky Constitution

## Core Principles

### I. Native Beauty & Apple HIG (iPhone + Mac)

Sparky MUST feel like a first-party Apple app on every shipped destination.
iPhone and Mac each get idiomatic platform chrome; shared product identity MUST
not force phone UI onto the desktop or desktop chrome onto the phone.

Non-negotiable rules:

- Follow Apple Human Interface Guidelines per platform for layout, navigation,
  typography, focus, pointer/keyboard (Mac), touch/haptics (iPhone), safe areas,
  Dynamic Type, and dark/light appearance.
- Prefer system materials, SF Symbols, continuous corner radii, and platform
  navigation patterns (`NavigationSplitView` / `NavigationStack`, sheets,
  fullScreenCover where appropriate, toolbars, inspectors) over custom chrome
  that fights the OS.
- Use Liquid Glass (`.liquidGlass` / `.glassEffect`) and native materials where
  they improve hierarchy; do not invent parallel glass systems.
- On iPhone: respect safe areas, home indicator, Dynamic Island, and the app tab
  bar via established spacers (e.g. `.tabBarSpacer()`).
- On Mac: support window resizing, sidebar/detail density, keyboard shortcuts,
  and pointer hover affordances for primary actions; avoid relying on
  phone-only gestures as the sole path.
- Support Dynamic Type and accessibility labels/traits on interactive controls.
  Decorative icons MUST be hidden from accessibility.
- Reduce motion: honor `@Environment(\.accessibilityReduceMotion)` for
  non-essential animation; keep state transitions interruptible.
- Never hardcode a single-size layout. Adaptive layout MUST react to size class,
  horizontal/vertical size, and platform idiom.

Rationale: One product, two native citizens. Beauty is platform-correct, not a
stretched phone layout on a large window.

### II. Semantic Theme System (NON-NEGOTIABLE)

All visual styling MUST flow through the semantic theme layer. Raw ad-hoc colors
in feature views are forbidden unless they are data-driven user colors (Mind/Tag
hex presets) or transient system overlays.

Non-negotiable rules:

- Use `Color.Theme.*` / `Color.theme*` semantic tokens for backgrounds, text,
  separators, borders, element chrome, accent foreground, success, warning, and
  destructive states.
- Theme assets live in the asset catalog and resolve light/dark automatically
  on every platform. Do not branch `if colorScheme == .dark` for routine chrome.
- Appearance preference goes through `ThemeManager` (`system` / `light` /
  `dark`) and `.withAppTheme()` / `preferredColorScheme`. Do not invent a second
  theme store.
- Shared surface treatments MUST reuse existing modifiers (`.cardStyle()`,
  `.neutralButtonStyle()`, `.liquidGlass(...)`) before adding new ones. Platform
  tweaks belong inside shared modifiers via availability/idiom checks, not as
  forked feature styling.
- New semantic needs expand `Color+Theme` + asset catalog first; feature code
  consumes tokens second.
- User-facing Mind/Tag colors use `Color(hex:)` / `PresetColors` and MUST remain
  legible against semantic backgrounds (contrast is a feature requirement).

Rationale: One theme spine keeps light/dark, settings, and both destinations
coherent without hunting hex values across views.

### III. Modern SwiftUI Interface Patterns

UI code MUST use current SwiftUI composition patterns and the app's established
MVVM + Services boundaries, shared across iPhone and Mac builds.

Non-negotiable rules:

- Views are declarative and small. Extract subviews, not massive bodies.
  Prefer value-type child views and focused `@ViewBuilder` helpers.
- State ownership:
  - Ephemeral UI: `@State`
  - Owned reference objects: `@StateObject`
  - Injected observables: `@ObservedObject` / `@EnvironmentObject`
  - App graph: `AppEnvironment` + `.environmentObject`
- Do not introduce the `@Observable` macro unless the constitution is amended;
  the codebase standard is `ObservableObject` + `@Published` + Combine +
  async/await.
- Editor flows MUST use draft value types (`MemoryDraft`, checklist/trigger
  drafts) and commit through services. Views MUST NOT mutate SwiftData models
  directly for durable writes.
- Navigation and presentation stay at container boundaries (`ContentView` and
  feature roots). Deep children emit intents; parents present sheets/covers/
  inspectors appropriate to the platform.
- Prefer SF Symbols with semantic rendering modes; match symbol scale/weight to
  surrounding text.
- Animations express hierarchy and feedback (selection, completion, presentation
  transitions). Avoid ornamental motion that delays primary actions.
- Previews MUST compile against `DataController.preview` / in-memory fixtures
  where data is required, and SHOULD cover both compact (iPhone) and regular
  (Mac/wide) width assumptions when layout diverges.

Rationale: Consistent SwiftUI patterns keep UI predictable, previewable, and
cheap to ship on two destinations without architectural drift.

### IV. Performance-First Rendering (NON-NEGOTIABLE)

The interface MUST stay responsive under real memory volume on iPhone and Mac.
Perceived speed is a core product requirement for a local-first second brain.

Non-negotiable rules:

- Lists and grids MUST use lazy containers (`List`, `LazyVStack`, `LazyVGrid`,
  `Table` where Mac-appropriate) for unbounded or large collections. No eager
  `ForEach` of full datasets in `VStack` for production timelines/grids.
- Avoid unnecessary view invalidation: narrow `@Published` surfaces, derive
  filters outside hot body paths, and keep expensive formatting out of
  repeatedly evaluated `body` code.
- Image/attachment work stays off the critical path: load thumbnails
  asynchronously, reuse `MemoryAttachmentStore`, and never decode full assets
  inside `body`.
- Trigger sync, import/export, geofence registration, and bulk mutations MUST
  not block interactive gestures/input; show local UI feedback immediately
  where safe.
- Honor main-actor defaults (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`). Mark
  pure helpers `nonisolated` deliberately. File I/O and heavy transforms belong
  in actors/background work, not view bodies.
- Prefer structural identity (`id:`) stability for rows. Do not regenerate
  identities on every refresh.
- Measure before micro-optimizing, but do not ship known O(n²) filters on the
  main timeline path or unbounded main-thread JSON/image work.
- Mac windows MUST remain usable while background work runs; do not freeze the
  main thread for multi-window or large-export scenarios.

Rationale: Local-first only feels magical when scrolling, capture, and
completion stay instant on every device class.

### V. Local-First Swift Architecture

Sparky is a single native Apple app family (iPhone + Mac) with an app-local,
private-by-default stack. Architecture MUST stay aligned with existing layers.

Non-negotiable rules:

- Stack: SwiftUI + SwiftData + `AppEnvironment` services + trigger executors.
  No custom backend, auth service, or sync layer without an explicit
  constitutional amendment.
- Mutations go through services (`MemoryService`, `MindService`, import/export,
  bulk processors). Services own index refresh and trigger re-sync after writes.
- Persistence: SwiftData `@Model` types with `@Attribute(.unique)` ids, explicit
  cascade relationships, and draft converters at the UI boundary.
- Trigger state uses only `scheduleConfig` / `locationConfig` paths.
- Executors under `Executors/` are the notification/geofence path.
- Platform-limited capabilities (e.g. geofence density, background modes,
  certain sensors) MUST degrade gracefully via availability checks; domain
  models stay shared.
- Code standards: English identifiers; one primary type per file;
  `TypeName+Feature.swift` extensions; `final class` for reference types; enums
  stored via raw values with computed wrappers.
- Complexity MUST be justified. Prefer extending an existing service/modifier/
  draft over introducing a parallel abstraction.

Rationale: The architecture already matches the product. Drift creates dual
systems and silent trigger bugs across both builds.

### VI. Shared Multiplatform Codebase (One Code, Two Builds) (NON-NEGOTIABLE)

Sparky ships from **one shared Swift codebase** with **two build destinations**:
iPhone (iOS) and Mac (macOS). There is no separate desktop rewrite, no parallel
UIKit/AppKit app, and no divergent business-logic tree.

Non-negotiable rules:

- Domain, services, drafts, SwiftData models, theme tokens, and executors live
  in the shared source set by default.
- Platform divergence is allowed only at the edges:
  - `#if os(iOS)` / `#if os(macOS)`
  - `@available` / API availability
  - size-class and idiom-driven adaptive SwiftUI
  - thin platform adapters (permissions, file panels, status item, etc.)
- Do not create `ios/` and `macos/` copies of features. Extract a shared view or
  view-model; specialize presentation chrome only when HIG demands it.
- New features MUST state iPhone + Mac behavior in the spec (including
  intentionally unavailable capabilities and the fallback UX).
- Build matrix: Xcode destinations for iOS Simulator/device and Mac. A change
  that compiles only for one destination is incomplete unless the spec marks the
  API as platform-limited and guards it.
- Dependencies and entitlements stay minimal and per-destination when required;
  shared code MUST NOT assume an entitlement exists on every platform.
- Prefer SwiftUI APIs that work on both platforms. UIKit-only or AppKit-only
  bridges require a shared protocol/adapter and a documented reason.

Rationale: Two products, one brain. Shared code protects local-first domain
integrity; adaptive edges protect native feel.

## Technology & Code Standards

**Platforms**: Native Apple multiplatform — **iOS (iPhone)** and **macOS** —
from one Xcode project / shared sources, two build destinations. Current
in-repo status may still be iOS-first; Mac destination work MUST converge on
this constitution rather than fork the app.

**UI**: SwiftUI only for app UI. UIKit or AppKit bridges only when a platform
API has no SwiftUI equivalent, isolated behind small adapters.

**State**: `ObservableObject`, `@Published`, Combine, async/await. DI via
`AppEnvironment` and environment objects (`ThemeManager.shared` for theme).

**Data**: SwiftData + file-system attachment store. Autosave enabled. Previews
use in-memory `DataController.preview`.

**Triggers**: `TriggerExecutorCoordinator` → scheduled (UserNotifications) +
location (CoreLocation where available). Unavailable
platform capabilities MUST no-op or surface clear UI, not crash.

**Testing**: Swift Testing (`import Testing`, `@Test`, `#expect`) for unit
tests shared across platforms; UI test targets as needed per destination.

**Language**: Source identifiers, commits, and technical docs in English. Chat
may be PT-BR. Prefer English for new inline comments.

**Forbidden by default**: separate Mac rewrite; third-party UI kits that replace
system look; parallel color systems; direct durable model writes from views;
parallel trigger managers; `@Observable` migration without
amendment; network-backed identity or mandatory accounts; unguarded
platform-only API use in shared files.

## Quality Gates & Review

Every feature plan MUST pass the Constitution Check before implementation.
Reviews and implementation checklists MUST verify:

1. **HIG / native feel** — per-platform navigation, materials, safe areas /
   window chrome, Dynamic Type, accessibility, reduce-motion, keyboard/pointer
   on Mac and touch on iPhone.
2. **Theme compliance** — semantic colors only; shared modifiers reused; theme
   changes resolve in light/dark/system on both destinations.
3. **SwiftUI structure** — small views, correct property wrappers, drafts for
   editors, presentation owned by containers, adaptive layout.
4. **Performance** — lazy lists/tables for large data, no heavy work in `body`,
   async attachment/trigger paths, stable identities, non-blocking Mac windows.
5. **Architecture** — service-mediated writes, SwiftData/draft discipline,
   executor path intact, no unjustified new layers.
6. **Multiplatform share** — shared domain/UI by default; divergence only via
   availability/idiom/adapters; both builds considered (or explicit platform
   limitation documented).
7. **Tests** — domain/service changes include Swift Testing coverage when
   behavior is non-trivial; previews or UI checks when layout diverges by
   platform.

Violations require an entry in the plan's Complexity Tracking table with a
simpler alternative that was rejected and why.

Runtime guidance lives in `CLAUDE.md` and `docs/development.md`. When guidance
conflicts with this constitution, this constitution wins until amended.

## Governance

This constitution supersedes informal practice and template defaults for Sparky.

**Amendments**:

1. Propose the change with rationale, impacted principles, and migration notes
   for existing code/docs.
2. Update `.specify/memory/constitution.md` with semantic version bump:
   - MAJOR: remove/redefine a principle or break prior guidance incompatibly
   - MINOR: add a principle/section or materially expand rules
   - PATCH: clarify wording without changing intent
3. Propagate to dependent templates (`plan`, `spec`, `tasks`, checklists) and
   flag runtime docs (`CLAUDE.md`, `docs/*`) when behavior guidance changes.
4. Set `Last Amended` to the amendment date (ISO `YYYY-MM-DD`).

**Compliance**:

- `/speckit.plan` MUST evaluate Constitution Check gates before Phase 0/1 work
  proceeds.
- `/speckit.tasks` and implementation work MUST include theme, HIG,
  multiplatform, and performance tasks when UI is in scope.
- PRs and agent implementations MUST not merge known non-compliant UI chrome,
  theme bypasses, single-platform-only shared code without guards, or
  main-thread regressions without explicit waiver in Complexity Tracking.

**Guidance precedence**: Constitution → feature spec → plan → tasks → ad-hoc
discussion.

**Version**: 1.1.0 | **Ratified**: 2026-07-18 | **Last Amended**: 2026-07-18
