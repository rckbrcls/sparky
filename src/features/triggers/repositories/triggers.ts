import { Q } from "@nozbe/watermelondb";
import type { Model } from "@nozbe/watermelondb";

import { database } from "@/src/database";

export const getActiveTriggers = async () => {
  const records = await database
    .get("triggers")
    .query(Q.where("is_active", 1))
    .fetch()
    .catch(() => [] as any[]);

  return records.map((t: any) => ({
    id: t.id,
    reminderId: t.reminderId ?? t.reminder_id,
    type: t.type,
    config: t.config,
    isActive: !!(t.isActive ?? t.is_active),
    createdAt: t.createdAt ?? t.created_at,
    updatedAt: t.updatedAt ?? t.updated_at,
  }));
};

export const createTrigger = async (input: {
  reminderId: string;
  type: string;
  config?: string;
  isActive?: boolean;
}) => {
  let id = "";
  await database.write(async () => {
    const rec = await database.get("triggers").create((r: Model) => {
      const raw: any = r._raw;
      raw.id = (Math.random() + 1).toString(36).substring(2);
      raw.reminder_id = input.reminderId;
      raw.type = input.type;
      raw.config = input.config ?? null;
      raw.is_active = input.isActive ? 1 : 0;
      raw.created_at = Date.now();
      raw.updated_at = Date.now();
    });
    id = rec.id;
  });

  return id;
};

export default {
  getActiveTriggers,
  createTrigger,
};
