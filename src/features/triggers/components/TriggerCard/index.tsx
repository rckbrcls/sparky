import React from "react";
import { Text, TouchableOpacity, View } from "react-native";

import { AppIcon } from "@/src/components/AppIcon";
import { Colors } from "@/src/constants/Colors";
import { styles } from "./styles";
import type { TriggerCardProps } from "./types";
import {
  formatTriggerConfig,
  getTriggerIcon,
  getTriggerStatusColor,
} from "../../utils/formatters";
export type { TriggerCardProps } from "./types";

export const TriggerCard: React.FC<TriggerCardProps> = ({ trigger }) => {
  const statusColor = getTriggerStatusColor(trigger);
  const triggerIcon = getTriggerIcon(trigger.type);
  const triggerConfig = formatTriggerConfig(trigger);
  const reminderTitle = trigger.reminderTitle || "Unknown Reminder";

  return (
    <TouchableOpacity style={styles.card} activeOpacity={0.92}>
      <View style={styles.cardHeader}>
        <View
          style={[
            styles.statusIndicator,
            { backgroundColor: statusColor },
          ]}
        />
        <View style={styles.cardContent}>
          <Text style={styles.reminderTitle}>{reminderTitle}</Text>
          <Text style={styles.triggerConfig}>{triggerConfig}</Text>
        </View>
        <View style={styles.triggerTypeContainer}>
          <AppIcon
            icon={triggerIcon}
            size={18}
            color={Colors.dark.tint}
            style={styles.triggerTypeIcon}
          />
        </View>
      </View>
    </TouchableOpacity>
  );
};
