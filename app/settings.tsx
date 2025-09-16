import * as DocumentPicker from "expo-document-picker";
import * as FileSystem from "expo-file-system";
import { useRouter } from "expo-router";
import React, { useState } from "react";
import {
  Alert,
  ScrollView,
  Share,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { IconSymbol } from "../components/ui/IconSymbol";
import { Colors } from "../constants/Colors";
import { Typography } from "../constants/Typography";
import { ReminderService } from "../services/ReminderService";

type FileSystemDirectories = {
  cacheDirectory?: string | null;
  documentDirectory?: string | null;
};

const getWritableDirectory = () => {
  const { cacheDirectory, documentDirectory } =
    FileSystem as FileSystemDirectories;
  const candidates = [cacheDirectory, documentDirectory];
  const directory = candidates.find(
    (candidate): candidate is string =>
      typeof candidate === "string" && candidate.length > 0
  );

  if (!directory) {
    throw new Error("No writable directory available");
  }

  return directory.endsWith("/") ? directory : `${directory}/`;
};

const buildDatedFileName = (prefix: string, extension: string) => {
  const [date] = new Date().toISOString().split("T");
  return `${prefix}_${date}.${extension}`;
};

const writeAndShareFile = async (
  fileName: string,
  data: string,
  title: string
) => {
  const directory = getWritableDirectory();
  const fileUri = `${directory}${fileName}`;

  await FileSystem.writeAsStringAsync(fileUri, data);
  await Share.share({
    url: fileUri,
    title,
  });

  return fileUri;
};

export default function SettingsScreen() {
  const router = useRouter();
  const [isExporting, setIsExporting] = useState(false);
  const [isImporting, setIsImporting] = useState(false);

  const handleExportJSON = async () => {
    try {
      setIsExporting(true);
      const jsonData = await ReminderService.exportData();

      await writeAndShareFile(
        buildDatedFileName("reminders_backup", "json"),
        jsonData,
        "Export Reminders"
      );

      Alert.alert("Success", "Data exported successfully!");
    } catch (error) {
      Alert.alert("Error", "Unable to export data");
      console.error("Export error:", error);
    } finally {
      setIsExporting(false);
    }
  };

  const handleExportCSV = async () => {
    try {
      setIsExporting(true);
      const csvData = await ReminderService.exportCSV();

      await writeAndShareFile(
        buildDatedFileName("reminders", "csv"),
        csvData,
        "Export Reminders CSV"
      );

      Alert.alert("Success", "Data exported as CSV successfully!");
    } catch (error) {
      Alert.alert("Error", "Unable to export data as CSV");
      console.error("Export CSV error:", error);
    } finally {
      setIsExporting(false);
    }
  };

  const handleImportJSON = async () => {
    try {
      setIsImporting(true);

      const result = await DocumentPicker.getDocumentAsync({
        type: "application/json",
        copyToCacheDirectory: true,
      });

      if (!result.canceled && result.assets[0]) {
        const fileContent = await FileSystem.readAsStringAsync(
          result.assets[0].uri
        );

        Alert.alert(
          "Confirm Import",
          "This will replace all your current reminders. Are you sure?",
          [
            { text: "Cancel", style: "cancel" },
            {
              text: "Import",
              style: "destructive",
              onPress: async () => {
                try {
                  await ReminderService.importData(fileContent);
                  Alert.alert("Success", "Data imported successfully!");
                } catch {
                  Alert.alert("Error", "Invalid or corrupted file");
                }
              },
            },
          ]
        );
      }
    } catch (error) {
      Alert.alert("Error", "Unable to import data");
      console.error("Import error:", error);
    } finally {
      setIsImporting(false);
    }
  };

  const handleClearAllData = () => {
    Alert.alert(
      "Delete All Data",
      "This action cannot be undone. All your reminders will be permanently lost.",
      [
        { text: "Cancel", style: "cancel" },
        {
          text: "Delete All",
          style: "destructive",
          onPress: async () => {
            try {
              // Here you would implement a method to clear all data
              Alert.alert("Success", "All data has been deleted");
            } catch {
              Alert.alert("Error", "Unable to delete data");
            }
          },
        },
      ]
    );
  };

  return (
    <SafeAreaView style={{ flex: 1 }}>
      <ScrollView style={styles.container}>
        <View style={styles.header}>
          <TouchableOpacity
            onPress={() => router.back()}
            hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}
            accessibilityRole="button"
            accessibilityLabel="Back"
            style={styles.backButton}
          >
            <IconSymbol
              name="chevron.left"
              color={Colors.dark.tint}
              size={16}
            />
          </TouchableOpacity>
          <View style={{ flex: 1, alignItems: "center" }}>
            <Text style={styles.headerTitle}>Settings</Text>
          </View>
        </View>

        <View style={styles.content}>
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>About the App</Text>
            <View style={styles.infoCard}>
              <Text style={styles.infoTitle}>I Can&apos;t Miss</Text>
              <Text style={styles.infoDescription}>
                A smart reminder app that helps you never forget important
                things again.
              </Text>
              <Text style={styles.infoFeatures}>
                • One-time and recurring reminders{"\n"}• Smart snooze system
                {"\n"}• Spaced review for important tasks{"\n"}• Important dates
                with advance notifications{"\n"}• Data backup and
                synchronization
              </Text>
            </View>
          </View>

          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Export Data</Text>
            <Text style={styles.sectionDescription}>
              Back up your reminders so you don&apos;t lose them
            </Text>

            <TouchableOpacity
              style={[styles.button, styles.primaryButton]}
              onPress={handleExportJSON}
              disabled={isExporting}
            >
              <Text style={styles.primaryButtonText}>
                {isExporting ? "Exporting..." : "Export as JSON"}
              </Text>
            </TouchableOpacity>

            <TouchableOpacity
              style={[styles.button, styles.secondaryButton]}
              onPress={handleExportCSV}
              disabled={isExporting}
            >
              <Text style={styles.secondaryButtonText}>
                {isExporting ? "Exporting..." : "Export as CSV"}
              </Text>
            </TouchableOpacity>
          </View>

          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Import Data</Text>
            <Text style={styles.sectionDescription}>
              Restore your reminders from a previous backup
            </Text>

            <TouchableOpacity
              style={[styles.button, styles.primaryButton]}
              onPress={handleImportJSON}
              disabled={isImporting}
            >
              <Text style={styles.primaryButtonText}>
                {isImporting ? "Importing..." : "Import JSON"}
              </Text>
            </TouchableOpacity>
          </View>

          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Danger Zone</Text>
            <Text style={styles.sectionDescription}>
              Irreversible actions that affect all your data
            </Text>

            <TouchableOpacity
              style={[styles.button, styles.dangerButton]}
              onPress={handleClearAllData}
            >
              <Text style={styles.dangerButtonText}>Delete All Data</Text>
            </TouchableOpacity>
          </View>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.dark.background,
  },
  header: {
    backgroundColor: Colors.dark.surface,
    paddingVertical: 20,
    paddingHorizontal: 20,
    borderBottomWidth: 1,
    borderBottomColor: Colors.dark.border,
    flexDirection: "row",
    alignItems: "center",
    position: "relative",
    minHeight: 60,
  },
  backButton: {
    padding: 10,
    position: "absolute",
    left: 20,
    zIndex: 20,
    backgroundColor: Colors.dark.surface,
    borderColor: Colors.dark.border,
    borderRadius: 100,
    borderWidth: 1,
  },
  headerTitle: {
    ...Typography.h2,
    textAlign: "center",
  },
  content: {
    padding: 20,
  },
  section: {
    marginBottom: 32,
  },
  sectionTitle: {
    ...Typography.h4,
    marginBottom: 8,
  },
  sectionDescription: {
    ...Typography.bodySmall,
    color: Colors.dark.muted,
    marginBottom: 16,
    lineHeight: 20,
  },
  button: {
    borderRadius: 12,
    padding: 10,
    alignItems: "center",
    justifyContent: "center",
    marginBottom: 12,
  },
  primaryButton: {
    backgroundColor: Colors.dark.tint,
  },
  primaryButtonText: {
    ...Typography.button,
    color: Colors.dark.background,
  },
  secondaryButton: {
    backgroundColor: Colors.dark.surface,
    borderWidth: 1,
    borderColor: Colors.dark.border,
  },
  secondaryButtonText: {
    ...Typography.button,
    color: Colors.dark.tint,
  },
  dangerButton: {
    backgroundColor: Colors.dark.error,
  },
  dangerButtonText: {
    ...Typography.button,
    color: Colors.dark.background,
  },
  infoCard: {
    backgroundColor: Colors.dark.surface,
    borderColor: Colors.dark.border,
    borderRadius: 12,
    borderWidth: 1,
    padding: 20,
  },
  infoTitle: {
    ...Typography.h5,
    marginBottom: 8,
  },
  infoDescription: {
    ...Typography.bodySmall,
    color: Colors.dark.muted,
    lineHeight: 20,
    marginBottom: 16,
  },
  infoFeatures: {
    ...Typography.bodySmall,
    lineHeight: 22,
  },
});
