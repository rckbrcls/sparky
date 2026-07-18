# Feature Specification: Focus Tab & Memory Pomodoro Configuration

**Feature Branch**: `001-focus-tab-pomodoro`

**Created**: 2026-07-18

**Status**: Implemented

**Input**: User description: "o focus do sparky esta se baseando no converge, gostaria que na criacao do memory, conseguimos configurar melhor o pomodoro; adicionar uma tab Focus que funciona por focus rapido ou por um focus configurado no memory; escopo mobile por enquanto"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Configure pomodoro on a Memory (Priority: P1)

A person creating or editing a Memory wants Focus (pomodoro) to mean more than a simple on/off switch. When they enable Focus on a scheduled Memory, they can set how long work blocks and breaks should last for that Memory, using sensible defaults from their global Focus preferences, and save those choices with the Memory.

**Why this priority**: Without richer per-Memory Focus setup, the new Focus tab can only start generic timers; the product promise is that planned work carries its own focus recipe.

**Independent Test**: Create a Memory with schedule + Focus enabled, change work/break lengths from defaults, save, reopen the editor, and confirm the same Focus values are shown and used when that Memory’s Focus session starts.

**Acceptance Scenarios**:

1. **Given** a user is editing a Memory that has an active schedule, **When** they turn Focus on, **Then** they see Focus duration controls pre-filled from global Focus defaults (work, short break, long break, pomodoros until long break, auto-continue).
2. **Given** Focus is enabled on a Memory, **When** the user changes any Focus duration or auto-continue setting and saves, **Then** those values are retained on that Memory and do not overwrite global Focus defaults.
3. **Given** Focus is enabled on a Memory with custom durations, **When** the user starts a Focus session for that Memory, **Then** the session uses the Memory’s Focus configuration (not only the global defaults).
4. **Given** Focus is off on a Memory, **When** the user views schedule settings, **Then** no per-Memory Focus duration controls are required, and the Memory is not treated as Focus-ready from schedule.
5. **Given** a Memory already had Focus enabled as a simple toggle before this feature, **When** the user opens it, **Then** Focus remains enabled and durations fall back to global defaults until customized.

---

### User Story 2 - Focus tab with quick start (Priority: P1)

A person opens the new Focus tab and starts a quick Focus session without attaching it to a Memory. They can run the classic pomodoro loop (work → break → work), pause, resume, reset, and end the session from the tab.

**Why this priority**: Quick Focus is the zero-friction path and makes the new tab useful even when nothing is scheduled.

**Independent Test**: Open the Focus tab with no active session, start Quick Focus, observe countdown and phase changes, pause/resume, end session, and return to an idle ready state.

**Acceptance Scenarios**:

1. **Given** no Focus session is active, **When** the user opens the Focus tab, **Then** they see a clear idle state with a primary action to start Quick Focus and a way to start from a Focus-enabled Memory (if any exist).
2. **Given** the user taps Quick Focus, **When** the session begins, **Then** a work phase starts using global Focus defaults and the tab shows remaining time, phase, completed pomodoros, and controls (pause/resume, reset, end).
3. **Given** a quick session is running, **When** a work phase completes, **Then** the user is notified and the session moves to the appropriate break (short or long) according to global settings and auto-continue preference.
4. **Given** auto-continue is off, **When** a phase ends, **Then** the timer waits for an explicit start of the next phase instead of auto-running.
5. **Given** a quick session is active, **When** the user ends it, **Then** the timer returns to idle and the tab offers starting again.

---

### User Story 3 - Start Focus from a configured Memory via the Focus tab (Priority: P1)

A person uses the Focus tab to pick a Memory that already has Focus configured and starts a session bound to that Memory (title visible, durations from the Memory’s Focus config).

**Why this priority**: Connects planning (Memory) with execution (Focus tab), which is the core delivery of this release.

**Independent Test**: With at least one Focus-enabled Memory saved, open Focus tab, choose that Memory, start session, and verify title binding and Memory-specific durations drive the timer.

**Acceptance Scenarios**:

1. **Given** one or more Memories have Focus enabled, **When** the user opens the Focus tab, **Then** those Memories appear as startable Focus targets (at minimum by title; schedule context may be shown when available).
2. **Given** the user selects a Focus-enabled Memory, **When** they start Focus, **Then** the session binds to that Memory, shows its title, and uses that Memory’s Focus configuration.
3. **Given** a Memory-bound session is running, **When** the user leaves the Focus tab and returns, **Then** the active session is still visible and controllable (session is app-level, not lost by tab switch).
4. **Given** a session is already active for Memory A, **When** the user tries to start Focus for Memory B or Quick Focus, **Then** the app prevents a silent overwrite: it either continues the current session or asks the user to end/replace it before starting another.
5. **Given** existing entry points (schedule notification open-request, editor Focus action when due), **When** they start Focus, **Then** behavior remains available and lands the user in the same Focus experience (tab and/or full session UI) without breaking prior flows.

---

### User Story 4 - Manage active session and discover Focus in navigation (Priority: P2)

A person discovers Focus as a first-class tab alongside Calendar, Mind, and Me, sees when a session is active, and can jump back into controls quickly.

**Why this priority**: Navigation and session continuity make the feature feel native; depends on Stories 1–3 existing.

**Independent Test**: Confirm tab presence, icon/label, selection, and that an active session remains reachable after switching tabs.

**Acceptance Scenarios**:

1. **Given** the main app shell on iPhone, **When** the user views the tab bar, **Then** a Focus tab is present with a clear label and symbol distinct from Calendar, Mind, and Me.
2. **Given** a Focus session is active, **When** the user is on another tab, **Then** they can return to the Focus tab and resume control without restarting the session.
3. **Given** global Focus settings in Me/Settings, **When** the user changes defaults, **Then** new Quick Focus sessions and newly enabled Memory Focus configs pick up those defaults; in-progress sessions are not destructively rewritten mid-phase without user action.

---

### Edge Cases

- No Focus-enabled Memories exist: Focus tab still supports Quick Focus; Memory list is empty with a short empty-state hint (e.g. enable Focus on a scheduled Memory).
- Memory Focus enabled but schedule later becomes inactive/removed: Memory should no longer appear as a scheduled Focus target; if a session is already running for it, the running session can finish with its bound title/config.
- App backgrounds during a session: timer behavior remains trustworthy for the user (phase completion still communicated via notification when appropriate); returning to the app shows accurate remaining time/phase.
- Very short durations (1 minute) and upper bounds consistent with existing settings ranges remain usable without crashing or showing invalid times.
- User disables Focus on a Memory while a session for that Memory is running: running session may complete; Memory drops from future start lists after save.
- Only one active Focus session at a time across the app.
- Dynamic Type and VoiceOver: primary controls (start, pause, resume, end, phase status) remain usable.
- Reduce Motion on: essential phase changes still occur; non-essential motion is reduced.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The app MUST add a primary **Focus** tab on iPhone alongside the existing main tabs.
- **FR-002**: Users MUST be able to start a **Quick Focus** session from the Focus tab without selecting a Memory.
- **FR-003**: Quick Focus MUST use the user’s **global Focus defaults** (work length, short break, long break, pomodoros until long break, auto-continue).
- **FR-004**: Users MUST be able to enable Focus on a Memory that has an active schedule and configure per-Memory Focus parameters at least for: work duration, short break duration, long break duration, pomodoros until long break, and auto-continue.
- **FR-005**: When Focus is first enabled on a Memory, per-Memory parameters MUST initialize from current global Focus defaults.
- **FR-006**: Per-Memory Focus parameters MUST persist with the Memory and MUST NOT overwrite global Focus defaults when saved.
- **FR-007**: Users MUST be able to start a Focus session for a Focus-enabled Memory from the Focus tab.
- **FR-008**: A Memory-bound session MUST display the Memory title and run using that Memory’s Focus configuration.
- **FR-009**: The app MUST allow only one active Focus session at a time and MUST require an explicit user choice before replacing an active session with a different one.
- **FR-010**: Focus session controls MUST include start/pause/resume, reset or end, visible remaining time, current phase (idle/work/break), and completed work blocks count.
- **FR-011**: When auto-continue is off, phase transitions MUST wait for explicit user start of the next phase.
- **FR-012**: Phase completion MUST notify the user in a way that works when the app is not in the foreground (consistent with existing Focus notification behavior).
- **FR-013**: Existing Focus entry points (schedule-driven open request and editor Focus when eligible) MUST remain functional and start/join the same session model used by the Focus tab.
- **FR-014**: Global Focus defaults MUST remain editable from Settings/Me and apply to Quick Focus and to newly enabled Memory Focus configs.
- **FR-015**: Memories that previously only stored Focus as enabled/disabled MUST remain Focus-enabled and resolve missing duration fields via global defaults.
- **FR-016**: Focus tab empty and active states MUST use the app semantic theme (light/dark/system) and expose accessibility labels on primary controls.
- **FR-017**: Focus tab and improved Memory Focus configuration are **iPhone (mobile) scoped for this delivery**; Mac MUST NOT be required to ship a full Focus tab in this release, but shared domain behavior MUST remain safe if opened on Mac later (no crash; graceful absence or simple fallback).
- **FR-018**: Leaving the Focus tab MUST NOT discard an active session; returning MUST show current progress.
- **FR-019**: The Focus-enabled Memory picker/list on the Focus tab MUST only include Memories that currently qualify as Focus-ready (Focus enabled on an active schedule, unless a clearer product rule is defined in planning).
- **FR-020**: Users MUST be able to turn Focus off on a Memory; off means it is not offered as a Focus target and does not auto-open Focus from schedule.

### Key Entities

- **Global Focus Defaults**: User-level pomodoro preferences (work, short break, long break, cycles until long break, auto-continue) used by Quick Focus and as defaults when enabling Focus on a Memory.
- **Memory Focus Configuration**: Per-Memory Focus recipe stored with the Memory’s schedule/Focus settings; includes enabled flag plus duration/cycle/auto-continue parameters.
- **Focus Session**: A single in-progress pomodoro run; either quick (no Memory) or bound to one Memory; tracks phase, remaining time, completed work blocks, running/paused/waiting state.
- **Focus Target**: A user-visible Memory eligible to start from the Focus tab.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A new user can start Quick Focus from the Focus tab in under 10 seconds from app open (cold familiarity aside: one tap path from tab).
- **SC-002**: A user can enable Focus on a scheduled Memory and customize at least work and break lengths in under 60 seconds.
- **SC-003**: 100% of saved per-Memory Focus configurations reload with the same values after closing and reopening the Memory.
- **SC-004**: 100% of Memory-bound sessions started from the Focus tab show the correct Memory title and honor that Memory’s work duration for the first phase.
- **SC-005**: Users can switch away from the Focus tab and return without losing an active session in normal foreground use.
- **SC-006**: At most one Focus session can be active; attempts to start another require an explicit user confirmation or are blocked with a clear message.
- **SC-007**: Phase completion still produces a user-visible notification when the app is backgrounded during a running phase (permission allowing).
- **SC-008**: Pre-existing Memories with Focus enabled only as a toggle continue to be startable without manual data repair.

### Platform, UI & Performance Outcomes *(include when UI or multiplatform behavior ships)*

- **SC-UI-001**: Primary Focus flows are completable on **iPhone** with tab-bar discovery and touch-first controls. **Mac** is out of scope for a full Focus tab in this delivery; if the shared shell is built for Mac, Focus MUST degrade safely (hidden/disabled with no crash).
- **SC-UI-002**: Light, dark, and system appearance remain legible on Focus tab and Memory Focus configuration via semantic theme.
- **SC-UI-003**: Start, pause/resume, end/reset, and phase status expose accessibility labels/traits; Dynamic Type does not clip primary actions on common iPhone sizes.
- **SC-PERF-001**: Focus tab idle list of Focus-ready Memories remains scrollable without UI stalls for a representative local dataset (hundreds of Memories with a smaller Focus-ready subset).
- **SC-PERF-002**: Starting or ticking a Focus session does not freeze navigation or other tabs; timer updates remain smooth to the user.

## Multiplatform Behavior *(mandatory for user-facing features)*

- **iPhone**: Full delivery — Focus tab in main tab bar; Memory editor Focus configuration; quick and Memory-bound sessions; notifications; theme and accessibility.
- **Mac**: Out of scope for this release’s Focus tab and editor polish. Shared models/services MUST remain compilable and non-crashing; no requirement to expose Focus tab chrome on Mac until a later delivery.
- **Shared**: Pomodoro rules (phases, defaults, per-Memory config meaning, single active session) are domain-identical when Focus runs.
- **Platform-limited**: This delivery intentionally limits UX scope to mobile/iPhone; Mac receives graceful absence/fallback only.

## Assumptions

- Inspiration and interaction baseline come from the existing Sparky Focus engine and Converge pomodoro (work/break/long break, auto-continue, circular session UI patterns), evolved rather than replaced wholesale.
- “Better pomodoro configuration on Memory creation” means per-Memory duration/cycle/auto-continue settings nested under the existing schedule Focus toggle—not a separate unrelated Focus system.
- Global Focus defaults in Settings remain the source of truth for Quick Focus and for initial values when enabling Focus on a Memory.
- Focus on a Memory stays tied to schedule (schedule-only Focus), consistent with current product rules; location-only Memories are not Focus hosts in this delivery.
- Quick Focus is intentionally not persisted as a Memory unless the user later chooses a future “save as Memory” capability (out of scope).
- Session history/analytics beyond in-session completed pomodoro count are out of scope unless already present.
- Notification permission may be denied; timer still runs in-app, but background completion alerts cannot be guaranteed without permission.
- Single active session is sufficient; parallel timers are out of scope.
- “Mobile only for now” means iPhone UX is the acceptance surface for this release; constitution multiplatform rules are satisfied via explicit Mac deferral + safe shared code.
- Existing schedule-notification → open Focus and editor Focus affordances remain; they should align with the Focus tab session model rather than invent a second timer.
