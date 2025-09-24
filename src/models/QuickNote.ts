import { Model, Relation } from "@nozbe/watermelondb";
import { field, relation, text } from "@nozbe/watermelondb/decorators";

import type { Folder } from "./Folder";

export class QuickNote extends Model {
  static table = "quick_notes";

  static associations = {
    folders: { type: "belongs_to", key: "folder_id" } as const,
  };

  @text("content")
  content!: string;

  @field("folder_id")
  folderId!: string | null;

  @field("tags")
  tags!: string;

  @field("is_pinned")
  isPinned!: boolean;

  @field("sort_order")
  sortOrder!: number | null;

  @field("created_at")
  createdAt!: number;

  @field("updated_at")
  updatedAt!: number;

  @relation("folders", "folder_id")
  folder!: Relation<Folder>;
}
