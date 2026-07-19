# Sparky Documentation

Sparky is a native Apple app (iPhone + Mac) with local-first SwiftData storage. macOS desktop distribution uses Sparkle + GitHub; iOS uses App Store tooling.

## Start Here

- [Getting Started](getting-started.md): open the Xcode project, understand targets, and prepare local development.
- [Architecture](architecture.md): app layers, dependency wiring, persistence, trigger execution, and data flow.
- [Development](development.md): project-specific coding conventions and safe extension patterns.

## Technical References

- [Data and Persistence](database.md): SwiftData schema, local attachment storage, JSON import/export, and iCalendar export.
- [Security and Privacy](security.md): local-first design, permissions, Privacy Manifest, and sensitive data risks.
- [Troubleshooting](troubleshooting.md): focused checks for persistence, attachments, notifications, location triggers, import/export, maps, and metadata drift.

## Release

- [Deployment](deployment.md): **macOS** Sparkle/GitHub/curl install **and** iOS App Store checklist.
- Shared macOS playbook: [`/Users/erickpatrickbarcelos/codes/docs/macos-desktop-distribution.md`](/Users/erickpatrickbarcelos/codes/docs/macos-desktop-distribution.md)
- [`../AppStoreMetadata.md`](../AppStoreMetadata.md): App Store Connect copy and review notes.
- [`../screenshots/README.md`](../screenshots/README.md): screenshot capture checklist tied to real app surfaces.

## Non-Goals

No custom backend/API product is documented here. macOS CI/CD for Sparkle releases **is** present (`.github/workflows/release.yml`).
