import React from "react";
import { Text, View } from "react-native";

import { Colors } from "../../constants/Colors";
import { AppIcon } from "../AppIcon";
import { styles } from "./styles";

interface NotesEmptyStateProps {
  showPinnedOnly: boolean;
}

export const NotesEmptyState: React.FC<NotesEmptyStateProps> = ({
  showPinnedOnly,
}) => {
  const title = showPinnedOnly ? "No pinned notes" : "No notes yet";
  const subtitle = showPinnedOnly
    ? "Pin notes to keep your favorites handy here."
    : "Start capturing ideas with quick notes.";
  const icon = showPinnedOnly ? "pin" : "notes";
  const iconColor = showPinnedOnly ? Colors.dark.tint : Colors.dark.muted;

  return (
    <View style={styles.emptyState}>
      <AppIcon icon={icon} size={32} color={iconColor} />
      <Text style={styles.emptyTitle}>{title}</Text>
      <Text style={styles.emptySubtitle}>{subtitle}</Text>
    </View>
  );
};
