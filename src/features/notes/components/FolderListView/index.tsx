import React, { useCallback } from "react";
import {
  ActivityIndicator,
  FlatList,
  Text,
  TouchableOpacity,
  View,
} from "react-native";
import { Swipeable } from "react-native-gesture-handler";

import { AppIcon } from "@/src/components/AppIcon";
import { Colors } from "@/src/constants/Colors";

import { styles } from "./styles";
import type { FolderListItem, FolderListViewProps } from "./types";
export type { FolderListItem, FolderListViewProps } from "./types";

export const FolderListView: React.FC<FolderListViewProps> = ({
  folders,
  selectedFolderId,
  onSelect,
  folderNoteCounts,
  loading,
  refreshing,
  onAddFolder,
  onDeleteFolder,
  onEditFolder,
}) => {
  const renderRightActions = useCallback(
    (item: FolderListItem) => (
      <View style={styles.swipeActionsContainer}>
        <TouchableOpacity
          style={styles.swipeEditAction}
          onPress={() => onEditFolder?.(item.id)}
          activeOpacity={0.85}
        >
          <AppIcon icon="edit" size={20} color={Colors.dark.background} />
        </TouchableOpacity>
        <TouchableOpacity
          style={styles.swipeDeleteAction}
          onPress={() => onDeleteFolder?.(item.id)}
          activeOpacity={0.85}
        >
          <AppIcon icon="trash" size={20} color={Colors.dark.background} />
        </TouchableOpacity>
      </View>
    ),
    [onDeleteFolder, onEditFolder]
  );

  const renderFolderCard = useCallback(
    ({ item }: { item: FolderListItem }) => {
      const accentColor = item.color || Colors.dark.tint;
      const isSelected = selectedFolderId === item.id;
      const noteCount =
        folderNoteCounts[item.id] ??
        (item.id === "all" ? folderNoteCounts.all ?? 0 : 0);
      const noteCountLabel = `${noteCount} ${
        noteCount === 1 ? "note" : "notes"
      }`;

      const card = (
        <TouchableOpacity
          style={[
            styles.folderCard,
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
              styles.folderCardIconWrap,
              {
                borderColor: `${accentColor}55`,
                backgroundColor: `${accentColor}22`,
              },
            ]}
          >
            <AppIcon
              icon={item.icon || "folder"}
              size={18}
              color={accentColor}
            />
          </View>
          <View style={styles.folderCardInfo}>
            <Text style={styles.folderCardTitle}>{item.name}</Text>
            <Text style={styles.folderCardSubtitle}>{noteCountLabel}</Text>
          </View>
          {isSelected && (loading || refreshing) ? (
            <ActivityIndicator
              size="small"
              color={accentColor}
              style={styles.folderCardIndicator}
            />
          ) : (
            <View style={styles.folderCardActions}>
              <AppIcon
                icon="chevronRight"
                size={18}
                color={Colors.dark.muted}
                style={styles.folderCardChevron}
              />
            </View>
          )}
        </TouchableOpacity>
      );

      if (item.id === "all" || (!onDeleteFolder && !onEditFolder)) return card;
      return (
        <Swipeable renderRightActions={() => renderRightActions(item)}>
          {card}
        </Swipeable>
      );
    },
    [folderNoteCounts, loading, onDeleteFolder, onEditFolder, onSelect, refreshing, renderRightActions, selectedFolderId]
  );

  return (
    <View style={styles.folderFilterContainer}>
      <FlatList
        data={folders}
        keyExtractor={(item) => item.id}
        renderItem={renderFolderCard}
        showsVerticalScrollIndicator={false}
        ItemSeparatorComponent={() => (
          <View style={styles.folderCardSeparator} />
        )}
        contentContainerStyle={styles.folderFilterList}
        ListHeaderComponent={
          onAddFolder ? (
            <View style={styles.folderListHeader}>
              <Text style={styles.folderListHeaderTitle}>Folders</Text>
              <TouchableOpacity
                style={styles.addButton}
                onPress={onAddFolder}
                activeOpacity={0.88}
              >
                <AppIcon icon="plus" size={18} color={Colors.dark.background} />
              </TouchableOpacity>
            </View>
          ) : null
        }
      />
    </View>
  );
};
