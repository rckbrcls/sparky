# Desktop Calendar Redesign — Validation

## Automated matrix

Run locally from the repository root:

```bash
xcodebuild -scheme sparkyMac -destination 'platform=macOS' build
xcodebuild -scheme sparkyMac -destination 'platform=macOS' test
xcodebuild -scheme sparky -destination 'platform=iOS Simulator,name=iPhone 16' test
```

## Manual Mac acceptance

1. Open Calendar and confirm Week is selected and positioned near 08:00.
2. Navigate previous/next, select Today, and switch Week/Month without losing
   the anchor date.
3. Confirm Week all-day overflow after four items and deterministic grouping
   for simultaneous timed occurrences.
4. Confirm Month always shows six complete weeks, one item per date, and
   `+N more`.
5. Select a Month date number and confirm its Week opens.
6. Quick-add from an hourly cell and Month hover action; confirm the saved
   schedule retains the intended timestamp/all-day date.
7. Resize to 1100×720, approximately 980×680, and full screen.
8. Repeat Calendar inspection in light and dark appearance.
9. Use `⌘N`, `⌘F`, and `⌘1` through `⌘4`.
10. Open Me directly from the fourth segment, use its gear button, and exercise
    every native Settings tab.
11. Confirm VoiceOver labels for dates, times, Memories, overflow, and toolbar actions.
12. Run the iPhone app and confirm its four tabs, Calendar, and Me remain unchanged.
13. Confirm the main toolbar never shows the automatic “Sparky” title in
    Calendar, Mind, Focus, or Me.
14. Confirm the centered navigation does not shift when the bottom-trailing
    `brain.fill` creation button appears.
15. Confirm toolbar and footer have no independent background band in any
    desktop section.
16. Confirm Week/Month occupies only its intrinsic width and remains centered.
17. Confirm Search remains at the trailing edge in Calendar, Mind, and Focus,
    disappears in Me, and no profile menu or Profile & Insights sheet remains.
18. Confirm the Mind overview keeps three columns at every required Mac window
    size while iPhone retains two columns.
19. Confirm the centered navigation is 288×55 pt, gives each of its four
    destinations an equal 72 pt segment, and uses the mobile `mind` and `me` assets.
20. Click the bottom `brain.fill` action and confirm a native New Memory
    popover is attached to the button.
21. Press `⌘N` and confirm it opens the same global popover with the current
    Mind context.
22. Click an empty Week hour cell and confirm the same popover is attached to
    that cell with the exact clicked timestamp enabled.
23. Use the Month-day add affordance and confirm the same popover is attached
    to that day with an all-day schedule.
24. Compare global, Week, and Month creation: fields, section order, actions,
    validation, and save behavior must be identical.
25. Confirm `Notes`, `Checklist`, `Media`, `Schedule`, and any editable
    switch-bearing location section use Liquid Glass without an opaque fill.
26. Confirm the native popover material remains visible between sections in
    light and dark appearance.
27. Cancel and outside-click each source; confirm no Memory is created.
28. Trigger a validation or save error and confirm the popover remains open
    with its draft intact.
29. Create successfully from global, Week, and Month sources; confirm each
    popover dismisses and Calendar-originated Memories retain their intended
    date/time.
30. Open existing Memory preview/edit flows and confirm they still use sheets.
31. Run the iPhone app and confirm quick creation and editor surfaces remain
    unchanged.
