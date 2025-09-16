import { CommandDefinition } from "./CommandRegistry";

const ARGUMENT_MAX_LENGTH = 64;

function withCommandPrefix(command: CommandDefinition): string {
  return `/${command.name}`;
}

function sanitizeArgument(raw: string): string {
  return raw.replace(/[\r\n\t]/g, " ").trim().slice(0, ARGUMENT_MAX_LENGTH);
}

export function applyCommandInsert(
  text: string,
  command: CommandDefinition,
  cursor: number
): { newText: string; newCursor: number } {
  const prefix = text.slice(0, cursor);
  const suffix = text.slice(cursor);
  const partialMatch = /(\/[^\s]*)$/.exec(prefix);

  let insertion = withCommandPrefix(command);
  if (command.argument) insertion += " ";

  if (partialMatch) {
    const start = partialMatch.index;
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
  const sanitized = sanitizeArgument(chosen);
  const insertion = finalize ? `${sanitized} ` : sanitized; // trailing space ends arg mode
  const before = text.slice(0, replaceFrom);
  const after = text.slice(cursor);
  const newText = before + insertion + after;
  const newCursor = (before + insertion).length;
  return { newText, newCursor };
}
