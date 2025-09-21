import { Database } from "@nozbe/watermelondb";
import SQLiteAdapter from "@nozbe/watermelondb/adapters/sqlite";

import { schema } from "./schema";
import { Reminder } from "../models/Reminder";
import { SnoozeHistory } from "../models/SnoozeHistory";
import { ImportantDate } from "../models/ImportantDate";
import { ReviewStage } from "../models/ReviewStage";
import { Folder } from "../models/Folder";
import { Trigger } from "../models/Trigger";
import { QuickNote } from "../models/QuickNote";

// Lazy-load repositories to avoid require cycles.
const loadRemindersRepo = (): typeof import("../repositories/reminders") =>
  require("../repositories/reminders");
const loadNotesFoldersRepo =
  (): typeof import("../repositories/notes_and_folders") =>
    require("../repositories/notes_and_folders");

const adapter = new SQLiteAdapter({
  schema,
  dbName: "reminders",
  jsi: false,
  onSetUpError(error) {
    console.error("Failed to set up WatermelonDB adapter", error);
  },
});

const dbInstance = new Database({
  adapter,
  modelClasses: [
    Reminder,
    SnoozeHistory,
    ImportantDate,
    ReviewStage,
    Folder,
    Trigger,
    QuickNote,
  ],
});

export const reminderCollection = dbInstance.get<Reminder>("reminders");
export const snoozeHistoryCollection =
  dbInstance.get<SnoozeHistory>("snooze_history");
export const importantDateCollection =
  dbInstance.get<ImportantDate>("important_dates");
export const reviewStageCollection =
  dbInstance.get<ReviewStage>("review_stages");
export const folderCollection = dbInstance.get<Folder>("folders");
export const triggerCollection = dbInstance.get<Trigger>("triggers");
export const quickNoteCollection = dbInstance.get<QuickNote>("quick_notes");

const getDayBounds = (date: Date): { startTs: number; endTs: number } => {
  const start = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  const end = new Date(date.getFullYear(), date.getMonth(), date.getDate() + 1);

  return {
    startTs: start.getTime(),
    endTs: end.getTime(),
  };
};

const tsNow = (): number => Date.now();

export const databaseApi = {
  initialize: async (): Promise<void> => {
    // place for any default setup (folders etc.) if needed later
    return Promise.resolve();
  },

  // reminders (lazy-loaded)
  getAllReminders: (...args: any[]) => {
    const r = loadRemindersRepo() as any;
    return r.getAllReminders.apply(r, args);
  },
  getReminderById: (...args: any[]) => {
    const r = loadRemindersRepo() as any;
    return r.getReminderById.apply(r, args);
  },
  createReminder: (...args: any[]) => {
    const r = loadRemindersRepo() as any;
    return r.createReminder.apply(r, args);
  },
  updateReminder: (...args: any[]) => {
    const r = loadRemindersRepo() as any;
    return r.updateReminder.apply(r, args);
  },
  deleteReminder: (...args: any[]) => {
    const r = loadRemindersRepo() as any;
    return r.deleteReminder.apply(r, args);
  },
  observeAllReminders: (...args: any[]) => {
    const r = loadRemindersRepo() as any;
    return r.observeAllReminders.apply(r, args);
  },
  observeTodayReminders: () => {
    const { startTs, endTs } = getDayBounds(new Date());
    return loadRemindersRepo().observeTodayReminders(startTs, endTs);
  },
  observeOverdueReminders: () =>
    loadRemindersRepo().observeOverdueReminders(tsNow()),
  observeUpcomingReminders: () =>
    loadRemindersRepo().observeUpcomingReminders(tsNow()),
  getOverdueReminders: () => loadRemindersRepo().getOverdueReminders(tsNow()),
  getUpcomingReminders: () => loadRemindersRepo().getUpcomingReminders(tsNow()),
  getSnoozeHistoryForReminder: (...args: any[]) => {
    const r = loadRemindersRepo() as any;
    return r.getSnoozeHistoryForReminder.apply(r, args);
  },
  createSnoozeHistory: (...args: any[]) => {
    const r = loadRemindersRepo() as any;
    return r.createSnoozeHistory.apply(r, args);
  },
  createReviewStage: (...args: any[]) => {
    const r = loadRemindersRepo() as any;
    return r.createReviewStage.apply(r, args);
  },
  updateReviewStage: (...args: any[]) => {
    const r = loadRemindersRepo() as any;
    return r.updateReviewStage.apply(r, args);
  },
  getReviewStageForReminder: (...args: any[]) => {
    const r = loadRemindersRepo() as any;
    return r.getReviewStageForReminder.apply(r, args);
  },
  getRemindersByPersonOrProject: (...args: any[]) => {
    const r = loadRemindersRepo() as any;
    return r.getRemindersByPersonOrProject.apply(r, args);
  },
  getRemindersWithFolders: (...args: any[]) => {
    const r = loadRemindersRepo() as any;
    return r.getRemindersWithFolders.apply(r, args);
  },
  getActiveTriggers: (...args: any[]) => {
    const r = loadRemindersRepo() as any;
    return r.getActiveTriggers.apply(r, args);
  },
  createTrigger: (...args: any[]) => {
    const r = loadRemindersRepo() as any;
    return r.createTrigger.apply(r, args);
  },
  createImportantDate: (...args: any[]) => {
    const r = loadRemindersRepo() as any;
    return r.createImportantDate.apply(r, args);
  },
  getTodayReminders: () => {
    const { startTs, endTs } = getDayBounds(new Date());
    return loadRemindersRepo().getTodayReminders(startTs, endTs);
  },

  // folders + quick notes (lazy-loaded)
  getAllFolders: (...args: any[]) => {
    const r = loadNotesFoldersRepo() as any;
    return r.getAllFolders.apply(r, args);
  },
  createFolder: (...args: any[]) => {
    const r = loadNotesFoldersRepo() as any;
    return r.createFolder.apply(r, args);
  },
  updateFolder: (...args: any[]) => {
    const r = loadNotesFoldersRepo() as any;
    return r.updateFolder.apply(r, args);
  },
  deleteFolder: (...args: any[]) => {
    const r = loadNotesFoldersRepo() as any;
    return r.deleteFolder.apply(r, args);
  },
  getAllQuickNotes: (...args: any[]) => {
    const r = loadNotesFoldersRepo() as any;
    return r.getAllQuickNotes.apply(r, args);
  },
  getQuickNotesByFolder: (...args: any[]) => {
    const r = loadNotesFoldersRepo() as any;
    return r.getQuickNotesByFolder.apply(r, args);
  },
  observeQuickNotesByFolder: (...args: any[]) => {
    const r = loadNotesFoldersRepo() as any;
    return r.observeQuickNotesByFolder.apply(r, args);
  },
  createQuickNote: (...args: any[]) => {
    const r = loadNotesFoldersRepo() as any;
    return r.createQuickNote.apply(r, args);
  },
  updateQuickNote: (...args: any[]) => {
    const r = loadNotesFoldersRepo() as any;
    return r.updateQuickNote.apply(r, args);
  },
  deleteQuickNote: (...args: any[]) => {
    const r = loadNotesFoldersRepo() as any;
    return r.deleteQuickNote.apply(r, args);
  },
  updateQuickNotesSortOrder: (...args: any[]) => {
    const r = loadNotesFoldersRepo() as any;
    return r.updateQuickNotesSortOrder.apply(r, args);
  },
  exportData: async () => {
    // Minimal export: gather reminders, folders, quick notes and triggers
    const reminders = await loadRemindersRepo().getAllReminders();
    const folders = await loadNotesFoldersRepo().getAllFolders();
    const quickNotes = await loadNotesFoldersRepo().getAllQuickNotes();
    const triggers = await loadRemindersRepo().getActiveTriggers();
    return { reminders, folders, quickNotes, triggers };
  },
  importData: async (data: any) => {
    // import is not implemented; placeholder to avoid runtime errors
    console.warn("database.importData called - not implemented");
    return Promise.resolve();
  },
};

export {
  Reminder,
  SnoozeHistory,
  ImportantDate,
  ReviewStage,
  Folder,
  Trigger,
  QuickNote,
};

// Export `database` as the high-level API expected across the app
// Build a `database` object that exposes both WatermelonDB instance methods
// and our higher-level API. This keeps existing call sites working which
// expect `database.get(...)`, `database.write(...)`, etc.
// Attach high-level API methods onto the WatermelonDB instance so that
// prototype methods (like `get`, `write`, etc.) remain available.
const dbWithApi: any = dbInstance as any;
Object.keys(databaseApi).forEach((k) => {
  // @ts-ignore: assign api methods onto the instance
  dbWithApi[k] = (databaseApi as any)[k];
});

export const database: typeof dbInstance & typeof databaseApi = dbWithApi;
