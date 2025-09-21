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

import * as remindersRepo from "../repositories/reminders";
import * as notesFoldersRepo from "../repositories/notes_and_folders";

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

  // reminders
  getAllReminders: remindersRepo.getAllReminders,
  getReminderById: remindersRepo.getReminderById,
  createReminder: remindersRepo.createReminder,
  updateReminder: remindersRepo.updateReminder,
  deleteReminder: remindersRepo.deleteReminder,
  observeAllReminders: remindersRepo.observeAllReminders,
  observeTodayReminders: () => {
    const { startTs, endTs } = getDayBounds(new Date());
    return remindersRepo.observeTodayReminders(startTs, endTs);
  },
  observeOverdueReminders: () => remindersRepo.observeOverdueReminders(tsNow()),
  observeUpcomingReminders: () =>
    remindersRepo.observeUpcomingReminders(tsNow()),
  getOverdueReminders: () => remindersRepo.getOverdueReminders(tsNow()),
  getUpcomingReminders: () => remindersRepo.getUpcomingReminders(tsNow()),
  getSnoozeHistoryForReminder: remindersRepo.getSnoozeHistoryForReminder,
  createSnoozeHistory: remindersRepo.createSnoozeHistory,
  createReviewStage: remindersRepo.createReviewStage,
  updateReviewStage: remindersRepo.updateReviewStage,
  getReviewStageForReminder: remindersRepo.getReviewStageForReminder,
  getRemindersByPersonOrProject: remindersRepo.getRemindersByPersonOrProject,
  getRemindersWithFolders: remindersRepo.getRemindersWithFolders,
  getActiveTriggers: remindersRepo.getActiveTriggers,
  createTrigger: remindersRepo.createTrigger,
  createImportantDate: remindersRepo.createImportantDate,
  getTodayReminders: () => {
    const { startTs, endTs } = getDayBounds(new Date());
    return remindersRepo.getTodayReminders(startTs, endTs);
  },

  // folders + quick notes
  getAllFolders: notesFoldersRepo.getAllFolders,
  createFolder: notesFoldersRepo.createFolder,
  updateFolder: notesFoldersRepo.updateFolder,
  deleteFolder: notesFoldersRepo.deleteFolder,
  getAllQuickNotes: notesFoldersRepo.getAllQuickNotes,
  getQuickNotesByFolder: notesFoldersRepo.getQuickNotesByFolder,
  observeQuickNotesByFolder: notesFoldersRepo.observeQuickNotesByFolder,
  createQuickNote: notesFoldersRepo.createQuickNote,
  updateQuickNote: notesFoldersRepo.updateQuickNote,
  deleteQuickNote: notesFoldersRepo.deleteQuickNote,
  updateQuickNotesSortOrder: notesFoldersRepo.updateQuickNotesSortOrder,
  exportData: async () => {
    // Minimal export: gather reminders, folders, quick notes and triggers
    const reminders = await remindersRepo.getAllReminders();
    const folders = await notesFoldersRepo.getAllFolders();
    const quickNotes = await notesFoldersRepo.getAllQuickNotes();
    const triggers = await remindersRepo.getActiveTriggers();
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
