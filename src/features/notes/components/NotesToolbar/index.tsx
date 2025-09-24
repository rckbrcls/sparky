import React from "react";
import { ScrollView, Text, TouchableOpacity, View } from "react-native";

import { styles } from "./styles";
import type { NotesToolbarProps } from "./types";
import { AppIcon } from "@/src/components/AppIcon";
import { Colors } from "@/src/constants/Colors";
export type { SettingsAction } from "./types";

export const NotesToolbar: React.FC<NotesToolbarProps> = ({
  actions,
  style,
}) => {
  return (
    <View style={[styles.toolbarContainer, style]}>
      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={styles.toolbarList}
        keyboardShouldPersistTaps="handled"
        directionalLockEnabled
        overScrollMode="never"
      >
        {actions.map((action) => {
          const isActive = !!action.active;
          const isDisabled = !!action.disabled;

          return (
            <TouchableOpacity
              key={action.key}
              style={[
                styles.toolbarButton,
                isActive && styles.toolbarButtonActive,
                isDisabled && styles.toolbarButtonDisabled,
              ]}
              onPress={action.onPress}
              disabled={isDisabled}
              activeOpacity={0.85}
            >
              <AppIcon
                icon={action.icon}
                size={16}
                color={isActive ? Colors.dark.background : Colors.dark.tint}
                style={styles.toolbarButtonIcon}
              />
              <Text
                style={[
                  styles.toolbarButtonText,
                  isActive && styles.toolbarButtonTextActive,
                  isDisabled && styles.toolbarButtonTextDisabled,
                ]}
              >
                {action.label}
              </Text>
            </TouchableOpacity>
          );
        })}
      </ScrollView>
    </View>
  );
};
