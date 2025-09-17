import React, { useEffect, useState } from "react";
import {
  Alert,
  FlatList,
  Modal,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from "react-native";
import { Colors } from "../constants/Colors";
import { Typography } from "../constants/Typography";
import { database, Folder } from "../database/database";
import { AppIcon } from "./AppIcon";
import { folderIconKeys } from "../constants/iconMappings";

interface FolderManagerProps {
  visible: boolean;
  onClose: () => void;
  onFolderCreated?: () => void;
}

const FOLDER_COLORS = [
  "#00D2FF",
  "#F85149",
  "#3FB950",
  "#D29922",
  "#8B5CF6",
  "#F59E0B",
  "#EF4444",
  "#10B981",
  "#6366F1",
  "#EC4899",
  "#F97316",
  "#84CC16",
];

export const FolderManager: React.FC<FolderManagerProps> = ({
  visible,
  onClose,
  onFolderCreated,
}) => {
  const [folders, setFolders] = useState<Folder[]>([]);
  const [showCreateForm, setShowCreateForm] = useState(false);
  const [newFolderName, setNewFolderName] = useState("");
  const [selectedColor, setSelectedColor] = useState(FOLDER_COLORS[0]);
  const [selectedIcon, setSelectedIcon] = useState(folderIconKeys[0]);

  useEffect(() => {
    if (visible) {
      loadFolders();
    }
  }, [visible]);

  const loadFolders = async () => {
    try {
      const folderData = await database.getAllFolders();
      setFolders(folderData);
    } catch (error) {
      console.error("Error loading folders:", error);
    }
  };

  const handleCreateFolder = async () => {
    if (!newFolderName.trim()) {
      Alert.alert("Error", "Folder name is required");
      return;
    }

    try {
      await database.createFolder({
        name: newFolderName.trim(),
        color: selectedColor,
        icon: selectedIcon,
        isDefault: false,
        sortOrder: folders.length,
      });

      setNewFolderName("");
      setSelectedColor(FOLDER_COLORS[0]);
      setSelectedIcon(folderIconKeys[0]);
      setShowCreateForm(false);
      loadFolders();
      onFolderCreated?.();
    } catch (error) {
      console.error("Error creating folder:", error);
      Alert.alert("Error", "Failed to create folder");
    }
  };

  const handleDeleteFolder = async (folderId: string, folderName: string) => {
    Alert.alert(
      "Delete Folder",
      `Are you sure you want to delete "${folderName}"? All items will be moved to the General folder.`,
      [
        { text: "Cancel", style: "cancel" },
        {
          text: "Delete",
          style: "destructive",
          onPress: async () => {
            try {
              await database.deleteFolder(folderId);
              loadFolders();
              onFolderCreated?.();
            } catch (error) {
              console.error("Error deleting folder:", error);
              Alert.alert("Error", "Failed to delete folder");
            }
          },
        },
      ]
    );
  };

  const renderFolderItem = ({ item }: { item: Folder }) => (
    <View style={styles.folderItem}>
      <View style={styles.folderInfo}>
        <View style={[styles.folderBadge, { backgroundColor: item.color }]}>
          <AppIcon
            icon={item.icon}
            size={20}
            color={Colors.dark.background}
          />
        </View>
        <View style={styles.folderDetails}>
          <Text style={styles.folderName}>{item.name}</Text>
          {item.isDefault && <Text style={styles.defaultLabel}>Default</Text>}
        </View>
      </View>

      {!item.isDefault && (
        <TouchableOpacity
          style={styles.deleteButton}
          onPress={() => handleDeleteFolder(item.id, item.name)}
        >
          <AppIcon
            icon="trash"
            size={18}
            color={Colors.dark.muted}
            style={styles.deleteIcon}
          />
        </TouchableOpacity>
      )}
    </View>
  );

  const renderColorPicker = () => (
    <View style={styles.pickerSection}>
      <Text style={styles.pickerLabel}>Color</Text>
      <View style={styles.colorGrid}>
        {FOLDER_COLORS.map((color) => (
          <TouchableOpacity
            key={color}
            style={[
              styles.colorOption,
              { backgroundColor: color },
              selectedColor === color && styles.selectedOption,
            ]}
            onPress={() => setSelectedColor(color)}
          />
        ))}
      </View>
    </View>
  );

  const renderIconPicker = () => (
    <View style={styles.pickerSection}>
      <Text style={styles.pickerLabel}>Icon</Text>
      <View style={styles.iconGrid}>
        {folderIconKeys.map((icon) => (
          <TouchableOpacity
            key={icon}
            style={[
              styles.iconOption,
              selectedIcon === icon && styles.selectedIconOption,
            ]}
            onPress={() => setSelectedIcon(icon)}
          >
            <AppIcon icon={icon} size={22} color={Colors.dark.text} />
          </TouchableOpacity>
        ))}
      </View>
    </View>
  );

  return (
    <Modal
      visible={visible}
      animationType="slide"
      presentationStyle="pageSheet"
    >
      <View style={styles.container}>
        <View style={styles.header}>
          <Text style={styles.title}>Manage Folders</Text>
          <TouchableOpacity style={styles.closeButton} onPress={onClose}>
            <AppIcon icon="close" size={20} color={Colors.dark.muted} />
          </TouchableOpacity>
        </View>

        {!showCreateForm ? (
          <View style={styles.content}>
            <TouchableOpacity
              style={styles.createButton}
              onPress={() => setShowCreateForm(true)}
            >
              <AppIcon
                icon="plus"
                size={20}
                color={Colors.dark.tint}
                style={styles.createIcon}
              />
              <Text style={styles.createText}>Create New Folder</Text>
            </TouchableOpacity>

            <FlatList
              data={folders}
              renderItem={renderFolderItem}
              keyExtractor={(item) => item.id}
              contentContainerStyle={styles.folderList}
              showsVerticalScrollIndicator={false}
            />
          </View>
        ) : (
          <View style={styles.createForm}>
            <TextInput
              style={styles.nameInput}
              value={newFolderName}
              onChangeText={setNewFolderName}
              placeholder="Folder name"
              placeholderTextColor={Colors.dark.muted}
              autoFocus
            />

            {renderColorPicker()}
            {renderIconPicker()}

            <View style={styles.formActions}>
              <TouchableOpacity
                style={styles.cancelButton}
                onPress={() => {
                  setShowCreateForm(false);
                  setNewFolderName("");
                  setSelectedColor(FOLDER_COLORS[0]);
      setSelectedIcon(folderIconKeys[0]);
                }}
              >
                <Text style={styles.cancelText}>Cancel</Text>
              </TouchableOpacity>

              <TouchableOpacity
                style={styles.saveButton}
                onPress={handleCreateFolder}
              >
                <Text style={styles.saveText}>Create</Text>
              </TouchableOpacity>
            </View>
          </View>
        )}
      </View>
    </Modal>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.dark.background,
  },
  header: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingHorizontal: 20,
    paddingVertical: 16,
    borderBottomWidth: 1,
    borderBottomColor: Colors.dark.border,
  },
  title: {
    ...Typography.h3,
    color: Colors.dark.text,
    fontWeight: "600",
  },
  closeButton: {
    padding: 8,
  },
  content: {
    flex: 1,
    padding: 20,
  },
  createButton: {
    flexDirection: "row",
    alignItems: "center",
    padding: 16,
    backgroundColor: Colors.dark.surface,
    borderRadius: 12,
    borderWidth: 2,
    borderStyle: "dashed",
    borderColor: Colors.dark.border,
    marginBottom: 20,
  },
  createIcon: {
    marginRight: 12,
  },
  createText: {
    ...Typography.body,
    color: Colors.dark.tint,
    fontWeight: "500",
  },
  folderList: {
    flexGrow: 1,
  },
  folderItem: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    padding: 16,
    backgroundColor: Colors.dark.surface,
    borderRadius: 12,
    marginBottom: 8,
    borderWidth: 1,
    borderColor: Colors.dark.border,
  },
  folderInfo: {
    flexDirection: "row",
    alignItems: "center",
    flex: 1,
  },
  folderBadge: {
    width: 40,
    height: 40,
    borderRadius: 20,
    alignItems: "center",
    justifyContent: "center",
    marginRight: 12,
  },
  folderDetails: {
    flex: 1,
  },
  folderName: {
    ...Typography.body,
    color: Colors.dark.text,
    fontWeight: "600",
  },
  defaultLabel: {
    ...Typography.caption,
    color: Colors.dark.muted,
    marginTop: 2,
  },
  deleteButton: {
    padding: 8,
  },
  deleteIcon: {
    opacity: 0.7,
  },
  createForm: {
    flex: 1,
    padding: 20,
  },
  nameInput: {
    ...Typography.body,
    color: Colors.dark.text,
    backgroundColor: Colors.dark.surface,
    borderRadius: 8,
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderWidth: 1,
    borderColor: Colors.dark.border,
    marginBottom: 24,
  },
  pickerSection: {
    marginBottom: 24,
  },
  pickerLabel: {
    ...Typography.body,
    color: Colors.dark.text,
    fontWeight: "600",
    marginBottom: 12,
  },
  colorGrid: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 12,
  },
  colorOption: {
    width: 40,
    height: 40,
    borderRadius: 20,
    borderWidth: 3,
    borderColor: "transparent",
  },
  selectedOption: {
    borderColor: Colors.dark.text,
  },
  iconGrid: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 8,
  },
  iconOption: {
    width: 48,
    height: 48,
    borderRadius: 24,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: Colors.dark.surface,
    borderWidth: 2,
    borderColor: "transparent",
  },
  selectedIconOption: {
    borderColor: Colors.dark.tint,
    backgroundColor: `${Colors.dark.tint}20`,
  },
  formActions: {
    flexDirection: "row",
    gap: 12,
    marginTop: "auto",
    paddingBottom: 20,
  },
  cancelButton: {
    flex: 1,
    padding: 16,
    borderRadius: 8,
    backgroundColor: Colors.dark.surface,
    borderWidth: 1,
    borderColor: Colors.dark.border,
    alignItems: "center",
  },
  cancelText: {
    ...Typography.body,
    color: Colors.dark.muted,
    fontWeight: "500",
  },
  saveButton: {
    flex: 1,
    padding: 16,
    borderRadius: 8,
    backgroundColor: Colors.dark.tint,
    alignItems: "center",
  },
  saveText: {
    ...Typography.body,
    color: Colors.dark.background,
    fontWeight: "600",
  },
});
