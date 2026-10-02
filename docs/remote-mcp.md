# Remote MCP

Sparky can optionally connect to a self-hosted [sparky-mcp](https://github.com/rckbrcls/sparky-mcp) server. The server exposes Minds and Memories to AI clients (Claude, ChatGPT, Claude Code, Codex) through the Model Context Protocol, for example to create a reminder while away from home.

The integration is optional and off by default. Nothing is hosted for you, and the app works unchanged without it.

## How It Works

- The app owns the data. The server never writes to SwiftData directly.
- **Mirror:** the app pushes a snapshot of Minds and Memories to the server (`PUT /api/mirror`). MCP read tools answer from this mirror.
- **Command queue:** MCP write tools queue commands on the server. The app polls (about every 10 seconds), claims them, applies them locally, and reports the result.
- **Conflicts:** each command carries a base version (the entity's `updatedAt`). If the entity changed since, the command ends as `conflict` instead of overwriting.
- **Idempotency:** commands are keyed by id and recorded in a local receipts journal, so a retried command is not applied twice.

## MCP Tools

Read: `get_current_time`, `list_minds`, `list_memories`, `get_memory`, `get_command_status`.

Write: `create_memory`, `update_memory`, `set_memory_status`, `toggle_check_item`, `delete_memory`, `create_mind`, `update_mind`, `delete_mind`. Deletes require `confirm: true`; deleting a Mind is recursive and moves its Memories to the Inbox.

Tags, Sequences, and Focus sessions are not exposed.

## Setup

1. Run and expose the server by following the [sparky-mcp README](https://github.com/rckbrcls/sparky-mcp).
2. In Sparky, open Settings > Advanced > Remote MCP.
3. Enter the Server URL and API token, enable the toggle, and use Test connection.

The token is stored in the Keychain. The URL and enabled flag are stored in UserDefaults.

## Sync Behavior

- macOS keeps syncing while the app is in the background.
- iOS syncs only while the app is active.
- Commands queued while the app is closed are applied the next time it syncs.

## Source

`sparky/Remote/`: `RemoteSyncService`, `RemoteSyncClient`, `RemoteMirrorBuilder`, `RemoteCommandExecutor`, `KeychainTokenStore`, `RemoteSyncSettings`. UI: `Views/Settings/RemoteMCPSettingsSection.swift`.
