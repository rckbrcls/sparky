# Research: Cross-Platform Experience Polish

## Decision 1: One desktop primary-content width

**Decision**: Add
`DesktopLayoutMetrics.primaryContentMaxWidth = 880` and use it for Calendar
Day, Mind overview, Mind detail, Focus, and Me. Apply content padding before the
maximum-width frame, then use an outer infinite-width frame to center the
column.

**Rationale**: Calendar Day already establishes 880 points as the approved
reference. A shared token prevents future drift and fixes Me's current
frame-before-padding order, which can make its total footprint exceed 880.

**Alternatives considered**:

- Keep independent `880` literals: rejected because the widths can drift.
- Constrain the entire desktop root: rejected because Calendar Month, toolbars,
  popovers, and Settings intentionally use different widths.
- Build a separate desktop layout tree: rejected by the shared-code
  constitution.

## Decision 2: Treat tab reselection as an explicit intent

**Decision**: `DesktopFloatingNavigationBar` will distinguish a new selection
from a reselection and send the latter to
`DesktopNavigationState.returnToRoot(of:)`.

The state transition is:

- Mind: clear the full `mindsPath`, `currentMindContext`, and transient search.
- Me: clear the full `mePath`.
- Calendar: no-op, preserving mode and anchor date.
- Focus: no-op, preserving running, paused, or waiting state.

**Rationale**: Assigning the same value to a `Binding` does not communicate a
reselection. An explicit intent makes the behavior testable, clears any path
depth in one action, and keeps working state outside navigation untouched.

**Alternatives considered**:

- Observe `selectedSection` changes: rejected because same-value taps do not
  create a meaningful change.
- Pop one destination at a time: rejected because the requirement is a
  one-action return to root.
- Recreate destination views with `.id`: rejected because it would also discard
  Calendar and Focus state.

## Decision 3: Use permanent native scroll-indicator suppression

**Decision**: Keep `CalendarDayContentView` as a `List`, add a configurable
vertical indicator visibility with the existing iPhone behavior as the
default, and pass `ScrollIndicatorVisibility.never` from Desktop Calendar Day.

**Rationale**: The current `.hidden` setting still allows the indicator shown in
the reference capture. The macOS 26 SwiftUI SDK provides `.never`, which
expresses the permanent-hide requirement without changing scrolling, list
virtualization, keyboard input, section insets, or the iPhone shell.

**Alternatives considered**:

- Replace `List` with `ScrollView` and `LazyVStack`: rejected because it changes
  native list behavior and increases regression risk.
- Start with an AppKit `NSScrollView` introspection adapter: rejected because a
  native SwiftUI API is available. A thin adapter is only a fallback if manual
  runtime validation proves the native setting ineffective.
- Disable scrolling: rejected because long Day content must remain accessible.

## Decision 4: Keep Me's analytics and simplify only presentation

**Decision**: Preserve `MeMetrics.calculate` and its insight calculation, but
stop presenting narrative insight. Add small presentation helpers that map
available values to text and unavailable values to `—`.

Weekly Spark always shows `N completed` and Scheduled completion. Activity
keeps the chart, legend, and day accessibility descriptions but removes the
selected-day sentence. Your rhythm always shows Most active period and Best
completion day, with `—` when the sample is insufficient or tied.

**Rationale**: The current model already distinguishes a valid zero from an
unavailable scheduled rate and already creates stable seven-day data. Keeping
the model avoids unrelated analytics changes while producing a stable,
data-first interface in empty and populated states.

**Alternatives considered**:

- Add a new empty-state view: rejected explicitly by the requirement.
- Show `0%` for an unavailable rate: rejected because there is no denominator.
- Remove inaccessible detail with the visible copy: rejected because VoiceOver
  must retain complete descriptions.
- Remove the insight model now: rejected as unrelated domain cleanup.

## Decision 5: Use one Focus feedback coordinator

**Decision**: Inject a `FocusFeedbackHandling` abstraction into `FocusTimer`.
`FocusFeedbackService` will coordinate one `FocusSoundPlaying` adapter and one
`FocusNotificationSending` adapter based on `FocusSettings`.

**Rationale**: The timer currently depends directly on a concrete notification
service. A single coordinator provides exactly-once dispatch, preserves the
timer when either adapter fails, and makes all toggle combinations testable
without posting real notifications or playing audio.

**Alternatives considered**:

- Let views play sounds: rejected because background and programmatic timer
  transitions would be missed.
- Put both APIs directly in `FocusTimer`: rejected because it couples timer
  state to external effects and makes tests brittle.
- Reuse `SettingsStore.notificationSoundEnabled`: rejected because it also
  controls Memory notifications and violates Focus independence.

## Decision 6: Use bundled cross-platform sounds

**Decision**: Define a compact shared catalog with Glass, Bell, Chime, Ping, and
Pop. Package original short audio files in `sparky/Resources/FocusSounds/` and
play them with AVFoundation on both destinations. Defaults are Glass for Focus
completion and Bell for Break completion. Start, pause, and end use separate
fixed cues.

On iPhone, configure an ambient, mixing audio session so cues respect the silent
switch and do not interrupt existing audio. Prepare assets before playback,
stop any currently owned cue before starting the next, and fail silently after
logging if an asset cannot be decoded.

**Rationale**: Converge provides the useful preference model and default names,
but its `NSSound` implementation is macOS-only and depends on platform sound
availability. Bundled assets produce the same contract on iPhone and Mac
without undocumented system IDs.

**Alternatives considered**:

- Reuse `NSSound`: rejected because it is unavailable on iPhone.
- Use undocumented system-sound IDs: rejected because availability and mapping
  are not stable.
- Use only the notification's default sound: rejected because users could not
  select or test completion sounds independently.
- Add an audio package: rejected because AVFoundation is sufficient.

## Decision 7: Separate user commands from silent timer mechanics

**Decision**: Model effective feedback events as `startOrResume`, `pause`,
`end`, `focusComplete`, and `breakComplete`. Internal stop and reset helpers do
not emit feedback.

Rules:

- Starting or resuming emits one start cue.
- Explicit pause emits one pause cue.
- Explicit end emits one end cue.
- Work and Break completion emit their selected cue and optional silent banner.
- Auto-continue does not add a start cue.
- Manual start of the next phase emits a start cue.
- No-op commands, extension, duration changes, internal replacement, and
  internal reset are silent.
- `autoContinue = false` stops internally without a pause cue.

**Rationale**: Current `reset()` and manual phase transitions call `pause()`.
Adding feedback directly to those methods would create duplicate completion and
pause sounds. The explicit event boundary satisfies exactly-once behavior.

**Alternatives considered**:

- Play a cue at every method entry: rejected because no-op and nested calls
  duplicate feedback.
- Infer feedback from published state in a view: rejected because transient and
  background transitions are easy to miss.

## Decision 8: Make completion notifications silent and independent

**Decision**: Add `notificationsEnabled` and `soundsEnabled` to
`FocusSettings`. `FocusNotificationService` posts only when the Focus-specific
notification toggle is on and always uses `content.sound = nil`.
`FocusSoundService` plays independently when the sound toggle is on.

**Rationale**: This produces the required four toggle combinations and ensures
that enabling both yields one selected sound rather than a selected sound plus
the system default. Notification denial or posting failure cannot suppress the
in-app cue or alter timer state.

**Alternatives considered**:

- Attach the selected asset to the notification and also play it in-app:
  rejected because it can produce duplicate audio.
- Disable Memory notification sounds with Focus: rejected because the features
  have separate user intent.

## Decision 9: Centralize reliable desktop preview completion

**Decision**: Map active to `circle` and completed to
`checkmark.circle.fill`. Move optimistic toggle-plus-save into a ViewModel
operation that snapshots status and checklist drafts, blocks repeat activation
while saving, and reloads or restores authoritative state if saving fails.

Every `DesktopPopoverActionBar` control will use a 44×44 label and matching
`contentShape(Circle())`, with the visible glass surface inside the same frame.

**Rationale**: The current view toggles before awaiting `saveMetadataOnly()` and
ignores its result, so a failure can leave misleading state. The action bar's
glass surface can also extend beyond the glyph's effective hit area. One
ViewModel transaction and one reusable round-button helper fix both behaviors.

**Alternatives considered**:

- Save before changing the icon: rejected because it weakens immediate
  feedback.
- Dismiss on save: rejected because the user asked for visible state parity.
- Add invisible padding without an explicit shape: rejected because it does not
  guarantee that the clickable and visible circles match.

## Resolved Unknowns

- No SwiftData schema change is required.
- No network or remote audio source is required.
- No new dependency is required.
- No AppKit bridge is planned for the scrollbar.
- All Focus sounds and preferences are shared across iPhone and Mac.
- Desktop-only layout and navigation behavior remains isolated from iPhone.
