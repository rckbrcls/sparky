import { appSchema } from "@nozbe/watermelondb";

import { notesTables } from "@/src/features/notes/database/tables";
import { timelineTables } from "@/src/features/timeline/database/tables";
import { triggersTables } from "@/src/features/triggers/database/tables";

export const schema = appSchema({
  version: 2,
  tables: [...timelineTables, ...triggersTables, ...notesTables],
});

export type Schema = typeof schema;
