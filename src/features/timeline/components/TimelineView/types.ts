import type {
  NativeScrollEvent,
  NativeSyntheticEvent,
} from "react-native";

import type { Folder, Reminder } from "@/src/repositories/types";

export interface ReminderWithFolder extends Reminder {
  folder?: Folder;
}

export type ReminderFilter = "all" | "overdue" | "today" | "upcoming";

export type ReminderUrgency =
  | "overdue"
  | "today"
  | "tomorrow"
  | "week"
  | "future";

export interface TimelineViewProps {
  onRefresh?: () => void;
  onScroll?: (event: NativeSyntheticEvent<NativeScrollEvent>) => void;
}
