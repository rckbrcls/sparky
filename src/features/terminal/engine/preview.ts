import type { ParsedReminder } from "./parser";
import type { IntentState } from "./intent";
import { slugifyForArgs } from "./utils/text";

function removeActivatedTokensFromText(text: string, intent: IntentState): string {
  if (!text) return "";
  if (!intent.activated.length) return text.trim();
  let value = text;
  const acts = [...intent.activated].sort((a, b) => (b.index ?? 0) - (a.index ?? 0));
  for (const a of acts) {
    const name = a.name;
    const idx = a.index != null ? a.index : value.indexOf(name);
    if (idx < 0) continue;
    const nameEnd = idx + name.length;
    let end = nameEnd;
    if (value[end] === " ") {
      end += 1;
      while (end < value.length && value[end] !== " ") end += 1;
    }
    value = (value.slice(0, idx) + value.slice(end)).replace(/\s{2,}/g, " ").trim();
  }
  return value.trim();
}

export function buildPreviewFromIntent(text: string, intent: IntentState): ParsedReminder {
  const cleaned = removeActivatedTokensFromText(text, intent);
  const folderValue = intent.activated.find((c) => c.name === 'folder')?.value?.trim();
  const persons = intent.activated.filter((c) => c.name === 'person' && (c.value ?? '').trim()).map((c) => c.value!.trim());
  const locations = intent.activated.filter((c) => c.name === 'location' && (c.value ?? '').trim()).map((c) => c.value!.trim());
  const priorityVal = intent.activated.find((c) => c.name === 'priority')?.value?.trim();

  let priority: 1 | 2 | 3 = 1;
  if (priorityVal === '!!!' || priorityVal === '3' || /urgent|alta/i.test(priorityVal || '')) priority = 3;
  else if (priorityVal === '!!' || priorityVal === '2' || /m[eé]dio|medio|important/i.test(priorityVal || '')) priority = 2;

  const kind = intent.type === 'reminder' ? 'reminder' : 'note';

  const base: ParsedReminder = {
    title: cleaned,
    type: kind === 'reminder' ? 'date' : 'note',
    priority,
    tags: [],
    person: persons[0],
    location: locations[0],
  };

  if (folderValue && kind === 'note') {
    base.folderId = slugifyForArgs(folderValue);
  }
  if (persons.length > 1) base.persons = persons;
  if (locations.length > 1) base.locations = locations;

  if (base.type !== 'date' && (persons.length || locations.length)) {
    base.type = 'trigger';
  }

  return base;
}

