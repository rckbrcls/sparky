import { database } from "@/src/database";

export type AppliesTo = "any" | "note" | "reminder";

export interface CommandDefinition {
  name: string; // without leading '/'
  description: string;
  group?: "type"; // exclusive group for type toggles
  appliesTo?: AppliesTo[]; // defaults to ['any']
  argument?: {
    source?: SourceKey; // optional async source for suggestions
  };
}

// Registry (static)
const COMMANDS: CommandDefinition[] = [
  // Type selection
  {
    name: "date",
    description: "Create a time-based reminder",
    group: "type",
    appliesTo: ["any"],
  },
  {
    name: "note",
    description: "Create a quick note",
    group: "type",
    appliesTo: ["any"],
  },

  // Properties
  {
    name: "folder",
    description: "Assign note to a folder",
    appliesTo: ["note"],
    argument: { source: "folders" },
  },
  {
    name: "tag",
    description: "Add a tag to the note",
    appliesTo: ["note"],
    argument: { source: "tags" },
  },
  {
    name: "priority",
    description: "Set priority (!, !!, !!! | 1,2,3)",
    appliesTo: ["any"],
  },
  {
    name: "person",
    description: "Trigger by person (contact name)",
    appliesTo: ["any"],
    argument: { source: "persons" },
  },
  {
    name: "location",
    description: "Trigger by location",
    appliesTo: ["any"],
    argument: { source: "locations" },
  },
];

export function getAllCommands(): CommandDefinition[] {
  return COMMANDS;
}

export function getCommandByName(name: string): CommandDefinition | undefined {
  const key = name.toLowerCase();
  return COMMANDS.find((c) => c.name.toLowerCase() === key);
}

// Lightweight sources with 30s TTL cache
export type SourceKey = "folders" | "persons" | "locations" | "tags";

interface CacheEntry {
  data: string[];
  fetchedAt: number;
  promise?: Promise<string[]>;
}

const TTL_MS = 30_000;
const caches: Record<string, CacheEntry> = {};

function now() {
  return Date.now();
}

function isFresh(key: string) {
  const e = caches[key];
  return !!e && now() - e.fetchedAt < TTL_MS && e.data.length > 0;
}

async function fetchFolders(): Promise<string[]> {
  try {
    // @ts-ignore init check
    if (!database.db && database.initialize) await database.initialize();
    const list = await database.getAllFolders();
    return list.map((f: any) => f.name);
  } catch {
    return [];
  }
}

async function fetchReminders(): Promise<any[]> {
  try {
    // @ts-ignore init check
    if (!database.db && database.initialize) await database.initialize();
    return await database.getAllReminders();
  } catch {
    return [] as any[];
  }
}

async function fetchQuickNotes(): Promise<any[]> {
  try {
    // @ts-ignore init check
    if (!database.db && database.initialize) await database.initialize();
    return await database.getAllQuickNotes();
  } catch {
    return [] as any[];
  }
}

async function uniqueFrom<T>(
  values: T[],
  map: (value: T) => string | undefined
): Promise<string[]> {
  const set = new Set<string>();
  values.forEach((v) => {
    const key = map(v);
    if (key) set.add(key);
  });
  return Array.from(set).sort((a, b) => a.localeCompare(b));
}

async function computePersons(): Promise<string[]> {
  const reminders = await fetchReminders();
  return uniqueFrom(reminders, (r: any) => r.person || undefined);
}

async function computeLocations(): Promise<string[]> {
  const reminders = await fetchReminders();
  return uniqueFrom(reminders, (r: any) => r.location || undefined);
}

async function computeTags(): Promise<string[]> {
  const notes = await fetchQuickNotes();
  const tags: string[] = [];
  for (const note of notes) {
    try {
      if (!note.tags) continue;
      const parsed = JSON.parse(note.tags);
      if (!Array.isArray(parsed)) continue;
      for (const tag of parsed) {
        if (typeof tag === "string" && !tags.includes(tag)) tags.push(tag);
      }
    } catch {}
  }
  return tags.sort((a, b) => a.localeCompare(b));
}

const sourceFetchers: Record<SourceKey, () => Promise<string[]>> = {
  folders: fetchFolders,
  persons: computePersons,
  locations: computeLocations,
  tags: computeTags,
};

export async function getSource(kind: SourceKey): Promise<string[]> {
  if (isFresh(kind)) return caches[kind].data;
  if (caches[kind]?.promise) return caches[kind].promise!;
  const p = sourceFetchers[kind]().then((data) => {
    caches[kind] = { data, fetchedAt: now() };
    return data;
  });
  caches[kind] = { data: [], fetchedAt: 0, promise: p };
  return p;
}

export function invalidate(kind?: SourceKey) {
  if (kind) delete caches[kind];
  else Object.keys(caches).forEach((k) => delete caches[k]);
}
