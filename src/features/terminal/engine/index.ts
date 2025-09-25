// Unified Terminal Command Engine public API
// Centralizes command registry, context engine, insertion helpers, syntax highlighting,
// smart text parsing, and utilities in one cohesive module.

// Command registry and types (single-file commands)
export type { CommandDefinition } from "./commands";
export { getAllCommands, getCommandByName } from "./commands";

// Command context engine (state computation and suggestions)
export type { ComputedCommandState } from "./commands/context";
export { computeCommandState, resolveArgumentSuggestions } from "./commands/context";

// Command insertion utilities
export { applyArgumentInsert } from "./commands/insertion";

// Minimal segment type used by InputBlock highlights only
export type { Segment } from "./types";

// Reminder/Note preview types
export type { ParsedReminder } from "./types";

// Text utilities used by UI/helpers
export { slugifyForArgs } from "./utils/text";
