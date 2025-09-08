// Extracted lightweight highlight module: segments for commands & their arguments
export interface Segment {
  text: string;
  kind: "command" | "commandArg" | "tag" | "normal";
}

// (Currently tags disabled) kept placeholder for future hashtag/tag parsing
const TAG_REGEX = /$^/; // matches nothing

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
    if (match.index > lastIndex)
      result.push(...splitTags(value.slice(lastIndex, match.index)));
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
