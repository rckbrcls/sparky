import React, { useEffect, useState } from "react";
import {
  NativeScrollEvent,
  NativeSyntheticEvent,
  RefreshControl,
  SectionList,
  SectionListProps,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from "react-native";
import Animated from "react-native-reanimated";
import { Colors } from "../constants/Colors";
import { Typography } from "../constants/Typography";
import { database, Trigger } from "../database";
import { AppIcon } from "./AppIcon";
import type { AppIconKey } from "../constants/iconMappings";

interface TriggerSection {
  title: string;
  icon: AppIconKey;
  data: (Trigger & { reminderTitle?: string })[];
}

type TriggerListItem = Trigger & { reminderTitle?: string };

const AnimatedSectionList =
  Animated.createAnimatedComponent<
    SectionListProps<TriggerListItem, TriggerSection>
  >(SectionList);

interface TriggersViewProps {
  onRefresh?: () => void;
  onScroll?: (event: NativeSyntheticEvent<NativeScrollEvent>) => void;
}

export const TriggersView: React.FC<TriggersViewProps> = ({
  onRefresh,
  onScroll,
}) => {
  const [sections, setSections] = useState<TriggerSection[]>([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    loadTriggers();
  }, []);

  const loadTriggers = async () => {
    setLoading(true);
    try {
      const triggers = await database.getActiveTriggers();

      // Group triggers by type
      const groupedTriggers = triggers.reduce((acc: any, trigger: any) => {
        const type = trigger.type;
        if (!acc[type]) {
          acc[type] = [];
        }
        acc[type].push(trigger);
        return acc;
      }, {} as Record<string, typeof triggers>);

      // Create sections
      const newSections: TriggerSection[] = [];

      if (groupedTriggers.location) {
        newSections.push({
          title: "Location Triggers",
          icon: "location",
          data: groupedTriggers.location,
        });
      }

      if (groupedTriggers.person) {
        newSections.push({
          title: "Person Triggers",
          icon: "person",
          data: groupedTriggers.person,
        });
      }

      if (groupedTriggers.time) {
        newSections.push({
          title: "Time Triggers",
          icon: "clock",
          data: groupedTriggers.time,
        });
      }

      if (groupedTriggers.dayOfWeek) {
        newSections.push({
          title: "Weekly Triggers",
          icon: "calendar",
          data: groupedTriggers.dayOfWeek,
        });
      }

      if (groupedTriggers.project) {
        newSections.push({
          title: "Project Triggers",
          icon: "building",
          data: groupedTriggers.project,
        });
      }

      setSections(newSections);
    } catch (error) {
      console.error("Error loading triggers:", error);
    } finally {
      setLoading(false);
    }
  };

  const handleRefresh = () => {
    loadTriggers();
    onRefresh?.();
  };

  const formatTriggerConfig = (trigger: Trigger) => {
    try {
      const config = JSON.parse(trigger.config);

      switch (trigger.type) {
        case "location":
          return config.address || `${config.latitude}, ${config.longitude}`;
        case "person":
          return config.contactName || "Unknown contact";
        case "time":
          return `${config.hour?.toString().padStart(2, "0")}:${config.minute
            ?.toString()
            .padStart(2, "0")}`;
        case "dayOfWeek":
          const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
          return (
            config.daysOfWeek?.map((day: number) => days[day]).join(", ") ||
            "No days set"
          );
        case "project":
          return config.projectName || "Unknown project";
        default:
          return "Unknown trigger";
      }
    } catch {
      return "Invalid config";
    }
  };

  const getTriggerStatusColor = (trigger: Trigger) => {
    return trigger.isActive ? Colors.dark.success : Colors.dark.muted;
  };

  const renderTriggerCard = ({
    item,
  }: {
    item: Trigger & { reminderTitle?: string };
  }) => (
    <TouchableOpacity style={styles.card}>
      <View style={styles.cardHeader}>
        <View
          style={[
            styles.statusIndicator,
            { backgroundColor: getTriggerStatusColor(item) },
          ]}
        />
        <View style={styles.cardContent}>
          <Text style={styles.reminderTitle}>
            {item.reminderTitle || "Unknown Reminder"}
          </Text>
          <Text style={styles.triggerConfig}>{formatTriggerConfig(item)}</Text>
        </View>
        <View style={styles.triggerTypeContainer}>
          <AppIcon
            icon={getTriggerIcon(item.type)}
            size={18}
            color={Colors.dark.tint}
            style={styles.triggerTypeIcon}
          />
        </View>
      </View>
    </TouchableOpacity>
  );

  const getTriggerIcon = (type: string): AppIconKey => {
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

  const renderSectionHeader = ({ section }: { section: TriggerSection }) => (
    <View style={styles.sectionHeader}>
      <AppIcon
        icon={section.icon}
        size={18}
        color={Colors.dark.text}
        style={styles.sectionIcon}
      />
      <Text style={styles.sectionTitle}>{section.title}</Text>
      <Text style={styles.sectionCount}>({section.data.length})</Text>
    </View>
  );

  const renderEmptyState = () => (
    <View style={styles.emptyState}>
      <AppIcon icon="lightning" size={32} color={Colors.dark.muted} />
      <Text style={styles.emptyTitle}>No Active Triggers</Text>
      <Text style={styles.emptySubtitle}>
        Create reminders with location, person, or time triggers to see them
        here
      </Text>
    </View>
  );

  return (
    <View style={styles.container}>
      <AnimatedSectionList
        sections={sections}
        renderItem={renderTriggerCard}
        renderSectionHeader={renderSectionHeader}
        keyExtractor={(item) => item.id}
        ListEmptyComponent={!loading ? renderEmptyState() : null}
        refreshControl={
          <RefreshControl
            refreshing={loading}
            onRefresh={handleRefresh}
            tintColor={Colors.dark.tint}
          />
        }
        contentContainerStyle={[styles.listContainer, { flexGrow: 1 }]}
        showsVerticalScrollIndicator={false}
        stickySectionHeadersEnabled={false}
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
  listContainer: {
    padding: 16,
  },
  sectionHeader: {
    flexDirection: "row",
    alignItems: "center",
    paddingVertical: 12,
    paddingHorizontal: 16,
    backgroundColor: Colors.dark.surface,
    borderRadius: 8,
    marginBottom: 8,
    borderWidth: 1,
    borderColor: Colors.dark.border,
  },
  sectionIcon: {
    marginRight: 8,
  },
  sectionTitle: {
    ...Typography.h5,
    color: Colors.dark.text,
    fontWeight: "600",
    flex: 1,
  },
  sectionCount: {
    ...Typography.caption,
    color: Colors.dark.muted,
  },
  card: {
    backgroundColor: Colors.dark.surface,
    borderRadius: 12,
    padding: 16,
    marginBottom: 8,
    borderWidth: 1,
    borderColor: Colors.dark.border,
  },
  cardHeader: {
    flexDirection: "row",
    alignItems: "center",
  },
  statusIndicator: {
    width: 8,
    height: 8,
    borderRadius: 4,
    marginRight: 12,
  },
  cardContent: {
    flex: 1,
  },
  reminderTitle: {
    ...Typography.body,
    color: Colors.dark.text,
    fontWeight: "600",
    marginBottom: 4,
  },
  triggerConfig: {
    ...Typography.body,
    color: Colors.dark.muted,
  },
  triggerTypeContainer: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: Colors.dark.background,
    alignItems: "center",
    justifyContent: "center",
  },
  triggerTypeIcon: {
    opacity: 0.8,
  },
  emptyState: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    paddingHorizontal: 32,
  },
  emptyTitle: {
    ...Typography.h3,
    color: Colors.dark.text,
    marginBottom: 8,
    textAlign: "center",
  },
  emptySubtitle: {
    ...Typography.body,
    color: Colors.dark.muted,
    textAlign: "center",
    lineHeight: 24,
  },
});
