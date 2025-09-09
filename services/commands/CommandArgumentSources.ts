import { database, QuickNote, Reminder } from "../../database/database";
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
    return list.map((f) => f.name);
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
  map: (v: T) => string | undefined
): Promise<string[]> {
  const out: string[] = [];
  for (const v of values) {
    const k = map(v);
    if (k && !out.includes(k)) out.push(k);
  }
  return out.sort((a, b) => a.localeCompare(b));
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
  // Extract tags from quick notes content using existing parser conventions (/tags block or #tags in future)
  const notes = await fetchQuickNotes();
  const tags: string[] = [];
  for (const n of notes) {
    // Simple heuristic: parse /tags block or JSON tags stored
    try {
      if (n.tags) {
        const arr = JSON.parse(n.tags);
        if (Array.isArray(arr)) {
          for (const t of arr)
            if (typeof t === "string" && !tags.includes(t)) tags.push(t);
        }
      }
    } catch {}
  }
  return tags.sort((a, b) => a.localeCompare(b));
}

type SourceKey = "folders" | "persons" | "locations" | "tags";

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
