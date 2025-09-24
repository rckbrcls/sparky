import { Model, Query } from "@nozbe/watermelondb";
import { children, field, text } from "@nozbe/watermelondb/decorators";

import type { Reminder } from "@/src/features/timeline/models/Reminder";
import type { QuickNote } from "./QuickNote";

export class Folder extends Model {
  static table = "folders";

  static associations = {
    reminders: { type: "has_many", foreignKey: "folder_id" } as const,
    quick_notes: { type: "has_many", foreignKey: "folder_id" } as const,
  };

  @text("name")
  name!: string;

  @text("color")
  color!: string;

  @text("icon")
  icon!: string;

  @field("is_default")
  isDefault!: boolean;

  @field("sort_order")
  sortOrder!: number;

  @field("created_at")
  createdAt!: number;

  @field("updated_at")
  updatedAt!: number;

  @children("reminders")
  reminders!: Query<Reminder>;

  @children("quick_notes")
  quickNotes!: Query<QuickNote>;
}
