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

  // Debug: let's see what we're working with
  console.log("Debug CommandContext:", {
    text: JSON.stringify(text),
    cursor,
    uptoCursor: JSON.stringify(uptoCursor),
  });

  // Alternative approach: check if we're at the end of a command followed by space
  // Look for /command pattern and check if there's a space right after where cursor is
  const commandAtCursor = /\/(\w+)$/.exec(uptoCursor);
  if (commandAtCursor) {
    const cmdName = commandAtCursor[1];
    const cmd = commands.find((c) => c.name === cmdName);

    // Check if there's a space right after the cursor position
    const charAfterCursor = text[cursor];
    console.log("Command at cursor:", {
      cmdName,
      charAfterCursor: JSON.stringify(charAfterCursor),
      hasArgument: !!cmd?.argument,
    });

    if (charAfterCursor === " " && cmd && cmd.argument) {
      inArgMode = true;
      activeCommand = cmd;
      argPartial = "";
      argReplaceFrom = cursor + 1; // Start after the space
      console.log("Entering arg mode for command followed by space:", cmdName);
    }
  }

  // Also check the original trailing space logic in case cursor positioning is correct sometimes
  const trailingSpaceMatch = /\/(\w+)\s+$/.exec(uptoCursor);
  console.log("trailingSpaceMatch:", trailingSpaceMatch);

  if (trailingSpaceMatch && !inArgMode) {
    const cmdName = trailingSpaceMatch[1];
    const cmd = commands.find((c) => c.name === cmdName);
    console.log("Found command with trailing space:", {
      cmdName,
      hasArgument: !!cmd?.argument,
    });
    if (cmd && cmd.argument) {
      inArgMode = true;
      activeCommand = cmd;
      argPartial = "";
      argReplaceFrom = cursor;
      console.log("Entering arg mode for:", cmdName);
    }
  }
  // If not in trailing space case, check for other patterns
  else {
    // Check for command query (typing a command) or argument with content
    const commandQueryMatch = /(?:^|\s)\/([^\s]*)$/.exec(uptoCursor);
    const argModeMatch = /\/(\w+)\s+([^\/\n]*)?$/.exec(uptoCursor);

    if (argModeMatch) {
      // We have a command followed by space and some argument content
      const cmdName = argModeMatch[1];
      const cmd = commands.find((c) => c.name === cmdName);
      if (cmd && cmd.argument) {
        const partial = argModeMatch[2] || "";
        // An argument is complete if it's not empty and is followed by a space.
        if (/\s$/.test(partial) && partial.trim().length > 0) {
          inArgMode = false; // Argument is complete
        } else {
          inArgMode = true;
          activeCommand = cmd;
          argPartial = partial;
          argReplaceFrom = cursor - partial.length;
        }
      }
    } else if (commandQueryMatch) {
      // We are typing a command name
      const query = commandQueryMatch[1];
      const exactMatch = commands.find((c) => c.name === query);

      // If we have an exact command match, don't show command suggestions
      if (exactMatch) {
        // Command is complete - no suggestions needed
      } else {
        // Partial command query - show matching commands
        openCommandQuery = query;
        const lower = query.toLowerCase();
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
      }
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
