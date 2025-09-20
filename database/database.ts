import { databaseApi } from "../db";

export const database: any = databaseApi as any;

export type {
  Folder,
  QuickNote,
  Reminder,
  Trigger,
} from "../repositories/types";

export default database;
