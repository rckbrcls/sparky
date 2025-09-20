import React from "react";
import { ScrollView, Text, TouchableOpacity, View } from "react-native";

import { Colors } from "../../constants/Colors";
import { AppIcon } from "../AppIcon";
import { styles } from "./styles";
import { SettingsAction } from "./types";

interface NotesToolbarProps {
  actions: SettingsAction[];
}

export const NotesToolbar: React.FC<NotesToolbarProps> = ({ actions }) => {
  return (
    <View style={styles.toolbarContainer}>
      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={styles.toolbarList}
        keyboardShouldPersistTaps="handled"
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
