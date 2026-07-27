# Data Model: Unified Desktop New Memory Popover

## Persistent model impact

None.

The plan does not add or alter SwiftData entities, attributes, relationships,
export formats, attachment storage, triggers, or service contracts.

## Existing transient values reused

### `MemoryEditorRoute`

Carries the create mode, optional Mind context, optional initial title, and
optional initial `ScheduleConfigDraft`. It remains ephemeral and identifies the
popover content instance.

### `CalendarQuickMemoryTarget`

Represents the Calendar source context:

- selected date and suggested time for a Day period;
- all-day date for a Month-day creation affordance;
- the same period-based initialization used by iPhone quick creation.

`scheduleDraft()` remains the single conversion into editor input.

### `ScheduleConfigDraft`

Seeds the editor without persisting anything. The draft becomes durable only
after `MemoryEditorViewModel.save()` succeeds through `MemoryService`.

## Presentation state transitions

```text
idle
  -> source creates MemoryEditorRoute
  -> popover presented at source anchor
      -> Cancel / outside click -> route cleared -> idle
      -> Create
          -> validation failure -> popover remains presented
          -> save failure -> popover remains presented with error
          -> save success -> route cleared -> idle
```

## Validation rules

- A Calendar-originated route must contain the schedule draft produced by its
  `CalendarQuickMemoryTarget`.
- A global route may omit schedule configuration.
- Dismissal must not call a service mutation.
- Save continues using the existing title/checklist validation.
- No presentation state is persisted between launches.
