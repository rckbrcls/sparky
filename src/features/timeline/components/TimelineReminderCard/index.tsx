import {
  format,
  isPast,
  isThisWeek,
  isToday,
  isTomorrow,
} from "date-fns";
import { ptBR } from "date-fns/locale";
import React, { useMemo } from "react";
import { Text, TouchableOpacity, View } from "react-native";

import { AppIcon } from "@/src/components/AppIcon";
import { Colors } from "@/src/constants/Colors";
import { styles } from "./styles";
import type {
  ReminderUrgency,
  TimelineReminderCardProps,
} from "./types";
export type { TimelineReminderCardProps } from "./types";

const getUrgencyLevel = (reminder: TimelineReminderCardProps["reminder"]): ReminderUrgency => {
  if (!reminder.nextFireAt) return "future";

  const fireDate = new Date(reminder.nextFireAt);

  if (isPast(fireDate) && !isToday(fireDate)) return "overdue";
  if (isToday(fireDate)) return "today";
  if (isTomorrow(fireDate)) return "tomorrow";
  if (isThisWeek(fireDate)) return "week";
  return "future";
};

const getUrgencyColor = (urgency: ReminderUrgency) => {
  switch (urgency) {
    case "overdue":
      return Colors.dark.error;
    case "today":
      return Colors.dark.warning;
    case "tomorrow":
      return Colors.dark.tint;
    case "week":
      return Colors.dark.success;
    default:
      return Colors.dark.muted;
  }
};

const getUrgencyLabel = (urgency: ReminderUrgency) => {
  switch (urgency) {
    case "overdue":
      return "Overdue";
    case "today":
      return "Today";
    case "tomorrow":
      return "Tomorrow";
    case "week":
      return "This Week";
    default:
      return "Future";
  }
};

const formatFireDate = (value: string | number | null | undefined) => {
  if (!value) return "";
  const date = typeof value === "number" ? new Date(value) : new Date(String(value));

  if (isToday(date)) {
    return format(date, "HH:mm", { locale: ptBR });
  }
  if (isTomorrow(date)) {
    return `Tomorrow ${format(date, "HH:mm", { locale: ptBR })}`;
  }
  if (isThisWeek(date)) {
    return format(date, "EEEE HH:mm", { locale: ptBR });
  }
  return format(date, "MMM dd, HH:mm", { locale: ptBR });
};

export const TimelineReminderCard: React.FC<TimelineReminderCardProps> = ({
  reminder,
}) => {
  const urgency = useMemo(() => getUrgencyLevel(reminder), [reminder]);
  const urgencyColor = useMemo(() => getUrgencyColor(urgency), [urgency]);
  const urgencyLabel = useMemo(() => getUrgencyLabel(urgency), [urgency]);
  const formattedFireDate = useMemo(
    () => formatFireDate(reminder.nextFireAt),
    [reminder.nextFireAt]
  );

  return (
    <TouchableOpacity style={styles.card} activeOpacity={0.92}>
      <View style={styles.cardHeader}>
        <View
          style={[
            styles.urgencyIndicator,
            {
              backgroundColor: urgencyColor,
            },
          ]}
        />
        <View style={styles.cardContent}>
          <Text style={styles.cardTitle}>{reminder.title}</Text>
          <Text style={styles.urgencyLabel}>{urgencyLabel}</Text>
        </View>
        {reminder.folder && (
          <View
            style={[
              styles.folderBadge,
              {
                backgroundColor: reminder.folder.color,
              },
            ]}
          >
            <AppIcon
              icon={reminder.folder.icon}
              size={18}
              color={Colors.dark.background}
            />
          </View>
        )}
      </View>

      {formattedFireDate ? (
        <Text style={styles.fireDate}>{formattedFireDate}</Text>
      ) : null}

      {reminder.notes ? (
        <Text style={styles.notes} numberOfLines={2}>
          {reminder.notes}
        </Text>
      ) : null}

      <View style={styles.cardFooter}>
        {reminder.person ? (
          <View style={styles.metadataChip}>
            <AppIcon
              icon="person"
              size={14}
              color={Colors.dark.muted}
              style={styles.metadataIcon}
            />
            <Text style={styles.metadataText}>{reminder.person}</Text>
          </View>
        ) : null}
        {reminder.project ? (
          <View style={styles.metadataChip}>
            <AppIcon
              icon="tag"
              size={14}
              color={Colors.dark.muted}
              style={styles.metadataIcon}
            />
            <Text style={styles.metadataText}>{reminder.project}</Text>
          </View>
        ) : null}
        {reminder.location ? (
          <View style={styles.metadataChip}>
            <AppIcon
              icon="location"
              size={14}
              color={Colors.dark.muted}
              style={styles.metadataIcon}
            />
            <Text style={styles.metadataText}>{reminder.location}</Text>
          </View>
        ) : null}
      </View>
    </TouchableOpacity>
  );
};
