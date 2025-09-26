import type { AppIconKey } from "@/src/constants/iconMappings";

export type TriggerTypeId =
  | "all"
  | "location"
  | "person"
  | "time"
  | "dayOfWeek"
  | "project";

export interface TriggerTypeListItem {
  id: TriggerTypeId;
  name: string;
  icon?: AppIconKey;
  color?: string;
}

export interface TriggerTypeListViewProps {
  triggerTypes: TriggerTypeListItem[];
  selectedTypeId: TriggerTypeId | null;
  onSelect: (typeId: TriggerTypeId) => void;
  triggerTypeCounts: Record<string, number>;
  loading: boolean;
  refreshing: boolean;
}

