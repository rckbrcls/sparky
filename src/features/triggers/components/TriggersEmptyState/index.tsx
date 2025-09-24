import React from "react";
import { Text, View } from "react-native";

import { AppIcon } from "@/src/components/AppIcon";
import { Colors } from "@/src/constants/Colors";
import { styles } from "./styles";
import type { TriggersEmptyStateProps } from "./types";
export type { TriggersEmptyStateProps } from "./types";

export const TriggersEmptyState: React.FC<TriggersEmptyStateProps> = ({
  title = "No Active Triggers",
  subtitle = "Create reminders with location, person, or time triggers to see them here",
}) => {
  return (
    <View style={styles.container}>
      <AppIcon icon="lightning" size={32} color={Colors.dark.muted} />
      <Text style={styles.title}>{title}</Text>
      <Text style={styles.subtitle}>{subtitle}</Text>
    </View>
  );
};
