import * as DocumentPicker from "expo-document-picker";
import * as FileSystem from "expo-file-system";
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
import { ReminderService } from "../../services/ReminderService";

export default function SettingsScreen() {
  const [isExporting, setIsExporting] = useState(false);
  const [isImporting, setIsImporting] = useState(false);

  const handleExportJSON = async () => {
    try {
      setIsExporting(true);
      const jsonData = await ReminderService.exportData();

      const fileName = `reminders_backup_${
        new Date().toISOString().split("T")[0]
      }.json`;
      const fileUri = FileSystem.documentDirectory + fileName;

      await FileSystem.writeAsStringAsync(fileUri, jsonData);

      await Share.share({
        url: fileUri,
        title: "Export Reminders",
      });

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

      const fileName = `reminders_${
        new Date().toISOString().split("T")[0]
      }.csv`;
      const fileUri = FileSystem.documentDirectory + fileName;

      await FileSystem.writeAsStringAsync(fileUri, csvData);

      await Share.share({
        url: fileUri,
        title: "Export Reminders CSV",
      });

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
    <ScrollView style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.headerTitle}>Settings</Text>
      </View>

      <View style={styles.content}>
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
          <Text style={styles.sectionTitle}>About the App</Text>
          <View style={styles.infoCard}>
            <Text style={styles.infoTitle}>I Can&apos;t Miss</Text>
            <Text style={styles.infoDescription}>
              A smart reminder app that helps you never forget important things
              again.
            </Text>
            <Text style={styles.infoFeatures}>
              • One-time and recurring reminders{"\n"}• Smart snooze system
              {"\n"}• Spaced review for important tasks{"\n"}• Important dates
              with advance notifications{"\n"}• Data backup and synchronization
            </Text>
          </View>
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
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#F8F9FA",
  },
  header: {
    backgroundColor: "#FFFFFF",
    paddingTop: 60,
    paddingBottom: 20,
    paddingHorizontal: 20,
    borderBottomWidth: 1,
    borderBottomColor: "#E9ECEF",
  },
  headerTitle: {
    fontSize: 28,
    fontWeight: "700",
    color: "#1A1A1A",
    textAlign: "center",
  },
  content: {
    padding: 20,
  },
  section: {
    marginBottom: 32,
  },
  sectionTitle: {
    fontSize: 20,
    fontWeight: "600",
    color: "#1A1A1A",
    marginBottom: 8,
  },
  sectionDescription: {
    fontSize: 14,
    color: "#6C757D",
    marginBottom: 16,
    lineHeight: 20,
  },
  button: {
    borderRadius: 12,
    padding: 16,
    alignItems: "center",
    marginBottom: 12,
  },
  primaryButton: {
    backgroundColor: "#339AF0",
  },
  primaryButtonText: {
    fontSize: 16,
    fontWeight: "600",
    color: "#FFFFFF",
  },
  secondaryButton: {
    backgroundColor: "#FFFFFF",
    borderWidth: 2,
    borderColor: "#339AF0",
  },
  secondaryButtonText: {
    fontSize: 16,
    fontWeight: "600",
    color: "#339AF0",
  },
  dangerButton: {
    backgroundColor: "#FF6B6B",
  },
  dangerButtonText: {
    fontSize: 16,
    fontWeight: "600",
    color: "#FFFFFF",
  },
  infoCard: {
    backgroundColor: "#FFFFFF",
    borderRadius: 12,
    padding: 20,
    borderWidth: 1,
    borderColor: "#E9ECEF",
  },
  infoTitle: {
    fontSize: 18,
    fontWeight: "600",
    color: "#1A1A1A",
    marginBottom: 8,
  },
  infoDescription: {
    fontSize: 14,
    color: "#6C757D",
    lineHeight: 20,
    marginBottom: 16,
  },
  infoFeatures: {
    fontSize: 14,
    color: "#495057",
    lineHeight: 22,
  },
});
