import React, { useMemo, useState } from "react";
import { ActivityIndicator, Text, TextInput, TouchableOpacity, View } from "react-native";
import { BottomSheetModal, BottomSheetScrollView, BottomSheetView } from "@gorhom/bottom-sheet";
import { useSafeAreaInsets } from "react-native-safe-area-context";

import { Colors } from "@/src/constants/Colors";
import { AppIcon } from "@/src/components/AppIcon";
import { folderIconKeys } from "@/src/constants/iconMappings";

import type { EditFolderSheetProps } from "./types";
import { styles } from "../CreateFolderSheet/styles";

const PRESET_COLORS = [
  "#0EA5E9",
  "#22C55E",
  "#A855F7",
  "#EAB308",
  "#EF4444",
  "#14B8A6",
  "#F97316",
  "#6366F1",
];

export const EditFolderSheet: React.FC<EditFolderSheetProps> = ({
  sheetRef,
  snapPoints,
  renderBackdrop,
  onDismiss,
  onClose,
  initialName,
  initialColor,
  initialIcon,
  onSave,
}) => {
  const insets = useSafeAreaInsets();
  const [name, setName] = useState(initialName);
  const [color, setColor] = useState<string | null>(initialColor ?? PRESET_COLORS[0]);
  const [icon, setIcon] = useState<string | null>(initialIcon ?? "folder");
  const [saving, setSaving] = useState(false);

  const canSave = useMemo(() => !!name.trim(), [name]);

  const handleCancel = () => {
    if (saving) return;
    onClose();
  };

  const handleSave = async () => {
    if (!canSave || saving) return;
    try {
      setSaving(true);
      await Promise.resolve(onSave({ name: name.trim(), color, icon }));
    } finally {
      setSaving(false);
    }
  };

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
      <BottomSheetView style={[styles.container, { paddingBottom: Math.max(24, 12 + insets.bottom) }]}>
        <BottomSheetScrollView
          contentContainerStyle={styles.content}
          keyboardShouldPersistTaps="handled"
          showsVerticalScrollIndicator={false}
        >
          <View style={styles.topBar}>
            <View style={styles.heroBadge}>
              <View style={styles.heroIconWrap}>
                <AppIcon icon="edit" size={16} color={Colors.dark.background} />
              </View>
              <Text style={styles.heroBadgeText}>Edit folder</Text>
            </View>
            <TouchableOpacity style={styles.closeButton} onPress={handleCancel} disabled={saving}>
              <AppIcon icon="close" size={20} color={Colors.dark.muted} />
            </TouchableOpacity>
          </View>
          <Text style={styles.title}>Rename or change look</Text>
          <Text style={styles.subtitle}>Update the name, icon and color.</Text>

          <View style={styles.section}>
            <Text style={styles.label}>Name</Text>
            <TextInput
              style={styles.nameInput}
              value={name}
              onChangeText={setName}
              placeholder="Folder name"
              placeholderTextColor={Colors.dark.muted}
              editable={!saving}
            />
          </View>

          <View style={styles.section}>
            <Text style={styles.label}>Icon</Text>
            <View style={styles.chipRow}>
              {folderIconKeys.map((k) => {
                const active = icon === k;
                return (
                  <TouchableOpacity
                    key={k}
                    style={[styles.chip, active && styles.chipActive]}
                    onPress={() => setIcon(k)}
                    disabled={saving}
                  >
                    <AppIcon icon={k} size={14} color={active ? Colors.dark.tint : Colors.dark.muted} style={styles.chipIcon} />
                    <Text style={[styles.chipText, active && styles.chipTextActive]}>
                      {k}
                    </Text>
                  </TouchableOpacity>
                );
              })}
            </View>
          </View>

          <View style={styles.section}>
            <Text style={styles.label}>Color</Text>
            <View style={styles.colorsRow}>
              {PRESET_COLORS.map((c) => {
                const active = color === c;
                return (
                  <TouchableOpacity
                    key={c}
                    onPress={() => setColor(c)}
                    disabled={saving}
                    style={[styles.colorSwatch, { backgroundColor: c }, active && styles.colorSwatchActive]}
                  />
                );
              })}
            </View>
          </View>
        </BottomSheetScrollView>
        <View style={styles.footerActions}>
          <TouchableOpacity style={styles.cancelButton} onPress={handleCancel} disabled={saving}>
            <Text style={styles.cancelText}>Cancel</Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={[styles.createButton, (!canSave || saving) && styles.createButtonDisabled]}
            onPress={handleSave}
            disabled={!canSave || saving}
          >
            {saving ? (
              <ActivityIndicator size="small" color={Colors.dark.background} />
            ) : (
              <Text style={styles.createText}>Save changes</Text>
            )}
          </TouchableOpacity>
        </View>
      </BottomSheetView>
    </BottomSheetModal>
  );
};

