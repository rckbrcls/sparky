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
    backgroundColor: "#F8F9FA",
  },
  header: {
    backgroundColor: "#FFFFFF",
    paddingTop: 60,
    paddingBottom: 20,
    paddingHorizontal: 20,
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    borderBottomWidth: 1,
    borderBottomColor: "#E9ECEF",
  },
  headerTitle: {
    fontSize: 28,
    fontWeight: "700",
    color: "#1A1A1A",
  },
  addButton: {
    width: 44,
    height: 44,
    backgroundColor: "#339AF0",
    borderRadius: 22,
    justifyContent: "center",
    alignItems: "center",
  },
  addButtonText: {
    fontSize: 24,
    fontWeight: "600",
    color: "#FFFFFF",
  },
  filterContainer: {
    flexDirection: "row",
    backgroundColor: "#FFFFFF",
    paddingHorizontal: 20,
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: "#E9ECEF",
  },
  filterButton: {
    flex: 1,
    paddingVertical: 8,
    paddingHorizontal: 12,
    borderRadius: 20,
    marginHorizontal: 4,
    backgroundColor: "#F1F3F5",
  },
  filterButtonActive: {
    backgroundColor: "#339AF0",
  },
  filterText: {
    fontSize: 14,
    fontWeight: "500",
    color: "#6C757D",
    textAlign: "center",
  },
  filterTextActive: {
    color: "#FFFFFF",
  },
  content: {
    flex: 1,
    padding: 20,
  },
  sectionTitle: {
    fontSize: 20,
    fontWeight: "600",
    color: "#1A1A1A",
    marginBottom: 16,
  },
  emptyState: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
    paddingHorizontal: 40,
  },
  emptyStateText: {
    fontSize: 16,
    color: "#6C757D",
    textAlign: "center",
    marginBottom: 24,
    lineHeight: 24,
  },
  emptyStateButton: {
    backgroundColor: "#339AF0",
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 24,
  },
  emptyStateButtonText: {
    fontSize: 16,
    fontWeight: "600",
    color: "#FFFFFF",
  },
  listContainer: {
    paddingBottom: 100,
  },
});
