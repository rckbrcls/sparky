import React from "react";
import { Text, View } from "react-native";

import { styles } from "./styles";
import type { TimelineEmptyStateProps } from "./types";
export type { TimelineEmptyStateProps } from "./types";

export const TimelineEmptyState: React.FC<TimelineEmptyStateProps> = ({
  message = "Nenhum lembrete encontrado.",
}) => {
  return (
    <View style={styles.emptyContainer}>
      <Text style={styles.emptyText}>{message}</Text>
    </View>
  );
};
