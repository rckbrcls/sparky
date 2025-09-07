import React, { useEffect, useState } from "react";
import {
  Animated,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from "react-native";
import { Colors } from "../constants/Colors";
import { Typography } from "../constants/Typography";
import { useColorScheme } from "../hooks/useColorScheme";

interface ViewMode {
  id: "date" | "triggers" | "notes";
  title: string;
  icon: string;
}

const VIEW_MODES: ViewMode[] = [
  { id: "date", title: "Timeline", icon: "📅" },
  { id: "triggers", title: "Triggers", icon: "⚡" },
  { id: "notes", title: "Notes", icon: "📝" },
];

interface MainNavigationProps {
  children: React.ReactNode;
  activeMode: "date" | "triggers" | "notes";
  onModeChange: (mode: "date" | "triggers" | "notes") => void;
}

export const MainNavigation: React.FC<MainNavigationProps> = ({
  children,
  activeMode,
  onModeChange,
}) => {
  const scheme = useColorScheme() ?? "dark";
  const themeColors = Colors[scheme];
  const [indicatorAnim] = useState(new Animated.Value(0));

  useEffect(() => {
    const activeIndex = VIEW_MODES.findIndex((mode) => mode.id === activeMode);
    Animated.spring(indicatorAnim, {
      toValue: activeIndex,
      useNativeDriver: true,
      tension: 100,
      friction: 8,
    }).start();
  }, [activeMode, indicatorAnim]);

  const handleModePress = (mode: "date" | "triggers" | "notes") => {
    onModeChange(mode);
  };

  return (
    <View
      style={[styles.container, { backgroundColor: themeColors.background }]}
    >
      {/* Navigation Header */}
      <View
        style={[
          styles.navigation,
          {
            backgroundColor: themeColors.surface,
            borderBottomColor: themeColors.border,
          },
        ]}
      >
        <View style={styles.navContainer}>
          {VIEW_MODES.map((mode, index) => (
            <TouchableOpacity
              key={mode.id}
              style={[
                styles.navItem,
                activeMode === mode.id && styles.navItemActive,
              ]}
              onPress={() => handleModePress(mode.id)}
            >
              <Text
                style={[
                  styles.navIcon,
                  { opacity: 0.6, color: themeColors.muted },
                  activeMode === mode.id && {
                    opacity: 1,
                    color: themeColors.tint,
                  },
                ]}
              >
                {mode.icon}
              </Text>
              <Text
                style={[
                  styles.navText,
                  { color: themeColors.muted },
                  activeMode === mode.id && { color: themeColors.tint },
                ]}
              >
                {mode.title}
              </Text>
            </TouchableOpacity>
          ))}

          {/* Animated Indicator */}
          <Animated.View
            style={[
              styles.indicator,
              {
                backgroundColor: themeColors.tint,
                transform: [
                  {
                    translateX: indicatorAnim.interpolate({
                      inputRange: [0, 1, 2],
                      outputRange: [0, 120, 240], // Adjust based on navItem width
                    }),
                  },
                ],
              },
            ]}
          />
        </View>
      </View>

      {/* Content Area */}
      <View style={styles.content}>{children}</View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  navigation: {
    borderBottomWidth: 1,
    paddingTop: 8,
  },
  navContainer: {
    flexDirection: "row",
    position: "relative",
    paddingHorizontal: 16,
  },
  navItem: {
    flex: 1,
    alignItems: "center",
    paddingVertical: 12,
    paddingHorizontal: 8,
  },
  navItemActive: {
    // Active state styling handled by text/icon styles
  },
  navIcon: {
    fontSize: 20,
    marginBottom: 4,
    opacity: 0.6,
  },
  navIconActive: {
    opacity: 1,
  },
  navText: {
    ...Typography.caption,
    fontWeight: "500",
  },
  indicator: {
    position: "absolute",
    bottom: 0,
    height: 3,
    width: 40,
    borderRadius: 2,
    marginLeft: 40, // Center the indicator within the navItem
  },
  content: {
    flex: 1,
  },
});
