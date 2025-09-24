import { Model, Relation } from "@nozbe/watermelondb";
import { field, relation, text } from "@nozbe/watermelondb/decorators";

import type { Reminder } from "@/src/features/timeline/models/Reminder";

export class Trigger extends Model {
  static table = "triggers";

  static associations = {
    reminders: { type: "belongs_to", key: "reminder_id" } as const,
  };

  @field("reminder_id")
  reminderId!: string;

  @text("type")
  type!: string;

  @field("config")
  config!: string;

  @field("is_active")
  isActive!: boolean;

  @field("created_at")
  createdAt!: number;

  @field("updated_at")
  updatedAt!: number;

  @relation("reminders", "reminder_id")
  reminder!: Relation<Reminder>;
}
