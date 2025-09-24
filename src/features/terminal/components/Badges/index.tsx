import React, { useMemo } from "react";
import { Animated, ScrollView, Text, View } from "react-native";
import { Colors } from "../../../../constants/Colors";
import type { AppIconKey } from "../../../../constants/iconMappings";
import { AppIcon } from "../../../../components/AppIcon";
import type { ParsedReminder } from "@/src/features/terminal/services/SmartTextParser";
import {
  matchCreateFolderCommand,
  matchFolderCommand,
} from "../../../../utils/terminal";
import { styles } from "./styles";

type BadgeTone = "neutral" | "accent" | "success" | "warning" | "danger";

interface PreviewBadge {
  key: string;
  label: string;
  icon?: AppIconKey;
  tone: BadgeTone;
  accessibilityLabel: string;
}

const BADGE_APPEARANCE: Record<
  BadgeTone,
  { backgroundColor: string; borderColor: string; textColor: string }
> = {
  neutral: {
    backgroundColor: Colors.dark.surface,
    borderColor: Colors.dark.border,
    textColor: Colors.dark.text,
  },
  accent: {
    backgroundColor: "rgba(255,255,255,0.12)",
    borderColor: Colors.dark.tint,
    textColor: Colors.dark.tint,
  },
  success: {
    backgroundColor: "rgba(63, 185, 80, 0.2)",
    borderColor: Colors.dark.success,
    textColor: Colors.dark.success,
  },
  warning: {
    backgroundColor: "rgba(210, 153, 34, 0.2)",
    borderColor: Colors.dark.warning,
    textColor: Colors.dark.warning,
  },
  danger: {
    backgroundColor: "rgba(248, 81, 73, 0.2)",
    borderColor: Colors.dark.error,
    textColor: Colors.dark.error,
  },
};

const getTypeIcon = (type: string, triggerType?: string): AppIconKey => {
  if (type === "date") return "clock";
  if (type === "note") return "notes";
  if (triggerType === "person") return "person";
  if (triggerType === "location") return "location";
  return "clipboard";
};

const getTypeLabel = (type: string, triggerType?: string) => {
  if (type === "date") return "Date Reminder";
  if (type === "note") return "Quick Note";
  if (triggerType === "person") return "Person Trigger";
  if (triggerType === "location") return "Location Trigger";
  return "General Reminder";
};

const getPriorityLabel = (priority: number) => {
  switch (priority) {
    case 3:
      return "Alta";
    case 2:
      return "Média";
    case 1:
      return "Baixa";
    default:
      return "Neutral";
  }
};

interface BadgesProps {
  preview: ParsedReminder | null;
  fadeAnim: Animated.Value;
  text: string;
  folderMap: Record<string, string>;
}

const resolvePreviewFolderName = (
  text: string,
  preview: ParsedReminder,
  folderMap: Record<string, string>
) => {
  const folderMatch = matchFolderCommand(text || "");
  if (folderMatch?.[1]?.trim()) return folderMatch[1].trim();

  const createMatch = matchCreateFolderCommand(text || "");
  if (createMatch?.[1]?.trim()) return createMatch[1].trim();

  if (preview.folderId) {
    return (
      folderMap[preview.folderId] ||
      (preview.folderId === "all" ? "All" : preview.folderId.replace(/-/g, " "))
    );
  }

  return undefined;
};

export const Badges: React.FC<BadgesProps> = ({
  preview,
  fadeAnim,
  text,
  folderMap,
}) => {
  const previewBadges = useMemo<PreviewBadge[]>(() => {
    if (!preview) return [];

    const badges: PreviewBadge[] = [];
    const folderName =
      preview.type === "note"
        ? resolvePreviewFolderName(text, preview, folderMap)
        : undefined;
    const typeIcon = getTypeIcon(preview.type, preview.triggerType);
    const typeLabel = getTypeLabel(preview.type, preview.triggerType);

    badges.push({
      key: "type",
      icon: typeIcon,
      label: typeLabel,
      tone: "accent",
      accessibilityLabel: `Tipo ${typeLabel}`,
    });

    if (preview.priority) {
      const priorityLabel = getPriorityLabel(preview.priority);
      const tone: BadgeTone =
        preview.priority === 3
          ? "danger"
          : preview.priority === 2
          ? "warning"
          : "success";
      badges.push({
        key: "priority",
        icon: "lightning",
        label: `Prioridade ${priorityLabel}`,
        tone,
        accessibilityLabel: `Prioridade ${priorityLabel}`,
      });
    }

    if (
      preview.fireAt instanceof Date &&
      !Number.isNaN(preview.fireAt.getTime())
    ) {
      const datePart = preview.fireAt.toLocaleDateString();
      const timePart = preview.fireAt.toLocaleTimeString([], {
        hour: "2-digit",
        minute: "2-digit",
      });
      const label = `${datePart} ${timePart}`.trim();
      badges.push({
        key: "fireAt",
        icon: "clock",
        label,
        tone: "neutral",
        accessibilityLabel: `Agendado para ${label}`,
      });
    }

    if (folderName) {
      badges.push({
        key: "folder",
        icon: "folder",
        label: folderName,
        tone: "neutral",
        accessibilityLabel: `Pasta ${folderName}`,
      });
    }

    const people = preview.persons?.length
      ? preview.persons
      : preview.person
      ? [preview.person]
      : [];
    people.forEach((person, index) => {
      const trimmed = person.trim();
      if (!trimmed) return;
      badges.push({
        key: `person-${index}-${trimmed}`,
        icon: "person",
        label: trimmed,
        tone: "neutral",
        accessibilityLabel: `Pessoa ${trimmed}`,
      });
    });

    const locations = preview.locations?.length
      ? preview.locations
      : preview.location
      ? [preview.location]
      : [];
    locations.forEach((location, index) => {
      const trimmed = location.trim();
      if (!trimmed) return;
      badges.push({
        key: `location-${index}-${trimmed}`,
        icon: "location",
        label: trimmed,
        tone: "neutral",
        accessibilityLabel: `Local ${trimmed}`,
      });
    });

    if (preview.project) {
      badges.push({
        key: "project",
        icon: "pin",
        label: preview.project,
        tone: "neutral",
        accessibilityLabel: `Projeto ${preview.project}`,
      });
    }

    if (preview.tags?.length) {
      preview.tags.forEach((tag, index) => {
        const trimmed = tag.trim();
        if (!trimmed) return;
        badges.push({
          key: `tag-${index}-${trimmed}`,
          label: `#${trimmed}`,
          tone: "neutral",
          accessibilityLabel: `Tag ${trimmed}`,
        });
      });
    }

    return badges;
  }, [preview, text, folderMap]);

  if (!preview || previewBadges.length === 0) {
    return null;
  }

  return (
    <Animated.View style={[styles.container, { opacity: fadeAnim }]}>
      <ScrollView
        style={styles.scroll}
        contentContainerStyle={styles.content}
        keyboardShouldPersistTaps="handled"
        showsVerticalScrollIndicator={previewBadges.length > 6}
        scrollEventThrottle={16}
      >
        {previewBadges.map((badge) => {
          const appearance = BADGE_APPEARANCE[badge.tone];
          return (
            <View
              key={badge.key}
              style={[
                styles.badge,
                {
                  backgroundColor: appearance.backgroundColor,
                  borderColor: appearance.borderColor,
                },
              ]}
              accessible
              accessibilityRole="text"
              accessibilityLabel={badge.accessibilityLabel}
            >
              {badge.icon ? (
                <AppIcon
                  icon={badge.icon}
                  size={16}
                  color={appearance.textColor}
                  style={styles.badgeIcon}
                />
              ) : null}
              <Text
                style={[styles.badgeLabel, { color: appearance.textColor }]}
              >
                {badge.label}
              </Text>
            </View>
          );
        })}
      </ScrollView>
    </Animated.View>
  );
};

export default Badges;
