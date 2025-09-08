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
  const segments: CommandStateSegment[] = [];
  // naive highlight: split by spaces, mark tokens starting with '/'
  const tokens = text.split(/(\s+)/); // preserve whitespace tokens
  let pos = 0;
  let activeRange: { start: number; end: number; token: string } | null = null;
  for (const tk of tokens) {
    // Consider any token starting with '/' as a command token so that a lone '/'
    // immediately opens the command palette (previously required at least one word char)
    const isCommand = tk.startsWith("/");
    const segKind: CommandStateSegment["kind"] = isCommand
      ? "command"
      : "normal";
    segments.push({ text: tk, kind: segKind });
    const start = pos;
    const end = pos + tk.length;
    if (cursor >= start && cursor <= end) {
      activeRange = { start, end, token: tk };
    }
    pos = end;
  }
  // Determine if inside an existing command argument region
  let inArgMode = false;
  let activeCommand: CommandDefinition | undefined;
  let argPartial: string | undefined;
  let argReplaceFrom: number | undefined;
  let commandMatches: CommandDefinition[] | undefined;
  let openCommandQuery: string | undefined;
  let openBlockKind: ComputedCommandState["openBlockKind"];

  // Detect open block by scanning tokens sequentially (simple stack for nested safety though only single level used)
  const blockStack: string[] = [];
  const BLOCK_START = new Set(["/tags", "/people", "/locations"]);
  const BLOCK_END: Record<string, string> = {
    "/endtags": "tags",
    "/endpeople": "people",
    "/endlocations": "locations",
  };
  const rawTokensForBlocks = text.split(/\s+/).filter(Boolean);
  for (const tk of rawTokensForBlocks) {
    if (BLOCK_START.has(tk))
      blockStack.push(tk.slice(1)); // store kind without '/'
    else if (BLOCK_END[tk]) {
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
    if (top === "tags" || top === "people" || top === "locations")
      openBlockKind = top;
  }

  if (activeRange) {
    const { token } = activeRange;
    if (token.startsWith("/")) {
      const partialName = token.slice(1); // may be empty when user just typed '/'
      // If token contains no whitespace we are selecting command name (including empty)
      if (!/\s/.test(partialName)) {
        openCommandQuery = partialName;
        const lower = partialName.toLowerCase();
        commandMatches = commands.filter((c) => {
          if (openBlockKind) {
            // inside a block, only show its closing command
            const closing =
              openBlockKind === "tags"
                ? "endtags"
                : openBlockKind === "people"
                ? "endpeople"
                : "endlocations";
            if (c.name !== closing) return false;
          }
          return lower === "" ? true : c.name.startsWith(lower);
        });
      } else {
        // token like /folder my-arg (not split yet due to simple splitting logic)
      }
    } else {
      // We might be in an argument after a command; find preceding command token
      const uptoCursor = text.slice(0, cursor);
      const cmdMatch = /\/(\w+)(?:\s+([^\/\n]*))?$/.exec(uptoCursor);
      if (cmdMatch) {
        const name = cmdMatch[1];
        activeCommand = commands.find((c) => c.name === name);
        if (activeCommand?.argument) {
          const rawPartial = cmdMatch[2] || "";
          // Determine if user has already finalized the argument (argument + space afterward)
          const endedPattern = new RegExp(`/` + name + `\\s+\\S+\\s+$`); // /command arg ␠
          const onlyCommandSpacePattern = new RegExp(`/` + name + `\\s+$`); // /command ␠ (no arg yet)
          const ended = endedPattern.test(uptoCursor);
          const onlyCommandSpace = onlyCommandSpacePattern.test(uptoCursor);
          if (!ended) {
            inArgMode = true;
            argPartial = rawPartial;
            argReplaceFrom = cursor - rawPartial.length;
          } else if (onlyCommandSpace) {
            // still waiting first arg char
            inArgMode = true;
            argPartial = "";
            argReplaceFrom = cursor;
          }
        }
      }
    }
  }

  // Additional rule: if token is exactly "/command" (cursor after it) and it expects argument -> enter arg mode
  if (!inArgMode) {
    const beforeCursor = text.slice(0, cursor);
    const exactCmd = /\/(\w+)$/.exec(beforeCursor);
    if (exactCmd) {
      const def = commands.find((c) => c.name === exactCmd[1]);
      if (def?.argument) {
        inArgMode = true;
        activeCommand = def;
        argPartial = "";
        argReplaceFrom = cursor;
      }
    } else if (/\/$/.test(beforeCursor)) {
      // Just a bare '/' at cursor end -> show all commands (or only block closing if inside block)
      openCommandQuery = "";
      commandMatches = commands.filter((c) => {
        if (openBlockKind) {
          const closing =
            openBlockKind === "tags"
              ? "endtags"
              : openBlockKind === "people"
              ? "endpeople"
              : "endlocations";
          return c.name === closing;
        }
        return true;
      });
    }
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
