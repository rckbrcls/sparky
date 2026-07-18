# Quickstart Validation: Desktop Multiplatform

**Feature**: `003-desktop-multiplatform`  
**Date**: 2026-07-18  
**Spec**: [spec.md](./spec.md) · **Plan**: [plan.md](./plan.md)

## Prerequisites

- Xcode 26+ with iOS 26 and macOS 26 SDKs
- Branch `003-desktop-multiplatform`
- Simulators/devices: iPhone simulator + Mac run destination (My Mac)
- Notification permission available to grant/deny on both

## Build matrix (must stay green)

```bash
# iOS (existing)
xcodebuild -scheme sparky \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build

# Mac (new scheme/target name may be sparkyMac — adjust when created)
xcodebuild -scheme sparkyMac \
  -destination 'platform=macOS' \
  build

# Shared unit tests (iOS host as today)
xcodebuild -scheme sparky \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  test

# Mac tests when target exists
xcodebuild -scheme sparkyMac \
  -destination 'platform=macOS' \
  test
```

Static preference during agent work: build both destinations; avoid long-lived dev servers (N/A for native).

## Scenario A — Mac shell & browse (P1)

1. Launch **sparkyMac** empty.
2. Confirm **sidebar** with Calendar, Mind, Focus, Me (no iPhone tab bar).
3. Create a Mind; create a Memory assigned to it with title + note + checklist.
4. Find Memory via Calendar/timeline and Mind detail.
5. Quit and relaunch → data still present.

**Pass**: SC-001/SC-002/SC-004 browse+CRUD subset.

## Scenario B — Schedule + notification (P1)

1. On Mac, create Memory with schedule a few minutes ahead.
2. Grant notification permission when prompted.
3. Wait for delivery (≤60s after due under normal conditions).
4. Click notification → Memory opens via desktop shell.

**Pass**: SC-003; contracts/trigger-executor-seams scheduled path.

## Scenario C — Focus desk session (P1)

1. Start Quick Focus from Mac Focus section; pause/resume/end.
2. Start Focus from a Focus-enabled Memory; confirm title/recipe binding.
3. Navigate to Calendar mid-session and back → session still correct while app running.

**Pass**: User Story 3; no claim of after-quit continuity.

## Scenario D — Attachments without phone capture (P1)

1. Mac editor: add image via picker/files; add file; add link.
2. Confirm **no** live camera or mic record controls (or clearly disabled).
3. Save, reopen, open/play where applicable.
4. If fixture has audio from export, playback works.

**Pass**: FR-007–009; capability matrix.

## Scenario E — Location honesty (P2)

1. Import or fixture a Memory with `locationConfig`.
2. On Mac: config still visible/stored; **no** geofence arming; label iPhone-only (or create UI absent).
3. Export from Mac → import iOS → location still intact and executable on iPhone.

**Pass**: FR-012; data-model validation rules.

## Scenario F — Settings & theme (P1/P2)

1. Toggle system/light/dark on Mac → chrome legible via semantic theme.
2. Confirm alternate app icon control **absent**.
3. Onboarding/settings copy indicates data stays on this Mac.

**Pass**: FR-015–018; SC-UI-002; SC-008 messaging check.

## Scenario G — Independence (P2)

1. Create data only on Mac; confirm it does not appear on a separate iPhone install without import.
2. Export Mac → import iPhone (or reverse) via existing backup flow.

**Pass**: FR-013/014.

## Scenario H — iPhone non-regression (P1 gate)

1. Run iOS build: tabs, camera capture, audio record, location trigger create+arm (simulator limits apply), notifications.
2. Confirm no unintended chrome/regressed navigation from Mac work.

**Pass**: SC-007; FR-020.

## Scenario I — Resize & a11y smoke (Mac)

1. Resize window toward ~800×600 and full screen.
2. VoiceOver on primary sidebar + editor save controls.
3. Larger text: critical actions remain reachable.

**Pass**: SC-UI-001/003; SC-PERF qualitative.

## Failure triage

| Symptom | Likely layer |
|---------|----------------|
| Mac target won't compile UIKit symbol | Target membership / missing `#if os` |
| Geofence prompt on Mac | Location executor still constructed |
| Notification opens nothing | Desktop shell not observing pending requests |
| locationConfig missing after Mac save | Illegal strip—fix editor/service |
| iPhone tab bar broken | ContentView regression from shared edit |

## Related contracts

- [platform-capability-matrix.md](./contracts/platform-capability-matrix.md)
- [desktop-shell-navigation.md](./contracts/desktop-shell-navigation.md)
- [trigger-executor-seams.md](./contracts/trigger-executor-seams.md)
