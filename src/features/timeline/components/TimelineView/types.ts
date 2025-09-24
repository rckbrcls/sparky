import type {
  NativeScrollEvent,
  NativeSyntheticEvent,
} from "react-native";

import type { Reminder } from "@/src/features/timeline/types";
import type { Folder } from "@/src/features/notes/types";

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
