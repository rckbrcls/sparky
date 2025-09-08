# Command & Argument Engine

This document explains how to add or extend slash commands.

## Overview

Architecture layers:

1. CommandRegistry.ts: register commands (name, description, argument metadata).
2. CommandArgumentSources.ts: cached async entity providers (folders, persons, projects, locations, tags). 30s TTL with simple in-flight promise de-dupe.
3. CommandContextEngine.ts: pure(ish) synchronous computeCommandState + async resolveArgumentSuggestions.
4. CommandInsertion.ts: helpers to insert command or argument text into the input.
5. SmartInput.tsx: UI wiring (renders command or argument palettes) consuming computed state.

## Adding a New Entity Command

1. Decide a unique command name (without slash), e.g. `client`.
2. If it maps to an existing source kind (folders, persons, projects, locations, tags) set `argument.source` accordingly. Otherwise use `source: 'custom'` and provide a `fetch` function.
3. Call `registerCommand({ name: 'client', description: 'Associate a client', category: 'entity', argument: { source: 'custom', fetch: fetchClients, allowEmptyInitialList: true } })` early in app startup (any imported module).
4. Ensure `fetchClients` returns a string array (unique values) — they will be filtered automatically.

## Argument Normalization

Default normalization lowercases, strips accents and non-alphanumerics then joins with `-`. Override via `argument.normalize` if needed.

## Filtering Logic

Provide a custom `argument.filter(candidate, partialNorm)` for specialized prefix/ fuzzy semantics; otherwise default is substring on normalized value.

## Invalidation

Call `invalidate('folders')` (or other key) after CRUD operations to refresh suggestions.

## Selection Semantics

`finalizeOnSelect` (default true) adds a trailing space, closing argument mode. Set false to allow chained editing (advanced use).

## Race Safety

UI layer holds a `requestId` (e.g., incrementing counter). After awaiting `resolveArgumentSuggestions`, discard results if requestId changed.

## Tests

Core state transitions should be unit tested around `computeCommandState` and `resolveArgumentSuggestions`.

## Future Enhancements

- Fuzzy scoring (e.g. fuse.js) if size grows.
- Multi-arg commands (argument segment descriptors array).
- Rich metadata (icon, color) per suggestion.
