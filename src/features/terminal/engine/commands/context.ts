import { getSource, getAllCommands, getCommandByName } from "../commands";
import type { CommandDefinition } from "../commands";

export interface CommandComputationInput {
  text: string;
  cursor: number;
  requestId?: string; // for async race protection
  activated?: { name: string; index?: number }[];
}

export interface ComputedCommandState {
  openCommandQuery?: string; // raw partial after '/'
  commandMatches?: CommandDefinition[];
  inArgMode: boolean;
  activeCommand?: CommandDefinition;
  argPartial?: string;
  argReplaceFrom?: number; // index where arg token starts (for replacement)
  argSuggestions?: string[];
  requestId?: string;
}

const MAX_SUGGESTIONS = 30;

const EMPTY_COMMAND_STATE: ComputedCommandState = {
  inArgMode: false,
};

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
  activated: { name: string; index?: number }[] | undefined
): CursorContextResult {
  const uptoCursor = text.slice(0, cursor);
  const result: CursorContextResult = { inArgMode: false };

  // Activated-command arg mode (single-word), without slash
  if (activated && activated.length) {
    for (const act of activated) {
      const def = act.name ? getCommandByName(act.name) : undefined;
      if (!def?.argument) continue;
      // locate the token start
      let start = act.index ?? -1;
      if (start < 0) {
        const re = new RegExp(`(?:^|\\s)${def.name}(?:\\s|$)`);
        const m = re.exec(text);
        if (m) start = m.index + (m[0].startsWith(" ") ? 1 : 0);
      }
      if (start < 0) continue;
      const argStart = start + def.name.length + 1; // after a space
      if (cursor >= argStart) {
        const between = text.slice(argStart, cursor);
        return {
          inArgMode: true,
          activeCommand: def,
          argPartial: between,
          argReplaceFrom: argStart,
        };
      }
    }
  }

  const commandQueryMatch = /(?:^|\s)\/([^\s]*)$/.exec(uptoCursor);
  if (!commandQueryMatch) return result;

  const query = commandQueryMatch[1];
  const hasExactMatch = !!getCommandByName(query);
  if (hasExactMatch) return result;

  const lower = query.toLowerCase();
  const prefixMatches = commands.filter((command) => {
    return lower === "" || command.name.toLowerCase().startsWith(lower);
  });

  let containsMatches: CommandDefinition[] = [];
  containsMatches = commands.filter((command) => {
    const normalized = command.name.toLowerCase();
    if (!normalized.includes(lower)) return false;
    return !prefixMatches.some((prefix) => prefix.name === command.name);
  });

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
  const cursorContext = computeCursorContext(
    text,
    cursor,
    commands,
    input.activated
  );

  return {
    ...cursorContext,
    argSuggestions: [], // filled asynchronously
    requestId: input.requestId,
  };
}

export async function resolveArgumentSuggestions(
  base: ComputedCommandState
): Promise<ComputedCommandState> {
  if (!base.inArgMode || !base.activeCommand?.argument) return base;
  const { argument } = base.activeCommand;
  try {
    const resolved = argument.source ? await getSource(argument.source) : [];
    const partial = (base.argPartial || "").toLowerCase();
    const list = Array.isArray(resolved) ? resolved : [];
    const filtered = partial
      ? list.filter((c) => (c || "").toLowerCase().includes(partial))
      : list;
    return { ...base, argSuggestions: filtered.slice(0, MAX_SUGGESTIONS) };
  } catch {
    return base; // silent fail
  }
}
