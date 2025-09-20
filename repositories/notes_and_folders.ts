import { Q } from "@nozbe/watermelondb";
import type { Model } from "@nozbe/watermelondb";

import { database, folderCollection, quickNoteCollection } from "../database";
import type { Folder as FolderModel } from "../models/Folder";
import type { QuickNote as QuickNoteModel } from "../models/QuickNote";

export type Subscription = { unsubscribe: () => void };

export type Observer<T> =
  | ((value: T) => void)
  | {
      next?: (value: T) => void;
      error?: (e: unknown) => void;
      complete?: () => void;
    };

export interface Observable<T> {
  subscribe(observer: Observer<T>): Subscription;
}

const mapObservable = <T, U>(source: Observable<T>, mapper: (v: T) => U) => ({
  subscribe(observer: Observer<U>): Subscription {
    if (typeof observer === "function")
      return source.subscribe((value) => observer(mapper(value)));
    return source.subscribe({
      next: observer.next
        ? (value) => observer.next!(mapper(value))
        : undefined,
      error: observer.error,
      complete: observer.complete,
    });
  },
});

const mapFolder = (r: FolderModel) => ({
  id: r.id,
  name: r.name,
  color: r.color,
  icon: r.icon ?? undefined,
  isDefault: !!r.isDefault,
  sortOrder: typeof r.sortOrder === "number" ? r.sortOrder : 0,
  createdAt: new Date(r.createdAt).toISOString(),
  updatedAt: new Date(r.updatedAt).toISOString(),
});

const mapQuickNote = (r: QuickNoteModel) => ({
  id: r.id,
  content: r.content,
  tags: r.tags,
  isPinned: !!r.isPinned,
  sortOrder: r.sortOrder,
  folder: undefined as any,
  folderId: r.folderId,
  createdAt: new Date(r.createdAt).toISOString(),
  updatedAt: new Date(r.updatedAt).toISOString(),
});

export const getAllFolders = async () => {
  const records = await folderCollection
    .query(Q.sortBy("created_at", Q.asc))
    .fetch();
  return records.map(mapFolder);
};

export const createFolder = async (input: { name: string; color?: string }) => {
  let id = "";
  await database.write(async () => {
    const rec = await folderCollection.create((r: Model) => {
      const raw: any = r._raw;
      raw.id = (Math.random() + 1).toString(36).substring(2);
      raw.name = input.name;
      raw.color = input.color ?? null;
      const ts = Date.now();
      raw.created_at = ts;
      raw.updated_at = ts;
    });
    id = rec.id;
  });

  return id;
};

export const updateFolder = async (
  id: string,
  updates: Partial<{ name: string; color: string }>
) => {
  const rec = await folderCollection.find(id);
  const ts = Date.now();
  await database.write(async () => {
    await rec.update((m: Model) => {
      const raw: any = m._raw;
      if (updates.name !== undefined) raw.name = updates.name;
      if (updates.color !== undefined) raw.color = updates.color;
      raw.updated_at = ts;
    });
  });
};

export const deleteFolder = async (id: string) => {
  const rec = await folderCollection.find(id);
  await database.write(async () => {
    await rec.markAsDeleted();
  });
};

export const getAllQuickNotes = async () => {
  const records = await quickNoteCollection
    .query(Q.sortBy("updated_at", Q.desc))
    .fetch();
  return records.map(mapQuickNote);
};

export const getQuickNotesByFolder = async (folderId: string) => {
  const records = await quickNoteCollection
    .query(Q.where("folder_id", folderId))
    .fetch();
  return records.map(mapQuickNote);
};

export const observeQuickNotesByFolder = (folderId: string) =>
  mapObservable(
    quickNoteCollection.query(Q.where("folder_id", folderId)).observe(),
    (records: QuickNoteModel[]) => records.map(mapQuickNote)
  );

export const createQuickNote = async (input: {
  title?: string;
  body?: string;
  folderId?: string;
}) => {
  let id = "";
  await database.write(async () => {
    const rec = await quickNoteCollection.create((r: Model) => {
      const raw: any = r._raw;
      raw.id = (Math.random() + 1).toString(36).substring(2);
      raw.content = input.title ?? null;
      raw.body = input.body ?? null;
      raw.folder_id = input.folderId ?? null;
      const ts = Date.now();
      raw.created_at = ts;
      raw.updated_at = ts;
    });
    id = rec.id;
  });

  return id;
};

export const updateQuickNote = async (
  id: string,
  updates: Partial<{ title: string; body: string; folderId: string }>
) => {
  const rec = await quickNoteCollection.find(id);
  const ts = Date.now();
  await database.write(async () => {
    await rec.update((m: Model) => {
      const raw: any = m._raw;
      if (updates.title !== undefined) raw.content = updates.title;
      if (updates.body !== undefined) raw.body = updates.body;
      if (updates.folderId !== undefined) raw.folder_id = updates.folderId;
      raw.updated_at = ts;
    });
  });
};

export const deleteQuickNote = async (id: string) => {
  const rec = await quickNoteCollection.find(id);
  await database.write(async () => {
    await rec.markAsDeleted();
  });
};

export default {
  getAllFolders,
  createFolder,
  updateFolder,
  deleteFolder,
  getAllQuickNotes,
  getQuickNotesByFolder,
  observeQuickNotesByFolder,
  createQuickNote,
  updateQuickNote,
  deleteQuickNote,
};
