import { format, parseISO } from "date-fns";
import { ptBR } from "date-fns/locale";
import React from "react";
import { Alert, StyleSheet, Text, TouchableOpacity, View } from "react-native";
import { Colors } from "../constants/Colors";
import { Typography } from "../constants/Typography";
import { Reminder } from "../database/database";
import { ReminderService } from "../services/ReminderService";

interface ReminderItemProps {
  reminder: Reminder;
  onRefresh: () => void;
}

export const ReminderItem: React.FC<ReminderItemProps> = ({
  reminder,
  onRefresh,
}) => {
  const getStatusColor = () => {
    switch (reminder.status) {
      case "overdue":
        return Colors.dark.error;
      case "completed":
        return Colors.dark.success;
      case "active":
        return Colors.dark.tint;
      case "archived":
        return Colors.dark.muted;
      default:
        return Colors.dark.tint;
    }
  };

  const getStatusText = () => {
    switch (reminder.status) {
      case "overdue":
        return "Overdue";
      case "completed":
        return "Completed";
      case "active":
        return "Active";
      case "archived":
        return "Archived";
      default:
        return "Active";
    }
  };

  const formatFireDate = () => {
    if (!reminder.nextFireAt) return "No date";

    try {
      const date = parseISO(reminder.nextFireAt);
      return format(date, "dd/MM/yyyy HH:mm", { locale: ptBR });
    } catch {
      return "Invalid date";
    }
  };

  const handleComplete = async () => {
    try {
      await ReminderService.completeReminder(reminder.id);
      onRefresh();
    } catch {
      Alert.alert("Error", "Unable to mark as completed");
    }
  };

  const handleSnooze = async () => {
    try {
      await ReminderService.snoozeReminder(reminder.id);
      onRefresh();
    } catch {
      Alert.alert("Error", "Unable to snooze reminder");
    }
  };

  const handleRemindLater = async () => {
    try {
      await ReminderService.remindLater(reminder.id);
      onRefresh();
    } catch {
      Alert.alert("Error", "Unable to reschedule reminder");
    }
  };

  const handleArchive = async () => {
    Alert.alert(
      "Archive Reminder",
      "Are you sure you want to archive this reminder?",
      [
        { text: "Cancel", style: "cancel" },
        {
          text: "Archive",
          style: "destructive",
          onPress: async () => {
            try {
              await ReminderService.archiveReminder(reminder.id);
              onRefresh();
            } catch {
              Alert.alert("Error", "Unable to archive reminder");
            }
          },
        },
      ]
    );
  };

  const showActionSheet = () => {
    const options: {
      text: string;
      onPress?: () => void;
      style?: "default" | "cancel" | "destructive";
    }[] = [];

    if (reminder.status === "active" || reminder.status === "overdue") {
      options.push(
        { text: "Mark as Completed", onPress: handleComplete },
        { text: "Snooze", onPress: handleSnooze },
        { text: "Remind Later", onPress: handleRemindLater },
        { text: "Archive", onPress: handleArchive, style: "destructive" }
      );
    }

    options.push({ text: "Cancel", style: "cancel" });

    Alert.alert("Actions", "What would you like to do?", options);
  };

  return (
    <TouchableOpacity style={styles.container} onPress={showActionSheet}>
      <View style={styles.header}>
        <Text style={styles.title}>{reminder.title}</Text>
        <View
          style={[styles.statusBadge, { backgroundColor: getStatusColor() }]}
        >
          <Text style={styles.statusText}>{getStatusText()}</Text>
        </View>
      </View>

      {reminder.notes && <Text style={styles.notes}>{reminder.notes}</Text>}

      <View style={styles.metadata}>
        {reminder.person && (
          <Text style={styles.metadataText}>👤 {reminder.person}</Text>
        )}
        {reminder.project && (
          <Text style={styles.metadataText}>📁 {reminder.project}</Text>
        )}
        {reminder.location && (
          <Text style={styles.metadataText}>📍 {reminder.location}</Text>
        )}
      </View>

      <View style={styles.footer}>
        <Text style={styles.fireDate}>⏰ {formatFireDate()}</Text>
        <Text style={styles.type}>{getTypeText(reminder.type)}</Text>
      </View>
    </TouchableOpacity>
  );
};

const getTypeText = (type: string) => {
  switch (type) {
    case "once":
      return "One-time";
    case "recurring":
      return "Recurring";
    case "by_person_project":
      return "By Person/Project";
    case "by_location":
      return "By Location";
    default:
      return type;
  }
};

const styles = StyleSheet.create({
  container: {
    backgroundColor: Colors.dark.surface,
    borderRadius: 12,
    padding: 16,
    marginVertical: 8,
    marginHorizontal: 16,
    borderWidth: 1,
    borderColor: Colors.dark.border,
  },
  header: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "flex-start",
    marginBottom: 8,
  },
  title: {
    ...Typography.h5,
    flex: 1,
    marginRight: 12,
  },
  statusBadge: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 12,
  },
  statusText: {
    ...Typography.caption,
    color: Colors.dark.background,
  },
  notes: {
    ...Typography.bodySmall,
    color: Colors.dark.muted,
    lineHeight: 20,
    marginBottom: 12,
  },
  metadata: {
    flexDirection: "row",
    flexWrap: "wrap",
    marginBottom: 12,
  },
  metadataText: {
    ...Typography.caption,
    color: Colors.dark.muted,
    marginRight: 16,
    marginBottom: 4,
  },
  footer: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
  },
  fireDate: {
    ...Typography.bodySmall,
    color: Colors.dark.tint,
    fontWeight: "500",
  },
  type: {
    ...Typography.caption,
    color: Colors.dark.muted,
    backgroundColor: Colors.dark.background,
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 8,
  },
});
