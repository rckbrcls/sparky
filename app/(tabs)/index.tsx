import { useFocusEffect } from "@react-navigation/native";
import React, { useCallback, useState } from "react";
import { Alert, SafeAreaView, StyleSheet, View } from "react-native";
import { MainNavigation } from "../../components/MainNavigation";
import { NotesView } from "../../components/NotesView";
import { SmartInput } from "../../components/SmartInput";
import { TimelineView } from "../../components/TimelineView";
import { TriggersView } from "../../components/TriggersView";
import { Colors } from "../../constants/Colors";
import { database } from "../../database/database";
import { NotificationService } from "../../services/NotificationService";

export default function HomeScreen() {
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

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.content}>
        {/* Smart Input */}
        <View style={styles.inputSection}>
          <SmartInput
            onReminderCreated={handleReminderCreated}
            placeholder={
              activeMode === "notes"
                ? "Capture a quick thought..."
                : activeMode === "triggers"
                ? "Create trigger: 'Call John when home'"
                : "Add reminder: 'Meeting tomorrow 2pm'"
            }
          />
        </View>

        {/* Main Navigation and Views */}
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
    backgroundColor: Colors.dark.background,
  },
  content: {
    flex: 1,
  },
  inputSection: {
    paddingHorizontal: 16,
    paddingVertical: 12,
    backgroundColor: Colors.dark.surface,
    borderBottomWidth: 1,
    borderBottomColor: Colors.dark.border,
  },
});
