import React, { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  Alert,
  FlatList,
  FlatListProps,
  RefreshControl,
  Text,
  TouchableOpacity,
  View,
} from "react-native";
import Animated from "react-native-reanimated";
import { Swipeable } from "react-native-gesture-handler";

import { Colors } from "@/src/constants/Colors";
import { AppIcon } from "@/src/components/AppIcon";
import { BottomSheetBackdrop, BottomSheetBackdropProps, BottomSheetModal } from "@gorhom/bottom-sheet";
import { CreateReminderSheet } from "../create/CreateReminderSheet";
import { EditReminderSheet } from "../edit/EditReminderSheet";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { useApp } from "@/src/context/AppContext";
import { database } from "@/src/database";
import { TimelineEmptyState } from "../TimelineEmptyState";
import { TimelineFilterBar } from "../TimelineFilterBar";
import { TimelineReminderCard } from "../TimelineReminderCard";
import { styles } from "./styles";
import type {
  ReminderFilter,
  ReminderWithFolder,
  TimelineViewProps,
} from "./types";
export type {
  ReminderFilter,
  ReminderWithFolder,
  TimelineViewProps,
} from "./types";

const AnimatedFlatList =
  Animated.createAnimatedComponent<FlatListProps<ReminderWithFolder>>(FlatList);

export const TimelineView: React.FC<TimelineViewProps> = ({
  onRefresh,
  onScroll,
}) => {
  const { isInitialized, error: initError, initializeApp } = useApp();
  const insets = useSafeAreaInsets();
  const [reminders, setReminders] = useState<ReminderWithFolder[]>([]);
  const [loading, setLoading] = useState(false);
  const [filter, setFilter] = useState<ReminderFilter>("all");
  const createSheetRef = useRef<BottomSheetModal | null>(null);
  const createSnapPoints = ["60%", "92%"] as const;
  const editSheetRef = useRef<BottomSheetModal | null>(null);
  const editSnapPoints = ["60%", "92%"] as const;
  const [editingReminder, setEditingReminder] = useState<ReminderWithFolder | null>(null);

  const loadReminders = useCallback(async () => {
    if (!isInitialized) return;
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
  }, [filter, isInitialized]);

  useEffect(() => {
    void loadReminders();
  }, [loadReminders]);

  const handleRefresh = () => {
    if (!isInitialized) {
      initializeApp();
      return;
    }
    void loadReminders();
    onRefresh?.();
  };

  const emptyComponent = useMemo(() => {
    if (!isInitialized || loading) return null;
    return <TimelineEmptyState />;
  }, [isInitialized, loading]);

  const renderBackdrop = useCallback(
    (backdropProps: BottomSheetBackdropProps) => (
      <BottomSheetBackdrop
        {...backdropProps}
        appearsOnIndex={0}
        disappearsOnIndex={-1}
        pressBehavior="close"
      />
    ),
    []
  );

  const handleStartCreate = () => {
    requestAnimationFrame(() => createSheetRef.current?.present());
  };

  const handleCreateReminder = async (input: {
    title: string;
    type: "once" | "recurring" | "by_person_project" | "by_location";
    notes?: string;
    person?: string;
    project?: string;
    location?: string;
    rrule?: string;
    fireAt?: Date;
  }) => {
    try {
      const { ReminderService } = await import("@/src/features/timeline/services/ReminderService");
      await ReminderService.createReminder({
        title: input.title,
        notes: input.notes,
        person: input.person,
        project: input.project,
        location: input.location,
        type: input.type,
        rrule: input.rrule,
        fireAt: input.fireAt,
      });
      await loadReminders();
      createSheetRef.current?.dismiss();
    } catch (e) {
      console.error("Failed to create reminder", e);
    }
  };

  const handleDeleteReminder = (reminderId: string) => {
    Alert.alert("Delete Reminder", "Are you sure you want to delete this reminder?", [
      { text: "Cancel", style: "cancel" },
      {
        text: "Delete",
        style: "destructive",
        onPress: async () => {
          try {
            // Attempt to cancel scheduled notification first
            const existing = await database.getReminderById(reminderId);
            if (existing?.notificationId) {
              const { NotificationService } = await import("@/src/services/NotificationService");
              await NotificationService.cancelNotification(existing.notificationId);
            }
            await database.deleteReminder(reminderId);
            await loadReminders();
          } catch (e) {
            console.error("Failed to delete reminder", e);
          }
        },
      },
    ]);
  };

  const handleStartEdit = (reminder: ReminderWithFolder) => {
    setEditingReminder(reminder);
    requestAnimationFrame(() => editSheetRef.current?.present());
  };

  const handleSaveReminder = async (input: {
    title: string;
    type: "once" | "recurring" | "by_person_project" | "by_location";
    notes?: string;
    person?: string;
    project?: string;
    location?: string;
    rrule?: string;
    fireAt?: Date;
  }) => {
    if (!editingReminder) return;
    try {
      const { ReminderService } = await import("@/src/features/timeline/services/ReminderService");
      await ReminderService.updateReminder(editingReminder.id, {
        title: input.title,
        notes: input.notes ?? "",
        person: input.person ?? "",
        project: input.project ?? "",
        location: input.location ?? "",
        rrule: input.rrule,
        fireAt: input.fireAt,
      });
      await loadReminders();
      editSheetRef.current?.dismiss();
      setEditingReminder(null);
    } catch (e) {
      console.error("Failed to update reminder", e);
    }
  };

  const remindersCountLabel = useMemo(() => {
    const count = reminders.length;
    return `${count} ${count === 1 ? "reminder" : "reminders"}`;
  }, [reminders.length]);

  return (
    <View style={styles.container}>
      {!isInitialized && (
        <View style={styles.initializingBox}>
          <Text style={styles.initializingText}>
            {initError
              ? `Erro: ${initError}`
              : "Inicializando banco de dados..."}
          </Text>
          {initError && (
            <TouchableOpacity style={styles.retryBtn} onPress={initializeApp}>
              <Text style={styles.retryBtnText}>Tentar novamente</Text>
            </TouchableOpacity>
          )}
        </View>
      )}

      <TimelineFilterBar value={filter} onChange={setFilter} />

      <View style={styles.remindersHeaderWrapper}>
        <Text style={styles.remindersHeaderCount}>{remindersCountLabel}</Text>
        <TouchableOpacity
          style={styles.addButton}
          onPress={handleStartCreate}
          activeOpacity={0.88}
        >
          <AppIcon icon="plus" size={18} color={Colors.dark.background} />
        </TouchableOpacity>
      </View>

      <AnimatedFlatList
        data={reminders}
        renderItem={({ item }) => (
          <Swipeable
            renderRightActions={() => (
              <View style={styles.swipeActionsContainer}>
                <TouchableOpacity
                  style={styles.swipeEditAction}
                  onPress={() => handleStartEdit(item)}
                  activeOpacity={0.85}
                >
                  <AppIcon icon="edit" size={20} color={Colors.dark.background} />
                </TouchableOpacity>
                <TouchableOpacity
                  style={styles.swipeDeleteAction}
                  onPress={() => handleDeleteReminder(item.id)}
                  activeOpacity={0.85}
                >
                  <AppIcon icon="trash" size={20} color={Colors.dark.background} />
                </TouchableOpacity>
              </View>
            )}
          >
            <TimelineReminderCard reminder={item} />
          </Swipeable>
        )}
        keyExtractor={(item) => item.id}
        ListEmptyComponent={emptyComponent}
        refreshControl={
          <RefreshControl
            refreshing={loading}
            onRefresh={handleRefresh}
            tintColor={Colors.dark.tint}
          />
        }
        contentContainerStyle={[
          styles.listContainer,
          { flexGrow: reminders.length ? 0 : 1 },
        ]}
        showsVerticalScrollIndicator={false}
        onScroll={onScroll}
        scrollEventThrottle={onScroll ? 16 : undefined}
        keyboardShouldPersistTaps="handled"
        bounces={false}
        alwaysBounceVertical={false}
        overScrollMode="never"
      />
      <CreateReminderSheet
        sheetRef={createSheetRef}
        snapPoints={[...createSnapPoints] as unknown as (string | number)[]}
        renderBackdrop={renderBackdrop}
        onDismiss={() => {}}
        onClose={() => createSheetRef.current?.dismiss()}
        onCreate={handleCreateReminder}
      />
      <EditReminderSheet
        sheetRef={editSheetRef}
        snapPoints={[...editSnapPoints] as unknown as (string | number)[]}
        renderBackdrop={renderBackdrop}
        onDismiss={() => setEditingReminder(null)}
        onClose={() => editSheetRef.current?.dismiss()}
        reminder={editingReminder}
        onSave={handleSaveReminder}
      />
    </View>
  );
};
