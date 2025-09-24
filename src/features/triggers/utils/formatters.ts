import { Colors } from "@/src/constants/Colors";
import type { AppIconKey } from "@/src/constants/iconMappings";

import type { TriggerListItem } from "../components/TriggersView/types";

const DAYS_LABEL = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

export const formatTriggerConfig = (trigger: TriggerListItem): string => {
  try {
    const config = JSON.parse(trigger.config ?? "{}");

    switch (trigger.type) {
      case "location":
        return config.address || `${config.latitude}, ${config.longitude}`;
      case "person":
        return config.contactName || "Unknown contact";
      case "time":
        if (config.hour == null || config.minute == null) {
          return "No time set";
        }
        return `${String(config.hour).padStart(2, "0")}:${String(
          config.minute
        ).padStart(2, "0")}`;
      case "dayOfWeek":
        return (
          config.daysOfWeek
            ?.map((day: number) => DAYS_LABEL[day] ?? "?")
            .join(", ") ||
          "No days set"
        );
      case "project":
        return config.projectName || "Unknown project";
      default:
        return "Unknown trigger";
    }
  } catch (error) {
    console.warn("Failed to parse trigger config", error);
    return "Invalid config";
  }
};

export const getTriggerIcon = (type: string): AppIconKey => {
  switch (type) {
    case "location":
      return "location";
    case "person":
      return "person";
    case "time":
      return "clock";
    case "dayOfWeek":
      return "calendar";
    case "project":
      return "building";
    default:
      return "lightning";
  }
};

export const getTriggerStatusColor = (trigger: TriggerListItem) =>
  trigger.isActive ? Colors.dark.success : Colors.dark.muted;
