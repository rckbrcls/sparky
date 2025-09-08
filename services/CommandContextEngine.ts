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
    // Not in command-name-typing mode, check for argument mode
    const cmdMatch = /\/(\w+)(?:\s+([^\/\n]*))?$/.exec(uptoCursor);
    if (cmdMatch) {
      const name = cmdMatch[1];
      activeCommand = commands.find((c) => c.name === name);
      if (activeCommand?.argument) {
        const rawPartial = cmdMatch[2] || "";
        const endedPattern = new RegExp(`/` + name + `\\s+\\S+\\s+$`);
        const onlyCommandSpacePattern = new RegExp(`/` + name + `\\s+$`);
        const ended = endedPattern.test(uptoCursor);
        const onlyCommandSpace = onlyCommandSpacePattern.test(uptoCursor);

        if (!ended) {
          inArgMode = true;
          argPartial = rawPartial;
          argReplaceFrom = cursor - rawPartial.length;
        } else if (onlyCommandSpace) {
          inArgMode = true;
          argPartial = "";
          argReplaceFrom = cursor;
        }
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
