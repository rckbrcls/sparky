import React, { useState } from 'react';
import {
  View,
  Text,
  TextInput,
  StyleSheet,
  TouchableOpacity,
  ScrollView,
  Alert,
  Switch,
} from 'react-native';
import DateTimePicker from '@react-native-community/datetimepicker';
import { ReminderService } from '../services/ReminderService';

interface ReminderFormProps {
  onSave: () => void;
  onCancel: () => void;
}

export const ReminderForm: React.FC<ReminderFormProps> = ({ onSave, onCancel }) => {
  const [title, setTitle] = useState('');
  const [notes, setNotes] = useState('');
  const [person, setPerson] = useState('');
  const [project, setProject] = useState('');
  const [location, setLocation] = useState('');
  const [type] = useState<'once' | 'recurring' | 'by_person_project' | 'by_location'>('once');
  const [fireAt, setFireAt] = useState<Date | undefined>(new Date());
  const [showDatePicker, setShowDatePicker] = useState(false);
  const [isRecurring, setIsRecurring] = useState(false);

  const handleSave = async () => {
    if (!title.trim()) {
      Alert.alert('Error', 'Title is required');
      return;
    }

    try {
      await ReminderService.createReminder({
        title: title.trim(),
        notes: notes.trim() || undefined,
        person: person.trim() || undefined,
        project: project.trim() || undefined,
        location: location.trim() || undefined,
        type: isRecurring ? 'recurring' : type,
        rrule: isRecurring ? generateRRule() : undefined,
        fireAt,
      });

      onSave();
    } catch {
      Alert.alert('Error', 'Unable to save reminder');
    }
  };

  const generateRRule = () => {
    // Simple daily recurrence for now
    // In a real app, you'd have a more sophisticated RRULE builder
    return 'FREQ=DAILY;INTERVAL=1';
  };

  const formatDate = (date: Date) => {
    return date.toLocaleDateString('pt-BR') + ' ' + date.toLocaleTimeString('pt-BR', {
      hour: '2-digit',
      minute: '2-digit',
    });
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
              trackColor={{ false: '#E9ECEF', true: '#339AF0' }}
              thumbColor={isRecurring ? '#FFFFFF' : '#ADB5BD'}
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
                {fireAt ? formatDate(fireAt) : 'Select date and time'}
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
    backgroundColor: '#F8F9FA',
  },
  header: {
    backgroundColor: '#FFFFFF',
    padding: 20,
    borderBottomWidth: 1,
    borderBottomColor: '#E9ECEF',
  },
  headerTitle: {
    fontSize: 24,
    fontWeight: '600',
    color: '#1A1A1A',
    textAlign: 'center',
  },
  form: {
    padding: 20,
  },
  field: {
    marginBottom: 20,
  },
  label: {
    fontSize: 16,
    fontWeight: '500',
    color: '#343A40',
    marginBottom: 8,
  },
  input: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    padding: 16,
    fontSize: 16,
    borderWidth: 1,
    borderColor: '#DEE2E6',
    color: '#1A1A1A',
  },
  textArea: {
    height: 100,
    textAlignVertical: 'top',
  },
  switchRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  dateButton: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    padding: 16,
    borderWidth: 1,
    borderColor: '#DEE2E6',
  },
  dateButtonText: {
    fontSize: 16,
    color: '#343A40',
  },
  actions: {
    flexDirection: 'row',
    gap: 12,
    marginTop: 20,
  },
  cancelButton: {
    flex: 1,
    backgroundColor: '#6C757D',
    borderRadius: 12,
    padding: 16,
    alignItems: 'center',
  },
  cancelButtonText: {
    fontSize: 16,
    fontWeight: '600',
    color: '#FFFFFF',
  },
  saveButton: {
    flex: 1,
    backgroundColor: '#339AF0',
    borderRadius: 12,
    padding: 16,
    alignItems: 'center',
  },
  saveButtonText: {
    fontSize: 16,
    fontWeight: '600',
    color: '#FFFFFF',
  },
});
