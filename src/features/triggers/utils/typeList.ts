import type { TriggerListItem } from "../components/TriggersView/types";
import type { TriggerTypeListItem } from "../components/TriggerTypeListView/types";
import {
  ALL_TRIGGERS_ITEM,
  TRIGGER_TYPES,
  TRIGGER_TYPE_ORDER,
  type TriggerTypeId,
} from "../constants";

export const buildTriggerTypeList = (
  triggers: TriggerListItem[]
): { items: TriggerTypeListItem[]; counts: Record<string, number> } => {
  const counts: Record<string, number> = { all: triggers.length };

  for (const t of triggers) {
    const type = t.type as TriggerTypeId;
    counts[type] = (counts[type] ?? 0) + 1;
  }

  const items: TriggerTypeListItem[] = [
    {
      id: ALL_TRIGGERS_ITEM.id,
      name: ALL_TRIGGERS_ITEM.name,
      icon: ALL_TRIGGERS_ITEM.icon,
      color: ALL_TRIGGERS_ITEM.color,
    },
    ...TRIGGER_TYPES.map((t) => ({
      id: t.id,
      name: t.name,
      icon: t.icon,
      color: t.color,
    })),
  ];

  return { items, counts };
};
