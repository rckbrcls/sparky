import React from "react";
import { Text, TouchableOpacity, View } from "react-native";

import { styles } from "./styles";
import type { TimelineFilterBarProps } from "./types";
export type { TimelineFilterBarProps } from "./types";

const FILTER_OPTIONS = [
  { key: "all", label: "All" },
  { key: "overdue", label: "Overdue" },
  { key: "today", label: "Today" },
  { key: "upcoming", label: "Upcoming" },
] as const;

export const TimelineFilterBar: React.FC<TimelineFilterBarProps> = ({
  value,
  onChange,
}) => {
  return (
    <View style={styles.filterBar}>
      {FILTER_OPTIONS.map((option) => {
        const isActive = value === option.key;

        return (
          <TouchableOpacity
            key={option.key}
            style={[
              styles.filterButton,
              isActive && styles.filterButtonActive,
            ]}
            onPress={() => onChange(option.key)}
            activeOpacity={0.85}
          >
            <Text
              style={[
                styles.filterButtonText,
                isActive && styles.filterButtonTextActive,
              ]}
            >
              {option.label}
            </Text>
          </TouchableOpacity>
        );
      })}
    </View>
  );
};
