# Contract: Desktop Shell Navigation (Mac)

**Feature**: `003-desktop-multiplatform`  
**Consumers**: `DesktopRootView`, `DesktopNavigationState`, `sparkyMacApp`, notification open handlers  
**Status**: v1 normative

## Purpose

Define Mac primary navigation and how global intents (create, notification open, Focus) route without using the iPhone tab bar.

## Information architecture

```text
Window
└─ NavigationSplitView
   ├─ Sidebar sections (exactly one selected)
   │   ├─ Calendar
   │   ├─ Mind
   │   ├─ Focus
   │   └─ Me
   └─ Detail
       └─ Section root + optional NavigationStack path
```

### Section → root content (reuse existing feature roots)

| Section | Detail root (conceptual) | Notes |
|---------|--------------------------|-------|
| Calendar | Timeline / calendar feature root | Same data queries as iOS calendar tab |
| Mind | Minds list / graph entry | Hierarchy unchanged |
| Focus | Focus idle/active experience | Shared Focus views; layout may densify |
| Me | Settings + metrics | Hide iOS-only rows |

## Navigation state machine

### Inputs

- User sidebar click
- User drill-in link (Memory, Mind)
- `pendingMemoryOpenRequest` from notifications
- `pendingFocusOpenRequest`
- Explicit create actions (toolbar / shortcut)

### Outputs

- `selectedSection` update
- `NavigationPath` push/pop per section
- Presentation of editor / composer / quick capture as **sheet** or **detail replacement** (not phone-stretched fullScreenCover as the only path)

### Notification → UI

```text
GIVEN pendingMemoryOpenRequest(memoryID)
WHEN DesktopRootView is active and bootstrap complete
THEN select Calendar (or Mind if product prefers last context — default Calendar)
AND open Memory detail/editor for memoryID
AND clear pending request

GIVEN pendingFocusOpenRequest(memoryID)
WHEN handled
THEN select Focus
AND start or present Focus bound to memory per existing replace-gate rules
AND clear pending request
```

If Memory missing: show not-found empty state; clear pending; no crash.

## Presentation rules

| Flow | Mac v1 presentation |
|------|---------------------|
| Create / edit Memory | Sheet (resizable) **or** detail column editor — pick one primary in implement; sheet default |
| Mind composer | Sheet |
| Quick memory | Sheet |
| File/image pickers | System picker panels |
| Destructive confirm | Alert |
| Onboarding | Sheet/window cover once |

iPhone `fullScreenCover` patterns remain on `ContentView` only.

## Keyboard / pointer (minimum)

| Action | Expectation |
|--------|-------------|
| Create Memory | Discoverable toolbar button; ⌘N recommended if no conflict |
| Dismiss sheet | Escape |
| Sidebar switch | Click; optional ⌘1…⌘4 |
| Complete / save | Explicit buttons (existing) |

Primary flows MUST NOT require trackpad gestures that lack button equivalents.

## Non-goals

- Multiple top-level windows per section
- Browser-style tabs inside the app
- Restoring full navigation path across cold launch (optional later; not required)
- Sharing `CustomTab` UIKit control on Mac

## Acceptance hooks

- Sidebar has four sections labeled consistently with product language
- Resizing window keeps sidebar collapsible and detail usable (~800×600 minimum per spec assumption)
- Opening notification with app running lands on correct Memory
- iPhone build does not load `DesktopRootView` as app root
