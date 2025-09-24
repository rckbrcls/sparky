import type { ReminderFilter } from "../TimelineView/types";

export interface TimelineFilterBarProps {
  value: ReminderFilter;
  onChange: (filter: ReminderFilter) => void;
}
