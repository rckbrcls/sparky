# Troubleshooting

## Memories do not persist

Start with `DataController`, SwiftData model definitions, and `MemoryService`.

## Attachments are missing

Review `MemoryAttachmentStore` and attachment references in the memory model.

## Reminders or location triggers do not fire

Check `TriggerExecutorCoordinator`, scheduled/location executors, permissions, and trigger config models.

## Public privacy claim changed

Update the native app, `../sparky-landing`, and `AppStoreMetadata.md` together so user-facing claims stay consistent.
