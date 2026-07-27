# Desktop Calendar Redesign — Validation

## Automated matrix

Run locally from the repository root:

```bash
xcodebuild -scheme sparkyMac -destination 'platform=macOS' build
xcodebuild -scheme sparkyMac -destination 'platform=macOS' test
xcodebuild -scheme sparky -destination 'platform=iOS Simulator,name=iPhone 16' test
```

## Manual Mac acceptance

1. Open Calendar and confirm Day is selected with the current date highlighted.
2. Navigate previous/next by one day, select Today, and switch Day/Month without losing
   the anchor date.
3. Select each date in the seven-date Day selector and confirm the daily
   content updates without duplicating the date header.
4. Confirm Month always shows six complete weeks, one item per date, and
   `+N more`.
5. Select a Month date number and confirm its Day opens.
6. Quick-add from All Day, Morning, Afternoon, Evening, and Night; confirm the
   popover is attached to the clicked period and receives the intended
   all-day date or suggested time.
7. Resize to 1100×720, approximately 980×680, and full screen.
8. Repeat Calendar inspection in light and dark appearance.
9. Use `⌘N`, `⌘F`, and `⌘1` through `⌘4`.
10. Open Me directly from the fourth segment, use its gear button, and exercise
    every native Settings tab.
11. Confirm VoiceOver labels for selected/today dates, periods, Memories,
    overflow, and toolbar actions.
12. Run the iPhone app and confirm its four tabs, Calendar, and Me remain unchanged.
13. Confirm the main toolbar never shows the automatic “Sparky” title in
    Calendar, Mind, Focus, or Me.
14. Confirm the centered navigation does not shift when the bottom-trailing
    `brain.fill` creation button appears.
15. Confirm toolbar and footer have no independent background band in any
    desktop section.
16. Confirm Day/Month occupies only its intrinsic width and remains centered.
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
22. Click each empty Day period and confirm the same popover is attached to
    that period with its selected date and suggested time enabled.
23. Use the Month-day add affordance and confirm the same popover is attached
    to that day with an all-day schedule.
24. Compare global, Day, and Month creation: fields, section order, actions,
    validation, and save behavior must be identical.
25. Confirm `Notes`, `Checklist`, `Media`, `Schedule`, and any editable
    switch-bearing location section use Liquid Glass without an opaque fill.
26. Confirm the native popover material remains visible between sections in
    light and dark appearance.
27. Cancel and outside-click each source; confirm no Memory is created.
28. Trigger a validation or save error and confirm the popover remains open
    with its draft intact.
29. Create successfully from global, Day, and Month sources; confirm each
    popover dismisses and Calendar-originated Memories retain their intended
    date/time.
30. Open existing Memory preview/edit flows from Calendar and Mind; confirm
    each uses the same popover and points to the clicked Memory item.
31. Run the iPhone app and confirm quick creation and editor surfaces remain
    unchanged.
32. Exercise Mind search/composer, link entry, audio playback, schedule,
    location, photo, file preview, and onboarding on Mac; confirm none presents
    a sheet.
33. In the Mind overview, click the toolbar `plus` button and confirm it matches
    the iPhone symbol and the composer popover arrow points to that button.
34. Confirm the New Mind composer exposes the native Liquid Glass popover
    material, has no `New Mind` title bar, and keeps visible glass Cancel and
    Save actions.
