import type { AppIconKey } from "@/src/constants/iconMappings";

import type {
  TriggerListItem,
  TriggerSection,
} from "../components/TriggersView/types";

const SECTION_ORDER: {
  type: string;
  title: string;
  icon: AppIconKey;
}[] = [
  { type: "location", title: "Location Triggers", icon: "location" },
  { type: "person", title: "Person Triggers", icon: "person" },
  { type: "time", title: "Time Triggers", icon: "clock" },
  { type: "dayOfWeek", title: "Weekly Triggers", icon: "calendar" },
  { type: "project", title: "Project Triggers", icon: "building" },
];

export const buildTriggerSections = (
  triggers: TriggerListItem[]
): TriggerSection[] => {
  if (!triggers.length) return [];

  const grouped = triggers.reduce<Record<string, TriggerListItem[]>>(
    (acc, trigger) => {
      const { type } = trigger;
      if (!acc[type]) {
        acc[type] = [];
      }
      acc[type].push(trigger);
      return acc;
    },
    {}
  );

  return SECTION_ORDER.reduce<TriggerSection[]>((sections, entry) => {
    const data = grouped[entry.type];
    if (!data || !data.length) return sections;
    sections.push({ title: entry.title, icon: entry.icon, data });
    return sections;
  }, []);
};
