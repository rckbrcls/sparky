import React, { useCallback } from "react";
import {
  ActivityIndicator,
  FlatList,
  Text,
  TouchableOpacity,
  View,
} from "react-native";

import { AppIcon } from "@/src/components/AppIcon";
import { Colors } from "@/src/constants/Colors";

import { styles } from "./styles";
import type {
  TriggerTypeListItem,
  TriggerTypeListViewProps,
  TriggerTypeId,
} from "./types";
export type { TriggerTypeListItem, TriggerTypeListViewProps, TriggerTypeId } from "./types";

export const TriggerTypeListView: React.FC<TriggerTypeListViewProps> = ({
  triggerTypes,
  selectedTypeId,
  onSelect,
  triggerTypeCounts,
  loading,
  refreshing,
}) => {
  const renderTypeCard = useCallback(
    ({ item }: { item: TriggerTypeListItem }) => {
      const accentColor = item.color || Colors.dark.tint;
      const isSelected = selectedTypeId === item.id;
      const count = triggerTypeCounts[item.id] ??
        (item.id === "all" ? triggerTypeCounts.all ?? 0 : 0);
      const countLabel = `${count} ${count === 1 ? "trigger" : "triggers"}`;

      return (
        <TouchableOpacity
          style={[
            styles.card,
            isSelected && {
              borderColor: accentColor,
              backgroundColor: `${accentColor}18`,
            },
          ]}
          onPress={() => onSelect(item.id)}
          activeOpacity={0.88}
        >
          <View
            style={[
              styles.iconWrap,
              {
                borderColor: `${accentColor}55`,
                backgroundColor: `${accentColor}22`,
              },
            ]}
          >
            <AppIcon icon={item.icon || "trigger"} size={18} color={accentColor} />
          </View>
          <View style={styles.info}>
            <Text style={styles.title}>{item.name}</Text>
            <Text style={styles.subtitle}>{countLabel}</Text>
          </View>
          {isSelected && (loading || refreshing) ? (
            <ActivityIndicator size="small" color={accentColor} style={styles.indicator} />
          ) : (
            <AppIcon icon="chevronRight" size={18} color={Colors.dark.muted} style={styles.chevron} />
          )}
        </TouchableOpacity>
      );
    },
    [onSelect, refreshing, selectedTypeId, loading, triggerTypeCounts]
  );

  return (
    <View style={styles.container}>
      <FlatList
        data={triggerTypes}
        keyExtractor={(item) => item.id}
        renderItem={renderTypeCard}
        showsVerticalScrollIndicator={false}
        ItemSeparatorComponent={() => <View style={styles.separator} />}
        contentContainerStyle={styles.listContent}
      />
    </View>
  );
};

