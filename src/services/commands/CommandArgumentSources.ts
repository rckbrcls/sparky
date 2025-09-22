import { database } from "../../database";
import type { QuickNote, Reminder } from "../../repositories/types";
import { slugify } from "../../utils/slug";

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
  return e && now() - e.fetchedAt < TTL_MS && e.data.length > 0;
}

async function fetchFolders(): Promise<string[]> {
  try {
    // @ts-ignore init check
    if (!database.db && database.initialize) {
      await database.initialize();
    }
    const list = await database.getAllFolders();
    return list.map((f: any) => f.name);
  } catch {
    return [];
  }
}

async function fetchReminders(): Promise<Reminder[]> {
  try {
    // @ts-ignore init check
    if (!database.db && database.initialize) {
      await database.initialize();
    }
    return await database.getAllReminders();
  } catch {
    return [] as any;
  }
}

async function fetchQuickNotes(): Promise<QuickNote[]> {
  try {
    // @ts-ignore init check
    if (!database.db && database.initialize) {
      await database.initialize();
    }
    return await database.getAllQuickNotes();
  } catch {
    return [] as any;
  }
}

async function uniqueFrom<T>(
  values: T[],
  map: (value: T) => string | undefined
): Promise<string[]> {
  const unique = new Set<string>();
  values.forEach((value) => {
    const key = map(value);
    if (key) unique.add(key);
  });
  return Array.from(unique).sort((a, b) => a.localeCompare(b));
}

async function computePersons(): Promise<string[]> {
  const reminders = await fetchReminders();
  return uniqueFrom(reminders, (r) => r.person || undefined);
}
async function computeLocations(): Promise<string[]> {
  const reminders = await fetchReminders();
  return uniqueFrom(reminders, (r) => r.location || undefined);
}
async function computeTags(): Promise<string[]> {
  // Extract tags from quick notes content using existing parser conventions
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
    } catch {
      // ignore malformed tag payloads, we just skip them
    }
  }
  return tags.sort((a, b) => a.localeCompare(b));
}

export type SourceKey = "folders" | "persons" | "locations" | "tags";

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

export function normalizeValue(raw: string): string {
  return slugify(raw);
}
