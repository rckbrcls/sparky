import type {
  NativeScrollEvent,
  NativeSyntheticEvent,
} from "react-native";

import type { AppIconKey } from "@/src/constants/iconMappings";
import type { Trigger } from "@/src/database";

export type TriggerListItem = Trigger & { reminderTitle?: string };

export interface TriggerSection {
  title: string;
  icon: AppIconKey;
  data: TriggerListItem[];
}

export interface TriggersViewProps {
  onRefresh?: () => void;
  onScroll?: (event: NativeSyntheticEvent<NativeScrollEvent>) => void;
}
