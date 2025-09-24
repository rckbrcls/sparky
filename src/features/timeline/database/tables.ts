import { tableSchema } from "@nozbe/watermelondb";

export const timelineTables = [
  tableSchema({
    name: "reminders",
    columns: [
      { name: "title", type: "string" },
      { name: "notes", type: "string", isOptional: true },
      { name: "person", type: "string", isOptional: true, isIndexed: true },
      { name: "project", type: "string", isOptional: true, isIndexed: true },
      { name: "location", type: "string", isOptional: true },
      { name: "type", type: "string" },
      { name: "rrule", type: "string", isOptional: true },
      {
        name: "next_fire_at",
        type: "number",
        isOptional: true,
        isIndexed: true,
      },
      { name: "status", type: "string", isIndexed: true },
      { name: "completed_at", type: "number", isOptional: true },
      { name: "notification_id", type: "string", isOptional: true },
      {
        name: "folder_id",
        type: "string",
        isOptional: true,
        isIndexed: true,
      },
      { name: "tags", type: "string", isOptional: true },
      { name: "priority", type: "number" },
      { name: "created_at", type: "number" },
      { name: "updated_at", type: "number" },
    ],
  }),
  tableSchema({
    name: "snooze_history",
    columns: [
      { name: "reminder_id", type: "string", isIndexed: true },
      { name: "snooze_count", type: "number" },
      { name: "original_fire_at", type: "number" },
      { name: "new_fire_at", type: "number" },
      { name: "created_at", type: "number" },
    ],
  }),
  tableSchema({
    name: "important_dates",
    columns: [
      { name: "title", type: "string" },
      { name: "description", type: "string", isOptional: true },
      { name: "date", type: "number" },
      { name: "type", type: "string" },
      { name: "person", type: "string", isOptional: true },
      { name: "lead_times", type: "string" },
      { name: "created_at", type: "number" },
      { name: "updated_at", type: "number" },
    ],
  }),
  tableSchema({
    name: "review_stages",
    columns: [
      { name: "reminder_id", type: "string", isIndexed: true },
      { name: "current_stage", type: "number" },
      { name: "last_review_at", type: "number" },
      { name: "ignore_count", type: "number" },
      { name: "created_at", type: "number" },
      { name: "updated_at", type: "number" },
    ],
  }),
];
