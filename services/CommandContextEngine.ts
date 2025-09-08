import { getSource } from "./CommandArgumentSources";
import { CommandDefinition, getAllCommands } from "./CommandRegistry";

export interface CommandComputationInput {
  text: string;
  cursor: number;
  requestId?: string; // for async race protection
}

export interface CommandStateSegment {
  text: string;
  kind: "command" | "commandArg" | "normal";
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

// Basic synchronous computation; async suggestions resolved separately
export function computeCommandState(
  input: CommandComputationInput
): ComputedCommandState {
  const { text, cursor } = input;
  const commands = getAllCommands();

  let openCommandQuery: string | undefined;
  let commandMatches: CommandDefinition[] | undefined;
  let inArgMode = false;
  let activeCommand: CommandDefinition | undefined;
  let argPartial: string | undefined;
  let argReplaceFrom: number | undefined;
  let openBlockKind: ComputedCommandState["openBlockKind"];

  // --- Block Detection (unchanged) ---
  const blockStack: string[] = [];
  const BLOCK_START = new Set(["/tags", "/people", "/locations"]);
  const BLOCK_END: Record<string, string> = {
    "/endtags": "tags",
    "/endpeople": "people",
    "/endlocations": "locations",
  };
  const rawTokensForBlocks = text.split(/\s+/).filter(Boolean);
  for (const tk of rawTokensForBlocks) {
    if (BLOCK_START.has(tk)) {
      blockStack.push(tk.slice(1));
    } else if (BLOCK_END[tk]) {
      const kind = BLOCK_END[tk];
      for (let i = blockStack.length - 1; i >= 0; i--) {
        if (blockStack[i] === kind) {
          blockStack.splice(i, 1);
          break;
        }
      }
    }
  }
  if (blockStack.length) {
    const top = blockStack[blockStack.length - 1];
    if (top === "tags" || top === "people" || top === "locations") {
      openBlockKind = top;
    }
  }
  // --- End Block Detection ---

  const uptoCursor = text.slice(0, cursor);
  const commandQueryMatch = /(?:^|\s)\/([^\s]*)$/.exec(uptoCursor);

  if (commandQueryMatch) {
    openCommandQuery = commandQueryMatch[1];
    const lower = openCommandQuery.toLowerCase();
    const closing = openBlockKind
      ? openBlockKind === "tags"
        ? "endtags"
        : openBlockKind === "people"
        ? "endpeople"
        : "endlocations"
      : null;

    const prefixList = commands.filter(
      (c) =>
        (closing ? c.name === closing : true) &&
        (lower === "" ? true : c.name.toLowerCase().startsWith(lower))
    );

    let containsList: CommandDefinition[] = [];
    if (!closing) {
      containsList = commands.filter(
        (c) =>
          c.name.toLowerCase().includes(lower) &&
          !prefixList.find((p) => p.name === c.name)
      );
    }
    commandMatches = [...prefixList, ...containsList];
  } else {
    // Not in command-name-typing mode, check for argument mode.
    // This regex now specifically checks for a command followed by a space,
    // and optionally captures the beginning of an argument.
    const argModeMatch = /\/(\w+)\s+([^\/\n]*)?$/.exec(uptoCursor);
    const exactCmdMatch = /\/(\w+)$/.exec(uptoCursor); // For case where cursor is right after command name, no space yet

    let commandName: string | undefined;
    let isArgMode = false;

    if (argModeMatch) {
      commandName = argModeMatch[1];
      isArgMode = true;
    } else if (exactCmdMatch) {
      const cmd = commands.find((c) => c.name === exactCmdMatch[1]);
      if (cmd?.argument) {
        commandName = cmd.name;
        isArgMode = true; // Enter arg mode immediately, waiting for first char
      }
    }

    if (isArgMode && commandName) {
      activeCommand = commands.find((c) => c.name === commandName);
      if (activeCommand?.argument) {
        if (argModeMatch) {
          const partial = argModeMatch[2] || "";
          // An argument is complete if it's not empty and is followed by a space.
          if (/\s$/.test(partial) && partial.trim().length > 0) {
            inArgMode = false;
          } else {
            inArgMode = true;
            argPartial = partial;
            argReplaceFrom = cursor - partial.length;
          }
        } else {
          // This case is for when the cursor is right after the command name, no space yet.
          // We transition to arg mode, but wait for a space to be typed.
          // Let's check if the command wants an immediate suggestion list.
          if (activeCommand.argument.allowEmptyInitialList) {
            inArgMode = true;
            argPartial = "";
            argReplaceFrom = cursor;
          } else {
            // We are technically in "argument mode" but don't set the flag
            // that triggers the UI until the user types a space or starts typing.
            // The next state computation after a space will trigger it.
            inArgMode = false;
          }
        }
      }
    }
  }

  // Final check: if cursor is at /folder<space>, we should be in arg mode.
  const trailingSpaceMatch = /\/(\w+)\s$/.exec(uptoCursor);
  if (trailingSpaceMatch && !inArgMode) {
    const cmdName = trailingSpaceMatch[1];
    const cmd = commands.find((c) => c.name === cmdName);
    if (cmd?.argument) {
      inArgMode = true;
      activeCommand = cmd;
      argPartial = "";
      argReplaceFrom = cursor;
    }
  }

  // Legacy highlighting logic (can be simplified later, but kept for now)
  const segments: CommandStateSegment[] = [];
  const tokens = text.split(/(\s+)/);
  for (const tk of tokens) {
    const isCommand = tk.startsWith("/");
    const segKind: CommandStateSegment["kind"] = isCommand
      ? "command"
      : "normal";
    segments.push({ text: tk, kind: segKind });
  }

  return {
    openCommandQuery,
    commandMatches,
    inArgMode,
    activeCommand,
    argPartial,
    argReplaceFrom,
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
    let list: string[] = [];
    if (argument.fetch) {
      const r = await argument.fetch();
      list = Array.isArray(r) ? r : [];
    } else {
      list = await getSource(argument.source as any);
    }
    if (!list) list = [];
    const norm = argument.normalize || ((s: string) => s.toLowerCase());
    const partialNorm = norm(base.argPartial || "");
    if (argument.exclude) list = list.filter((v) => !argument.exclude!(v));
    if (partialNorm) {
      if (argument.filter)
        list = list.filter((v) => argument.filter!(v, partialNorm));
      else list = list.filter((v) => norm(v).includes(partialNorm));
    } else if (!argument.allowEmptyInitialList) {
      list = [];
    }
    return { ...base, argSuggestions: list.slice(0, 30) };
  } catch {
    return base; // silent fail
  }
}
