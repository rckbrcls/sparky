import { CommandDefinition } from "./CommandRegistry";

export function applyCommandInsert(
  text: string,
  command: CommandDefinition,
  cursor: number
): { newText: string; newCursor: number } {
  const prefix = text.slice(0, cursor);
  const suffix = text.slice(cursor);
  // Replace current token if it is a /partial
  const m = /(\/[^\s]*)$/.exec(prefix);
  let insertion = `/${command.name}`;
  if (command.argument) insertion += " ";
  if (m) {
    const start = m.index;
    const newPrefix = prefix.slice(0, start) + insertion;
    return { newText: newPrefix + suffix, newCursor: newPrefix.length };
  }
  const newPrefix = prefix + insertion;
  return { newText: newPrefix + suffix, newCursor: newPrefix.length };
}

export function applyArgumentInsert(
  text: string,
  replaceFrom: number,
  cursor: number,
  chosen: string,
  finalize: boolean
): { newText: string; newCursor: number } {
  const safe = chosen
    .replace(/[\r\n\t]/g, " ")
    .trim()
    .substring(0, 64);
  const insertion = finalize ? safe + " " : safe; // trailing space ends arg mode
  const before = text.slice(0, replaceFrom);
  const after = text.slice(cursor);
  const newText = before + insertion + after;
  const newCursor = (before + insertion).length;
  return { newText, newCursor };
}
