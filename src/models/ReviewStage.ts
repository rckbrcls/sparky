import { Model, Relation } from '@nozbe/watermelondb';
import { field, relation } from '@nozbe/watermelondb/decorators';

import type { Reminder } from './Reminder';

export class ReviewStage extends Model {
  static table = 'review_stages';

  static associations = {
    reminders: { type: 'belongs_to', key: 'reminder_id' } as const,
  };

  @field('reminder_id')
  reminderId!: string;

  @field('current_stage')
  currentStage!: number;

  @field('last_review_at')
  lastReviewAt!: number;

  @field('ignore_count')
  ignoreCount!: number;

  @field('created_at')
  createdAt!: number;

  @field('updated_at')
  updatedAt!: number;

  @relation('reminders', 'reminder_id')
  reminder!: Relation<Reminder>;
}
