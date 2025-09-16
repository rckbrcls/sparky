import { useFocusEffect } from "@react-navigation/native";
import { useRouter } from "expo-router";
import React, { useCallback, useState } from "react";
import {
  Alert,
  SafeAreaView,
  StyleSheet,
  TouchableOpacity,
  View,
} from "react-native";
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
import { database } from "../database/database";
import { useColorScheme } from "../hooks/useColorScheme";
import { NotificationService } from "../services/NotificationService";

export default function HomeScreen() {
  const scheme = useColorScheme() ?? "dark"; // fallback dark
  const [activeMode, setActiveMode] = useState<"date" | "triggers" | "notes">(
    "date"
  );
  const [refreshKey, setRefreshKey] = useState(0);

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
          />
        );
      case "triggers":
        return (
          <TriggersView
            key={`triggers-${refreshKey}`}
            onRefresh={handleRefresh}
          />
        );
      case "notes":
        return (
          <NotesView key={`notes-${refreshKey}`} onRefresh={handleRefresh} />
        );
      default:
        return (
          <TimelineView
            key={`timeline-${refreshKey}`}
            onRefresh={handleRefresh}
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
        <View
          style={[
            styles.inputSection,
            {
              backgroundColor: themeColors.background,
              borderBottomColor: themeColors.border,
            },
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
        </View>
        <MainNavigation activeMode={activeMode} onModeChange={setActiveMode}>
          {renderActiveView()}
        </MainNavigation>
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
  },
  settingsButton: {
    padding: 10,
    backgroundColor: Colors.dark.surface,
    borderColor: Colors.dark.border,
    borderRadius: 100,
    borderWidth: 1,
  },
});
