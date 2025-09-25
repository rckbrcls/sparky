// Unified Terminal Command Engine public API
// Centralizes command registry, context engine, insertion helpers, syntax highlighting,
// smart text parsing, and utilities in one cohesive module.

// Command registry and types
export type { CommandDefinition } from "./commands/registry";
export {
  getAllCommands,
  getCommandByName,
  registerCommand,
} from "./commands/registry";

// Command context engine (state computation and suggestions)
export type {
  ComputedCommandState,
  CommandStateSegment,
} from "./commands/context";
export { computeCommandState, resolveArgumentSuggestions } from "./commands/context";

// Command insertion utilities
export { applyCommandInsert, applyArgumentInsert } from "./commands/insertion";

// Syntax highlighting segments
export type { Segment } from "./commands/highlights";
export { buildSegments } from "./commands/highlights";

// Smart parser for reminders/notes
export type { ParsedReminder } from "./parser";
export { SmartTextParser } from "./parser";

// Text utilities and command helpers
export {
  slugify,
  defaultNormalize,
  slugifyForArgs,
  stripCreateDeleteCommands,
  stripAllSystemCommands,
  cleanSystemCommands,
  shouldHidePreviewForText,
  matchFolderCommand,
  matchCreateFolderCommand,
  matchDeleteFolderCommand,
  SLUG_ARG_COMMANDS,
} from "./utils/text";
