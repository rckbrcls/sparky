import { Colors } from "@/src/constants/Colors";
import type { AppIconKey } from "@/src/constants/iconMappings";

export type TriggerTypeId =
  | "location"
  | "person"
  | "time"
  | "dayOfWeek"
  | "project";

export interface TriggerTypeDef {
  id: TriggerTypeId;
  name: string;
  icon: AppIconKey;
  color?: string;
}

export const TRIGGER_TYPES: TriggerTypeDef[] = [
  { id: "location", name: "Location", icon: "location", color: Colors.dark.tint },
  { id: "person", name: "Person", icon: "person", color: Colors.dark.tint },
  { id: "time", name: "Time", icon: "clock", color: Colors.dark.tint },
  { id: "dayOfWeek", name: "Weekly", icon: "calendar", color: Colors.dark.tint },
  { id: "project", name: "Project", icon: "building", color: Colors.dark.tint },
];

export const ALL_TRIGGERS_ITEM = {
  id: "all" as const,
  name: "All triggers",
  icon: "stack" as const,
  color: Colors.dark.tint,
};

export const TRIGGER_TYPE_ORDER: TriggerTypeId[] = TRIGGER_TYPES.map((t) => t.id);

