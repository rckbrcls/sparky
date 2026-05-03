# Architecture

## Overview

Sparky is a local-first SwiftUI iOS app for memories, minds, tags, reminders, checklists, attachments, import/export, and contextual triggers.

## Components

- `AppEnvironment.swift`: dependency container and bootstrap owner.
- `Data/`: SwiftData stack and migrations.
- `Model/`: SwiftData models and draft/value types.
- `Services/`: memory, mind, import/export, and bulk action services.
- `Executors/`: scheduled and location trigger execution.
- `Managers/`: attachments, theme, and app icon.
- `ViewModels/`: editor and screen view models.
- `Views/`: memories, minds, onboarding, settings, and shared UI.

## Data Flow

1. `AppEnvironment` creates long-lived services.
2. `DataController` provides SwiftData persistence.
3. Views and view models call services for memory, mind, trigger, and attachment workflows.
4. Trigger executors coordinate scheduled and location-based reminders.
5. Import/export services move user data in and out of the local model.

## Security and Privacy

The public product direction is local-first: no accounts, no cloud dependency, and no tracking. Keep implementation and landing-page copy aligned with that claim.

## Trade-offs

- Local-first storage improves privacy but makes import/export and backups important.
- The trigger model is powerful but requires careful migration and executor coordination.
