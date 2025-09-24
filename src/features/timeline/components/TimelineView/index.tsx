import React, { useCallback, useEffect, useMemo, useState } from "react";
import {
  FlatList,
  FlatListProps,
  RefreshControl,
  Text,
  TouchableOpacity,
  View,
} from "react-native";
import type { NativeScrollEvent, NativeSyntheticEvent } from "react-native";
import Animated from "react-native-reanimated";

import { Colors } from "@/src/constants/Colors";
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
  const [reminders, setReminders] = useState<ReminderWithFolder[]>([]);
  const [loading, setLoading] = useState(false);
  const [filter, setFilter] = useState<ReminderFilter>("all");

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

  const handleScroll = useCallback(
    (event: NativeSyntheticEvent<NativeScrollEvent>) => {
      onScroll?.(event);
    },
    [onScroll]
  );

  const emptyComponent = useMemo(() => {
    if (!isInitialized || loading) return null;
    return <TimelineEmptyState />;
  }, [isInitialized, loading]);

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

      <AnimatedFlatList
        data={reminders}
        renderItem={({ item }) => <TimelineReminderCard reminder={item} />}
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
        onScroll={handleScroll}
        scrollEventThrottle={onScroll ? 16 : undefined}
        keyboardShouldPersistTaps="handled"
        bounces={false}
        alwaysBounceVertical={false}
        overScrollMode="never"
      />
    </View>
  );
};
