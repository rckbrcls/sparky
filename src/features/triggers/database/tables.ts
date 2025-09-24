import { tableSchema } from "@nozbe/watermelondb";

export const triggersTables = [
  tableSchema({
    name: "triggers",
    columns: [
      { name: "reminder_id", type: "string", isIndexed: true },
      { name: "type", type: "string", isIndexed: true },
      { name: "config", type: "string" },
      { name: "is_active", type: "boolean", isIndexed: true },
      { name: "created_at", type: "number" },
      { name: "updated_at", type: "number" },
    ],
  }),
];
