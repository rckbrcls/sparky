# Contract: Focus Redesign UI

**Feature**: `002-focus-screen-redesign`  
**Platform**: iPhone primary; Mac shared views optional  
**Supersedes**: Visual/layout sections of `001` `focus-tab-ui.md` for Focus tab idle/active chrome. Navigation tab id, replace alert copy, editor Focus form, and global settings contracts from 001 remain unless noted.

## 1. Navigation (unchanged shell)

| Element | Contract |
|---------|----------|
| Tab | `CustomTab.focus`, label `Focus`, symbol `timer` (or keep current) |
| Order | Calendar · Mind · Focus · Me |
| Root | `FocusTabView` in `NavigationStack` optional — prefer **minimal nav chrome** on idle/active (inline title may hide in favor of in-canvas “Focus”) |
| Spacer | `.tabBarSpacer()` on scroll/safe content |
| Theme | `Color.Theme.background` full bleed; semantic text/colors only |

## 2. Idle state (`!focusTimer.isSessionActive`)

### Layout hierarchy (top → bottom)

1. **Optional top utilities** (trailing): control that opens **duration presets** (clock / “Duration”). Leading utility slot reserved empty (no Tune-in).
2. **Title**: “Focus” — large, centered, primary text.
3. **Duration dial**: large circular control; center shows selected minutes + “MINS” (or localized unit).
4. **Primary CTA**: “Start” (with play affordance) — starts Quick Focus with `selectedWorkMinutes` after replace-gate.
5. **Secondary**: “From Memories” targets (section or entry to sheet).

### Duration dial

| Rule | Contract |
|------|----------|
| Binding | `selectedWorkMinutes: Int` (1…120) |
| Interaction | Drag around ring changes value in 1-minute steps; haptic optional on step change |
| Visual arc | Fills proportionally to `min(minutes, 60) / 60`; value label always shows real minutes |
| Ticks | Show reference marks near 15 / 30 / 45 / 60 |
| A11y | Adjustable: label `Focus duration`, value `"\(n) minutes"`; allow accessibility increment/decrement by 1 (or 5) |
| Reduce motion | No continuous spin ornament; drag still works |

### Presets control

| Item | Minutes | Label |
|------|---------|-------|
| | 5 | 5 min |
| | 10 | 10 min |
| | 15 | 15 min |
| | 30 | 30 min |
| | 45 | 45 min |
| | 60 | 1 hr |

- Presentation: system `Menu` or equivalent from top trailing control.
- Action: set `selectedWorkMinutes`.
- No mandatory separate Custom row (dial is custom).
- A11y: menu labeled `Focus duration presets`.

### Start control

| | |
|--|--|
| Label | `Start` |
| A11y | `Start Quick Focus, \(selectedWorkMinutes) minutes` |
| Action | replace-gate → `startQuickFocus(workDurationMinutes: selectedWorkMinutes)` |

### Memory targets

| | |
|--|--|
| Placement | Below Start; must not replace dial as first screenful hero on default phone size |
| Empty | One secondary caption: enable Focus on a scheduled Memory |
| Row | Title + recipe summary; play affordance |
| Action | replace-gate → `beginSession` with **Memory recipe** (ignore dial) |
| A11y | `Start Focus, {title}` |

### Idle must not

- Show dense multi-field pomodoro form as hero.
- Show ambient audio “Tune in”.
- Copy third-party tab bar/mascot.

## 3. Active state (`focusTimer.isSessionActive`)

### Layout hierarchy

1. **Context**: phase label (“Focus” / “Break” / waiting copy) + session title (`activeMemoryTitle`).
2. **Optional time window**: `start → end` short times when dates available.
3. **Hero ring**: circular progress for current phase + center artwork (SF Symbol hourglass or phase symbol); decorative art hidden from a11y if redundant.
4. **Countdown**: large `formattedTime` (primary glance target).
5. **Controls row**:
   - **+1 min** when `canExtendPhase` — calls `extendCurrentPhase(byMinutes: 1)`
   - **Pause** / **Resume** (or play) primary capsule
6. **End**: explicit end control (destructive or secondary) → `endSession` → idle
7. **Waiting for next phase**: single prominent `Start Focus` / `Start Break` instead of pause/+1 pair

### Progress & phase

| Phase | Visual |
|-------|--------|
| work | Accent-tinted progress / labels |
| break | Success/theme break treatment |
| waiting | CTA for next phase; timer may show 00:00 or full next length per existing engine |

### Active a11y

| Control | Label |
|---------|-------|
| Time | `Remaining {formattedTime}` |
| Pause / Resume | `Pause Focus` / `Resume Focus` |
| +1 min | `Add one minute` |
| End | `End Focus session` |
| Next phase | Existing start-next copy |

### Active must not

- Require opening Settings to pause.
- End session on tab blur.
- Drop Memory title on Memory-bound sessions.

## 4. Replace-session confirmation (unchanged copy)

```text
Title: Focus session in progress
Message: End the current session and start a new one?
Actions:
  - Keep current (cancel)
  - End & Start (destructive)
```

## 5. Full-screen / cover session

`FocusSessionView` (notification/editor path) **must** embed the same active layout component as the tab so chrome matches (Close dismisses presentation; End ends session — preserve 001 continuity rules).

## 6. Theme & motion

- Semantic tokens only (`Color.Theme.*`, `Color.accentColor`).
- No hardcoded pure black bypassing theme.
- Light/dark/system legible.
- Reduce Motion: disable non-essential hero/arc animations; keep time/progress updates.
- Dynamic Type: countdown may scale down slightly at accessibility sizes but remain readable; controls stack/ wrap rather than clip off-screen.

## 7. Mac fallback

- Shared views should compile.
- Pointer drag on dial acceptable.
- If Focus tab omitted on Mac shell, no crash paths in shared code.
- Full Mac visual QA not a release gate for this feature.

## 8. Out of scope UI

- Tune in / ambient sound
- Stats/charts tab from reference
- Reference mascot button
- Redesign of Me → Focus settings form (except values still seed idle default)
