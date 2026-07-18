# Feature Specification: Focus Screen Visual Redesign

**Feature Branch**: `002-focus-screen-redesign`

**Created**: 2026-07-18

**Status**: Draft

**Input**: User description: "vamos criar uma entrega para melhorar a cara da tela de focus, vou te mandar uma tela que acho bonita que gostaria que ela fosse assim" + three reference screenshots of an immersive Focus timer (idle dial, preset menu, active hourglass session).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Immersive idle Focus setup (Priority: P1)

A person opens the Focus tab and immediately understands they can start a calm focus session. Instead of a utilitarian list-first layout, they see a centered, immersive setup: large title, a circular duration control showing the chosen length, and a clear primary Start action. They can change the session length with the dial or a quick preset menu, then start without leaving the screen.

**Why this priority**: The idle state is the first impression of Focus and the main gap versus the reference experience. Without a refined setup surface, the rest of the redesign does not land.

**Independent Test**: Open Focus with no active session; confirm centered immersive layout, duration display, ability to change duration via presets and/or dial, and that Start begins a session with the selected length.

**Acceptance Scenarios**:

1. **Given** no Focus session is active, **When** the user opens the Focus tab, **Then** they see an immersive, centered idle layout with a prominent “Focus” title, a large circular duration control, the selected duration value, and a primary Start control — not a dense form or plain list as the hero.
2. **Given** the idle Focus screen, **When** the user opens the duration preset menu, **Then** they can pick common lengths (at least 5, 10, 15, 30, 45 minutes and 1 hour) and the dial/value updates to match.
3. **Given** the idle Focus screen, **When** the user adjusts duration via the circular control (drag or equivalent direct manipulation), **Then** the center value updates in near real time within allowed bounds and snaps to sensible minute steps.
4. **Given** a duration is selected on idle, **When** the user taps Start, **Then** a Quick Focus work session begins using that selected work length (other pomodoro parameters still come from global Focus defaults or the Memory recipe when starting from a Memory).
5. **Given** light, dark, or system appearance, **When** the user views the idle Focus screen, **Then** contrast remains legible and chrome uses the app semantic theme (immersive dark aesthetic may bias toward deep backgrounds but MUST remain correct in light mode).

---

### User Story 2 - Calm active session experience (Priority: P1)

A person in an active Focus session sees a serene, distraction-light screen: phase/title context, a large hero visual with progress around it, a big remaining-time readout, and a small set of primary controls (pause/resume, optional +1 minute, end). The session feels intentional and calm rather than like a settings form with a timer attached.

**Why this priority**: Active session is where users spend time; visual calm directly supports the product job of focus.

**Independent Test**: Start any Focus session; verify hero layout, countdown legibility, progress indication, pause/resume, extend-by-one-minute (if offered), and end; confirm phase changes (work/break) still communicate clearly.

**Acceptance Scenarios**:

1. **Given** a Focus session is running, **When** the user views the Focus tab, **Then** the layout is centered and immersive: phase or session title, optional planned time window (start → end), a large circular hero with progress, a large remaining-time display, and minimal primary controls.
2. **Given** a running work or break phase, **When** time elapses, **Then** remaining time and circular progress update continuously and remain easy to read at a glance (including from arm’s length on iPhone).
3. **Given** a running session, **When** the user pauses, **Then** the primary control switches to a clear resume affordance and the timer stops; resume continues from the same remaining time.
4. **Given** a running session, **When** the user chooses “+1 min” (or equivalent extend action), **Then** one minute is added to the current phase remaining time and the planned end time (if shown) updates.
5. **Given** a work phase completes and a break begins (or vice versa), **When** the UI updates, **Then** phase identity remains obvious (label and/or color/treatment change) without abandoning the calm hero layout.
6. **Given** auto-continue is off and the timer is waiting for the next phase, **When** the user views the session, **Then** they see an explicit control to start the next phase, still within the same visual language.

---

### User Story 3 - Memory-bound Focus without breaking calm UI (Priority: P2)

A person still wants to start Focus from a Memory that has Focus configured. The redesigned screen keeps Memory targets discoverable without turning the idle hero into a long scrolling list. Starting a Memory-bound session shows that Memory’s title in the active chrome and uses the Memory’s Focus recipe for the pomodoro loop; the selected dial duration may apply only to Quick Focus, not override a Memory recipe (unless the user explicitly chooses otherwise — default: Memory recipe wins).

**Why this priority**: Preserves the value of delivery 001 while upgrading presentation; secondary to the visual hero of Quick Focus.

**Independent Test**: With at least one Focus-enabled Memory, open idle Focus, find and start that Memory, confirm title binding and Memory durations; confirm Quick Focus still uses the dial duration.

**Acceptance Scenarios**:

1. **Given** one or more Focus-enabled Memories, **When** the user is on idle Focus, **Then** those targets remain reachable (secondary list, sheet, or equivalent) without replacing the centered duration hero as the primary content.
2. **Given** the user starts Focus from a Memory, **When** the session becomes active, **Then** the Memory title is shown and work/break lengths follow that Memory’s Focus configuration.
3. **Given** a Memory-bound session is active, **When** the user views progress and controls, **Then** the same calm active layout is used as for Quick Focus (only context/title and recipe differ).
4. **Given** a session is already active, **When** the user tries to start another Focus target, **Then** the existing replace confirmation behavior is preserved (no silent overwrite).

---

### User Story 4 - Continuity, accessibility, and platform polish (Priority: P2)

A person switching tabs mid-session, using VoiceOver, larger text, or Reduce Motion still gets a trustworthy Focus experience. The redesign must not sacrifice session continuity or accessibility for aesthetics.

**Why this priority**: Non-negotiable product quality; depends on Stories 1–2 existing.

**Independent Test**: Start session, leave Focus tab and return; exercise VoiceOver on primary controls; enable Reduce Motion and Dynamic Type and confirm critical actions remain usable.

**Acceptance Scenarios**:

1. **Given** an active session, **When** the user leaves the Focus tab and returns, **Then** the same session state is shown (phase, remaining time, title) without restart.
2. **Given** VoiceOver is on, **When** the user navigates Focus idle and active states, **Then** primary controls (duration, Start, pause/resume, +1 min, end, next phase, Memory targets) have clear labels and traits.
3. **Given** Reduce Motion is on, **When** progress and phase changes occur, **Then** essential state still updates; non-essential ornamental motion is reduced or removed.
4. **Given** larger Dynamic Type sizes, **When** the user views idle and active Focus, **Then** remaining time and primary actions remain readable and tappable (layout may reflow; critical controls must not clip off-screen without a way to reach them).

---

### Edge Cases

- No Focus-enabled Memories: idle hero and Quick Start still work; Memory entry point shows a short empty hint or hides gracefully.
- Duration at minimum/maximum bounds: dial and presets cannot select invalid lengths; UI gives clear feedback at edges (stop advancing / disable further drag).
- Very short sessions (e.g. 1–5 minutes): countdown and progress remain correct; +1 min still works.
- +1 min near phase end or after pause: remaining time and progress stay consistent; cannot produce negative time.
- Break phase vs work phase: hero treatment may differ subtly (color/label) but layout structure stays the same.
- Waiting-for-manual-start between phases: must not look like a “dead” timer; next-phase CTA is obvious.
- App backgrounds during session: returning shows accurate remaining time; redesign does not change notification obligations from existing Focus behavior.
- Light appearance: immersive design must not assume pure black only; semantic surfaces and text remain legible.
- Replace-session alert during redesigned UI: still understandable and actionable.
- Session started from legacy entry points (notification, editor): lands in the same redesigned active chrome.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The Focus tab idle state MUST present an immersive, centered setup experience with a prominent title, circular duration control, selected duration readout, and primary Start action as the visual hero.
- **FR-002**: Users MUST be able to set Quick Focus work duration from the idle screen via preset choices of at least: 5, 10, 15, 30, 45 minutes, and 60 minutes.
- **FR-003**: Users MUST be able to set Quick Focus work duration via direct manipulation of the circular control within allowed minute bounds and steps (defaults: 1–120 minutes, 1-minute steps, unless product tightens bounds to match global settings).
- **FR-004**: Starting Quick Focus from the redesigned idle screen MUST begin a work phase using the duration currently shown on the idle control; other recipe fields (break lengths, pomodoros until long break, auto-continue) MUST continue to come from global Focus defaults.
- **FR-005**: The Focus tab active state MUST use a calm, centered session layout with: session/phase context, large remaining-time display, circular progress around a hero visual, and a minimal control set.
- **FR-006**: Active session MUST show circular progress that reflects elapsed vs total time for the current phase.
- **FR-007**: Active session MUST offer pause and resume for the running phase.
- **FR-008**: Active session MUST offer an action to add one minute to the current phase remaining time, updating progress and any displayed end time.
- **FR-009**: Active session MUST offer a way to end the session and return to the redesigned idle state.
- **FR-010**: When a planned time window can be derived (session start + current phase or total remaining context), the active UI SHOULD show a start → end time range; if not reliably known, the range may be omitted rather than showing incorrect times.
- **FR-011**: Phase identity (Focus/work vs Break, and waiting-for-next-phase) MUST remain visually and accessibly distinct inside the active layout.
- **FR-012**: Focus-enabled Memories MUST remain startable from the Focus experience without making the Memory list the idle hero; empty Memory state MUST remain clear.
- **FR-013**: Memory-bound sessions MUST display the Memory title and use the Memory Focus recipe; idle dial duration MUST NOT silently override Memory recipe lengths.
- **FR-014**: Only one Focus session at a time; replace confirmation behavior from the existing Focus product MUST be preserved.
- **FR-015**: Leaving and returning to the Focus tab MUST NOT discard an active session; redesigned UI MUST reflect live timer state.
- **FR-016**: Existing Focus entry points (schedule open-request, editor Focus when eligible) MUST present or resume the same redesigned active session experience.
- **FR-017**: Idle and active Focus UI MUST use semantic theme tokens for surfaces, text, and accents; light, dark, and system appearances MUST remain legible.
- **FR-018**: Primary interactive controls MUST expose accessibility labels/traits; decorative hero artwork MUST be hidden from accessibility where it adds no information.
- **FR-019**: Non-essential motion (ornamental hero animation, decorative transitions) MUST respect Reduce Motion; timer accuracy MUST NOT depend on animation.
- **FR-020**: Ambient audio / “Tune in” style soundscapes from the reference screenshots are **out of scope** for this delivery unless explicitly pulled in later.
- **FR-021**: Reference-app branding, mascot tab bar, and unrelated navigation chrome from the screenshots MUST NOT be copied; Sparky keeps its own tab bar and navigation identity.
- **FR-022**: Pomodoro loop behavior already shipped (work/break, long break cadence, auto-continue, notifications, global settings, per-Memory config) MUST remain intact except where this spec explicitly adds UX (idle duration pick for Quick Focus, +1 minute, visual redesign).
- **FR-023**: iPhone is the primary delivery surface for the full redesigned Focus tab; Mac MUST NOT crash if Focus is reached and SHOULD show a usable fallback or the same shared layout when width allows, without blocking this release on a Mac-only polish pass.

### Key Entities

- **Focus idle setup**: Ephemeral UI state for choosing Quick Focus work duration before start (selected minutes, preset menu open/closed); not a new durable domain entity.
- **Focus session (existing)**: Running or paused pomodoro session with phase, remaining time, recipe, optional Memory binding, completed work blocks.
- **Focus recipe (existing)**: Work/break lengths, long-break cadence, auto-continue — from global defaults or a Memory.
- **Duration preset**: Named quick-pick values offered in the idle preset menu.
- **Session time window**: Optional display of wall-clock start and expected end for the current phase or session context.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In moderated or self-check review against the provided references, at least 4 of these 5 traits are recognizably present on idle Focus: immersive centered layout, large circular duration control, clear duration value, preset access, primary Start control.
- **SC-002**: In the same review for active Focus, at least 4 of these 5 traits are present: calm centered layout, hero circle with progress, large countdown, minimal controls including pause, +1 minute action.
- **SC-003**: A user can change Quick Focus duration and start a session in under 10 seconds from opening the Focus tab (happy path, no Memory).
- **SC-004**: A user can pause, resume, add one minute, and end a session without leaving the Focus tab, with each action taking one intentional tap (or equivalent).
- **SC-005**: 100% of previously supported Focus session behaviors remain available: Quick Focus, Memory-bound Focus, single-session replace gate, phase notifications, auto-continue on/off, global defaults, per-Memory recipes.
- **SC-006**: First-time visual QA on iPhone finds no blocking contrast issues in light and dark appearance for title, duration, countdown, and primary buttons.

### Platform, UI & Performance Outcomes *(include when UI or multiplatform behavior ships)*

- **SC-UI-001**: Primary Focus tasks (set duration, start, pause/resume, +1 min, end, start from Memory) are completable on **iPhone**; **Mac** either shares the layout or presents a safe fallback without crash.
- **SC-UI-002**: Light, dark, and system appearance remain legible via semantic theme on Focus idle and active states.
- **SC-UI-003**: Interactive controls expose accessibility labels/traits; Dynamic Type does not make Start/pause/end unreachable; Reduce Motion removes non-essential ornament only.
- **SC-PERF-001**: Countdown and progress updates remain smooth to the eye during an active session (no multi-second UI stalls caused by the redesign).
- **SC-PERF-002**: Opening Focus tab and switching idle ↔ active feels immediate; Memory target list (if shown) stays responsive for a typical local set of Focus-enabled Memories.

## Multiplatform Behavior *(mandatory for user-facing features)*

- **iPhone**: Full redesigned Focus tab — immersive idle dial/presets, calm active session, Memory targets secondary, haptics optional on start/pause/+1 min if already consistent with app patterns.
- **Mac**: Shared domain/session logic unchanged. UI may reuse the same Focus views in a window; pointer-driven dial/presets acceptable. Full Mac-specific chrome polish is not required to ship the iPhone redesign; absence of Focus tab on Mac (if still not in shell) remains acceptable as in prior delivery.
- **Shared**: Timer, recipes, notifications, single-session rules, Memory binding, settings defaults.
- **Platform-limited**: Fine-grained drag haptics and tab-bar adjacency are iPhone-first; ambient audio remains out of scope on all platforms.

## Assumptions

- Reference screenshots define **visual direction and interaction hierarchy**, not pixel-perfect cloning or third-party branding.
- Delivery **001-focus-tab-pomodoro** remains the functional baseline; this feature is primarily a **presentation and Quick Focus duration UX** upgrade on top of that baseline.
- Ambient sound / “Tune in” is intentionally excluded to keep scope visual and timer-centric.
- Custom duration beyond presets is satisfied by the circular dial (and optionally a future custom sheet); a separate “Custom” form is not required if the dial covers the full allowed range.
- Default idle duration initializes from the user’s global Focus work default (e.g. 25 minutes) so Start without adjustment matches prior Quick Focus expectations.
- +1 minute applies only to the **current phase** remaining time, not to future phases in the recipe.
- Hero artwork may be a system symbol composition, simple illustration, or abstract mark consistent with Sparky; a photoreal hourglass asset is desirable if available but not mandatory if a polished native alternative matches the calm tone.
- Memory targets can live below the fold, in a collapsible section, or in a picker/sheet — exact pattern is a design/plan choice as long as FR-012 and FR-013 hold.
- No new backend, account, or sync requirements.
- Localization: English UI copy in code for new strings is acceptable and consistent with the project; final copy can be refined in implementation (“Start”, “+1 min”, “Focus”, preset labels).

## Out of Scope

- Ambient audio / soundscapes
- Copying reference app tab bar, mascot, or non-Focus features
- Redesigning global Focus Settings/Me form layout (except where idle duration should stay in sync with the work-default value)
- Changing notification copy or OS permission flows
- Multiplayer, stats/history graphs, or streaks UI (reference bottom “charts” tab is not Sparky)
- Full Mac-native Focus polish pass as a release gate
- Replacing the pomodoro model with a single-shot-only timer (pomodoro loop stays)

## Reference Direction (non-normative summary)

From the user-provided screenshots, the target feeling is:

1. **Idle**: Deep immersive background; elegant centered “Focus”; large dual-tone ring with accent arc and handle; center value + unit (e.g. “15” / “MINS”); pill Start; top trailing control opening duration presets (5 / 10 / 15 / 30 / 45 / 1 hr / custom-via-dial).
2. **Active**: Same calm field; title + optional wall-clock range; large circular hero with progress chip/arc; oversized remaining time; compact “+1 min” and pause capsule; minimal chrome.
3. **Overall**: Fewer competing panels, more breathing room, one primary action at a time — adapted to Sparky’s theme system, tab shell, and existing Focus domain.
