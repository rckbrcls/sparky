import { Model } from '@nozbe/watermelondb';
import { field, text } from '@nozbe/watermelondb/decorators';

export class ImportantDate extends Model {
  static table = 'important_dates';

  static associations = {};

  @text('title')
  title!: string;

  @field('description')
  description!: string | null;

  @field('date')
  date!: number;

  @text('type')
  type!: string;

  @field('person')
  person!: string | null;

  @field('lead_times')
  leadTimes!: string;

  @field('created_at')
  createdAt!: number;

  @field('updated_at')
  updatedAt!: number;
}
