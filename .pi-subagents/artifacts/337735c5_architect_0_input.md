# Task for architect

Read-only architecture advice for adding a Mac desktop destination to Sparky while keeping ONE shared codebase and TWO builds (iPhone + Mac). Constitution already mandates multiplatform (principle VI). Repo: /Users/erickpatrickbarcelos/codes/migration/sparky

Context from scout:
- Entry: sparkyApp WindowGroup → ContentView TabView (Calendar, Mind, Focus, Me)
- CustomTabBar UIKit-based; many UIKit bridges (camera UIImagePicker, QuickLook, LPLinkView, UITextField wrappers)
- LocationTriggerExecutor CLLocationManager; Audio AVAudioSession; AppIconManager iOS-only
- LiquidGlass/tabBarSpacer iPhone chrome
- Domain/services/SwiftData largely shareable
- Xcode currently iOS-only (SDKROOT iphoneos)

Produce decisions suitable for a PRODUCT SPEC (WHAT/WHY outcomes), grounded in constraints:

1. Recommended product scope for v1 Mac: which primary flows must work (calendar, mind, me/settings, memory editor, focus, notifications, location)
2. Navigation shell on Mac vs iPhone (split/sidebar vs tabs) — user-visible behavior
3. Platform-limited capabilities and user-visible fallbacks (geofences, camera, background, haptics, alternate icons)
4. Data locality assumptions (local-first, no cloud sync)
5. Biggest risks of heavy refactor and how to bound v1
6. Non-goals for v1 desktop
7. Success criteria ideas (user-facing, measurable, tech-agnostic)

Do NOT implement. Max ~90 lines. Clear MUST/SHOULD.

## Acceptance Contract
Acceptance level: reviewed
Completion is not accepted from prose alone. End with a structured acceptance report.

Criteria:
- criterion-1: Implement the requested change without widening scope
- criterion-2: Return evidence sufficient for an independent acceptance review

Required evidence: changed-files, tests-added, commands-run, validation-output, residual-risks, no-staged-files

Review gate: required by reviewer.

Finish with a fenced JSON block tagged `acceptance-report` in this shape:
Use empty arrays when no items apply; array fields contain strings unless object entries are shown.
`criteriaSatisfied[].status` must be exactly one of: satisfied, not-satisfied, not-applicable.
`commandsRun[].result` must be exactly one of: passed, failed, not-run.
`manualNotes` and `notes` are optional strings; an empty string means no note and does not satisfy `manual-notes` evidence.
```acceptance-report
{
  "criteriaSatisfied": [
    {
      "id": "criterion-1",
      "status": "satisfied",
      "evidence": "specific proof"
    },
    {
      "id": "criterion-2",
      "status": "satisfied",
      "evidence": "specific proof"
    }
  ],
  "changedFiles": [
    "src/file.ts"
  ],
  "testsAddedOrUpdated": [
    "test/file.test.ts"
  ],
  "commandsRun": [
    {
      "command": "command",
      "result": "passed",
      "summary": "short result"
    }
  ],
  "validationOutput": [
    "validation output or concise summary"
  ],
  "residualRisks": [
    "none"
  ],
  "noStagedFiles": true,
  "diffSummary": "short description of the diff",
  "reviewFindings": [
    "blocker: file.ts:12 - issue found, or no blockers"
  ],
  "manualNotes": "anything else the parent should know"
}
```