# Sparky — Claude Code Guide

## Build & Run

Pure Xcode project (no SPM, no Makefile). Three targets: `sparky`, `sparkyTests`, `sparkyUITests`. Bundle ID: `polterware.sparky`. Deployment target: **iOS 26.0**.

```bash
# Build
xcodebuild -scheme sparky -destination 'platform=iOS Simulator,name=iPhone 16' build

# Test (uses Swift Testing framework, not XCTest)
xcodebuild -scheme sparky -destination 'platform=iOS Simulator,name=iPhone 16' test
```

Or open `sparky.xcodeproj` in Xcode and Cmd+R.

**Critical build flag:** `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — all types are `@MainActor` by default. Use `nonisolated` explicitly for pure functions.

## Architecture

**MVVM + Services + Executors**, with `AppEnvironment` as the DI container.

```
sparkyApp (@main)
  └─ AppEnvironment (ObservableObject, owns all services)
       ├─ DataController        — SwiftData ModelContainer/ModelContext
       ├─ MemoryService         — Memory CRUD, attachment loading, trigger sync
       ├─ MindService           — Mind & Tag CRUD
       ├─ TriggerExecutorCoordinator
       │    ├─ ScheduledTriggerExecutor  (UNUserNotificationCenter)
       │    └─ LocationTriggerExecutor   (CLLocationManager, max 20 geofences)
       ├─ MemoryAttachmentStore — File-system actor for photos/links/audio/files
       └─ SettingsStore         — UserDefaults-backed preferences
```

**Bootstrap:** `sparkyApp` creates `AppEnvironment` as `@StateObject` → `.task { appEnvironment.bootstrap() }` triggers async parallel refresh of minds, tags, memories, then requests notification auth.

**Injection:** `AppEnvironment` is injected both as a direct parameter and via `.environmentObject()`. `ThemeManager.shared` is injected only via `.environmentObject()`.

**Reactive pattern:** Hybrid **Combine + async/await**. Services are `ObservableObject` with `@Published` properties. Timer-based auto-refresh every 30s via `Timer.publish`. CRUD operations are `async`. No `@Observable` macro — uses `@StateObject`/`@ObservedObject`/`@EnvironmentObject` throughout.

**Persistence:** SwiftData (not Core Data despite what the README says). `DataController.shared` for production, `DataController.preview` (in-memory) for SwiftUI previews. `modelContext.autosaveEnabled = true`.

## Domain Models

| SwiftData `@Model` | Draft (value type) | Notes |
|---|---|---|
| `Memory` | `MemoryDraft` | Core entity: title, body/note, status, checklist, triggers, attachments |
| `Mind` | — (composed inline) | Hierarchical (self-referential `parent`/`children`). Two virtual sentinels: `Mind.allMinds`, `Mind.inbox` (not persisted) |
| `Tag` | — | Simple name + colorHex |
| `CheckItemModel` | `CheckItemDraft` | Belongs to Memory, has sortOrder |
| `ScheduleConfig` | `ScheduleConfigDraft` | 1:1 schedule primary with recurrence and `focusEnabled` |
| `LocationConfig` | `LocationConfigDraft` | 1:1 location primary |
| `MemoryAttachmentReference` | — | Lightweight index into file-system store |
| `MemoryCompletionDate` | — | Per-day completion tracking for recurring memories |

**Draft pattern:** Every persisted model that goes through UI editing has a matching `struct` draft. Drafts are `Identifiable` + `Hashable` with `.toModel()` and `static func from(_ model:)` converters.

## Trigger System

`Memory.scheduleConfig` and `Memory.locationConfig` are the only trigger representations. Focus is schedule-only (`focusEnabled`). Schedule recurrence provides repeated notifications; location triggers notify on entry or exit.

**Recurrence:** `RecurrenceRule` (frequency + interval + endDate). `RecurrenceFrequency`: minutely, hourly, daily, weekly, monthly, yearly. `weekdayMask: Int16` bitmask where bit `(1 << weekdayNumber)` enables that day (Sunday = 1).

## Key Files & Entry Points

- `sparkyApp.swift` — App entry, bootstrap
- `ContentView.swift` — Root TabView (calendar/mind/me), navigation stacks, editor sheets
- `AppEnvironment.swift` — DI container, service wiring
- `DataController.swift` — SwiftData stack
- `MemoryService.swift` — All memory operations, triggers sync after every mutation
- `MindService.swift` — Mind & Tag operations
- `MemoryEditorViewModel.swift` — The main editor ViewModel
- `TriggerExecutorCoordinator.swift` — Orchestrates scheduled + location executors

## Theme & Color System

- `Color+Theme.swift` — Semantic colors via two access patterns: `Color.themeBackground` or `Color.Theme.background`. Includes: background, secondaryBackground, tertiaryBackground, groupedBackground, textPrimary/Secondary/Tertiary, separator, border, success, warning, destructive.
- `Color+Hex.swift` — `Color(hex:)` init, `.toHex()`, `PresetColors.all` (12 named presets for Mind/Tag pickers).
- `ThemeManager` — Singleton, `AppTheme` enum (system/light/dark), persisted in UserDefaults.
- `View+CardStyle.swift` — `.cardStyle()` and `.neutralButtonStyle()` modifiers.
- `LiquidGlassModifier.swift` — iOS 26 glass effect, `.tabBarSpacer()` (55pt).

## Conventions

- **Language:** Code identifiers in English. Inline comments mixed (Portuguese in older code, English in newer). Prefer English for new code.
- **One type per file.** Extensions use `TypeName+Feature.swift` naming.
- **`final class` everywhere** — no open or non-final classes.
- **Raw value pattern:** Enums stored in SwiftData via `rawValue: String` with computed property wrappers.
- **`@Attribute(.unique)` on `id: UUID`** for all `@Model` types.
- **Cascade deletes** declared explicitly with `@Relationship(deleteRule: .cascade, inverse:)`.
- **Tests** use Swift Testing (`import Testing`, `@Test`, `#expect`), not XCTest.
