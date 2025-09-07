import { useFocusEffect } from "@react-navigation/native";
import React, { useCallback, useState } from "react";
import { Alert, SafeAreaView, StyleSheet, View } from "react-native";
import { MainNavigation } from "../../components/MainNavigation";
import { NotesView } from "../../components/NotesView";
import { SmartInput } from "../../components/SmartInput";
import { ThemedText } from "../../components/ThemedText";
import { TimelineView } from "../../components/TimelineView";
import { TriggersView } from "../../components/TriggersView";
import { Colors } from "../../constants/Colors";
import { Typography } from "../../constants/Typography";
import { database } from "../../database/database";
import { useColorScheme } from "../../hooks/useColorScheme";
import { NotificationService } from "../../services/NotificationService";

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
    // This can be used to coordinate refreshes across views
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

  return (
    <SafeAreaView
      style={[styles.container, { backgroundColor: themeColors.background }]}
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
          <ThemedText
            style={[
              Typography.h3,
              styles.inlineTitle,
              { color: themeColors.text },
            ]}
          >
            i cant miss
          </ThemedText>
          <SmartInput
            onReminderCreated={handleReminderCreated}
            placeholder={
              "Type text. Use /commands or #tags (e.g. /date /note /person)"
            }
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
  inlineTitle: {
    marginBottom: 8,
  },
  inputSection: {
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderBottomWidth: 1,
  },
});
