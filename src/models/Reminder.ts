import { Model, Query, Relation } from '@nozbe/watermelondb';
import { children, field, relation, text } from '@nozbe/watermelondb/decorators';

import type { ReviewStage } from './ReviewStage';
import type { SnoozeHistory } from './SnoozeHistory';
import type { Trigger } from './Trigger';
import type { Folder } from './Folder';

export class Reminder extends Model {
  static table = 'reminders';

  static associations = {
    folders: { type: 'belongs_to', key: 'folder_id' } as const,
    triggers: { type: 'has_many', foreignKey: 'reminder_id' } as const,
    snooze_history: { type: 'has_many', foreignKey: 'reminder_id' } as const,
    review_stages: { type: 'has_many', foreignKey: 'reminder_id' } as const,
  };

  @text('title')
  title!: string;

  @field('notes')
  notes!: string | null;

  @field('person')
  person!: string | null;

  @field('project')
  project!: string | null;

  @field('location')
  location!: string | null;

  @text('type')
  type!: string;

  @field('rrule')
  rrule!: string | null;

  @field('next_fire_at')
  nextFireAt!: number | null;

  @text('status')
  status!: string;

  @field('completed_at')
  completedAt!: number | null;

  @field('notification_id')
  notificationId!: string | null;

  @field('folder_id')
  folderId!: string | null;

  @field('tags')
  tags!: string | null;

  @field('priority')
  priority!: number;

  @field('created_at')
  createdAt!: number;

  @field('updated_at')
  updatedAt!: number;

  @relation('folders', 'folder_id')
  folder!: Relation<Folder>;

  @children('triggers')
  triggers!: Query<Trigger>;

  @children('snooze_history')
  snoozeHistory!: Query<SnoozeHistory>;

  @relation('review_stages', 'reminder_id')
  reviewStage!: Relation<ReviewStage>;
}
