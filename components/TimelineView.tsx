import { format, isPast, isThisWeek, isToday, isTomorrow } from "date-fns";
import { ptBR } from "date-fns/locale";
import React, { useEffect, useState } from "react";
import {
  FlatList,
  FlatListProps,
  NativeScrollEvent,
  NativeSyntheticEvent,
  RefreshControl,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from "react-native";
import Animated from "react-native-reanimated";
import { Colors } from "../constants/Colors";
import { Typography } from "../constants/Typography";
import { useApp } from "../context/AppContext";
import { database, Folder, Reminder } from "../database/database";
import { AppIcon } from "./AppIcon";

interface ReminderWithFolder extends Reminder {
  folder?: Folder;
}

const AnimatedFlatList =
  Animated.createAnimatedComponent<FlatListProps<ReminderWithFolder>>(FlatList);

interface TimelineViewProps {
  onRefresh?: () => void;
  onScroll?: (event: NativeSyntheticEvent<NativeScrollEvent>) => void;
}

export const TimelineView: React.FC<TimelineViewProps> = ({
  onRefresh,
  onScroll,
}) => {
  const { isInitialized, error: initError, initializeApp } = useApp();
  const [reminders, setReminders] = useState<ReminderWithFolder[]>([]);
  const [loading, setLoading] = useState(false);
  const [filter, setFilter] = useState<
    "all" | "overdue" | "today" | "upcoming"
  >("all");

  useEffect(() => {
    if (isInitialized) {
      loadReminders();
    }
  }, [filter, isInitialized]); // eslint-disable-line react-hooks/exhaustive-deps

  const loadReminders = async () => {
    if (!isInitialized) return; // evita erro de inicialização
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
    if (!isInitialized) {
      initializeApp();
      return;
    }
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
              <AppIcon
                icon={item.folder.icon}
                size={18}
                color={Colors.dark.background}
              />
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
          {item.person && (
            <View style={styles.metadataChip}>
              <AppIcon
                icon="person"
                size={14}
                color={Colors.dark.muted}
                style={styles.metadataIcon}
              />
              <Text style={styles.metadataText}>{item.person}</Text>
            </View>
          )}
          {item.project && (
            <View style={styles.metadataChip}>
              <AppIcon
                icon="tag"
                size={14}
                color={Colors.dark.muted}
                style={styles.metadataIcon}
              />
              <Text style={styles.metadataText}>{item.project}</Text>
            </View>
          )}
          {item.location && (
            <View style={styles.metadataChip}>
              <AppIcon
                icon="location"
                size={14}
                color={Colors.dark.muted}
                style={styles.metadataIcon}
              />
              <Text style={styles.metadataText}>{item.location}</Text>
            </View>
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
      {/* Filter Bar */}
      <View style={styles.filterBar}>
        {renderFilterButton("all", "All")}
        {renderFilterButton("overdue", "Overdue")}
        {renderFilterButton("today", "Today")}
        {renderFilterButton("upcoming", "Upcoming")}
      </View>

      {/* Reminders List */}
      <AnimatedFlatList
        data={reminders}
        renderItem={renderReminderCard}
        keyExtractor={(item) => item.id}
        ListEmptyComponent={
          isInitialized && !loading ? (
            <View
              style={{
                flex: 1,
                alignItems: "center",
                justifyContent: "center",
                paddingVertical: 32,
              }}
            >
              <Text style={styles.emptyText}>Nenhum lembrete encontrado.</Text>
            </View>
          ) : null
        }
        refreshControl={
          <RefreshControl
            refreshing={loading}
            onRefresh={handleRefresh}
            tintColor={Colors.dark.tint}
          />
        }
        contentContainerStyle={[styles.listContainer, { flexGrow: 1 }]}
        showsVerticalScrollIndicator={false}
        onScroll={onScroll}
        scrollEventThrottle={onScroll ? 16 : undefined}
        keyboardShouldPersistTaps="handled"
        bounces={false}
        alwaysBounceVertical={false}
        overScrollMode="never"
      />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "transparent",
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
  initializingBox: {
    padding: 16,
    alignItems: "center",
  },
  initializingText: {
    ...Typography.caption,
    color: Colors.dark.muted,
    marginBottom: 8,
  },
  retryBtn: {
    paddingHorizontal: 14,
    paddingVertical: 8,
    backgroundColor: Colors.dark.tint,
    borderRadius: 8,
  },
  retryBtnText: {
    ...Typography.caption,
    color: Colors.dark.background,
    fontWeight: "600",
  },
  emptyText: {
    ...Typography.caption,
    color: Colors.dark.muted,
    textAlign: "center",
    marginTop: 32,
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
  metadataChip: {
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: Colors.dark.background,
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 12,
    gap: 4,
  },
  metadataIcon: {
    opacity: 0.7,
  },
  metadataText: {
    ...Typography.caption,
    color: Colors.dark.muted,
  },
});
