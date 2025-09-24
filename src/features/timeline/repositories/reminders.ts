import uuid from "react-native-uuid";
import { Q } from "@nozbe/watermelondb";
import type { Model } from "@nozbe/watermelondb";

import { database, reminderCollection } from "@/src/database";
import * as notesFoldersRepo from "@/src/features/notes/repositories/notesAndFolders";
import type { Reminder as ReminderModel } from "@/src/features/timeline/models/Reminder";
import type { Reminder as ReminderDTO } from "../types";

export type Subscription = { unsubscribe: () => void };

export type Observer<T> =
  | ((value: T) => void)
  | {
      next?: (value: T) => void;
      error?: (error: unknown) => void;
      complete?: () => void;
    };

export interface Observable<T> {
  subscribe(observer: Observer<T>): Subscription;
}

const nowTimestamp = (): number => Date.now();

const toNullableTimestamp = (value?: number | null): number | null =>
  value ?? null;

const optionalTimestamp = (
  value: number | null | undefined
): number | null | undefined => {
  if (value === undefined) return undefined;
  return value ?? null;
};

const mapObservable = <T, U>(source: Observable<T>, mapper: (v: T) => U) => ({
  subscribe(observer: Observer<U>): Subscription {
    if (typeof observer === "function") {
      return source.subscribe((value) => observer(mapper(value)));
    }

    return source.subscribe({
      next: observer.next
        ? (value) => {
            observer.next!(mapper(value));
          }
        : undefined,
      error: observer.error,
      complete: observer.complete,
    });
  },
});

const mapReminderModelToDomain = (record: ReminderModel): ReminderDTO => ({
  id: record.id,
  title: record.title,
  notes: record.notes,
  person: record.person,
  project: record.project,
  location: record.location,
  type: record.type,
  rrule: record.rrule,
  nextFireAt: record.nextFireAt
    ? new Date(record.nextFireAt).toISOString()
    : null,
  status: record.status as ReminderDTO["status"],
  completedAt: record.completedAt
    ? new Date(record.completedAt).toISOString()
    : null,
  notificationId: record.notificationId,
  folderId: record.folderId,
  tags: record.tags ?? null,
  priority: record.priority,
  createdAt: new Date(record.createdAt).toISOString(),
  updatedAt: new Date(record.updatedAt).toISOString(),
});

const mapReminderList = (records: ReminderModel[]) =>
  records.map(mapReminderModelToDomain);

const toReminderObservable = (
  query: ReturnType<typeof reminderCollection.query>
): Observable<ReturnType<typeof mapReminderList>> =>
  mapObservable(query.observe(), mapReminderList as any);

export const observeAllReminders = (): Observable<any[]> =>
  toReminderObservable(
    reminderCollection.query(Q.sortBy("next_fire_at", Q.asc))
  );

export const observeTodayReminders = (dayStartTs: number, dayEndTs: number) =>
  toReminderObservable(
    reminderCollection.query(
      Q.where("status", "active"),
      Q.where("next_fire_at", Q.between(dayStartTs, dayEndTs - 1)),
      Q.sortBy("next_fire_at", Q.asc)
    )
  );

export const observeOverdueReminders = (nowTs: number) =>
  toReminderObservable(
    reminderCollection.query(
      Q.where("status", "active"),
      Q.where("next_fire_at", Q.lt(nowTs)),
      Q.sortBy("next_fire_at", Q.asc)
    )
  );

export const observeUpcomingReminders = (nowTs: number) =>
  toReminderObservable(
    reminderCollection.query(
      Q.where("status", "active"),
      Q.where("next_fire_at", Q.gt(nowTs)),
      Q.sortBy("next_fire_at", Q.asc)
    )
  );

export const getAllReminders = async () => {
  const records = await reminderCollection
    .query(Q.sortBy("next_fire_at", Q.asc))
    .fetch();
  return mapReminderList(records);
};

export const getReminderById = async (id: string) => {
  const record = await reminderCollection.find(id).catch(() => null);
  return record ? mapReminderModelToDomain(record) : null;
};

export const getTodayReminders = async (
  dayStartTs: number,
  dayEndTs: number
) => {
  const records = await reminderCollection
    .query(
      Q.where("status", "active"),
      Q.where("next_fire_at", Q.between(dayStartTs, dayEndTs - 1)),
      Q.sortBy("next_fire_at", Q.asc)
    )
    .fetch();

  return mapReminderList(records);
};

export const getOverdueReminders = async (nowTs: number) => {
  const records = await reminderCollection
    .query(
      Q.where("status", "active"),
      Q.where("next_fire_at", Q.lt(nowTs)),
      Q.sortBy("next_fire_at", Q.asc)
    )
    .fetch();

  return mapReminderList(records);
};

export const getUpcomingReminders = async (nowTs: number) => {
  const records = await reminderCollection
    .query(
      Q.where("status", "active"),
      Q.where("next_fire_at", Q.gt(nowTs)),
      Q.sortBy("next_fire_at", Q.asc)
    )
    .fetch();

  return mapReminderList(records);
};

export const createReminder = async (input: any): Promise<string> => {
  const reminderId = uuid.v4() as string;
  const timestamp = nowTimestamp();

  await database.write(async () => {
    await reminderCollection.create((record: Model) => {
      const raw: any = record._raw;
      raw.id = reminderId;
      raw.title = input.title;
      raw.notes = input.notes ?? null;
      raw.person = input.person ?? null;
      raw.project = input.project ?? null;
      raw.location = input.location ?? null;
      raw.type = input.type ?? "single";
      raw.rrule = input.rrule ?? null;
      raw.next_fire_at = toNullableTimestamp(input.nextFireAt);
      raw.status = input.status ?? "active";
      raw.completed_at = toNullableTimestamp(input.completedAt);
      raw.notification_id = input.notificationId ?? null;
      raw.folder_id = input.folderId ?? null;
      raw.tags = Array.isArray(input.tags) ? input.tags.join(",") : null;
      raw.priority = input.priority ?? 1;
      raw.created_at = timestamp;
      raw.updated_at = timestamp;
    });
  });

  return reminderId;
};

export const updateReminder = async (id: string, updates: Partial<any>) => {
  const record = await reminderCollection.find(id);
  const timestamp = nowTimestamp();

  await database.write(async () => {
    await record.update((mutableRecord: Model) => {
      const raw: any = mutableRecord._raw;
      if (updates.title !== undefined) raw.title = updates.title;
      if (updates.notes !== undefined) raw.notes = updates.notes;
      if (updates.person !== undefined) raw.person = updates.person;
      if (updates.project !== undefined) raw.project = updates.project;
      if (updates.location !== undefined) raw.location = updates.location;
      if (updates.type !== undefined) raw.type = updates.type;
      if (updates.rrule !== undefined) raw.rrule = updates.rrule;
      if (updates.nextFireAt !== undefined)
        raw.next_fire_at = optionalTimestamp(updates.nextFireAt);
      if (updates.status !== undefined) raw.status = updates.status;
      if (updates.completedAt !== undefined)
        raw.completed_at = optionalTimestamp(updates.completedAt);
      if (updates.notificationId !== undefined)
        raw.notification_id = updates.notificationId;
      if (updates.folderId !== undefined) raw.folder_id = updates.folderId;
      if (updates.tags !== undefined)
        raw.tags = Array.isArray(updates.tags)
          ? updates.tags.join(",")
          : updates.tags;
      if (updates.priority !== undefined) raw.priority = updates.priority;
      raw.updated_at = timestamp;
    });
  });
};

export const deleteReminder = async (id: string) => {
  const record = await reminderCollection.find(id);
  await database.write(async () => {
    await record.markAsDeleted();
  });
};

export const getSnoozeHistoryForReminder = async (reminderId: string) => {
  const records = await database
    .get("snooze_history")
    .query(Q.where("reminder_id", reminderId))
    .fetch()
    .catch(() => [] as any[]);

  return records.map((r: any) => ({
    id: r.id,
    reminderId: r.reminderId ?? r.reminder_id,
    snoozeCount: r.snoozeCount ?? r.snooze_count,
    originalFireAt: r.originalFireAt ?? r.original_fire_at,
    newFireAt: r.newFireAt ?? r.new_fire_at,
    createdAt: r.createdAt ?? r.created_at,
  }));
};

export const createSnoozeHistory = async (input: {
  reminderId: string;
  snoozeCount: number;
  originalFireAt: string;
  newFireAt: string;
}) => {
  let id = "";
  await database.write(async () => {
    const rec = await database.get("snooze_history").create((r: Model) => {
      const raw: any = r._raw;
      raw.id = (Math.random() + 1).toString(36).substring(2);
      raw.reminder_id = input.reminderId;
      raw.snooze_count = input.snoozeCount;
      raw.original_fire_at = input.originalFireAt;
      raw.new_fire_at = input.newFireAt;
      raw.created_at = Date.now();
    });
    id = rec.id;
  });

  return id;
};

export const createReviewStage = async (input: {
  reminderId: string;
  currentStage: number;
  lastReviewAt: string;
  ignoreCount: number;
}) => {
  let id = "";
  await database.write(async () => {
    const rec = await database.get("review_stages").create((r: Model) => {
      const raw: any = r._raw;
      raw.id = (Math.random() + 1).toString(36).substring(2);
      raw.reminder_id = input.reminderId;
      raw.current_stage = input.currentStage;
      raw.last_review_at = input.lastReviewAt;
      raw.ignore_count = input.ignoreCount;
      raw.created_at = Date.now();
      raw.updated_at = Date.now();
    });
    id = rec.id;
  });

  return id;
};

export const getReviewStageForReminder = async (reminderId: string) => {
  const records = await database
    .get("review_stages")
    .query(Q.where("reminder_id", reminderId))
    .fetch()
    .catch(() => [] as any[]);

  if (records.length === 0) return null;
  const r: any = records[0];
  return {
    id: r.id,
    reminderId: r.reminderId ?? r.reminder_id,
    currentStage: r.currentStage ?? r.current_stage,
    lastReviewAt: r.lastReviewAt ?? r.last_review_at,
    ignoreCount: r.ignoreCount ?? r.ignore_count,
    createdAt: r.createdAt ?? r.created_at,
    updatedAt: r.updatedAt ?? r.updated_at,
  };
};

export const updateReviewStage = async (
  reminderId: string,
  updates: Partial<any>
) => {
  const records = await database
    .get("review_stages")
    .query(Q.where("reminder_id", reminderId))
    .fetch()
    .catch(() => [] as any[]);

  if (records.length === 0) return;
  const rec = records[0];
  const ts = Date.now();
  await database.write(async () => {
    await rec.update((m: Model) => {
      const raw: any = m._raw;
      if (updates.currentStage !== undefined)
        raw.current_stage = updates.currentStage;
      if (updates.lastReviewAt !== undefined)
        raw.last_review_at = updates.lastReviewAt;
      if (updates.ignoreCount !== undefined)
        raw.ignore_count = updates.ignoreCount;
      raw.updated_at = ts;
    });
  });
};

export const getRemindersByPersonOrProject = async (filter: string) => {
  const records = await reminderCollection
    .query(
      Q.where("status", "active"),
      Q.or(Q.where("person", filter), Q.where("project", filter)),
      Q.sortBy("next_fire_at", Q.asc)
    )
    .fetch();

  return mapReminderList(records);
};

export const getRemindersWithFolders = async () => {
  const reminders = await getAllReminders();
  const folders = await notesFoldersRepo
    .getAllFolders()
    .catch(() => [] as any[]);

  const folderMap = (folders || []).reduce((acc: any, f: any) => {
    acc[f.id] = f;
    return acc;
  }, {} as Record<string, any>);

  return reminders.map((r: any) => ({
    ...r,
    folder: r.folderId ? folderMap[r.folderId] : undefined,
  }));
};

export const createImportantDate = async (input: {
  title: string;
  description?: string | null;
  date: string;
  type: string;
  person?: string | null;
  leadTimes: string;
}) => {
  let id = "";
  await database.write(async () => {
    const rec = await database.get("important_dates").create((r: Model) => {
      const raw: any = r._raw;
      raw.id = (Math.random() + 1).toString(36).substring(2);
      raw.title = input.title;
      raw.description = input.description ?? null;
      raw.date = input.date;
      raw.type = input.type;
      raw.person = input.person ?? null;
      raw.lead_times = input.leadTimes;
      raw.created_at = Date.now();
      raw.updated_at = Date.now();
    });
    id = rec.id;
  });

  return id;
};

export default {
  observeAllReminders,
  observeTodayReminders,
  observeOverdueReminders,
  observeUpcomingReminders,
  getAllReminders,
  getReminderById,
  getTodayReminders,
  getOverdueReminders,
  getUpcomingReminders,
  createReminder,
  updateReminder,
  deleteReminder,
};
