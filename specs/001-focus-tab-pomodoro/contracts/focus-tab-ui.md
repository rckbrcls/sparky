# Contract: Focus Tab & Memory Focus UI

**Feature**: `001-focus-tab-pomodoro`  
**Platform**: iPhone (primary). Mac: tab not required this delivery.

## 1. Navigation

| Element | Contract |
|---------|----------|
| Tab id | `CustomTab.focus` |
| Label | `Focus` |
| Symbol | `timer` (SF Symbol) |
| Order | Calendar · Mind · **Focus** · Me (Focus before Me) |
| Spacer | Existing `.tabBarSpacer()` on tab root |
| Theme | `Color.Theme.background` and semantic text/colors |

## 2. Focus tab — Idle state

Visible when `!focusTimer.isSessionActive`.

| Region | Content | Actions |
|--------|---------|---------|
| Hero / primary | Title “Focus”; short subtitle optional | — |
| Primary CTA | “Quick Focus” | Starts quick session after replace-gate |
| Secondary list | “From Memories” | Rows for each `hasFocus` memory |
| Empty list | Caption: enable Focus on a scheduled Memory | Optional link/hint only (no forced navigation) |
| Row | Title; optional “25m focus” style subtitle from recipe | Tap → start memory session after replace-gate |

**A11y**:
- Quick Focus button label: `Start Quick Focus`
- Row label: `Start Focus, {title}`
- Dynamic Type: primary CTA not clipped at accessibility sizes (stack vertically if needed)

## 3. Focus tab — Active state

Visible when `focusTimer.isSessionActive`.

| Element | Contract |
|---------|----------|
| Phase label | Ready / Focus / Break |
| Title | `activeMemoryTitle` or “Quick Focus” |
| Ring + time | Existing session chrome patterns |
| Completed count | `Completed: N` |
| Next break | When phase ≠ break |
| Controls | Pause/Resume **or** Start next phase when waiting |
| End | Explicit End (destructive/secondary) clears session → idle |
| Reset | Optional; resets counters, keeps binding (existing semantics) |

**Must not**: toolbar “Close” that ends session without labeling End.

## 4. Replace-session confirmation

When user starts a **different** target while active:

```text
Title: Focus session in progress
Message: End the current session and start a new one?
Actions:
  - Keep current (cancel, default)
  - End & Start (destructive/confirm)
```

## 5. Memory editor — Focus configuration

Location: Schedule card nested Focus toggle (existing).

When **Focus off**: toggle only.  
When **Focus on**:

| Control | Range | Binding |
|---------|-------|---------|
| Focus (work) minutes | 1…120 | draft recipe |
| Short break minutes | 1…60 | draft |
| Long break minutes | 1…60 | draft |
| Long break every N sessions | 1…12 | draft |
| Auto-continue | on/off | draft |

On toggle **on**: if recipe unset, seed from `environment.focusSettings`.  
On toggle **off**: `focusEnabled = false`; keep field values.  
Save: via existing Memory save → `ScheduleConfigDraft.toModel`.

**Caption**: Indicate session can start from Focus tab and from schedule notification when due.

**A11y**: each stepper labeled with unit; match Focus settings wording where possible.

## 6. Global Focus settings

`FocusSettingsView` remains under Me/Settings. Changes:
- Affect new Quick Focus
- Affect newly seeded Memory Focus
- Do not rewrite existing customized Memory recipes
- Do not mutate an in-progress session’s `activeRecipe`

## 7. Shell integration

| Entry | Behavior |
|-------|----------|
| Tab Focus | Show FocusTabView |
| `pendingFocusOpenRequest` | begin/join session; select Focus tab; dismiss request |
| Editor Focus button (when eligible) | `startFocus(for:)` + land on Focus experience |
| Notification Start Focus | same as pending focus open |

## 8. Visual / motion

- Semantic colors only (`Color.Theme.*`, accent for work, success for break — existing session view).
- Honor reduce motion: disable non-essential ring animations if required; keep time updates.
- Light/dark/system via `ThemeManager` — no scheme branches for chrome.

## 9. Mac fallback (this delivery)

- Focus tab may be omitted from tab bar.
- Shared types compile.
- No requirement for FocusTabView layout on Mac window chrome.
