# Sparky

> **Status:** Active
> This project is currently maintained as a native iOS second-brain app.

Native iOS second-brain app for memories, reminders, tasks, attachments, timeline planning, and contextual triggers. Sparky is built around private local organization with SwiftUI, SwiftData, services, and trigger executors.

## Summary

- [What it is](#what-it-is)
- [Goals](#goals)
- [Product model](#product-model)
- [Project map](#project-map)
- [Architecture](#architecture)
- [Current state](#current-state)
- [Working notes](#working-notes)

## What it is

Sparky is an iOS app for capturing and organizing things the user does not want to forget: ideas, tasks, reminders, checklists, notes, links, photos, files, and recurring plans. It combines a memory system with hierarchical minds and trigger-based reminders.

## Goals

- Give users a fast private place to capture memories and tasks.
- Organize memories inside minds, tags, and timeline views.
- Support scheduled and location-based reminders.
- Store rich attachments locally.
- Keep the product useful without accounts, cloud dependency, or tracking.
- Make import/export and local persistence first-class concerns.

## Product model

- `Memory`: the core item, with title, body, status, checklist, attachments, completion history, and trigger configuration.
- `Mind`: a hierarchical organization unit for contexts, projects, or areas of life.
- `Tag`: lightweight cross-cutting classification.
- `ScheduleConfig`: one-time or recurring scheduled reminder setup.
- `LocationConfig`: geofence-style reminder setup.
- `Attachment`: reference to local files managed by the attachment store.

## Project map

```text
sparky/
├── sparky/
│   ├── AppEnvironment.swift        # Dependency container and bootstrap owner
│   ├── ContentView.swift           # Root navigation shell
│   ├── Data/                       # SwiftData stack and migrations
│   ├── Executors/                  # Scheduled and location trigger executors
│   ├── Model/                      # SwiftData models and draft/value types
│   ├── Services/                   # Memory, mind, import/export, bulk action services
│   ├── Settings/                   # UserDefaults-backed settings
│   ├── Managers/                   # Theme, app icon, attachment store
│   ├── ViewModels/                 # Editor and screen view models
│   ├── Views/                      # Memories, minds, onboarding, settings, shared UI
│   └── sparkyApp.swift
├── sparky.xcodeproj
├── sparkyTests/
├── sparkyUITests/
├── AppStoreMetadata.md
└── CLAUDE.md
```

## Architecture

Sparky follows an MVVM + Services + Executors shape:

- `AppEnvironment` owns long-lived services and bootstraps data.
- `DataController` manages SwiftData persistence.
- `MemoryService` owns memory CRUD, attachment loading, and trigger synchronization.
- `MindService` owns minds and tags.
- `TriggerExecutorCoordinator` coordinates scheduled and location executors.
- `MemoryAttachmentStore` manages local attachment files.
- `SettingsStore` persists app preferences.

The app currently has a dual trigger system while migrating from legacy array-based triggers to dedicated schedule/location config models.

## Current state

The repository is a real native iOS app with tests and App Store metadata. `CLAUDE.md` is the densest technical guide and documents MainActor isolation, SwiftData models, trigger migration, theme conventions, and key entry points.

## Working notes

- Do not run build or test commands from agent sessions in this workspace.
- Use Swift Testing conventions in new tests.
- Keep code identifiers and new comments in English.
- Preserve local-first privacy claims in implementation and public copy.
