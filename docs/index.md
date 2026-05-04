# Sparky Documentation

This directory documents the native iOS app in this repository. It intentionally avoids backend, web, API, and deployment assumptions that are not present in the codebase.

## Start Here

- [Getting Started](getting-started.md): open the Xcode project, understand targets, and prepare local development.
- [Architecture](architecture.md): app layers, dependency wiring, persistence, trigger execution, and data flow.
- [Development](development.md): project-specific coding conventions and safe extension patterns.

## Technical References

- [Data and Persistence](database.md): SwiftData schema, local attachment storage, migration, JSON import/export, and iCalendar export.
- [Security and Privacy](security.md): local-first design, permissions, Privacy Manifest, and sensitive data risks.
- [Troubleshooting](troubleshooting.md): focused checks for persistence, attachments, notifications, location triggers, import/export, maps, and metadata drift.

## Release

- [Deployment](deployment.md): App Store release inputs, signing requirements, metadata alignment, and release checklist.
- [`../AppStoreMetadata.md`](../AppStoreMetadata.md): App Store Connect copy and review notes.
- [`../screenshots/README.md`](../screenshots/README.md): screenshot capture checklist tied to real app surfaces.

## Non-Goals

No separate API, backend, Docker, CI/CD, Supabase, Firebase, or server documentation exists because those systems were not identified in the current repository.
