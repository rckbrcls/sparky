# Feature Specification: Desktop Multiplatform (iPhone + Mac)

**Feature Branch**: `003-desktop-multiplatform`

**Created**: 2026-07-18

**Status**: Draft

**Input**: User description: "tendo em vista o que temos hoje, vamos planejar a implementacao da versao desktop desse aplicativo, ele deve usar o mesmo estilo e base de codigo da versao mobile, duas builds, com mesmo codigo… vai ser uma refatoracao pesada, entao crie uma outra branch para fazer tudo isso, saindo da branch atual que estamos"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Use Sparky as a full Mac desk companion (Priority: P1)

A person who already trusts Sparky on iPhone opens the Mac build and can run their day from the desktop: browse the calendar/timeline, open minds, create and edit memories (title, note, checklist, mind, schedule/recurrence, focus recipe, compatible attachments), complete items, search/filter, and adjust Me/settings — without needing the phone beside them for core capture and review.

**Why this priority**: Without primary desk flows, a desktop build is a shell, not a product. This is the minimum viable Mac experience.

**Independent Test**: On a Mac-only install with sample data (or empty state), complete create → schedule → find → edit → complete → export/import backup without touching an iPhone.

**Acceptance Scenarios**:

1. **Given** a fresh Mac install, **When** the user launches Sparky, **Then** they land in a desktop-idiomatic shell (sidebar navigation, not a phone tab bar stretched to the window) and can reach Calendar, Mind, Focus, and Me.
2. **Given** the Mac app, **When** the user creates a Memory with title, note, checklist items, mind assignment, and a schedule, **Then** it persists locally and appears in calendar/timeline and mind views.
3. **Given** existing memories, **When** the user searches, filters, opens, edits, pins/changes status, or completes one, **Then** results match the same domain rules as iPhone and survive quit/relaunch.
4. **Given** the Mac app, **When** the user changes appearance (system/light/dark) and other existing settings that apply on Mac, **Then** the UI updates via the shared semantic theme and remains legible.
5. **Given** a Mac window resized from roughly laptop compact width to full screen, **When** the user works primary flows, **Then** content reflows usefully; critical actions stay reachable (no clipped-only controls).

---

### User Story 2 - Capture and edit without phone-only dead ends (Priority: P1)

A person capturing from the desk uses desktop-appropriate ways to attach content. Phone-only capture paths (live camera, microphone record, haptics-only actions) never trap them in a broken control; they get a clear alternative or the control is simply absent.

**Why this priority**: Editor is the highest-risk shared surface; broken attachments or silent no-ops destroy trust on day one.

**Independent Test**: Open Memory editor on Mac; add image from files, file attachment, and link; confirm checklist/schedule/focus fields; confirm no camera/mic dead controls; save and reopen.

**Acceptance Scenarios**:

1. **Given** the Memory editor on Mac, **When** the user adds an image, **Then** they choose an existing image from the system (e.g. file/photos picker) — not a live camera capture requirement.
2. **Given** the Memory editor on Mac, **When** the user adds a file or link attachment, **Then** the attachment is stored and previewable/openable with a Mac-appropriate viewer path.
3. **Given** a Memory that already has audio on disk (e.g. imported or created on iPhone and later brought via manual backup), **When** the user opens it on Mac, **Then** they can play the audio if present.
4. **Given** the Mac editor, **When** the user looks for live microphone recording or live camera capture, **Then** those actions are omitted or clearly unavailable — never a control that fails with no explanation.
5. **Given** primary editor actions (save, cancel, add checklist row, set schedule), **When** the user works with keyboard and pointer, **Then** every primary action has an explicit control (toolbar, button, or shortcut path) — long-press/haptic-only paths are not required.

---

### User Story 3 - Focus and scheduled reminders at the desk (Priority: P1)

A person runs Focus sessions and relies on time-based reminders while working on the Mac. Focus start/pause/resume/end works for Quick Focus and Memory-bound Focus. Scheduled reminders fire with system permission and open the right Memory when acted on.

**Why this priority**: Focus and schedule are core product promises; desk use is where long focus blocks happen.

**Independent Test**: Start Quick Focus and a Memory-bound Focus on Mac; pause/resume/end; schedule a near-term reminder, grant permission, receive it, open target Memory.

**Acceptance Scenarios**:

1. **Given** idle Focus on Mac, **When** the user starts Quick Focus with a chosen duration, **Then** the session runs with correct remaining time while the app is open.
2. **Given** a Focus-enabled Memory, **When** the user starts Focus from that Memory on Mac, **Then** work/break recipe and title binding follow the same rules as iPhone.
3. **Given** an active Focus session, **When** the user pauses, resumes, or ends, **Then** state updates immediately and remains correct if they navigate to another section and return (app still running).
4. **Given** notification permission granted on Mac, **When** a scheduled Memory reminder is due, **Then** the system delivers a notification within about one minute of the scheduled time under normal permission/Focus-mode conditions, and acting on it opens/reveals that Memory.
5. **Given** the user quits Sparky entirely, **When** a Focus session was running, **Then** the product does not claim cross-quit Focus continuity on Mac in v1 (no false “still running in background” promise).

---

### User Story 4 - Honest platform limits (location, icons, phone chrome) (Priority: P2)

A person who used location triggers or alternate icons on iPhone is not misled on Mac. Location-based automation is iPhone-only in v1; existing location configuration is preserved and labeled, not silently deleted. Phone-only settings (e.g. alternate app icon) are hidden on Mac. iPhone users keep their current tab-based experience without unrelated visual regressions.

**Why this priority**: Trust and data safety matter more than fake parity; protects iPhone while bounding Mac scope.

**Independent Test**: Open a Memory with location config on Mac (via fixture/import); confirm preserved + labeled unavailable; confirm no Mac geofence arming; confirm iPhone build still shows tabs and location flows.

**Acceptance Scenarios**:

1. **Given** a Memory with location configuration present in local data, **When** viewed on Mac, **Then** the configuration remains stored and is shown as available on iPhone only (or equivalent clear label) — not stripped on open/save.
2. **Given** the Mac build, **When** the user tries to create or arm a new location trigger, **Then** they cannot enable live geofencing on Mac in v1.
3. **Given** Me/settings on Mac, **When** the user browses preferences, **Then** iPhone-only controls (e.g. alternate app icon) are omitted rather than shown broken.
4. **Given** the iPhone build after this work, **When** the user performs existing tab navigation, location triggers, camera capture, and audio record flows, **Then** behavior remains intact aside from intentional shared improvements called out in this feature.

---

### User Story 5 - Local-first independence per device (Priority: P2)

A person understands that the Mac copy is a separate local brain on that computer: data lives on this Mac; there is no automatic cloud sync with iPhone. Backup/export/import remains the supported way to move a snapshot between devices.

**Why this priority**: Avoids false continuity expectations; matches constitution (no backend/sync without amendment).

**Independent Test**: Create data only on Mac; confirm it is absent on a separate iPhone install; export from one and import on the other restores a snapshot via existing backup flows.

**Acceptance Scenarios**:

1. **Given** two installs (iPhone and Mac) with no manual import, **When** the user creates memories on one, **Then** the other does not receive them automatically.
2. **Given** export/backup on one device, **When** the user imports on the other, **Then** they receive a manual snapshot restore consistent with existing import/export product rules (not live merge/sync).
3. **Given** offline Mac use, **When** the user performs CRUD, Focus (while app open), and browsing, **Then** all primary flows work without network.

---

### Edge Cases

- User denies notification permission on Mac: scheduling still saves; user sees that alerts won’t fire until permission is granted.
- User opens a Memory that references missing attachment files: clear missing-file state; no crash.
- User resizes window very narrow or very short: layout compresses; sidebar may collapse; primary actions remain reachable.
- User imports data containing location triggers onto Mac: data kept; live monitoring off; label explains iPhone-only execution.
- User double-clicks notification for a deleted Memory: harmless empty/not-found state, no crash.
- Large local library (thousands of memories): timeline/mind lists remain scrollable without freezing the window.
- Reduce Motion / larger text on Mac: essential chrome and controls remain usable.
- External display or full-screen Space: window remains usable; no reliance on iPhone safe-area spacers.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Product MUST ship as one shared application family with two native builds — iPhone and Mac — sharing domain behavior, visual language (semantic theme), and user mental model.
- **FR-002**: Mac build MUST provide desktop-idiomatic primary navigation (sidebar sections for Calendar, Mind, Focus, Me) rather than a stretched iPhone tab bar.
- **FR-003**: iPhone build MUST keep bottom-tab primary navigation and existing phone interaction patterns unless a change is explicitly required for shared correctness.
- **FR-004**: Users MUST be able to create, read, update, complete, pin/status-change, search, and filter Memories on Mac with the same domain rules as iPhone.
- **FR-005**: Users MUST be able to browse and manage Minds (hierarchy as today) and assign Memories to Minds on Mac.
- **FR-006**: Memory editor on Mac MUST support title, note/body, checklist, mind, tags (if present on iPhone), schedule/recurrence, focus configuration, and compatible attachments.
- **FR-007**: On Mac, image capture MUST use choosing an existing image/file; live camera capture is out of scope for v1.
- **FR-008**: On Mac, live microphone recording controls MUST be omitted or disabled with clear unavailability; playback of existing audio MUST work when files exist.
- **FR-009**: File and link attachments MUST be addable and openable via Mac-appropriate system interactions.
- **FR-010**: Focus on Mac MUST support Quick Focus and Memory-bound Focus with start, pause, resume, and end while the app is running.
- **FR-011**: Scheduled reminders MUST register with the system on Mac after permission; notification actions MUST route the user to the correct Memory when it still exists.
- **FR-012**: Mac v1 MUST NOT arm or execute location/geofence triggers; existing location configuration MUST be preserved and disclosed as iPhone-only execution.
- **FR-013**: Each install MUST keep an independent local data store, attachments, and preferences; no automatic cross-device sync in this feature.
- **FR-014**: Import/export (or equivalent backup) MUST remain available on Mac as the manual move/copy path between devices.
- **FR-015**: Appearance (system/light/dark) MUST work on Mac through the shared theme system; light and dark remain legible.
- **FR-016**: Primary Mac actions MUST be operable with pointer and keyboard; no primary flow may depend solely on touch gestures or haptics.
- **FR-017**: Phone-only settings (e.g. alternate app icon) MUST be hidden on Mac rather than shown in a broken state.
- **FR-018**: Mac onboarding/permission prompts MUST request only capabilities used on Mac and MUST state that data stays on this Mac.
- **FR-019**: Shared product identity (theme, materials language, typography hierarchy, SF Symbols where applicable) MUST remain consistent across builds while chrome stays platform-correct.
- **FR-020**: iPhone regressions in navigation, location triggers, camera, audio record, and notifications are out of bounds unless explicitly specified as intentional shared fixes.
- **FR-021**: Unavailable platform actions MUST never fail silently: omit the control or show a clear explanation.
- **FR-022**: All primary Mac flows MUST work offline.

### Key Entities

- **Memory**: Core capture unit (content, checklist, status, schedule, optional location config, focus recipe, attachments) — shared meaning on both builds; location *execution* is iPhone-only in v1.
- **Mind**: Hierarchical organization container for memories — fully usable on both builds.
- **Attachment**: User media/file/link referenced by a Memory — stored with the local install; some capture methods are platform-limited.
- **Focus Session**: Time-boxed work/break run bound to Quick Focus or a Memory — runs while app is active on Mac in v1.
- **Scheduled Reminder**: Time-based alert tied to a Memory — delivered by the system on each device where permission exists.
- **Local Install**: One device-bound brain (data + attachments + preferences) with no automatic multi-device merge.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A new Mac user can create a scheduled Memory and find it again in under 2 minutes without documentation.
- **SC-002**: 100% of P1 Mac flows (browse calendar/minds, CRUD memory, checklist, schedule, focus start/pause/end, settings appearance, export/import) are completable on a Mac-only install.
- **SC-003**: With notification permission allowed, a scheduled reminder is delivered within 60 seconds of the due time under normal system permission conditions, and acting on it surfaces the correct Memory when it exists.
- **SC-004**: After quit and relaunch on Mac, user data and attachments still present before quit remain available (no silent data loss).
- **SC-005**: Primary create/search/edit/complete/Focus journeys are completable using only keyboard and pointer on Mac (no required touch gesture).
- **SC-006**: Offline Mac use supports all P1 flows with no network dependency.
- **SC-007**: iPhone P1 regression suite for tabs, editor capture (camera/audio), location triggers, and notifications continues to pass with no unspecified behavior change.
- **SC-008**: In usability checks, at least 9/10 participants correctly understand that Mac and iPhone data do not sync automatically (via onboarding copy or empty-state/settings messaging).

### Platform, UI & Performance Outcomes

- **SC-UI-001**: Primary tasks are completable on iPhone and Mac with platform-idiomatic chrome (iPhone tabs; Mac sidebar/window).
- **SC-UI-002**: Light, dark, and system appearance remain legible via semantic theme on both destinations.
- **SC-UI-003**: Interactive controls expose accessibility labels/traits; larger text does not permanently hide critical Mac actions.
- **SC-PERF-001**: Representative local libraries (on the order of thousands of memories) keep timeline/mind scrolling responsive without window freezes.
- **SC-PERF-002**: Capture/edit/save feedback appears immediately; heavy attachment or reminder registration work does not freeze the Mac window.

## Multiplatform Behavior *(mandatory for user-facing features)*

- **iPhone**: Bottom tabs (Calendar, Mind, Focus, Me); sheets/full-screen editor patterns as today; touch and haptics; camera capture; microphone recording; location geofence execution; alternate icon settings if already offered.
- **Mac**: Windowed app with collapsible sidebar sections for the same four areas; editor/composer in detail pane or resizable sheet (not a stretched phone full-screen); pointer hover and keyboard paths for primary actions; image/file pickers instead of live camera; no live mic record in v1; no geofence arming/execution in v1; no alternate-icon control; no iPhone tab-bar spacer chrome.
- **Shared**: Domain rules for memories, minds, checklists, schedule/recurrence semantics, focus recipes, completion, search/filter meaning, semantic theme, local-first privacy, import/export snapshot semantics, draft-style editing commit model (user-facing: edits confirm on save, not mysterious partial writes).
- **Platform-limited**:
  - Location triggers: configure/execute on iPhone; preserve + disclose on Mac.
  - Live camera & mic record: iPhone; Mac uses file pick / omit record.
  - Focus after app quit & any cross-device handoff: not promised on Mac v1.
  - Haptics: iPhone only; Mac uses visual state only.
  - Alternate app icon: iPhone only.

## Assumptions

- Target user is an individual using Sparky as a personal local second brain on Apple devices they own.
- v1 Mac is a **native Mac destination**, not a phone UI scaled up, and not a separate product rewrite.
- No account, cloud sync, or multi-user access ships in this feature (constitution-aligned).
- Manual export/import is sufficient continuity between iPhone and Mac for v1.
- “Same style” means shared semantic theme, materials language, and information hierarchy — not identical chrome widgets on both OSes.
- Heavy refactor is in service of shared code + adaptive edges; product scope is bounded by P1 flows above rather than full pixel parity of every iPhone affordance.
- Existing Focus and schedule product rules from prior features remain unless this spec overrides platform continuity promises on Mac.
- Distribution specifics (Mac App Store vs direct) do not change functional requirements herein.
- Minimum usable Mac window is approximately laptop-compact (about 800×600 logical) up to full screen; multi-window document architecture is out of scope.
- Menu-bar-only companion, Stage Manager-specific layouts, and advanced drag-and-drop productivity features are out of scope for v1.

## Out of Scope (v1)

- Automatic sync or conflict resolution between iPhone and Mac
- Accounts, auth, or shared family libraries
- Mac geofencing / location automation execution
- Live camera capture and live microphone recording on Mac
- Focus continuity after full app quit on Mac; cross-device Focus handoff
- Menu bar agent / background daemon product
- Multiple simultaneous windows or document-based multi-window architecture
- Full redesign of every feature surface unrelated to multiplatform adaptation
- Non-Apple desktop platforms (Windows/Linux)
