import React from "react";
import { Text, View } from "react-native";

import { AppIcon } from "@/src/components/AppIcon";
import { Colors } from "@/src/constants/Colors";
import { styles } from "./styles";
import { TimelineEmptyStateProps } from "./types";

export const TimelineEmptyState: React.FC<TimelineEmptyStateProps> = ({
  title = "No Timeline",
  subtitle = "Create reminders and tasks to see them here.",
}) => {
  return (
    <View style={styles.container}>
      <AppIcon icon="calendar" size={32} color={Colors.dark.muted} />
      <Text style={styles.title}>{title}</Text>
      <Text style={styles.subtitle}>{subtitle}</Text>
    </View>
  );
};
