import { useFocusEffect } from "@react-navigation/native";
import { useRouter } from "expo-router";
import React, { useCallback, useEffect, useMemo, useState } from "react";
import { Alert, StyleSheet, TouchableOpacity, View } from "react-native";
import type { SharedValue } from "react-native-reanimated";
import Animated, {
  Easing,
  runOnUI,
  useAnimatedScrollHandler,
  useAnimatedStyle,
  useSharedValue,
  withTiming,
} from "react-native-reanimated";
import { SafeAreaView } from "react-native-safe-area-context";
import { MainNavigation } from "../components/MainNavigation";
import { NotesView } from "../components/NotesView";
import { Terminal, TerminalHandle } from "../components/Terminal";
import { ThemedText } from "../components/ThemedText";
import { TimelineView } from "../components/TimelineView";
import { TriggersView } from "../components/TriggersView";
import { IconSymbol } from "../components/ui/IconSymbol";
import { Colors } from "../constants/Colors";
import { Typography } from "../constants/Typography";
import { useGlobalTouchDismiss } from "../context/GlobalTouchDismissContext";
import { database } from "../database";
import { useColorScheme } from "../hooks/useColorScheme";
import { NotificationService } from "../services/NotificationService";

const DEFAULT_INPUT_HEIGHT = 168;
const BOTTOM_THRESHOLD_PX = 2;
const BOTTOM_RELEASE_DELTA_PX = 12;
const HEADER_SCROLL_ANIMATION = {
  duration: 220,
  easing: Easing.bezier(0.16, 1, 0.3, 1),
};

type HeaderScrollMetrics = {
  y: number;
  contentHeight: number;
  layoutHeight: number;
};

type HeaderSharedRefs = {
  freezeBottom: SharedValue<number>;
  headerHeight: SharedValue<number>;
  headerTranslation: SharedValue<number>;
  scrollPrevY: SharedValue<number>;
};

const applyHeaderScroll = (
  { y, contentHeight, layoutHeight }: HeaderScrollMetrics,
  {
    freezeBottom,
    headerHeight,
    headerTranslation,
    scrollPrevY,
  }: HeaderSharedRefs
) => {
  "worklet";
  const prevY = scrollPrevY.value;
  const dy = y - prevY;
  scrollPrevY.value = y;

  const available = Math.max(contentHeight - layoutHeight, 0);
  const hasScrollableContent = available > 0;

  if (y <= 0) {
    freezeBottom.value = 0;
    if (headerTranslation.value !== 0) {
      headerTranslation.value = withTiming(0, HEADER_SCROLL_ANIMATION);
    }
    return;
  }

  const nearBottom = hasScrollableContent
    ? y >= available - BOTTOM_THRESHOLD_PX
    : false;

  if (nearBottom && dy >= 0) {
    freezeBottom.value = 1;
    return;
  }

  if (freezeBottom.value === 1) {
    if (y <= available - BOTTOM_RELEASE_DELTA_PX) {
      freezeBottom.value = 0;
    } else {
      return;
    }
  }

  const limit = headerHeight.value;
  const clamped = Math.min(Math.max(y, 0), limit);
  headerTranslation.value = withTiming(clamped, HEADER_SCROLL_ANIMATION);
};

export default function HomeScreen() {
  const scheme = useColorScheme() ?? "dark"; // fallback dark
  const [activeMode, setActiveMode] = useState<"date" | "triggers" | "notes">(
    "date"
  );
  const [refreshKey, setRefreshKey] = useState(0);
  const [headerHeightState, setHeaderHeightState] =
    useState(DEFAULT_INPUT_HEIGHT);
  const headerTranslation = useSharedValue(0);
  const headerHeight = useSharedValue(DEFAULT_INPUT_HEIGHT);
  const scrollPrevY = useSharedValue(0);
  const freezeBottom = useSharedValue(0);
  const NAV_TIGHTEN = 0; // keep original nav size/spacing
  const SCRIM_MAX_OPACITY = 1;

  useEffect(() => {
    headerTranslation.value = withTiming(0, HEADER_SCROLL_ANIMATION);
    scrollPrevY.value = 0;
    freezeBottom.value = 0;
  }, [activeMode, freezeBottom, headerTranslation, scrollPrevY]);

  const scrollHandler = useAnimatedScrollHandler({
    onBeginDrag: (event) => {
      scrollPrevY.value = event.contentOffset?.y ?? 0;
      freezeBottom.value = 0;
    },
    onScroll: (event) => {
      const y = event.contentOffset?.y ?? 0;
      const contentHeight = event.contentSize?.height ?? 0;
      const layoutHeight = event.layoutMeasurement?.height ?? 0;

      applyHeaderScroll(
        { y, contentHeight, layoutHeight },
        { freezeBottom, headerHeight, headerTranslation, scrollPrevY }
      );
    },
  });

  const notesScrollBridge = useMemo(
    () =>
      runOnUI((y: number, contentHeight: number, layoutHeight: number) => {
        "worklet";
        applyHeaderScroll(
          { y, contentHeight, layoutHeight },
          { freezeBottom, headerHeight, headerTranslation, scrollPrevY }
        );
      }),
    [freezeBottom, headerHeight, headerTranslation, scrollPrevY]
  );

  const handleNotesScroll = useCallback(
    ({
      y,
      contentHeight,
      layoutHeight,
    }: {
      y: number;
      contentHeight: number;
      layoutHeight: number;
    }) => {
      notesScrollBridge(y, contentHeight, layoutHeight);
    },
    [notesScrollBridge]
  );

  const headerAnimatedStyle = useAnimatedStyle(() => ({
    transform: [{ translateY: -headerTranslation.value }],
  }));

  const headerShadowAnimatedStyle = useAnimatedStyle(() => {
    const progress =
      headerHeight.value > 0 ? headerTranslation.value / headerHeight.value : 0;
    const clamped = Math.max(0, Math.min(progress, 1));
    const opacity = 0.2 * (1 - clamped);
    const elevation = 4 * (1 - clamped);
    const shadowRadius = 14 * (1 - clamped);
    const shadowOffsetHeight = 8 * (1 - clamped);
    return {
      shadowOpacity: opacity,
      elevation,
      shadowRadius,
      shadowOffset: { width: 0, height: shadowOffsetHeight },
    } as any;
  });

  const headerScrimAnimatedStyle = useAnimatedStyle(() => {
    const progress =
      headerHeight.value > 0 ? headerTranslation.value / headerHeight.value : 0;
    const clamped = Math.max(0, Math.min(progress, 1));
    return {
      // Darken gradually with scroll progress
      opacity: clamped * SCRIM_MAX_OPACITY,
    } as any;
  });

  const contentAnimatedStyle = useAnimatedStyle(() => ({
    paddingTop: Math.max(
      headerHeight.value - headerTranslation.value - NAV_TIGHTEN,
      0
    ),
  }));

  useFocusEffect(
    useCallback(() => {
      initializeApp();
    }, [])
  );
  const initializeApp = async () => {
    try {
      await database.initialize();
      await NotificationService.initialize();
    } catch (error) {
      Alert.alert("Error", "Error initializing the application");
      console.error("Initialization error:", error);
    }
  };

  const handleReminderCreated = () => {
    // Trigger refresh of all views
    setRefreshKey((prev) => prev + 1);
  };

  const handleRefresh = () => {
    setRefreshKey((prev) => prev + 1);
  };

  const renderActiveView = () => {
    switch (activeMode) {
      case "date":
        return (
          <TimelineView
            key={`timeline-${refreshKey}`}
            onRefresh={handleRefresh}
            onScroll={scrollHandler}
          />
        );
      case "triggers":
        return (
          <TriggersView
            key={`triggers-${refreshKey}`}
            onRefresh={handleRefresh}
            onScroll={scrollHandler}
          />
        );
      case "notes":
        return (
          <NotesView
            key={`notes-${refreshKey}`}
            onRefresh={handleRefresh}
            onScrollMetrics={handleNotesScroll}
          />
        );
      default:
        return (
          <TimelineView
            key={`timeline-${refreshKey}`}
            onRefresh={handleRefresh}
            onScroll={scrollHandler}
          />
        );
    }
  };

  const themeColors = Colors[scheme];
  const terminalRef = React.useRef<TerminalHandle>(null);
  const router = useRouter();

  const { handleCapture } = useGlobalTouchDismiss();

  return (
    <SafeAreaView
      style={[styles.container, { backgroundColor: themeColors.background }]}
      // Use capture only; no nested onStartShouldSetResponder in children
      onStartShouldSetResponderCapture={handleCapture}
    >
      <View style={styles.content}>
        <Animated.View
          onLayout={(event) => {
            const measuredHeight = event.nativeEvent.layout.height;
            if (Math.abs(measuredHeight - headerHeightState) > 1) {
              setHeaderHeightState(measuredHeight);
              headerHeight.value = measuredHeight;
              headerTranslation.value = Math.min(
                headerTranslation.value,
                measuredHeight
              );
            }
          }}
          style={[
            styles.inputSection,
            {
              backgroundColor: themeColors.background,
              borderBottomColor: themeColors.border,
            },
            headerAnimatedStyle,
            headerShadowAnimatedStyle,
          ]}
        >
          <View
            style={{
              flexDirection: "row",
              justifyContent: "space-between",
              alignItems: "center",
              marginBottom: 8,
            }}
          >
            <ThemedText style={[Typography.h3, { color: themeColors.text }]}>
              I Can&#39;t Miss
            </ThemedText>
            <TouchableOpacity
              onPress={() => router.push("/settings")}
              style={styles.settingsButton}
            >
              <IconSymbol name="gear" color={themeColors.tint} size={22} />
            </TouchableOpacity>
          </View>
          <Terminal
            ref={terminalRef}
            onReminderCreated={handleReminderCreated}
            placeholder={"text, /commands and #tags"}
          />
          {/* Darkening scrim overlay (overlay header content) */}
          <Animated.View
            pointerEvents="none"
            style={[
              styles.headerScrim,
              { backgroundColor: "#000", zIndex: 10 },
              headerScrimAnimatedStyle,
            ]}
          />
        </Animated.View>
        <Animated.View
          style={[
            styles.mainContent,
            { paddingTop: headerHeightState },
            contentAnimatedStyle,
          ]}
        >
          <MainNavigation activeMode={activeMode} onModeChange={setActiveMode}>
            {renderActiveView()}
          </MainNavigation>
        </Animated.View>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  content: {
    flex: 1,
  },
  inputSection: {
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderBottomWidth: 1,
    position: "absolute",
    top: 0,
    left: 0,
    right: 0,
    zIndex: 2,
    shadowColor: "#000",
    shadowOpacity: 0.12,
    shadowRadius: 12,
    shadowOffset: { width: 0, height: 6 },
    elevation: 3,
  },
  mainContent: {
    flex: 1,
  },
  settingsButton: {
    padding: 10,
    backgroundColor: Colors.dark.surface,
    borderColor: Colors.dark.border,
    borderRadius: 100,
    borderWidth: 1,
  },
  headerScrim: {
    position: "absolute",
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
  },
});
