# Sparky Documentation

Sparky is a native Apple app with local-first SwiftData storage. The **Mac app is the released product** (distributed with Sparkle + GitHub). An iPhone target exists in the codebase but is unreleased, with no release date.

## Start Here

- [Getting Started](getting-started.md): open the Xcode project, understand targets, and prepare local development.
- [Architecture](architecture.md): app layers, dependency wiring, persistence, trigger execution, and data flow.
- [Development](development.md): project-specific coding conventions and safe extension patterns.

## Technical References

- [Data and Persistence](database.md): SwiftData schema, local attachment storage, JSON import/export, and iCalendar export.
- [Security and Privacy](security.md): local-first design, permissions, Privacy Manifest, and sensitive data risks.
- [Remote MCP](remote-mcp.md): optional self-hosted MCP server integration for AI clients.
- [Troubleshooting](troubleshooting.md): focused checks for persistence, attachments, notifications, location triggers, import/export, maps, and metadata drift.

## Release

- [Deployment](deployment.md): **macOS** Sparkle/GitHub/curl install. The iOS section is a draft checklist for a future release.
- Shared macOS playbook: [`/Users/erickpatrickbarcelos/codes/docs/macos-desktop-distribution.md`](/Users/erickpatrickbarcelos/codes/docs/macos-desktop-distribution.md)
- [`../AppStoreMetadata.md`](../AppStoreMetadata.md): draft App Store Connect copy for the unreleased iOS app.
- [`../screenshots/README.md`](../screenshots/README.md): screenshot capture checklist tied to real app surfaces.

## Non-Goals

No hosted backend/API product is documented here. The only server integration is the optional, self-hosted [Sparky MCP](remote-mcp.md). macOS CI/CD for Sparkle releases **is** present (`.github/workflows/release.yml`).
