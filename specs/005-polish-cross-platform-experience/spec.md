# Feature Specification: Cross-Platform Experience Polish

**Feature Branch**: `master`

**Created**: 2026-07-27

**Status**: Draft

**Input**: User description: "Standardize desktop content width against the Calendar Day list; return a selected desktop tab to its root when clicked again; simplify Me on iPhone and Mac while keeping its data visible without an empty state; add configurable Focus notifications and sounds inspired by Converge; correct desktop Memory preview completion behavior and circular hit areas; hide the desktop Calendar Day scrollbar."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Predictable Desktop Navigation and Layout (Priority: P1)

A Mac user moves among Calendar, Mind, Focus, and Me without each destination
feeling like a different-sized application. When they click the currently
selected destination again, they return directly to that destination's root
instead of backing out one screen at a time. The Calendar Day list remains
scrollable without a persistent scrollbar competing with its content.

**Why this priority**: These behaviors affect every desktop session and define
whether the shell feels coherent and predictable.

**Independent Test**: Open each desktop destination at the minimum supported
window size, compare its primary content width with Calendar Day, navigate into
a Mind, reselect Mind, and scroll Calendar Day.

**Acceptance Scenarios**:

1. **Given** Calendar Day, Mind overview, Mind detail, Focus, and Me on Mac,
   **When** the user compares their main content columns, **Then** each uses the
   same centered maximum width as the Calendar Day list.
2. **Given** a desktop destination with internal navigation, **When** the user
   clicks its already-selected tab, **Then** the destination returns to its root
   in one click.
3. **Given** a non-default Calendar date or mode and an active Focus session,
   **When** the user reselects their tabs, **Then** Calendar keeps its date and
   mode and Focus keeps the active session.
4. **Given** Calendar Day contains enough content to scroll, **When** the user
   scrolls with a mouse or trackpad, **Then** scrolling continues to work while
   the vertical scrollbar remains hidden.
5. **Given** Calendar Month is open, **When** the window is resized, **Then** its
   grid may continue using the available window width instead of being forced
   into the Day content column.

---

### User Story 2 - Read the Me Dashboard Without Explanatory Copy (Priority: P1)

A person opens Me on iPhone or Mac and sees the same useful weekly structure
whether their history is populated or empty. The cards and metric labels do the
explaining; missing values appear as neutral placeholders rather than prose,
fake percentages, or a replacement empty screen.

**Why this priority**: The dashboard must remain trustworthy and useful before
enough activity exists to calculate patterns.

**Independent Test**: Open Me with no Memories, with active but uncompleted
Memories, and with a populated completion history; verify the same cards and
metric positions remain visible in all three states.

**Acceptance Scenarios**:

1. **Given** no completion history, **When** Me opens, **Then** Weekly Spark,
   Activity, and Your rhythm remain visible without an empty-state component.
2. **Given** a metric cannot yet be calculated, **When** its card is shown,
   **Then** the value is displayed as `—`, not as a fabricated `0%` and not as
   instructional copy.
3. **Given** Me contains recent activity, **When** the dashboard appears,
   **Then** Weekly Spark uses the concise `N completed` summary and the chart
   and rhythm rows communicate the remaining data visually.
4. **Given** the dashboard is read visually, **When** the user scans it,
   **Then** the header subtitle, selected-day sentence, rhythm learning message,
   and narrative insight block are absent.
5. **Given** a screen reader is active, **When** the user explores the compact
   dashboard, **Then** complete metric and chart descriptions remain available
   even though visible explanatory sentences were removed.

---

### User Story 3 - Hear and Control Focus Feedback (Priority: P1)

A person receives clear, brief audible feedback when a Focus session starts,
pauses, ends, or changes between Focus and Break. They can independently turn
Focus notifications and Focus sounds on or off. They can also choose and test
the sounds used when Focus or Break finishes, following the useful controls
already established in Converge.

**Why this priority**: Focus often runs while the user is looking elsewhere;
audible and notification feedback makes phase changes perceptible without
requiring constant visual attention.

**Independent Test**: Exercise all four combinations of notifications and
sounds enabled or disabled, then start, pause, resume, end, and complete both
types of phase.

**Acceptance Scenarios**:

1. **Given** Focus sounds are enabled, **When** a session starts or resumes,
   pauses, ends, changes from Focus to Break, or changes from Break to Focus,
   **Then** one brief sound appropriate to that event is played.
2. **Given** Focus sounds are disabled, **When** any Focus event occurs,
   **Then** no in-app Focus sound is played and timer behavior is unchanged.
3. **Given** Focus notifications are disabled and sounds are enabled, **When**
   a phase completes, **Then** the sound still plays without posting a Focus
   notification.
4. **Given** Focus notifications are enabled and sounds are disabled, **When**
   a phase completes, **Then** the notification is posted without an additional
   Focus sound.
5. **Given** both settings are enabled, **When** a phase completes, **Then** the
   user receives the notification and exactly one selected completion sound.
6. **Given** Focus Settings, **When** the user changes the Focus-complete or
   Break-complete sound and chooses Test, **Then** the selected sound plays
   without changing timer state.
7. **Given** settings have been changed, **When** the app is reopened, **Then**
   the notification toggle, sound toggle, and selected completion sounds are
   preserved.

---

### User Story 4 - Complete a Memory Reliably From Desktop Preview (Priority: P1)

A Mac user can click anywhere inside a circular action in Memory preview, not
only the icon at its center. Completing or reopening the Memory immediately
updates the completion symbol to match the mobile experience and saves the
state.

**Why this priority**: The current control looks interactive but has an
unexpectedly small working area and does not communicate the resulting state
correctly.

**Independent Test**: Open an active Memory in desktop preview, click near the
edge of the completion circle, verify it becomes checked, close and reopen the
preview, then repeat to reopen the Memory.

**Acceptance Scenarios**:

1. **Given** an active Memory preview on Mac, **When** the user clicks anywhere
   inside the completion circle, **Then** the Memory is completed and the icon
   changes from an empty circle to a filled checked circle.
2. **Given** a completed Memory preview, **When** the user activates the same
   control, **Then** the Memory is reopened and the icon returns to an empty
   circle.
3. **Given** any round action in the desktop preview action bar, **When** the
   pointer clicks within the visible circle but outside the icon glyph, **Then**
   the corresponding action runs.
4. **Given** a completion change succeeds, **When** preview is reopened,
   **Then** the saved Memory state and icon remain consistent.

### Edge Cases

- Me has no Memories, only uncompleted Memories, future completion dates, or
  too little history to establish a unique rhythm.
- Scheduled completion has no elapsed occurrences and therefore has no valid
  denominator.
- A rhythm period or weekday is tied rather than uniquely identifiable.
- The user repeatedly reselects a tab that is already at its root.
- Calendar is in Month or on a non-current date when its selected tab is
  clicked again.
- Focus is running, paused, or waiting for manual phase start when its tab is
  reselected.
- Notification permission is denied while in-app Focus sounds remain enabled.
- An individual sound cannot be played; the timer and phase transition must
  continue without interruption.
- A no-op timer command, such as starting an already-running session, must not
  produce duplicate sound feedback.
- A Memory status update fails after the user activates the preview control;
  the preview must not remain in a misleading saved state.
- Calendar Day contains no items or enough items to require extensive
  scrolling; neither state may show a vertical scrollbar on Mac.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Calendar Day, Mind overview, Mind detail, Focus, and Me on Mac
  MUST use a centered primary content column with the same 880-point maximum
  width.
- **FR-002**: Calendar Month, window toolbars, navigation chrome, native
  Settings, and popovers MUST remain free to use their existing platform-
  appropriate widths.
- **FR-003**: Clicking an already-selected desktop tab that has internal
  navigation MUST return that tab to its root in one action.
- **FR-004**: Tab reselection MUST preserve Calendar date and mode, preserve an
  active Focus session, and avoid mutating user data.
- **FR-005**: The desktop Calendar Day list MUST remain scrollable while hiding
  its vertical scrollbar in empty, short, and long-content states.
- **FR-006**: Me MUST always render Weekly Spark, Activity, and Your rhythm on
  both iPhone and Mac, regardless of Memory count or completion history.
- **FR-007**: Me MUST NOT introduce or display a replacement empty-state
  component.
- **FR-008**: Unavailable Me metrics MUST display `—`; zero MUST be shown only
  when it is a valid measured value.
- **FR-009**: Scheduled completion MUST NOT display `0%` when there are no
  eligible scheduled occurrences.
- **FR-010**: Weekly Spark MUST use the visible summary format `N completed`
  without adding `memory` or `memories`.
- **FR-011**: Me MUST remove the header subtitle, selected-day summary sentence,
  rhythm learning message, and narrative insight block identified in the
  reference image.
- **FR-012**: Your rhythm MUST keep its metric labels visible and use `—` for
  an unavailable active period or completion day; Weekly Spark MUST keep
  Scheduled completion visible and use `—` when no valid rate exists.
- **FR-013**: Removing visible Me copy MUST NOT remove complete accessibility
  descriptions for weekly metrics, chart days, periods, or completion values.
- **FR-014**: Focus Settings MUST provide independent controls for Focus
  notifications and in-app Focus sounds, both enabled by default.
- **FR-015**: Disabling Focus notifications MUST affect only Focus phase
  notifications and MUST NOT disable Memory schedule or location
  notifications.
- **FR-016**: Focus Settings MUST allow the user to select and test separate
  sounds for Focus completion and Break completion.
- **FR-017**: The default Focus-completion sound MUST be Glass and the default
  Break-completion sound MUST be Bell, matching the Converge reference.
- **FR-018**: Focus MUST provide distinct brief audible feedback for initial
  start or resume, pause, explicit session end, Focus completion, and Break
  completion.
- **FR-019**: A Focus event MUST produce no more than one in-app sound, including
  when a phase notification is also posted.
- **FR-020**: Focus notification and sound preferences, including completion
  sound selections, MUST persist locally and participate in Reset to Defaults.
- **FR-021**: Failure to post a notification or play a sound MUST NOT stop,
  delay, reset, or otherwise alter the Focus timer.
- **FR-022**: Changing a duration or extending a phase MUST NOT play a phase-
  transition sound.
- **FR-023**: Desktop Memory preview MUST represent an active Memory with an
  empty circle and a completed Memory with a filled checked circle, matching
  mobile state semantics.
- **FR-024**: Activating the desktop preview completion control MUST toggle and
  persist Memory completion or reopening, with immediate visible state
  feedback.
- **FR-025**: Every round action in the desktop Memory preview action bar MUST
  accept pointer activation across its full visible circular surface.
- **FR-026**: Preview completion failure MUST use existing error handling and
  MUST NOT present an unsaved state as successfully persisted.
- **FR-027**: All changed surfaces MUST remain legible in light, dark, and
  system appearance using the established semantic theme.
- **FR-028**: Primary controls and state-changing icons MUST retain visible
  keyboard focus, accessible labels, and correct selected or completed traits.
- **FR-029**: The feature MUST remain fully local-first and MUST NOT require an
  account, network service, or new remote data flow.
- **FR-030**: Shared Me and Focus behavior MUST remain consistent across iPhone
  and Mac, while desktop-only layout, tab, scrollbar, and preview behavior MUST
  not alter the iPhone shell.

### Key Entities

- **Focus feedback preferences**: Local user choices for Focus notifications,
  in-app sounds, Focus-completion sound, and Break-completion sound.
- **Focus feedback event**: A meaningful timer transition that may produce
  audible feedback: start or resume, pause, explicit end, Focus completion, or
  Break completion.
- **Focus completion sound choice**: A named, testable sound selected
  independently for the end of Focus and the end of Break.
- **Me metric display state**: A measured value, a valid zero, or an unavailable
  value represented by `—`.
- **Desktop tab root**: The initial content of a primary desktop destination,
  reached by clearing only that destination's internal navigation.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: At approximately 980×680, 1100×720, and full-screen Mac window
  sizes, 100% of the scoped primary desktop content columns align to the same
  maximum width as Calendar Day without horizontal clipping.
- **SC-002**: In every desktop tab with internal navigation, one reselection
  returns from any supported depth to the root while preserving Calendar and
  Focus working state.
- **SC-003**: Calendar Day remains scrollable with both mouse and trackpad in
  long-content testing, and no vertical scrollbar is visible in 100% of tested
  Day states.
- **SC-004**: Me shows all three dashboard cards in no-memory, no-completion,
  and populated-history fixtures on both iPhone and Mac.
- **SC-005**: In fixtures with unavailable scheduled or rhythm data, 100% of
  unavailable values display `—` and none display a misleading `0%`.
- **SC-006**: The four combinations of Focus notifications and Focus sounds
  enabled or disabled behave independently without changing timer accuracy.
- **SC-007**: Start or resume, pause, explicit end, Focus completion, and Break
  completion each produce exactly one expected sound when enabled and no sound
  when disabled.
- **SC-008**: A user can select and test either completion sound from Focus
  Settings in no more than three intentional actions.
- **SC-009**: Clicking the center or outer visible area of every circular
  desktop preview action produces the same result in all tested controls.
- **SC-010**: A successful desktop preview completion or reopening displays
  the correct icon within one second and remains correct after reopening.

### Platform, UI & Performance Outcomes

- **SC-UI-001**: Me and Focus feedback settings are usable on both iPhone and
  Mac; desktop-only changes remain confined to the Mac shell and preview.
- **SC-UI-002**: Light, dark, and system appearance remain legible with no
  blocking contrast issue on any changed surface.
- **SC-UI-003**: VoiceOver communicates all removed visible Me details through
  accessibility values, and keyboard focus reaches every changed desktop
  control.
- **SC-PERF-001**: Tab reselection, completion feedback, sound feedback, and
  settings changes appear immediate, with no user-observable interface stall.
- **SC-PERF-002**: Calendar Day scrolling remains responsive with a
  representative local dataset after the scrollbar is hidden.

## Multiplatform Behavior *(mandatory for user-facing features)*

- **iPhone**: Receives the concise Me dashboard and configurable Focus
  notification and sound experience. Existing tab navigation, Calendar,
  Memory preview, and editor presentation remain unchanged.
- **Mac**: Receives all feature behavior, including shared Me and Focus changes,
  standardized desktop content width, root-on-reselection navigation, hidden
  Calendar Day scrollbar, and corrected desktop Memory preview actions.
- **Shared**: Me metric meaning, unavailable-value rules, Focus feedback
  preferences, Focus event semantics, completion sound choices, and local
  persistence are identical across destinations.
- **Platform-limited**: Pointer hit-area and scrollbar requirements apply only
  to Mac. Touch and haptic behavior remains platform-native on iPhone.

## Assumptions

- "Changing times" refers to Focus-to-Break and Break-to-Focus phase changes,
  not duration adjustment or the add-time action.
- Converge is the behavioral reference for independent notification and sound
  controls plus separate, testable Focus-complete and Break-complete choices;
  Sparky keeps its own visual design.
- Start or resume, pause, and explicit end use concise fixed sounds rather than
  additional user-selectable settings.
- Calendar Month benefits from available window width and is intentionally
  excluded from the 880-point primary content column.
- Reselecting a tab means clearing only internal navigation; it does not reset
  dates, modes, filters, timer sessions, or durable data.
- Visible Me copy remains in English and intentionally minimal; accessibility
  descriptions may be more explicit than the visual interface.
- No new persisted domain entity, account, cloud dependency, or data migration
  is required.

## Out of Scope

- Redesigning Calendar Month or desktop window chrome
- Resetting Calendar or Focus state when a selected tab is clicked again
- Changing iPhone tab-reselection behavior
- Adding ambient Focus soundscapes or continuous background audio
- Making start, pause, resume, or end sounds individually selectable
- Changing Focus durations, recipes, auto-continue rules, or timer accuracy
- Redesigning Memory editing beyond the desktop preview action bar
- Adding new Me analytics, history ranges, milestones, or narrative insights
