import { getSource } from "./CommandArgumentSources";
import { buildSegments } from "./CommandHighlights";
import {
  CommandDefinition,
  getAllCommands,
  getCommandByName,
} from "./CommandRegistry";

export interface CommandComputationInput {
  text: string;
  cursor: number;
  requestId?: string; // for async race protection
}

export interface CommandStateSegment {
  text: string;
  kind: "command" | "commandArg" | "tag" | "normal";
}

export interface ComputedCommandState {
  openCommandQuery?: string; // raw partial after '/'
  commandMatches?: CommandDefinition[];
  inArgMode: boolean;
  activeCommand?: CommandDefinition;
  argPartial?: string;
  argReplaceFrom?: number; // index where arg token starts (for replacement)
  argSuggestions?: string[];
  segments: CommandStateSegment[]; // highlight info (kept simple for now)
  requestId?: string;
  openBlockKind?: "tags" | "people" | "locations"; // legacy block support
}

const BLOCK_START = new Set(["/tags", "/people", "/locations"]);
const BLOCK_END: Record<string, "tags" | "people" | "locations"> = {
  "/endtags": "tags",
  "/endpeople": "people",
  "/endlocations": "locations",
};

const MAX_SUGGESTIONS = 30;

const EMPTY_COMMAND_STATE: ComputedCommandState = {
  inArgMode: false,
  segments: [],
};

function resolveOpenBlockKind(
  text: string
): ComputedCommandState["openBlockKind"] {
  const tokens = text.split(/\s+/).filter(Boolean);
  const stack: Array<"tags" | "people" | "locations"> = [];
  tokens.forEach((token) => {
    if (BLOCK_START.has(token)) {
      stack.push(token.slice(1) as typeof stack[number]);
      return;
    }
    const closing = BLOCK_END[token];
    if (!closing) return;
    for (let i = stack.length - 1; i >= 0; i--) {
      if (stack[i] === closing) {
        stack.splice(i, 1);
        break;
      }
    }
  });
  return stack.length > 0 ? stack[stack.length - 1] : undefined;
}

interface CursorContextResult {
  inArgMode: boolean;
  activeCommand?: CommandDefinition;
  argPartial?: string;
  argReplaceFrom?: number;
  openCommandQuery?: string;
  commandMatches?: CommandDefinition[];
}

function computeCursorContext(
  text: string,
  cursor: number,
  commands: CommandDefinition[],
  openBlockKind: ComputedCommandState["openBlockKind"]
): CursorContextResult {
  const uptoCursor = text.slice(0, cursor);
  const charAfterCursor = text[cursor];
  const result: CursorContextResult = { inArgMode: false };

  const commandAtCursor = /\/(\w+)$/.exec(uptoCursor);
  if (commandAtCursor) {
    const command = getCommandByName(commandAtCursor[1]);
    if (charAfterCursor === " " && command?.argument) {
      return {
        inArgMode: true,
        activeCommand: command,
        argPartial: "",
        argReplaceFrom: cursor + 1,
      };
    }
  }

  const trailingSpaceMatch = /\/(\w+)\s+$/.exec(uptoCursor);
  if (trailingSpaceMatch) {
    const command = getCommandByName(trailingSpaceMatch[1]);
    if (command?.argument) {
      return {
        inArgMode: true,
        activeCommand: command,
        argPartial: "",
        argReplaceFrom: cursor,
      };
    }
  }

  const argModeMatch = /\/(\w+)\s+([^\/\n]*)$/.exec(uptoCursor);
  if (argModeMatch) {
    const command = getCommandByName(argModeMatch[1]);
    if (command?.argument) {
      const partial = argModeMatch[2] || "";
      if (/\s$/.test(partial) && partial.trim().length > 0) {
        return { inArgMode: false };
      }
      return {
        inArgMode: true,
        activeCommand: command,
        argPartial: partial,
        argReplaceFrom: cursor - partial.length,
      };
    }
  }

  const commandQueryMatch = /(?:^|\s)\/([^\s]*)$/.exec(uptoCursor);
  if (!commandQueryMatch) return result;

  const query = commandQueryMatch[1];
  const hasExactMatch = !!getCommandByName(query);
  if (hasExactMatch) return result;

  const lower = query.toLowerCase();
  const closingName =
    openBlockKind === "tags"
      ? "endtags"
      : openBlockKind === "people"
      ? "endpeople"
      : openBlockKind === "locations"
      ? "endlocations"
      : null;

  const prefixMatches = commands.filter((command) => {
    if (closingName && command.name !== closingName) return false;
    return lower === "" || command.name.toLowerCase().startsWith(lower);
  });

  let containsMatches: CommandDefinition[] = [];
  if (!closingName) {
    containsMatches = commands.filter((command) => {
      const normalized = command.name.toLowerCase();
      if (!normalized.includes(lower)) return false;
      return !prefixMatches.some((prefix) => prefix.name === command.name);
    });
  }

  result.openCommandQuery = query;
  result.commandMatches = [...prefixMatches, ...containsMatches];
  return result;
}

// Basic synchronous computation; async suggestions resolved separately
export function computeCommandState(
  input: CommandComputationInput
): ComputedCommandState {
  const { text, cursor } = input;
  const commands = getAllCommands();
  if (!text) {
    return { ...EMPTY_COMMAND_STATE, requestId: input.requestId };
  }

  const openBlockKind = resolveOpenBlockKind(text);
  const cursorContext = computeCursorContext(
    text,
    cursor,
    commands,
    openBlockKind
  );

  const segments = buildSegments(text).map((segment) => ({
    text: segment.text,
    kind: segment.kind,
  }));

  return {
    ...cursorContext,
    argSuggestions: [], // filled asynchronously
    segments,
    requestId: input.requestId,
    openBlockKind,
  };
}

export async function resolveArgumentSuggestions(
  base: ComputedCommandState
): Promise<ComputedCommandState> {
  if (!base.inArgMode || !base.activeCommand?.argument) return base;
  const { argument } = base.activeCommand;
  try {
    const resolved = await (async () => {
      if (argument.fetch) {
        const result = await argument.fetch();
        return Array.isArray(result) ? result : [];
      }
      return getSource(argument.source);
    })();

    const normalize = argument.normalize || ((value: string) => value.toLowerCase());
    const partialNorm = normalize(base.argPartial || "");

    let filtered = Array.isArray(resolved) ? resolved.slice() : [];
    if (argument.exclude) {
      filtered = filtered.filter((candidate) => !argument.exclude!(candidate));
    }

    if (partialNorm) {
      filtered = filtered.filter((candidate) => {
        if (argument.filter) return argument.filter(candidate, partialNorm);
        return normalize(candidate).includes(partialNorm);
      });
    } else if (!argument.allowEmptyInitialList) {
      filtered = [];
    }

    return { ...base, argSuggestions: filtered.slice(0, MAX_SUGGESTIONS) };
  } catch {
    return base; // silent fail
  }
}
