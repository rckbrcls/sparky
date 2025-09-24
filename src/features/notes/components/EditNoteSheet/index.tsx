import React from "react";
import {
  ActivityIndicator,
  ScrollView,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from "react-native";
import {
  BottomSheetModal,
  BottomSheetScrollView,
  BottomSheetView,
} from "@gorhom/bottom-sheet";

import { styles } from "./styles";
import type {
  EditNoteSheetProps,
  FolderListItem,
  QuickNoteWithFolder,
} from "./types";
export type {
  EditNoteSheetProps,
  FolderListItem,
  QuickNoteWithFolder,
} from "./types";
import { AppIcon } from "@/src/components/AppIcon";
import { Colors } from "@/src/constants/Colors";

export const EditNoteSheet: React.FC<EditNoteSheetProps> = ({
  sheetRef,
  snapPoints,
  renderBackdrop,
  onDismiss,
  note,
  saving,
  editedContent,
  onChangeContent,
  editedTags,
  onChangeTags,
  editedFolderId,
  onChangeFolder,
  editedPinned,
  onTogglePinned,
  availableFolders,
  onClose,
  onSave,
  onDelete,
}) => {
  const accentColor = note?.folder?.color ?? Colors.dark.tint;
  const timestampLabel = note?.updatedAt
    ? new Date(note.updatedAt).toLocaleString()
    : "";

  return (
    <BottomSheetModal
      ref={sheetRef}
      snapPoints={snapPoints}
      enablePanDownToClose
      backdropComponent={renderBackdrop}
      android_keyboardInputMode="adjustResize"
      backgroundStyle={styles.sheetBackground}
      handleStyle={styles.sheetHandle}
      handleIndicatorStyle={styles.sheetHandleIndicator}
      onDismiss={onDismiss}
    >
      <BottomSheetView style={styles.editSheetContainer}>
        {note ? (
          <>
            <BottomSheetScrollView
              contentContainerStyle={styles.editSheetContent}
              keyboardShouldPersistTaps="handled"
              showsVerticalScrollIndicator={false}
            >
              <View style={styles.editTopBar}>
                <View
                  style={[
                    styles.editHeroBadge,
                    { backgroundColor: `${accentColor}33` },
                  ]}
                >
                  <View
                    style={[
                      styles.editHeroIconWrap,
                      { backgroundColor: accentColor },
                    ]}
                  >
                    <AppIcon
                      icon={note.folder?.icon || "notes"}
                      size={16}
                      color={Colors.dark.background}
                    />
                  </View>
                  <Text style={styles.editHeroBadgeText}>Quick note</Text>
                </View>
                <TouchableOpacity
                  style={styles.editCloseButton}
                  onPress={() => onClose()}
                  disabled={saving}
                >
                  <AppIcon icon="close" size={20} color={Colors.dark.muted} />
                </TouchableOpacity>
              </View>
              <Text style={styles.editTitle}>Polish your thought</Text>
              {timestampLabel ? (
                <Text
                  style={styles.editSubtitle}
                >{`Updated ${timestampLabel}`}</Text>
              ) : null}
              <TouchableOpacity
                style={[
                  styles.pinToggle,
                  editedPinned && styles.pinToggleActive,
                ]}
                onPress={onTogglePinned}
                disabled={saving}
              >
                <AppIcon
                  icon="pin"
                  size={18}
                  color={
                    editedPinned ? Colors.dark.background : Colors.dark.muted
                  }
                  style={styles.pinToggleIcon}
                />
                <Text
                  style={[
                    styles.pinToggleText,
                    editedPinned && styles.pinToggleTextActive,
                  ]}
                >
                  {editedPinned ? "Pinned" : "Pin note"}
                </Text>
              </TouchableOpacity>
              <View style={styles.editSection}>
                <Text style={styles.editLabel}>Content</Text>
                <TextInput
                  style={styles.editContentInput}
                  multiline
                  value={editedContent}
                  onChangeText={onChangeContent}
                  placeholder="Capture your note..."
                  placeholderTextColor={Colors.dark.muted}
                  editable={!saving}
                />
              </View>
              <View style={styles.editSection}>
                <Text style={styles.editLabel}>Tags</Text>
                <TextInput
                  style={styles.editTagInput}
                  value={editedTags}
                  onChangeText={onChangeTags}
                  placeholder="Add tags separated by space or comma"
                  placeholderTextColor={Colors.dark.muted}
                  editable={!saving}
                  autoCapitalize="none"
                  autoCorrect={false}
                />
                <Text style={styles.editHelperText}>
                  Add tags with `#` or separated by comma.
                </Text>
              </View>
              <View style={styles.editSection}>
                <Text style={styles.editLabel}>Folder</Text>
                <ScrollView
                  horizontal
                  showsHorizontalScrollIndicator={false}
                  contentContainerStyle={styles.editFolderChips}
                  keyboardShouldPersistTaps="handled"
                >
                  <TouchableOpacity
                    style={[
                      styles.folderChip,
                      !editedFolderId && styles.folderChipActive,
                    ]}
                    onPress={() => onChangeFolder(null)}
                    disabled={saving}
                  >
                    <AppIcon
                      icon="notes"
                      size={14}
                      color={
                        !editedFolderId ? Colors.dark.tint : Colors.dark.muted
                      }
                      style={styles.folderChipIcon}
                    />
                    <Text
                      style={[
                        styles.folderChipText,
                        !editedFolderId && styles.folderChipTextActive,
                      ]}
                    >
                      No folder
                    </Text>
                  </TouchableOpacity>
                  {availableFolders.map((folder) => {
                    const isSelected = editedFolderId === folder.id;
                    return (
                      <TouchableOpacity
                        key={folder.id}
                        style={[
                          styles.folderChip,
                          isSelected && styles.folderChipActive,
                        ]}
                        onPress={() => onChangeFolder(folder.id)}
                        disabled={saving}
                      >
                        <AppIcon
                          icon={folder.icon || "folder"}
                          size={14}
                          color={
                            isSelected ? Colors.dark.tint : Colors.dark.muted
                          }
                          style={styles.folderChipIcon}
                        />
                        <Text
                          style={[
                            styles.folderChipText,
                            isSelected && styles.folderChipTextActive,
                          ]}
                        >
                          {folder.name}
                        </Text>
                      </TouchableOpacity>
                    );
                  })}
                </ScrollView>
              </View>
            </BottomSheetScrollView>
            <View style={styles.editFooterArea}>
              <TouchableOpacity
                style={styles.editDeleteButton}
                onPress={() =>
                  note &&
                  onDelete(note.id, {
                    afterDelete: () => onClose(true),
                  })
                }
                disabled={saving}
              >
                <AppIcon
                  icon="trash"
                  size={16}
                  color={Colors.dark.error}
                  style={styles.editDeleteIcon}
                />
                <Text style={styles.editDeleteText}>Delete note</Text>
              </TouchableOpacity>
              <View style={styles.editFooterActions}>
                <TouchableOpacity
                  style={styles.editCancelButton}
                  onPress={() => onClose()}
                  disabled={saving}
                >
                  <Text style={styles.editCancelText}>Cancel</Text>
                </TouchableOpacity>
                <TouchableOpacity
                  style={[
                    styles.editSaveButton,
                    (saving || !editedContent.trim()) &&
                      styles.editSaveButtonDisabled,
                  ]}
                  onPress={onSave}
                  disabled={saving || !editedContent.trim()}
                >
                  {saving ? (
                    <ActivityIndicator
                      size="small"
                      color={Colors.dark.background}
                    />
                  ) : (
                    <Text style={styles.editSaveText}>Save changes</Text>
                  )}
                </TouchableOpacity>
              </View>
            </View>
          </>
        ) : (
          <View style={styles.editSheetPlaceholder}>
            <ActivityIndicator size="small" color={Colors.dark.tint} />
          </View>
        )}
      </BottomSheetView>
    </BottomSheetModal>
  );
};
