import { format, isPast, isThisWeek, isToday, isTomorrow } from "date-fns";
import { ptBR } from "date-fns/locale";
import React, { useEffect, useState } from "react";
import {
  FlatList,
  RefreshControl,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from "react-native";
import { Colors } from "../constants/Colors";
import { Typography } from "../constants/Typography";
import { database, Folder, Reminder } from "../database/database";

interface ReminderWithFolder extends Reminder {
  folder?: Folder;
}

interface TimelineViewProps {
  onRefresh?: () => void;
}

export const TimelineView: React.FC<TimelineViewProps> = ({ onRefresh }) => {
  const [reminders, setReminders] = useState<ReminderWithFolder[]>([]);
  const [loading, setLoading] = useState(false);
  const [filter, setFilter] = useState<
    "all" | "overdue" | "today" | "upcoming"
  >("all");

  useEffect(() => {
    loadReminders();
  }, [filter]); // eslint-disable-line react-hooks/exhaustive-deps

  const loadReminders = async () => {
    setLoading(true);
    try {
      let data: ReminderWithFolder[] = [];

      switch (filter) {
        case "overdue":
          data = await database.getOverdueReminders();
          break;
        case "today":
          data = await database.getTodayReminders();
          break;
        case "upcoming":
          data = await database.getUpcomingReminders();
          break;
        default:
          data = await database.getRemindersWithFolders();
          break;
      }

      setReminders(data);
    } catch (error) {
      console.error("Error loading reminders:", error);
    } finally {
      setLoading(false);
    }
  };

  const handleRefresh = () => {
    loadReminders();
    onRefresh?.();
  };

  const getUrgencyLevel = (
    reminder: Reminder
  ): "overdue" | "today" | "tomorrow" | "week" | "future" => {
    if (!reminder.nextFireAt) return "future";

    const fireDate = new Date(reminder.nextFireAt);

    if (isPast(fireDate) && !isToday(fireDate)) return "overdue";
    if (isToday(fireDate)) return "today";
    if (isTomorrow(fireDate)) return "tomorrow";
    if (isThisWeek(fireDate)) return "week";
    return "future";
  };

  const getUrgencyColor = (urgency: string) => {
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

  const getUrgencyLabel = (urgency: string) => {
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

  const formatFireDate = (dateString: string) => {
    const date = new Date(dateString);

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

  const renderReminderCard = ({ item }: { item: ReminderWithFolder }) => {
    const urgency = getUrgencyLevel(item);

    return (
      <TouchableOpacity style={styles.card}>
        <View style={styles.cardHeader}>
          <View
            style={[
              styles.urgencyIndicator,
              { backgroundColor: getUrgencyColor(urgency) },
            ]}
          />
          <View style={styles.cardContent}>
            <Text style={styles.cardTitle}>{item.title}</Text>
            <Text style={styles.urgencyLabel}>{getUrgencyLabel(urgency)}</Text>
          </View>
          {item.folder && (
            <View
              style={[
                styles.folderBadge,
                { backgroundColor: item.folder.color },
              ]}
            >
              <Text style={styles.folderIcon}>{item.folder.icon}</Text>
            </View>
          )}
        </View>

        {item.nextFireAt && (
          <Text style={styles.fireDate}>{formatFireDate(item.nextFireAt)}</Text>
        )}

        {item.notes && (
          <Text style={styles.notes} numberOfLines={2}>
            {item.notes}
          </Text>
        )}

        <View style={styles.cardFooter}>
          {item.person && <Text style={styles.metadata}>👤 {item.person}</Text>}
          {item.project && (
            <Text style={styles.metadata}>🏷️ {item.project}</Text>
          )}
          {item.location && (
            <Text style={styles.metadata}>📍 {item.location}</Text>
          )}
        </View>
      </TouchableOpacity>
    );
  };

  const renderFilterButton = (filterType: typeof filter, label: string) => (
    <TouchableOpacity
      style={[
        styles.filterButton,
        filter === filterType && styles.filterButtonActive,
      ]}
      onPress={() => setFilter(filterType)}
    >
      <Text
        style={[
          styles.filterButtonText,
          filter === filterType && styles.filterButtonTextActive,
        ]}
      >
        {label}
      </Text>
    </TouchableOpacity>
  );

  return (
    <View style={styles.container}>
      {/* Filter Bar */}
      <View style={styles.filterBar}>
        {renderFilterButton("all", "All")}
        {renderFilterButton("overdue", "Overdue")}
        {renderFilterButton("today", "Today")}
        {renderFilterButton("upcoming", "Upcoming")}
      </View>

      {/* Reminders List */}
      <FlatList
        data={reminders}
        renderItem={renderReminderCard}
        keyExtractor={(item) => item.id}
        refreshControl={
          <RefreshControl
            refreshing={loading}
            onRefresh={handleRefresh}
            tintColor={Colors.dark.tint}
          />
        }
        contentContainerStyle={styles.listContainer}
        showsVerticalScrollIndicator={false}
      />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.dark.background,
  },
  filterBar: {
    flexDirection: "row",
    paddingHorizontal: 16,
    paddingVertical: 12,
    backgroundColor: Colors.dark.surface,
    borderBottomWidth: 1,
    borderBottomColor: Colors.dark.border,
  },
  filterButton: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    marginRight: 8,
    borderRadius: 20,
    backgroundColor: Colors.dark.background,
    borderWidth: 1,
    borderColor: Colors.dark.border,
  },
  filterButtonActive: {
    backgroundColor: Colors.dark.tint,
    borderColor: Colors.dark.tint,
  },
  filterButtonText: {
    ...Typography.caption,
    color: Colors.dark.muted,
    fontWeight: "500",
  },
  filterButtonTextActive: {
    color: Colors.dark.background,
    fontWeight: "600",
  },
  listContainer: {
    padding: 16,
  },
  card: {
    backgroundColor: Colors.dark.surface,
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    borderWidth: 1,
    borderColor: Colors.dark.border,
  },
  cardHeader: {
    flexDirection: "row",
    alignItems: "flex-start",
    marginBottom: 8,
  },
  urgencyIndicator: {
    width: 4,
    height: 24,
    borderRadius: 2,
    marginRight: 12,
  },
  cardContent: {
    flex: 1,
  },
  cardTitle: {
    ...Typography.body,
    color: Colors.dark.text,
    fontWeight: "600",
    marginBottom: 2,
  },
  urgencyLabel: {
    ...Typography.caption,
    color: Colors.dark.muted,
  },
  folderBadge: {
    width: 32,
    height: 32,
    borderRadius: 16,
    alignItems: "center",
    justifyContent: "center",
  },
  folderIcon: {
    fontSize: 16,
  },
  fireDate: {
    ...Typography.body,
    color: Colors.dark.tint,
    fontWeight: "500",
    marginBottom: 8,
  },
  notes: {
    ...Typography.body,
    color: Colors.dark.muted,
    marginBottom: 8,
    lineHeight: 20,
  },
  cardFooter: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 8,
  },
  metadata: {
    ...Typography.caption,
    color: Colors.dark.muted,
    backgroundColor: Colors.dark.background,
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 12,
  },
});
