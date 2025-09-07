import DateTimePicker from "@react-native-community/datetimepicker";
import React, { useState } from "react";
import {
  Alert,
  ScrollView,
  StyleSheet,
  Switch,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from "react-native";
import { Colors } from "../constants/Colors";
import { Typography } from "../constants/Typography";
import { ReminderService } from "../services/ReminderService";

interface ReminderFormProps {
  onSave: () => void;
  onCancel: () => void;
}

export const ReminderForm: React.FC<ReminderFormProps> = ({
  onSave,
  onCancel,
}) => {
  const [title, setTitle] = useState("");
  const [notes, setNotes] = useState("");
  const [person, setPerson] = useState("");
  const [project, setProject] = useState("");
  const [location, setLocation] = useState("");
  const [type] = useState<
    "once" | "recurring" | "by_person_project" | "by_location"
  >("once");
  const [fireAt, setFireAt] = useState<Date | undefined>(new Date());
  const [showDatePicker, setShowDatePicker] = useState(false);
  const [isRecurring, setIsRecurring] = useState(false);

  const handleSave = async () => {
    if (!title.trim()) {
      Alert.alert("Error", "Title is required");
      return;
    }

    try {
      await ReminderService.createReminder({
        title: title.trim(),
        notes: notes.trim() || undefined,
        person: person.trim() || undefined,
        project: project.trim() || undefined,
        location: location.trim() || undefined,
        type: isRecurring ? "recurring" : type,
        rrule: isRecurring ? generateRRule() : undefined,
        fireAt,
      });

      onSave();
    } catch {
      Alert.alert("Error", "Unable to save reminder");
    }
  };

  const generateRRule = () => {
    // Simple daily recurrence for now
    // In a real app, you'd have a more sophisticated RRULE builder
    return "FREQ=DAILY;INTERVAL=1";
  };

  const formatDate = (date: Date) => {
    return (
      date.toLocaleDateString("pt-BR") +
      " " +
      date.toLocaleTimeString("pt-BR", {
        hour: "2-digit",
        minute: "2-digit",
      })
    );
  };

  return (
    <ScrollView style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.headerTitle}>New Reminder</Text>
      </View>

      <View style={styles.form}>
        <View style={styles.field}>
          <Text style={styles.label}>Title *</Text>
          <TextInput
            style={styles.input}
            value={title}
            onChangeText={setTitle}
            placeholder="Enter reminder title"
            maxLength={100}
          />
        </View>

        <View style={styles.field}>
          <Text style={styles.label}>Notes</Text>
          <TextInput
            style={[styles.input, styles.textArea]}
            value={notes}
            onChangeText={setNotes}
            placeholder="Add more details (optional)"
            multiline
            numberOfLines={4}
            maxLength={500}
          />
        </View>

        <View style={styles.field}>
          <Text style={styles.label}>Person</Text>
          <TextInput
            style={styles.input}
            value={person}
            onChangeText={setPerson}
            placeholder="Related person (optional)"
            maxLength={50}
          />
        </View>

        <View style={styles.field}>
          <Text style={styles.label}>Project</Text>
          <TextInput
            style={styles.input}
            value={project}
            onChangeText={setProject}
            placeholder="Related project (optional)"
            maxLength={50}
          />
        </View>

        <View style={styles.field}>
          <Text style={styles.label}>Location</Text>
          <TextInput
            style={styles.input}
            value={location}
            onChangeText={setLocation}
            placeholder="Related location (optional)"
            maxLength={100}
          />
        </View>

        <View style={styles.field}>
          <View style={styles.switchRow}>
            <Text style={styles.label}>Recurring reminder</Text>
            <Switch
              value={isRecurring}
              onValueChange={setIsRecurring}
              trackColor={{ false: Colors.dark.border, true: Colors.dark.tint }}
              thumbColor={
                isRecurring ? Colors.dark.background : Colors.dark.muted
              }
            />
          </View>
        </View>

        {!isRecurring && (
          <View style={styles.field}>
            <Text style={styles.label}>Date and Time</Text>
            <TouchableOpacity
              style={styles.dateButton}
              onPress={() => setShowDatePicker(true)}
            >
              <Text style={styles.dateButtonText}>
                {fireAt ? formatDate(fireAt) : "Select date and time"}
              </Text>
            </TouchableOpacity>
          </View>
        )}

        {showDatePicker && (
          <DateTimePicker
            value={fireAt || new Date()}
            mode="datetime"
            display="default"
            onChange={(_event: any, selectedDate: any) => {
              setShowDatePicker(false);
              if (selectedDate) {
                setFireAt(selectedDate);
              }
            }}
          />
        )}

        <View style={styles.actions}>
          <TouchableOpacity style={styles.cancelButton} onPress={onCancel}>
            <Text style={styles.cancelButtonText}>Cancel</Text>
          </TouchableOpacity>

          <TouchableOpacity style={styles.saveButton} onPress={handleSave}>
            <Text style={styles.saveButtonText}>Save</Text>
          </TouchableOpacity>
        </View>
      </View>
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.dark.background,
  },
  header: {
    backgroundColor: Colors.dark.surface,
    padding: 20,
    borderBottomWidth: 1,
    borderBottomColor: Colors.dark.border,
  },
  headerTitle: {
    ...Typography.h3,
    textAlign: "center",
  },
  form: {
    padding: 20,
  },
  field: {
    marginBottom: 20,
  },
  label: {
    ...Typography.h6,
    marginBottom: 8,
  },
  input: {
    ...Typography.input,
    backgroundColor: Colors.dark.surface,
    borderRadius: 12,
    padding: 16,
    borderWidth: 1,
    borderColor: Colors.dark.border,
  },
  textArea: {
    height: 100,
    textAlignVertical: "top",
  },
  switchRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
  },
  dateButton: {
    backgroundColor: Colors.dark.surface,
    borderRadius: 12,
    padding: 16,
    borderWidth: 1,
    borderColor: Colors.dark.border,
  },
  dateButtonText: {
    ...Typography.body,
  },
  actions: {
    flexDirection: "row",
    gap: 12,
    marginTop: 20,
  },
  cancelButton: {
    flex: 1,
    backgroundColor: Colors.dark.muted,
    borderRadius: 12,
    padding: 16,
    alignItems: "center",
  },
  cancelButtonText: {
    ...Typography.button,
  },
  saveButton: {
    flex: 1,
    backgroundColor: Colors.dark.tint,
    borderRadius: 12,
    padding: 16,
    alignItems: "center",
  },
  saveButtonText: {
    ...Typography.button,
    color: Colors.dark.background,
  },
});
