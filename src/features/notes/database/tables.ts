import { tableSchema } from "@nozbe/watermelondb";

export const notesTables = [
  tableSchema({
    name: "folders",
    columns: [
      { name: "name", type: "string" },
      { name: "color", type: "string" },
      { name: "icon", type: "string" },
      { name: "is_default", type: "boolean" },
      { name: "sort_order", type: "number" },
      { name: "created_at", type: "number" },
      { name: "updated_at", type: "number" },
    ],
  }),
  tableSchema({
    name: "quick_notes",
    columns: [
      { name: "content", type: "string", isIndexed: true },
      {
        name: "folder_id",
        type: "string",
        isOptional: true,
        isIndexed: true,
      },
      { name: "tags", type: "string" },
      { name: "is_pinned", type: "boolean" },
      { name: "sort_order", type: "number", isOptional: true },
      { name: "created_at", type: "number" },
      { name: "updated_at", type: "number" },
    ],
  }),
];
