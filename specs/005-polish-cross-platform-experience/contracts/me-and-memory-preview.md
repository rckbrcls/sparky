# UI Contract: Me and Desktop Memory Preview

## Me Dashboard

The same three cards are always present on iPhone and Mac:

1. `Weekly Spark`
2. `Activity`
3. `Your rhythm`

There is no replacement empty state.

### Visible copy

- Page title: `Your week`
- Weekly summary: `N completed`
- Weekly metric labels: `Streak`, `Active`, `All time`
- Scheduled metric label: `Scheduled completion`
- Rhythm labels: `Most active period`, `Best completion day`
- Activity legend: `Morning`, `Afternoon`, `Evening`, `Night`

The page subtitle, selected-day sentence, rhythm learning message, and
narrative insight are absent.

### Values

| Condition | Visible value | Accessibility value |
|---|---|---|
| Valid zero | `0`, `0d`, or `0%` as appropriate | Full measured value |
| Scheduled denominator absent | `—` | `Not available` |
| Rhythm sample insufficient | `—` | `Not available` |
| Rhythm tie | `—` | `Not available` |
| Measured rhythm value | Period or weekday | Full value |

Activity bars remain available for seven days even when every count is zero.
Each day keeps a complete accessibility description.

## Desktop Memory Preview

### Status action

| Current state | Symbol | Accessible action | Result after successful save |
|---|---|---|---|
| Active | `circle` | `Complete Memory` | Filled checked circle |
| Completed | `checkmark.circle.fill` | `Reopen Memory` | Empty circle |

The icon updates immediately. Reopening the preview reads the persisted state.
If saving fails, the preview returns to authoritative state and surfaces the
existing save error.

### Round action hit areas

- Close, delete, edit, and confirm/status actions use a 44×44 interactive frame.
- The pointer target is a `Circle` matching the visible circular surface.
- Clicking the center or any visible edge produces the same action.
- Disabled state blocks the full circle, not only the glyph.
- Keyboard focus and accessible labels remain visible and correct.
