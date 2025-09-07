// Single-file command engine (consolidated)
// Centraliza: definição de comandos, contexto, filtro, highlight e inserção.

export interface CommandDef {
  cmd: string;
  label: string;
  desc: string;
  insert: string;
  type?: "block";
  end?: string; // para comandos de bloco
}

export interface CommandContext {
  openBlock: string | null;
  showCommands: boolean;
  query: string | null;
}

export interface Segment {
  text: string;
  kind: "command" | "commandArg" | "tag" | "normal";
}

// --- Comandos -------------------------------------------------------------
export function getCommands(): CommandDef[] {
  return [
    {
      cmd: "/date",
      label: "date",
      desc: "Definir data/hora: /date amanhã 18:00",
      insert: "/date ",
    },
    {
      cmd: "/note",
      label: "note",
      desc: "Título rápido: /note Comprar leite",
      insert: "/note ",
    },
    {
      cmd: "/title",
      label: "title",
      desc: "Definir título: /title Reunião equipe",
      insert: "/title ",
    },
    {
      cmd: "/person",
      label: "person",
      desc: "Pessoa: /person João",
      insert: "/person ",
    },
    {
      cmd: "/people",
      label: "people",
      desc: "Bloco pessoas: /people João; Maria /endpeople",
      insert: "/people ",
      type: "block",
      end: "/endpeople",
    },
    {
      cmd: "/location",
      label: "location",
      desc: "Local: /location escritório",
      insert: "/location ",
    },
    {
      cmd: "/locations",
      label: "locations",
      desc: "Bloco locais: /locations escritório; casa /endlocations",
      insert: "/locations ",
      type: "block",
      end: "/endlocations",
    },
    {
      cmd: "/project",
      label: "project",
      desc: "Projeto: /project Novo App",
      insert: "/project ",
    },
    {
      cmd: "/priority",
      label: "priority",
      desc: "Prioridade: /priority !!! | !! | ! | 1..3",
      insert: "/priority ",
    },
    {
      cmd: "/tags",
      label: "tags",
      desc: "Tags: /tags urgente backend",
      insert: "/tags ",
      type: "block",
      end: "/endtags",
    },
    { cmd: "/help", label: "help", desc: "Lista de comandos", insert: "/help" },
    // Fechamentos
    {
      cmd: "/endtags",
      label: "endtags",
      desc: "Fechar bloco de tags",
      insert: "/endtags",
    },
    {
      cmd: "/endpeople",
      label: "endpeople",
      desc: "Fechar bloco de pessoas",
      insert: "/endpeople",
    },
    {
      cmd: "/endlocations",
      label: "endlocations",
      desc: "Fechar bloco de locais",
      insert: "/endlocations",
    },
  ];
}

const BLOCK_START_TO_KIND: Record<string, string> = {
  "/tags": "tags",
  "/people": "people",
  "/locations": "locations",
};
const BLOCK_END_TO_KIND: Record<string, string> = {
  "/endtags": "tags",
  "/endpeople": "people",
  "/endlocations": "locations",
};
const BLOCK_KIND_TO_END: Record<string, string> = {
  tags: "/endtags",
  people: "/endpeople",
  locations: "/endlocations",
};

// --- Contexto -------------------------------------------------------------
export function detectContext(text: string): CommandContext {
  const tokens = text.split(/\s+/).filter(Boolean);
  const cursor = tokens.length ? tokens[tokens.length - 1] : "";
  const stack: string[] = [];
  for (const t of tokens) {
    if (BLOCK_START_TO_KIND[t]) stack.push(BLOCK_START_TO_KIND[t]);
    else if (BLOCK_END_TO_KIND[t]) {
      const kind = BLOCK_END_TO_KIND[t];
      for (let i = stack.length - 1; i >= 0; i--) {
        if (stack[i] === kind) {
          stack.splice(i, 1);
          break;
        }
      }
    }
  }
  const openBlock = stack.length ? stack[stack.length - 1] : null;
  if (cursor.startsWith("/")) {
    return { openBlock, showCommands: true, query: cursor.slice(1) };
  }
  return { openBlock, showCommands: false, query: null };
}

// --- Filtro ---------------------------------------------------------------
export function filterCommandList(
  all: CommandDef[],
  openBlock: string | null,
  query: string | null
): CommandDef[] {
  if (openBlock) {
    const end = BLOCK_KIND_TO_END[openBlock];
    const closing = all.find((c) => c.cmd === end);
    return closing ? [closing] : [];
  }
  const q = (query || "").toLowerCase();
  if (!q) return all.filter((c) => !c.cmd.startsWith("/end"));
  return all.filter(
    (c) =>
      (c.cmd.startsWith(`/${q}`) || c.label.includes(q)) &&
      !c.cmd.startsWith("/end")
  );
}

// --- Highlight ------------------------------------------------------------
const TAG_REGEX = /#[a-zA-Z\u00C0-\u017F0-9_]+/g;

function splitTags(
  textChunk: string,
  base: Segment["kind"] = "normal"
): Segment[] {
  if (!textChunk) return [];
  const segs: Segment[] = [];
  let last = 0;
  let m: RegExpExecArray | null;
  while ((m = TAG_REGEX.exec(textChunk)) !== null) {
    if (m.index > last)
      segs.push({ text: textChunk.slice(last, m.index), kind: base });
    segs.push({ text: m[0], kind: "tag" });
    last = m.index + m[0].length;
  }
  if (last < textChunk.length)
    segs.push({ text: textChunk.slice(last), kind: base });
  return segs;
}

export function buildSegments(value: string): Segment[] {
  if (!value) return [];
  const result: Segment[] = [];
  const regex = /(\/[a-zA-Z]+)([\s\S]*?)(?=(?:\s\/[a-zA-Z]+)|$)/g;
  let lastIndex = 0;
  let match: RegExpExecArray | null;
  while ((match = regex.exec(value)) !== null) {
    if (match.index > lastIndex) {
      result.push(...splitTags(value.slice(lastIndex, match.index)));
    }
    const token = match[1];
    const argText = match[2] || "";
    result.push({ text: token, kind: "command" });
    if (argText) result.push(...splitTags(argText, "commandArg"));
    lastIndex = match.index + token.length + argText.length;
  }
  if (lastIndex < value.length)
    result.push(...splitTags(value.slice(lastIndex)));
  return result;
}

// --- Inserção -------------------------------------------------------------
export function applyCommandInsert(current: string, cmd: CommandDef): string {
  const parts = current.split(/\s+/);
  if (parts.length === 0 || !current.trim()) return cmd.insert;
  let idx = parts.length - 1;
  while (idx >= 0 && parts[idx] === "") idx--;
  if (idx >= 0 && parts[idx].startsWith("/")) parts[idx] = cmd.insert.trimEnd();
  else parts.push(cmd.insert.trimEnd());
  return (
    parts.filter(Boolean).join(" ") + (cmd.insert.endsWith(" ") ? "" : " ")
  );
}
