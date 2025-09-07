import { useFocusEffect } from "@react-navigation/native";
import React, { useCallback, useEffect, useState } from "react";
import {
  Alert,
  FlatList,
  RefreshControl,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from "react-native";
import { ReminderForm } from "../../components/ReminderForm";
import { ReminderItem } from "../../components/ReminderItem";
import { Colors } from "../../constants/Colors";
import { Typography } from "../../constants/Typography";
import { database, Reminder } from "../../database/database";
import { NotificationService } from "../../services/NotificationService";
import { ReminderService } from "../../services/ReminderService";

export default function HomeScreen() {
  const [reminders, setReminders] = useState<Reminder[]>([]);
  const [todayReminders, setTodayReminders] = useState<Reminder[]>([]);
  const [overdueReminders, setOverdueReminders] = useState<Reminder[]>([]);
  const [showForm, setShowForm] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const [filter, setFilter] = useState<"today" | "overdue" | "upcoming">(
    "today"
  );

  useEffect(() => {
    initializeApp();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useFocusEffect(
    useCallback(() => {
      loadReminders();
      // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [filter])
  );

  const initializeApp = async () => {
    try {
      await database.initialize();
      await NotificationService.initialize();
      await loadReminders();
    } catch (error) {
      Alert.alert("Error", "Error initializing the application");
      console.error("Initialization error:", error);
    }
  };

  const loadReminders = async () => {
    try {
      await ReminderService.updateReminderStatuses();

      const [today, overdue, upcoming] = await Promise.all([
        ReminderService.getTodayReminders(),
        ReminderService.getOverdueReminders(),
        ReminderService.getUpcomingReminders(),
      ]);

      setTodayReminders(today);
      setOverdueReminders(overdue);

      switch (filter) {
        case "today":
          setReminders(today);
          break;
        case "overdue":
          setReminders(overdue);
          break;
        case "upcoming":
          setReminders(upcoming);
          break;
      }
    } catch (error) {
      Alert.alert("Error", "Error loading reminders");
      console.error("Load reminders error:", error);
    }
  };

  const onRefresh = async () => {
    setRefreshing(true);
    await loadReminders();
    setRefreshing(false);
  };

  const handleFormSave = () => {
    setShowForm(false);
    loadReminders();
  };

  const getFilterTitle = () => {
    switch (filter) {
      case "today":
        return "Today";
      case "overdue":
        return "Overdue";
      case "upcoming":
        return "Upcoming";
      default:
        return "Reminders";
    }
  };

  const getFilterBadgeCount = () => {
    switch (filter) {
      case "today":
        return todayReminders.length;
      case "overdue":
        return overdueReminders.length;
      case "upcoming":
        return reminders.length;
      default:
        return 0;
    }
  };

  if (showForm) {
    return (
      <ReminderForm
        onSave={handleFormSave}
        onCancel={() => setShowForm(false)}
      />
    );
  }

  return (
    <View style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.headerTitle}>I Can&apos;t Miss</Text>
        <TouchableOpacity
          style={styles.addButton}
          onPress={() => setShowForm(true)}
        >
          <Text style={styles.addButtonText}>+</Text>
        </TouchableOpacity>
      </View>

      {/* Filters */}
      <View style={styles.filterContainer}>
        <TouchableOpacity
          style={[
            styles.filterButton,
            filter === "today" && styles.filterButtonActive,
          ]}
          onPress={() => setFilter("today")}
        >
          <Text
            style={[
              styles.filterText,
              filter === "today" && styles.filterTextActive,
            ]}
          >
            Today ({todayReminders.length})
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[
            styles.filterButton,
            filter === "overdue" && styles.filterButtonActive,
          ]}
          onPress={() => setFilter("overdue")}
        >
          <Text
            style={[
              styles.filterText,
              filter === "overdue" && styles.filterTextActive,
            ]}
          >
            Overdue ({overdueReminders.length})
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[
            styles.filterButton,
            filter === "upcoming" && styles.filterButtonActive,
          ]}
          onPress={() => setFilter("upcoming")}
        >
          <Text
            style={[
              styles.filterText,
              filter === "upcoming" && styles.filterTextActive,
            ]}
          >
            Upcoming
          </Text>
        </TouchableOpacity>
      </View>

      {/* Content */}
      <View style={styles.content}>
        <Text style={styles.sectionTitle}>
          {getFilterTitle()} ({getFilterBadgeCount()})
        </Text>

        {reminders.length === 0 ? (
          <View style={styles.emptyState}>
            <Text style={styles.emptyStateText}>
              {filter === "today" && "No reminders for today"}
              {filter === "overdue" && "No overdue reminders"}
              {filter === "upcoming" && "No upcoming reminders"}
            </Text>
            <TouchableOpacity
              style={styles.emptyStateButton}
              onPress={() => setShowForm(true)}
            >
              <Text style={styles.emptyStateButtonText}>
                Create First Reminder
              </Text>
            </TouchableOpacity>
          </View>
        ) : (
          <FlatList
            data={reminders}
            keyExtractor={(item) => item.id}
            renderItem={({ item }) => (
              <ReminderItem reminder={item} onRefresh={loadReminders} />
            )}
            refreshControl={
              <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
            }
            contentContainerStyle={styles.listContainer}
          />
        )}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.dark.background,
  },
  header: {
    backgroundColor: Colors.dark.surface,
    paddingTop: 60,
    paddingBottom: 20,
    paddingHorizontal: 20,
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    borderBottomWidth: 1,
    borderBottomColor: Colors.dark.border,
  },
  headerTitle: {
    ...Typography.h2,
  },
  addButton: {
    width: 44,
    height: 44,
    backgroundColor: Colors.dark.tint,
    borderRadius: 22,
    justifyContent: "center",
    alignItems: "center",
  },
  addButtonText: {
    ...Typography.h3,
    color: Colors.dark.background,
  },
  filterContainer: {
    flexDirection: "row",
    backgroundColor: Colors.dark.surface,
    paddingHorizontal: 20,
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: Colors.dark.border,
  },
  filterButton: {
    flex: 1,
    paddingVertical: 8,
    paddingHorizontal: 12,
    borderRadius: 20,
    marginHorizontal: 4,
    backgroundColor: Colors.dark.background,
  },
  filterButtonActive: {
    backgroundColor: Colors.dark.tint,
  },
  filterText: {
    ...Typography.bodySmall,
    color: Colors.dark.muted,
    textAlign: "center",
  },
  filterTextActive: {
    color: Colors.dark.background,
  },
  content: {
    flex: 1,
    padding: 20,
  },
  sectionTitle: {
    ...Typography.h4,
    marginBottom: 16,
  },
  emptyState: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
    paddingHorizontal: 40,
  },
  emptyStateText: {
    ...Typography.body,
    color: Colors.dark.muted,
    textAlign: "center",
    marginBottom: 24,
    lineHeight: 24,
  },
  emptyStateButton: {
    backgroundColor: Colors.dark.tint,
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 24,
  },
  emptyStateButtonText: {
    ...Typography.button,
    color: Colors.dark.background,
  },
  listContainer: {
    paddingBottom: 100,
  },
});
