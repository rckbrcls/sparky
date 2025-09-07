import React, { useState } from "react";
import {
  Alert,
  Animated,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from "react-native";
import { Colors } from "../constants/Colors";
import { Typography } from "../constants/Typography";
import { database } from "../database/database";
import { ReminderService } from "../services/ReminderService";
import { ParsedReminder, SmartTextParser } from "../services/SmartTextParser";

interface SmartInputProps {
  onReminderCreated: () => void;
  placeholder?: string;
  style?: any;
}

export const SmartInput: React.FC<SmartInputProps> = ({
  onReminderCreated,
  placeholder = "Add reminder...",
  style,
}) => {
  const [text, setText] = useState("");
  const [isProcessing, setIsProcessing] = useState(false);
  const [preview, setPreview] = useState<ParsedReminder | null>(null);
  const fadeAnim = new Animated.Value(0);

  const handleTextChange = (newText: string) => {
    setText(newText);

    if (newText.trim().length > 3) {
      const parsed = SmartTextParser.parseText(newText);
      setPreview(parsed);

      // Animate preview appearance
      Animated.timing(fadeAnim, {
        toValue: 1,
        duration: 200,
        useNativeDriver: true,
      }).start();
    } else {
      setPreview(null);
      Animated.timing(fadeAnim, {
        toValue: 0,
        duration: 200,
        useNativeDriver: true,
      }).start();
    }
  };

  const handleSubmit = async () => {
    if (!text.trim()) return;

    setIsProcessing(true);

    try {
      const parsed = SmartTextParser.parseText(text);

      if (parsed.type === "note") {
        // Create quick note
        await database.createQuickNote({
          content: parsed.title,
          folderId: parsed.folderId,
          tags: JSON.stringify(parsed.tags),
          isPinned: parsed.priority === 3,
        });
      } else {
        // Create reminder
        await ReminderService.createReminder({
          title: parsed.title,
          person: parsed.person,
          project: parsed.project,
          location: parsed.location,
          type:
            parsed.type === "date"
              ? "once"
              : parsed.triggerType === "location"
              ? "by_location"
              : "by_person_project",
          fireAt: parsed.fireAt,
        });

        // Create triggers if needed
        if (parsed.type === "trigger" && parsed.triggerConfig) {
          // This would need the reminder ID, so we'd need to modify the service
          // For now, we'll handle triggers in the ReminderService
        }
      }

      setText("");
      setPreview(null);
      onReminderCreated();

      // Success feedback
      Animated.sequence([
        Animated.timing(fadeAnim, {
          toValue: 0,
          duration: 100,
          useNativeDriver: true,
        }),
        Animated.timing(fadeAnim, {
          toValue: 1,
          duration: 100,
          useNativeDriver: true,
        }),
        Animated.timing(fadeAnim, {
          toValue: 0,
          duration: 100,
          useNativeDriver: true,
        }),
      ]).start();
    } catch (error) {
      console.error("Error creating reminder:", error);
      Alert.alert("Error", "Failed to create reminder");
    } finally {
      setIsProcessing(false);
    }
  };

  const getTypeIcon = (type: string, triggerType?: string) => {
    if (type === "date") return "⏰";
    if (type === "note") return "📝";
    if (triggerType === "person") return "👤";
    if (triggerType === "location") return "📍";
    return "📋";
  };

  const getTypeLabel = (type: string, triggerType?: string) => {
    if (type === "date") return "Date Reminder";
    if (type === "note") return "Quick Note";
    if (triggerType === "person") return "Person Trigger";
    if (triggerType === "location") return "Location Trigger";
    return "General Reminder";
  };

  const getPriorityColor = (priority: number) => {
    switch (priority) {
      case 3:
        return Colors.dark.error; // High priority
      case 2:
        return Colors.dark.warning; // Medium priority
      case 1:
        return Colors.dark.success; // Low priority
      default:
        return Colors.dark.muted;
    }
  };

  return (
    <View style={[styles.container, style]}>
      <View style={styles.inputContainer}>
        <TextInput
          style={styles.input}
          value={text}
          onChangeText={handleTextChange}
          placeholder={placeholder}
          placeholderTextColor={Colors.dark.muted}
          multiline
          returnKeyType="done"
          onSubmitEditing={handleSubmit}
          editable={!isProcessing}
        />

        {text.trim().length > 0 && (
          <TouchableOpacity
            style={[
              styles.submitButton,
              isProcessing && styles.submitButtonDisabled,
            ]}
            onPress={handleSubmit}
            disabled={isProcessing}
          >
            <Text style={styles.submitButtonText}>
              {isProcessing ? "⏳" : "✓"}
            </Text>
          </TouchableOpacity>
        )}
      </View>

      {preview && (
        <Animated.View style={[styles.preview, { opacity: fadeAnim }]}>
          <View style={styles.previewHeader}>
            <Text style={styles.previewIcon}>
              {getTypeIcon(preview.type, preview.triggerType)}
            </Text>
            <Text style={styles.previewType}>
              {getTypeLabel(preview.type, preview.triggerType)}
            </Text>
            <View
              style={[
                styles.priorityIndicator,
                { backgroundColor: getPriorityColor(preview.priority) },
              ]}
            />
          </View>

          <Text style={styles.previewTitle}>{preview.title}</Text>

          {preview.fireAt && (
            <Text style={styles.previewDetail}>
              📅 {preview.fireAt.toLocaleDateString()}{" "}
              {preview.fireAt.toLocaleTimeString([], {
                hour: "2-digit",
                minute: "2-digit",
              })}
            </Text>
          )}

          {preview.person && (
            <Text style={styles.previewDetail}>👤 {preview.person}</Text>
          )}

          {preview.location && (
            <Text style={styles.previewDetail}>📍 {preview.location}</Text>
          )}

          {preview.project && (
            <Text style={styles.previewDetail}>🏷️ {preview.project}</Text>
          )}

          {preview.tags.length > 0 && (
            <Text style={styles.previewDetail}>
              🏷️ {preview.tags.map((tag) => `#${tag}`).join(" ")}
            </Text>
          )}
        </Animated.View>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    marginVertical: 8,
  },
  inputContainer: {
    flexDirection: "row",
    alignItems: "flex-end",
    backgroundColor: Colors.dark.surface,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: Colors.dark.border,
    paddingHorizontal: 16,
    paddingVertical: 12,
    minHeight: 48,
  },
  input: {
    ...Typography.body,
    flex: 1,
    color: Colors.dark.text,
    maxHeight: 120,
  },
  submitButton: {
    marginLeft: 12,
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: Colors.dark.tint,
    alignItems: "center",
    justifyContent: "center",
  },
  submitButtonDisabled: {
    backgroundColor: Colors.dark.muted,
  },
  submitButtonText: {
    ...Typography.body,
    color: Colors.dark.background,
    fontWeight: "600",
  },
  preview: {
    marginTop: 8,
    backgroundColor: Colors.dark.surface,
    borderRadius: 8,
    padding: 12,
    borderWidth: 1,
    borderColor: Colors.dark.border,
  },
  previewHeader: {
    flexDirection: "row",
    alignItems: "center",
    marginBottom: 8,
  },
  previewIcon: {
    fontSize: 16,
    marginRight: 8,
  },
  previewType: {
    ...Typography.caption,
    color: Colors.dark.muted,
    flex: 1,
  },
  priorityIndicator: {
    width: 8,
    height: 8,
    borderRadius: 4,
  },
  previewTitle: {
    ...Typography.body,
    color: Colors.dark.text,
    fontWeight: "600",
    marginBottom: 4,
  },
  previewDetail: {
    ...Typography.caption,
    color: Colors.dark.muted,
    marginVertical: 1,
  },
});
