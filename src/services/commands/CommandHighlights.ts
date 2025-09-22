// Lightweight segment builder used by the terminal and command context engine.
// Responsible for identifying command tokens (/command) and their arguments so
// both syntax highlighting and contextual menus can stay in sync without
// duplicating parsing logic across the app.

export interface Segment {
  text: string;
  kind: "command" | "commandArg" | "tag" | "normal";
}

const COMMAND_PATTERN = /(\/[a-zA-Z]+)([\s\S]*?)(?=(?:\s\/[a-zA-Z]+)|$)/g;

// Tags are not enabled yet, but we keep the plumbing ready for a future
// /#hashtag or inline tag parser by holding a no-op regex placeholder.
const TAG_PATTERN = /$^/; // matches nothing

function appendSegment(target: Segment[], text: string, kind: Segment["kind"]) {
  if (!text) return;
  target.push({ text, kind });
}

function splitWithTags(text: string, base: Segment["kind"]): Segment[] {
  if (!text) return [];
  const collected: Segment[] = [];
  let lastIndex = 0;
  let match: RegExpExecArray | null;
  while ((match = TAG_PATTERN.exec(text)) !== null) {
    if (match.index > lastIndex)
      appendSegment(collected, text.slice(lastIndex, match.index), base);
    appendSegment(collected, match[0], "tag");
    lastIndex = match.index + match[0].length;
  }
  if (lastIndex < text.length)
    appendSegment(collected, text.slice(lastIndex), base);
  return collected;
}

export function buildSegments(value: string): Segment[] {
  if (!value) return [];
  const segments: Segment[] = [];
  let match: RegExpExecArray | null;
  let cursor = 0;

  while ((match = COMMAND_PATTERN.exec(value)) !== null) {
    if (match.index > cursor) {
      segments.push(...splitWithTags(value.slice(cursor, match.index), "normal"));
    }

    const commandToken = match[1];
    const argumentText = match[2] || "";

    appendSegment(segments, commandToken, "command");
    if (argumentText) {
      segments.push(...splitWithTags(argumentText, "commandArg"));
    }

    cursor = match.index + commandToken.length + argumentText.length;
  }

  if (cursor < value.length) {
    segments.push(...splitWithTags(value.slice(cursor), "normal"));
  }

  return segments;
}
