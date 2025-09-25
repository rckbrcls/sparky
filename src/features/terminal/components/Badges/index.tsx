import React, { useMemo } from "react";
import { Animated, ScrollView, Text, TouchableOpacity, View } from "react-native";
import { Colors } from "../../../../constants/Colors";
import type { AppIconKey } from "../../../../constants/iconMappings";
import { AppIcon } from "../../../../components/AppIcon";
import type { ParsedReminder } from "@/src/features/terminal/engine";
import type { IntentState } from "@/src/features/terminal/engine/intent";
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
  folderMap: Record<string, string>;
  intent: IntentState;
  onRemoveCommand?: (id: string) => void;
  onEditCommand?: (id: string) => void;
}

const resolvePreviewFolderName = (
  preview: ParsedReminder,
  folderMap: Record<string, string>,
  intent: IntentState
) => {
  const cmd = intent.activated.find((c) => c.name === "folder");
  if (cmd?.value?.trim()) return cmd.value.trim();
  if (preview.folderId) {
    return folderMap[preview.folderId] || (preview.folderId === "all" ? "All" : preview.folderId.replace(/-/g, " "));
  }
  return undefined;
};

export const Badges: React.FC<BadgesProps> = ({ preview, fadeAnim, folderMap, intent, onRemoveCommand, onEditCommand }) => {
  const previewBadges = useMemo<PreviewBadge[]>(() => {
    if (!preview) return [];

    const badges: PreviewBadge[] = [];
    const folderName = preview.type === "note" ? resolvePreviewFolderName(preview, folderMap, intent) : undefined;
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

    // Conditionally hide preview chips that have an interactive counterpart
    const detached = intent.activated.filter((c) => c.detached);
    const hasType = !!detached.find((c) => c.name === 'note' || c.name === 'date');
    const hasFolder = !!detached.find((c) => c.name === 'folder' && (c.value ?? '').trim());
    const hasPriority = !!detached.find((c) => c.name === 'priority' && (c.value ?? '').trim());
    const hasPerson = !!detached.find((c) => c.name === 'person' && (c.value ?? '').trim());
    const hasLocation = !!detached.find((c) => c.name === 'location' && (c.value ?? '').trim());

    return badges.filter((b) => {
      if (hasType && b.key === 'type') return false;
      if (hasFolder && b.key === 'folder') return false;
      if (hasPriority && b.key === 'priority') return false;
      if (hasPerson && b.key.startsWith('person-')) return false;
      if (hasLocation && b.key.startsWith('location-')) return false;
      return true;
    });
  }, [preview, folderMap, intent]);

  const interactiveBadges = useMemo(() => {
    const list: (PreviewBadge & { id: string })[] = [];
    const detached = intent.activated.filter((c) => c.detached);

    const typeCmd = detached.find((c) => c.name === 'note' || c.name === 'date');
    if (typeCmd) {
      const type = typeCmd.name === 'note' ? 'note' : 'date';
      list.push({
        key: `cmd-type-${typeCmd.id}`,
        id: typeCmd.id,
        icon: getTypeIcon(type, undefined),
        label: getTypeLabel(type, undefined),
        tone: 'accent',
        accessibilityLabel: `Tipo ${getTypeLabel(type, undefined)}`,
      });
    }

    detached.filter((c) => c.name === 'folder' && (c.value ?? '').trim()).forEach((c) => {
      const label = (c.value || '').trim();
      list.push({
        key: `cmd-folder-${c.id}`,
        id: c.id,
        icon: 'folder',
        label,
        tone: 'neutral',
        accessibilityLabel: `Pasta ${label}`,
      });
    });

    detached.filter((c) => c.name === 'priority' && (c.value ?? '').trim()).forEach((c) => {
      const v = (c.value || '').trim();
      let tone: BadgeTone = 'success';
      if (v === '!!!' || v === '3' || /urgent|alta/i.test(v)) tone = 'danger';
      else if (v === '!!' || v === '2' || /m[eé]dio|medio|important/i.test(v)) tone = 'warning';
      list.push({
        key: `cmd-priority-${c.id}`,
        id: c.id,
        icon: 'lightning',
        label: `Prioridade ${v}`,
        tone,
        accessibilityLabel: `Prioridade ${v}`,
      });
    });

    detached.filter((c) => c.name === 'person' && (c.value ?? '').trim()).forEach((c, idx) => {
      const label = (c.value || '').trim();
      list.push({
        key: `cmd-person-${c.id}-${idx}`,
        id: c.id,
        icon: 'person',
        label,
        tone: 'neutral',
        accessibilityLabel: `Pessoa ${label}`,
      });
    });

    detached.filter((c) => c.name === 'location' && (c.value ?? '').trim()).forEach((c, idx) => {
      const label = (c.value || '').trim();
      list.push({
        key: `cmd-location-${c.id}-${idx}`,
        id: c.id,
        icon: 'location',
        label,
        tone: 'neutral',
        accessibilityLabel: `Local ${label}`,
      });
    });

    return list;
  }, [intent]);

  if ((!preview || previewBadges.length === 0) && interactiveBadges.length === 0) {
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
        {interactiveBadges.map((badge) => {
          const appearance = BADGE_APPEARANCE[badge.tone];
          return (
            <TouchableOpacity
              key={badge.key}
              style={[
                styles.badge,
                {
                  backgroundColor: appearance.backgroundColor,
                  borderColor: appearance.borderColor,
                },
              ]}
              onPress={() => onEditCommand?.(badge.id)}
              activeOpacity={0.8}
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
              <TouchableOpacity
                onPress={(e) => {
                  // @ts-ignore RN gesture event may support stopPropagation
                  if (typeof (e as any)?.stopPropagation === 'function') (e as any).stopPropagation();
                  onRemoveCommand?.(badge.id);
                }}
                style={styles.badgeClose}
                accessibilityRole="button"
                accessibilityLabel={`Remover ${badge.label}`}
                hitSlop={{ top: 6, bottom: 6, left: 6, right: 6 }}
              >
                <AppIcon icon="close" size={12} color={appearance.textColor} />
              </TouchableOpacity>
            </TouchableOpacity>
          );
        })}
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
