# Research: Unified Desktop New Memory Popover

## Decision 1 — Use native SwiftUI popovers at the source anchor

**Decision**: Attach SwiftUI `.popover` to the actual `brain.fill`, Day-period,
or Month-day creation control.

**Rationale**: This preserves the native arrow, placement, dismissal, keyboard,
and window behavior shown in Apple Calendar and Reminders. The installed macOS
26.5 SDK exposes both item- and boolean-driven popovers with attachment anchors
and optional arrow edges.

**Alternatives considered**:

- Keep the root sheet: rejected because it is not spatially attached to the
  action.
- Attach one popover to `DesktopRootView`: rejected because the arrow would not
  reliably point to the initiating Calendar cell or bottom action.
- Build an AppKit panel: rejected because SwiftUI already provides the required
  native presentation.

## Decision 2 — Reuse one editor presentation

**Decision**: Introduce one Mac-specific popover wrapper around the existing
`MemoryEditorView`, driven by `MemoryEditorRoute`.

**Rationale**: Every entry point requires the same fields, switches, validation,
draft lifecycle, and save behavior. A wrapper keeps presentation-specific size
and material out of the domain/editor logic.

**Alternatives considered**:

- Duplicate a compact Calendar editor: rejected because behavior and validation
  would drift from the global creation flow.
- Expand `QuickMemorySheet`: rejected because it is intentionally a reduced
  capture flow and cannot represent the requested full native editor hierarchy.

## Decision 3 — Preserve Calendar target conversion

**Decision**: Continue using `CalendarQuickMemoryTarget.scheduleDraft()` to
seed Calendar-originated creation.

**Rationale**: It already distinguishes period-based suggested times from
all-day dates and produces the existing `ScheduleConfigDraft` consumed by
`MemoryEditorViewModel`.

**Alternatives considered**:

- Recalculate dates in each Calendar cell: rejected because it duplicates
  existing date/time and time-zone rules.
- Persist a placeholder Memory before showing the popover: rejected because
  cancel/outside-click must leave no durable data.

## Decision 4 — Scope Liquid Glass to toggle-driven popover sections

**Decision**: In the desktop-popover style only, place nearby switch-bearing
sections in one `GlassEffectContainer` and use interactive regular glass with a
continuous rounded rectangle.

**Rationale**: The macOS 26.5 SDK provides `GlassEffectContainer` and
`glassEffect`. Interactive glass is appropriate for containers with switches,
menus, pickers, and text input. One container ensures coherent refraction.

**Alternatives considered**:

- Reuse `.cardStyle()` unchanged: rejected because it paints the opaque surface
  the requested design explicitly removes.
- Make every editor block glass: rejected because the request is specifically
  about switch sections and indiscriminate glass weakens hierarchy.
- Create a custom blur/material stack: rejected because it competes with native
  Liquid Glass and the popover material.

## Decision 5 — Keep platform and mode boundaries explicit

**Decision**: Standard editor sheets, Memory preview/edit, and iPhone quick-add
retain their current surfaces and presentation.

**Rationale**: The requested behavior is specific to New Memory creation on
Mac. A default standard presentation mode avoids changing shared behavior by
accident.

**Alternatives considered**:

- Convert every Memory editor to a popover: rejected because previews and edits
  can be long-lived workflows and were not requested.
- Apply the glass modifier globally: rejected because iPhone presentation surfaces
  have separate established visual contracts.
