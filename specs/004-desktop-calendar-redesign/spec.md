# Feature Specification: Desktop Calendar Redesign

**Feature**: `004-desktop-calendar-redesign`  
**Created**: 2026-07-27  
**Status**: Baseline implemented; unified New Memory popover planned  
**Supersedes**: The desktop navigation and Calendar surface contract in `003-desktop-multiplatform`

## Scope

Sparky for macOS uses a stable, sidebar-free shell with Calendar, Mind, Focus,
and Me as its primary destinations. A centered Liquid Glass bottom navigation
matches the mobile four-item composition with fixed-width vertical icon-and-label
segments. Calendar is a Mac-specific surface with Week and Month modes; Week is
the default. New Memory creation from the global bottom action and desktop
Calendar uses one shared, native popover editor. The iPhone shell and Calendar
remain unchanged.

## User stories

### US1 — Plan a week

A user opens Sparky on Mac and immediately sees a seven-day week with a fixed
weekday header, fixed all-day area, and a scrollable 24-hour grid initially
positioned near 08:00.

### US2 — Review a month

A user switches to Month without losing the anchor date and sees a complete
six-week, 42-cell grid. Selecting a date opens its week.

### US3 — Move between desktop work areas

A user switches among Calendar, Mind, Focus, and Me from the floating control
without a permanent sidebar. Deep links still open Memories in Calendar and
sessions in Focus.

### US4 — Find content and manage the app

A user searches every local Memory from the top toolbar in Calendar, Mind, and
Focus. Me opens the shared dashboard directly, and its gear button opens native
macOS Settings for Appearance, Focus, Data, and Advanced preferences.

### US5 — Create a Memory in context

A user opens the same native New Memory popover either from the global
`brain.fill` action or from a Calendar creation affordance. Calendar-originated
creation retains the selected all-day date or exact timestamp, and the popover
remains visually attached to the control that opened it.

## Functional requirements

- **FR-001**: Desktop primary navigation MUST expose Calendar, Mind, Focus, and Me.
- **FR-002**: The desktop shell MUST NOT use `NavigationSplitView` or a permanent sidebar.
- **FR-003**: Calendar MUST expose only Week and Month, with Week as the initial mode.
- **FR-004**: Calendar navigation MUST use one anchor date preserved across mode changes.
- **FR-005**: Week boundaries MUST respect `Calendar.current.firstWeekday`.
- **FR-006**: Week MUST show seven columns, fixed headers, a fixed all-day area,
  and a scrollable 24-hour grid.
- **FR-007**: Concrete recurring occurrences MUST be preserved, including
  multiple occurrences of one Memory on the same day.
- **FR-008**: Month MUST render exactly 42 date cells.
- **FR-009**: Month cells MUST show one compact Memory and deterministic overflow.
- **FR-010**: Quick add MUST retain either the selected all-day date or exact timestamp.
- **FR-011**: Search MUST include all local Memories and open the existing Memory surface.
- **FR-012**: The shared Me dashboard MUST be a direct desktop destination.
- **FR-013**: Native Settings MUST omit alternate app icon controls on Mac.
- **FR-014**: The iPhone shell, Calendar modes, and Me destination MUST remain unchanged.
- **FR-015**: New desktop surfaces MUST use Sparky semantic colors.
- **FR-016**: Reduce Motion MUST disable the bottom-navigation selection animation.
- **FR-017**: The global New Memory action MUST use the mobile `brain.fill`
  symbol in a trailing bottom button while preserving the centered navigation
  and the Command-N shortcut.
- **FR-018**: The main Mac window MUST hide the automatic application title
  while retaining contextual content titles.
- **FR-019**: Window toolbar and bottom safe-area chrome MUST inherit the active
  section surface instead of drawing independent background bands.
- **FR-020**: The macOS Mind overview MUST use three grid columns while iPhone
  retains its existing two-column grid.
- **FR-021**: The Week/Month control MUST use its compact intrinsic width, while
  Search remains trailing in Calendar, Mind, and Focus and is absent from Me.
- **FR-022**: Me MUST expose a gear button that opens the native macOS Settings scene.
- **FR-023**: The bottom navigation MUST use four 72 pt segments in a centered
  288×55 pt capsule and reuse the mobile `mind` and `me` assets.
- **FR-024**: The global `brain.fill` action and every desktop Calendar
  creation affordance MUST present the same New Memory popover implementation.
- **FR-025**: The global popover MUST be anchored to the bottom-trailing
  `brain.fill` button and remain the destination of Command-N.
- **FR-026**: A Calendar-originated popover MUST be anchored to the clicked
  date/time affordance and initialize the existing schedule draft with the
  selected all-day date or exact timestamp.
- **FR-027**: Desktop Calendar creation MUST NOT use a separate
  `QuickMemorySheet`; iPhone quick creation MUST remain unchanged.
- **FR-028**: Existing Memory preview and edit flows MUST remain sheets; the
  popover change applies only to New Memory creation on Mac.
- **FR-029**: The New Memory popover MUST use the native popover material
  without an app-painted opaque root background.
- **FR-030**: Editable sections with toggle switches MUST use interactive
  Liquid Glass surfaces inside one coherent glass container in the desktop
  popover. Their existing opaque card treatment MUST remain unchanged on
  iPhone and outside this popover.
- **FR-031**: Cancel or outside-click dismissal MUST not persist a draft.
  Create MUST continue saving through `MemoryEditorViewModel` and
  `MemoryService`.
- **FR-032**: The popover MUST remain keyboard accessible, focus the title for
  a new draft, scroll when its content exceeds the available height, and keep
  visible Cancel/Create actions.

## Non-goals

- Day and Year modes
- Event duration, resizing, or drag-to-reschedule
- Multi-day span rendering
- Contextual side panels
- A broader Mind or Focus visual redesign beyond the desktop Mind grid
- SwiftData schema changes
- Recreating Apple Calendar or Reminders fields that Sparky does not support
- Changing Memory preview/edit presentation from sheets
- Changing iPhone quick-add or editor presentation

## Acceptance

- Week and Month remain usable at 1100×720, approximately 980×680, and full screen.
- The floating navigation never covers the last Calendar row or a primary control.
- The navigation remains geometrically centered while New Memory stays 24 pt
  from the trailing window edge.
- Calendar header, grid, toolbar, and footer read as one continuous surface;
  Mind, Focus, and Me inherit their own existing section surfaces.
- The Mind overview keeps three columns at every supported Mac window size.
- Week/Month remains compact; Search remains trailing in Calendar, Mind, and
  Focus, while Me shows only its Settings gear.
- Selecting Me replaces the main content directly without opening a menu or sheet.
- Keyboard focus remains visible and VoiceOver announces dates, times, and Memories.
- Light and dark appearances remain legible.
- The Mac and iPhone build/test matrix in `quickstart.md` passes locally.
- Global and Calendar creation show the same editor hierarchy, actions, switch
  sections, and save behavior.
- The global popover points to `brain.fill`; Calendar popovers point to the
  initiating hour/day affordance and retain its schedule context.
- Toggle-driven sections refract as Liquid Glass without an opaque card fill,
  while the native popover background remains visible between sections.
