import { Model, Relation } from "@nozbe/watermelondb";
import { field, relation } from "@nozbe/watermelondb/decorators";

import type { Reminder } from "./Reminder";

export class SnoozeHistory extends Model {
  static table = "snooze_history";

  static associations = {
    reminders: { type: "belongs_to", key: "reminder_id" } as const,
  };

  @field("reminder_id")
  reminderId!: string;

  @field("snooze_count")
  snoozeCount!: number;

  @field("original_fire_at")
  originalFireAt!: number;

  @field("new_fire_at")
  newFireAt!: number;

  @field("created_at")
  createdAt!: number;

  @relation("reminders", "reminder_id")
  reminder!: Relation<Reminder>;
}
