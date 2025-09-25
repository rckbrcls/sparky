const ARGUMENT_MAX_LENGTH = 64;

function sanitizeArgument(raw: string): string {
  return raw.replace(/[\r\n\t]/g, " ").trim().slice(0, ARGUMENT_MAX_LENGTH);
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
