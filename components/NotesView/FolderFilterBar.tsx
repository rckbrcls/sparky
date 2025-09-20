import React from "react";
import {
  ActivityIndicator,
  ScrollView,
  Text,
  TouchableOpacity,
  View,
} from "react-native";

import { Colors } from "../../constants/Colors";
import { AppIcon } from "../AppIcon";
import { styles } from "./styles";
import { FolderListItem } from "./types";

interface FolderFilterBarProps {
  folders: FolderListItem[];
  selectedFolderId: string;
  onSelect: (folderId: string) => void;
  folderNoteCounts: Record<string, number>;
  loading: boolean;
  refreshing: boolean;
}

export const FolderFilterBar: React.FC<FolderFilterBarProps> = ({
  folders,
  selectedFolderId,
  onSelect,
  folderNoteCounts,
  loading,
  refreshing,
}) => {
  const renderFolderChip = (folder: FolderListItem) => {
    const accentColor = folder.color || Colors.dark.tint;
    const isSelected = selectedFolderId === folder.id;
    const backgroundColor = isSelected
      ? `${accentColor}22`
      : Colors.dark.surface;
    const borderColor = isSelected ? accentColor : Colors.dark.border;
    const noteCount =
      folderNoteCounts[folder.id] ??
      (folder.id === "all" ? folderNoteCounts.all ?? 0 : 0);

    return (
      <TouchableOpacity
        key={folder.id}
        style={[
          styles.folderFilterChip,
          { backgroundColor, borderColor },
          isSelected && styles.folderFilterChipActive,
        ]}
        onPress={() => onSelect(folder.id)}
        activeOpacity={0.85}
      >
        <AppIcon
          icon={folder.icon || "folder"}
          size={14}
          color={isSelected ? accentColor : Colors.dark.muted}
          style={styles.folderFilterChipIcon}
        />
        <Text
          style={[
            styles.folderFilterChipLabel,
            isSelected && styles.folderFilterChipLabelActive,
          ]}
          numberOfLines={1}
        >
          {folder.name}
        </Text>
        <Text
          style={[
            styles.folderFilterChipCount,
            isSelected && styles.folderFilterChipCountActive,
          ]}
        >
          {noteCount}
        </Text>
        {isSelected && (loading || refreshing) ? (
          <ActivityIndicator
            size="small"
            color={accentColor}
            style={styles.folderFilterChipSpinner}
          />
        ) : null}
      </TouchableOpacity>
    );
  };

  return (
    <View style={styles.folderFilterContainer}>
      <ScrollView
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={styles.folderFilterList}
        keyboardShouldPersistTaps="handled"
      >
        {folders.map(renderFolderChip)}
      </ScrollView>
    </View>
  );
};
