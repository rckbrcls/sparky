import React, { useMemo, useState } from "react";
import { ActivityIndicator, Platform, Text, TextInput, TouchableOpacity, View } from "react-native";
import { BottomSheetModal, BottomSheetScrollView, BottomSheetView } from "@gorhom/bottom-sheet";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import DateTimePicker from "@react-native-community/datetimepicker";

import { Colors } from "@/src/constants/Colors";
import { AppIcon } from "@/src/components/AppIcon";

import type { CreateReminderSheetProps, ReminderType } from "./types";
import { styles } from "./styles";

export const CreateReminderSheet: React.FC<CreateReminderSheetProps> = ({
  sheetRef,
  snapPoints,
  renderBackdrop,
  onDismiss,
  onClose,
  onCreate,
}) => {
  const insets = useSafeAreaInsets();
  const [title, setTitle] = useState("");
  const [saving, setSaving] = useState(false);
  const [type, setType] = useState<ReminderType>("once");
  const [notes, setNotes] = useState("");
  const [person, setPerson] = useState("");
  const [project, setProject] = useState("");
  const [location, setLocation] = useState("");
  const [date, setDate] = useState<Date | null>(null);
  const [time, setTime] = useState<Date | null>(null);
  const [showDatePicker, setShowDatePicker] = useState(false);
  const [showTimePicker, setShowTimePicker] = useState(false);
  const [recurrence, setRecurrence] = useState<"daily" | "weekly" | "monthly" | null>(null);
  const [recurrenceTime, setRecurrenceTime] = useState<Date | null>(null);
  const [showRecurrenceTimePicker, setShowRecurrenceTimePicker] = useState(false);

  const canCreate = useMemo(() => !!title.trim(), [title]);

  const combineDateTime = (d: Date | null, t: Date | null): Date | undefined => {
    if (!d || !t) return undefined;
    const merged = new Date(d);
    merged.setHours(t.getHours(), t.getMinutes(), 0, 0);
    return merged;
  };

  const buildRRule = (): string | undefined => {
    if (!recurrence) return undefined;
    const dt = recurrenceTime ?? new Date();
    const hour = dt.getHours();
    const minute = dt.getMinutes();
    const base = `BYHOUR=${hour};BYMINUTE=${minute}`;
    if (recurrence === "daily") return `FREQ=DAILY;${base}`;
    if (recurrence === "weekly") return `FREQ=WEEKLY;${base}`;
    if (recurrence === "monthly") return `FREQ=MONTHLY;${base}`;
    return undefined;
  };

  const handleCancel = () => {
    if (saving) return;
    onClose();
  };

  const handleCreate = async () => {
    if (!canCreate || saving) return;
    try {
      setSaving(true);
      const input: any = { title: title.trim(), type };
      if (notes.trim()) input.notes = notes.trim();
      if (type === "once") {
        const fireAt = combineDateTime(date, time);
        if (fireAt) input.fireAt = fireAt;
      } else if (type === "recurring") {
        const r = buildRRule();
        if (r) input.rrule = r;
      } else if (type === "by_person_project") {
        if (person.trim()) input.person = person.trim();
        if (project.trim()) input.project = project.trim();
      } else if (type === "by_location") {
        if (location.trim()) input.location = location.trim();
      }

      await Promise.resolve(onCreate(input));
      setTitle("");
      setNotes("");
      setPerson("");
      setProject("");
      setLocation("");
      setDate(null);
      setTime(null);
      setRecurrence(null);
      setRecurrenceTime(null);
    } finally {
      setSaving(false);
    }
  };

  return (
    <BottomSheetModal
      ref={sheetRef}
      snapPoints={snapPoints}
      enablePanDownToClose
      backdropComponent={renderBackdrop}
      android_keyboardInputMode="adjustResize"
      backgroundStyle={styles.sheetBackground}
      handleStyle={styles.sheetHandle}
      handleIndicatorStyle={styles.sheetHandleIndicator}
      onDismiss={onDismiss}
    >
      <BottomSheetView style={[styles.container, { paddingBottom: Math.max(24, 12 + insets.bottom) }]}>
        <BottomSheetScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled" showsVerticalScrollIndicator={false}>
          <View style={styles.topBar}>
            <View style={styles.heroBadge}>
              <View style={styles.heroIconWrap}>
                <AppIcon icon="clock" size={16} color={Colors.dark.background} />
              </View>
              <Text style={styles.heroBadgeText}>New reminder</Text>
            </View>
            <TouchableOpacity style={styles.closeButton} onPress={handleCancel} disabled={saving}>
              <AppIcon icon="close" size={20} color={Colors.dark.muted} />
            </TouchableOpacity>
          </View>
          <Text style={styles.title}>Create reminder</Text>
          <Text style={styles.subtitle}>Set type, time and details.</Text>

          <View style={styles.section}>
            <Text style={styles.label}>Title</Text>
            <TextInput
              style={styles.input}
              value={title}
              onChangeText={setTitle}
              placeholder="Call mom"
              placeholderTextColor={Colors.dark.muted}
              editable={!saving}
            />
          </View>

          <View style={styles.section}>
            <Text style={styles.label}>Type</Text>
            <View style={styles.chipRow}>
              {([
                { key: "once", label: "Once" },
                { key: "recurring", label: "Recurring" },
                { key: "by_person_project", label: "By person/project" },
                { key: "by_location", label: "By location" },
              ] as { key: ReminderType; label: string }[]).map((opt) => {
                const active = type === opt.key;
                return (
                  <TouchableOpacity
                    key={opt.key}
                    style={[styles.chip, active && styles.chipActive]}
                    onPress={() => setType(opt.key)}
                    disabled={saving}
                  >
                    <Text style={[styles.chipText, active && styles.chipTextActive]}>
                      {opt.label}
                    </Text>
                  </TouchableOpacity>
                );
              })}
            </View>
          </View>

          {type === "once" && (
            <View style={styles.section}>
              <Text style={styles.label}>Date & Time</Text>
              {Platform.OS === "ios" ? (
                <View style={styles.chipRow}>
                  <DateTimePicker
                    value={date ?? new Date()}
                    mode="date"
                    display="compact"
                    onChange={(_, d) => {
                      if (d) setDate(d);
                    }}
                  />
                  <DateTimePicker
                    value={time ?? new Date()}
                    mode="time"
                    display="compact"
                    onChange={(_, d) => {
                      if (d) setTime(d);
                    }}
                  />
                </View>
              ) : (
                <>
                  <View style={styles.chipRow}>
                    <TouchableOpacity
                      style={styles.chip}
                      onPress={() => setShowDatePicker(true)}
                      disabled={saving}
                    >
                      <Text style={styles.chipText}>{date ? date.toDateString() : "Pick date"}</Text>
                    </TouchableOpacity>
                    <TouchableOpacity
                      style={styles.chip}
                      onPress={() => setShowTimePicker(true)}
                      disabled={saving}
                    >
                      <Text style={styles.chipText}>
                        {time ? `${String(time.getHours()).padStart(2, "0")}:${String(time.getMinutes()).padStart(2, "0")}` : "Pick time"}
                      </Text>
                    </TouchableOpacity>
                  </View>
                  {showDatePicker && (
                    <DateTimePicker
                      value={date ?? new Date()}
                      mode="date"
                      display="default"
                      onChange={(_, d) => {
                        setShowDatePicker(false);
                        if (d) setDate(d);
                      }}
                    />
                  )}
                  {showTimePicker && (
                    <DateTimePicker
                      value={time ?? new Date()}
                      mode="time"
                      display="default"
                      onChange={(_, d) => {
                        setShowTimePicker(false);
                        if (d) setTime(d);
                      }}
                    />
                  )}
                </>
              )}
            </View>
          )}

          {type === "recurring" && (
            <View style={styles.section}>
              <Text style={styles.label}>Recurrence</Text>
              <View style={styles.chipRow}>
                {(["daily", "weekly", "monthly"] as const).map((opt) => {
                  const active = recurrence === opt;
                  return (
                    <TouchableOpacity
                      key={opt}
                      style={[styles.chip, active && styles.chipActive]}
                      onPress={() => setRecurrence(opt)}
                      disabled={saving}
                    >
                      <Text style={[styles.chipText, active && styles.chipTextActive]}>
                        {opt[0].toUpperCase() + opt.slice(1)}
                      </Text>
                    </TouchableOpacity>
                  );
                })}
                {Platform.OS === "ios" ? (
                  <DateTimePicker
                    value={recurrenceTime ?? new Date()}
                    mode="time"
                    display="compact"
                    onChange={(_, d) => {
                      if (d) setRecurrenceTime(d);
                    }}
                  />
                ) : (
                  <TouchableOpacity
                    style={styles.chip}
                    onPress={() => setShowRecurrenceTimePicker(true)}
                  >
                    <Text style={styles.chipText}>
                      {recurrenceTime
                        ? `${String(recurrenceTime.getHours()).padStart(2, "0")}:${String(
                            recurrenceTime.getMinutes()
                          ).padStart(2, "0")}`
                        : "Pick time"}
                    </Text>
                  </TouchableOpacity>
                )}
              </View>
              {Platform.OS !== "ios" && showRecurrenceTimePicker && (
                <DateTimePicker
                  value={recurrenceTime ?? new Date()}
                  mode="time"
                  display="default"
                  onChange={(_, d) => {
                    setShowRecurrenceTimePicker(false);
                    if (d) setRecurrenceTime(d);
                  }}
                />
              )}
            </View>
          )}

          {type === "by_person_project" && (
            <View style={styles.section}>
              <Text style={styles.label}>Person / Project</Text>
              <TextInput
                style={[styles.input, { marginBottom: 10 }]}
                value={person}
                onChangeText={setPerson}
                placeholder="Person"
                placeholderTextColor={Colors.dark.muted}
                editable={!saving}
              />
              <TextInput
                style={styles.input}
                value={project}
                onChangeText={setProject}
                placeholder="Project"
                placeholderTextColor={Colors.dark.muted}
                editable={!saving}
              />
            </View>
          )}

          {type === "by_location" && (
            <View style={styles.section}>
              <Text style={styles.label}>Location</Text>
              <TextInput
                style={styles.input}
                value={location}
                onChangeText={setLocation}
                placeholder="e.g. Grocery store"
                placeholderTextColor={Colors.dark.muted}
                editable={!saving}
              />
            </View>
          )}

          <View style={styles.section}>
            <Text style={styles.label}>Notes</Text>
            <TextInput
              style={styles.input}
              value={notes}
              onChangeText={setNotes}
              placeholder="Optional notes"
              placeholderTextColor={Colors.dark.muted}
              editable={!saving}
            />
          </View>
        </BottomSheetScrollView>
        <View style={styles.footerActions}>
          <TouchableOpacity style={styles.cancelButton} onPress={handleCancel} disabled={saving}>
            <Text style={styles.cancelText}>Cancel</Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={[styles.createButton, (!canCreate || saving) && styles.createButtonDisabled]}
            onPress={handleCreate}
            disabled={!canCreate || saving}
          >
            {saving ? (
              <ActivityIndicator size="small" color={Colors.dark.background} />
            ) : (
              <Text style={styles.createText}>Create reminder</Text>
            )}
          </TouchableOpacity>
        </View>
      </BottomSheetView>
    </BottomSheetModal>
  );
};
