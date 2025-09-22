import React, { useEffect, useRef, useState } from "react";
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
import { AppIcon } from "./AppIcon";
import type { AppIconKey } from "../constants/iconMappings";

interface ViewMode {
  id: "date" | "triggers" | "notes";
  title: string;
  icon: AppIconKey;
}

const VIEW_MODES: ViewMode[] = [
  { id: "date", title: "Timeline", icon: "calendar" },
  { id: "triggers", title: "Triggers", icon: "trigger" },
  { id: "notes", title: "Notes", icon: "notes" },
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
  // Layout info per nav item (x and width)
  const [itemLayouts, setItemLayouts] = useState<
    { x: number; width: number }[]
  >([]);
  const [allMeasured, setAllMeasured] = useState(false);
  const indicatorX = useRef(new Animated.Value(0)).current;
  const [indicatorWidth, setIndicatorWidth] = useState(0);

  const handleItemLayout = (index: number, x: number, width: number) => {
    setItemLayouts((prev) => {
      const next = [...prev];
      next[index] = { x, width };
      if (next.filter(Boolean).length === VIEW_MODES.length) {
        setAllMeasured(true);
      }
      return next;
    });
  };

  useEffect(() => {
    if (!allMeasured) return;
    const activeIndex = VIEW_MODES.findIndex((m) => m.id === activeMode);
    const layout = itemLayouts[activeIndex];
    if (!layout) return;
    const targetWidth = layout.width * 0.6; // 60% of item content width
    const targetX = layout.x + (layout.width - targetWidth) / 2;
    setIndicatorWidth(targetWidth); // update immediately (no width animation to avoid native driver issue)
    Animated.spring(indicatorX, {
      toValue: targetX,
      useNativeDriver: true,
      tension: 160,
      friction: 18,
    }).start();
  }, [activeMode, allMeasured, itemLayouts, indicatorX]);

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
              onLayout={(e) =>
                handleItemLayout(
                  index,
                  e.nativeEvent.layout.x,
                  e.nativeEvent.layout.width
                )
              }
            >
              <AppIcon
                icon={mode.icon}
                size={20}
                color={
                  activeMode === mode.id ? themeColors.tint : themeColors.muted
                }
                style={[
                  styles.navIcon,
                  { opacity: activeMode === mode.id ? 1 : 0.6 },
                ]}
              />
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
                opacity: allMeasured ? 1 : 0,
                width: indicatorWidth,
                transform: [
                  {
                    translateX: indicatorX,
                  },
                ],
              },
            ]}
          />
        </View>
      </View>

      {/* Content Area (no responder handlers; global capture in root) */}
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
  },
  navContainer: {
    flexDirection: "row",
    position: "relative",
    paddingHorizontal: 16,
  },
  navItem: {
    flex: 1,
    display: "flex",
    flexDirection: "row",
    gap: 4,
    justifyContent: "center",
    alignItems: "center",
    paddingVertical: 12,
    paddingHorizontal: 8,
  },
  navItemActive: {
    // Active state styling handled by text/icon styles
  },
  navIcon: {
    opacity: 0.6,
  },
  navText: {
    ...Typography.caption,
    fontWeight: "500",
  },
  indicator: {
    position: "absolute",
    bottom: 0,
    height: 3,
    borderRadius: 2,
    left: 0,
  },
  content: {
    flex: 1,
  },
});
