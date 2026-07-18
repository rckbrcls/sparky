# Task for scout

Read-only recon of Sparky iOS app for desktop/macOS multiplatform readiness. Repo: /Users/erickpatrickbarcelos/codes/migration/sparky

Return a concise handoff covering:
1. App entry, root navigation (ContentView, tabs), window/scene setup
2. Platform-coupled APIs: UIKit, UNUserNotificationCenter, CLLocationManager, photos/camera, haptics, file pickers, tab bar, sheets
3. UI patterns that are iPhone-centric (TabView-only, fullScreenCover, phone gestures)
4. Services/executors that may need Mac adapters (triggers, attachments, settings)
5. Xcode project: targets, deployment, whether any macOS target exists
6. Theme/modifiers that assume iOS (LiquidGlass, tabBarSpacer)
7. Top 15 files that will need multiplatform attention
8. What already looks shareable (domain, SwiftData, drafts, services core)

Do NOT modify files. Be specific with paths. Max ~80 lines.

## Acceptance Contract
Acceptance level: attested
Completion is not accepted from prose alone. End with a structured acceptance report.

Criteria:
- criterion-1: Return concrete findings with file paths and severity when applicable

Required evidence: review-findings, residual-risks

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