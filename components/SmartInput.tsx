import React, { useCallback, useEffect, useMemo, useState } from "react";
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
import {
  applyCommandInsert,
  buildSegments,
  CommandDef,
  detectContext,
  filterCommandList,
  getCommands,
  Segment,
} from "../services/CommandEngine";
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
  const [commandQuery, setCommandQuery] = useState<string | null>(null);
  const [showCommands, setShowCommands] = useState(false);
  const [openBlock, setOpenBlock] = useState<string | null>(null);
  // Dynamic height state (base min 68)
  const [autoHeight, setAutoHeight] = useState<number>(68);
  const BASE_MIN_HEIGHT = 68;
  const BULLET = "•";
  const INDENT = "  ";
  const [selection, setSelection] = useState<{ start: number; end: number }>({ start: 0, end: 0 });

  // Importa engine única
  const COMMANDS = useMemo<CommandDef[]>(() => getCommands(), []);

  const filteredCommands = useMemo(
    () => filterCommandList(COMMANDS, openBlock, commandQuery),
    [COMMANDS, openBlock, commandQuery]
  );

  const updateContext = useCallback((value: string) => {
    const ctx = detectContext(value);
    setOpenBlock(ctx.openBlock);
    setShowCommands(ctx.showCommands);
    setCommandQuery(ctx.query);
  }, []);
  const fadeAnim = React.useRef(new Animated.Value(0)).current;

  // Highlight segments
  const [segments, setSegments] = useState<ReturnType<typeof buildSegments>>(
    []
  );

  // buildSegments já vem do engine único

  const handleTextChange = (newText: string) => {
    setText(newText);
    updateContext(newText);
    setSegments(buildSegments(newText));

    if (newText.trim().length > 3) {
      try {
        const parsed = SmartTextParser.parseText(newText);
        console.log("Parsed text:", parsed);
        setPreview(parsed);

        // Animate preview appearance
        Animated.timing(fadeAnim, {
          toValue: 1,
          duration: 200,
          useNativeDriver: true,
        }).start();
      } catch (error) {
        console.error("Error parsing text:", error);
        setPreview(null);
      }
    } else {
      setPreview(null);
      Animated.timing(fadeAnim, {
        toValue: 0,
        duration: 200,
        useNativeDriver: true,
      }).start();
    }
  };

  const setTextAndSelection = (newValue: string, cursor: number) => {
    setText(newValue);
    // Defer selection update slightly if needed (RN sometimes lags)
    setSelection({ start: cursor, end: cursor });
  };

  const getCurrentLineInfo = (content: string, cursor: number) => {
    const before = content.slice(0, cursor);
    const lineStart = before.lastIndexOf("\n") + 1; // -1 returns 0
    const line = content.slice(lineStart, cursor);
    return { line, lineStart };
  };

  const handleKeyPress = (e: any) => {
    const key = e.nativeEvent.key;
    if (selection.start !== selection.end) return; // ignore range selection for now
    const cursor = selection.start;
    let value = text;

    // TAB => indent or start bullet list
    if (key === 'Tab') {
      e.preventDefault?.();
      const { line } = getCurrentLineInfo(value, cursor);
      let insert = INDENT;
      // If line empty -> start bullet automatically
      if (line.trim().length === 0) {
        insert = `${BULLET} `;
      }
      const newValue = value.slice(0, cursor) + insert + value.slice(cursor);
      setTextAndSelection(newValue, cursor + insert.length);
      return;
    }

  // Enter behavior handled post-change in effect to avoid double newlines
  };

  // Transform start-of-line markers like "- " or "* " into bullet automatically
  useEffect(() => {
    // Only act on latest line
    const { start } = selection;
    const { line, lineStart } = getCurrentLineInfo(text, start);
    if (/^(?:-|\*)\s$/.test(line)) {
      const newValue = text.slice(0, lineStart) + BULLET + ' ' + text.slice(lineStart + line.length);
      const newCursor = lineStart + (BULLET + ' ').length;
      if (newValue !== text) {
        setTextAndSelection(newValue, newCursor);
      }
    }
  }, [text, selection]);

  // Bullet continuation / termination similar to word processors
  const prevTextRef = React.useRef(text);
  const transformingRef = React.useRef(false);
  useEffect(() => {
    if (transformingRef.current) {
      transformingRef.current = false;
      prevTextRef.current = text;
      return;
    }
    const prev = prevTextRef.current;
    if (text.length > prev.length && text.endsWith('\n')) {
      // User pressed Enter
      const beforeNewline = text.slice(0, -1); // remove last \n
      const lines = beforeNewline.split('\n');
      const lastLine = lines[lines.length - 1]; // line before the newline
      const trimmed = lastLine.trim();
      const isBullet = trimmed.startsWith(BULLET);
      if (isBullet) {
        const afterBullet = trimmed.slice(BULLET.length).trim();
        if (afterBullet.length > 0) {
          // Continue list: append bullet to new empty line
            const withNext = text + BULLET + ' ';
            transformingRef.current = true;
            setText(withNext);
            setSelection({ start: withNext.length, end: withNext.length });
        } else {
          // Bullet line was empty -> end list (remove bullet chars from that empty line)
          // Remove previous bullet markers from empty bullet line (replace that entire lastLine with '')
          const cleanedLine = lastLine.replace(/\s*•\s?/, '');
          if (cleanedLine.length === 0) {
            // Replace lines array last element with '' (already empty). Do nothing; just leave blank line.
            // But if we inserted two consecutive Enters, we already have a blank line; nothing to do.
          }
        }
      }
    }
    prevTextRef.current = text;
  }, [text]);

  const handleSelectCommand = (command: any) => {
    const newValue = applyCommandInsert(text, command);
    setText(newValue);
    setShowCommands(false);
    setCommandQuery(null);
  };

  useEffect(() => {
    setSegments(buildSegments(text));
  }, [text]);

  const handleSubmit = async () => {
    if (!text.trim()) return;

    setIsProcessing(true);

    try {
      const parsed = SmartTextParser.parseText(text);
      console.log("Submitting parsed text:", parsed);

      if (parsed.type === "note") {
        // Create quick note
        await database.createQuickNote({
          content: parsed.body ? `${parsed.title}\n${parsed.body}` : parsed.title,
          folderId: parsed.folderId,
          tags: JSON.stringify(parsed.tags),
          isPinned: parsed.priority === 3,
        });
        console.log("Quick note created successfully");
      } else {
        // Create reminder
        const reminderId = await ReminderService.createReminder({
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
        console.log("Reminder created with ID:", reminderId);
        // Create triggers (singular or plural)
        if (parsed.type === "trigger") {
          const triggerPromises: Promise<string>[] = [];
          if (parsed.persons && parsed.persons.length) {
            for (const p of parsed.persons) {
              triggerPromises.push(
                database.createTrigger({
                  reminderId,
                  type: "person",
                  config: JSON.stringify({ contactName: p }),
                  isActive: true,
                })
              );
            }
          } else if (parsed.person) {
            triggerPromises.push(
              database.createTrigger({
                reminderId,
                type: "person",
                config: JSON.stringify({ contactName: parsed.person }),
                isActive: true,
              })
            );
          }
          if (parsed.locations && parsed.locations.length) {
            for (const loc of parsed.locations) {
              triggerPromises.push(
                database.createTrigger({
                  reminderId,
                  type: "location",
                  config: JSON.stringify({ location: loc }),
                  isActive: true,
                })
              );
            }
          } else if (parsed.location) {
            triggerPromises.push(
              database.createTrigger({
                reminderId,
                type: "location",
                config: JSON.stringify({ location: parsed.location }),
                isActive: true,
              })
            );
          }
          await Promise.all(triggerPromises);
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
      const errorMessage =
        error instanceof Error ? error.message : "Erro desconhecido";
      Alert.alert("Erro", `Falha ao criar lembrete: ${errorMessage}`);
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
      <View style={[styles.inputContainer, { minHeight: autoHeight }]}>
        <View style={styles.composedInput}>
          <View style={styles.highlightLayer} pointerEvents="none">
            {text.length === 0 ? (
              <Text
                style={styles.placeholderText}
                onLayout={(e) => {
                  const h = e.nativeEvent.layout.height;
                  setAutoHeight((prev) => Math.max(BASE_MIN_HEIGHT, h + 28)); // padding compensation
                }}
              >
                {placeholder}
              </Text>
            ) : (
              <Text style={styles.highlightText}>
                {segments.map((s: Segment, idx: number) => (
                  <Text
                    key={idx}
                    style={
                      s.kind === "command"
                        ? styles.hlCommand
                        : s.kind === "commandArg"
                        ? styles.hlCommandArg
                        : s.kind === "tag"
                        ? styles.hlTag
                        : styles.hlNormal
                    }
                  >
                    {s.text}
                  </Text>
                ))}
              </Text>
            )}
          </View>
          <TextInput
            style={styles.inputOverlay}
            value={text}
            onChangeText={handleTextChange}
            multiline
            returnKeyType="done"
            onSubmitEditing={handleSubmit}
            editable={!isProcessing}
            onContentSizeChange={(e) => {
              const h = e.nativeEvent.contentSize.height;
              setAutoHeight((prev) =>
                Math.max(BASE_MIN_HEIGHT, Math.min(h + 28, 220))
              ); // cap growth
            }}
            onSelectionChange={(e) => {
              const { start, end } = e.nativeEvent.selection;
              setSelection({ start, end });
            }}
            onKeyPress={handleKeyPress}
            autoCapitalize="none"
            autoCorrect={false}
          />
        </View>

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

      {showCommands && filteredCommands.length > 0 && (
        <View style={styles.commandPalette}>
          {filteredCommands.map((c: CommandDef) => (
            <TouchableOpacity
              key={c.cmd}
              style={styles.commandItem}
              onPress={() => handleSelectCommand(c)}
            >
              <Text style={styles.commandName}>{c.cmd}</Text>
              <Text style={styles.commandDesc}>{c.desc}</Text>
            </TouchableOpacity>
          ))}
        </View>
      )}

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

          {preview.type === 'note' && (preview.body || text.includes('\n')) ? (
            <Text style={styles.previewMultiline}>
              {[preview.title, ...(preview.body ? preview.body.split('\n') : [])].map((ln, i, arr) => (
                <Text key={i} style={i === 0 ? styles.previewTitle : styles.previewLine}>
                  {ln || ' '}{i < arr.length - 1 ? '\n' : ''}
                </Text>
              ))}
            </Text>
          ) : (
            <Text style={styles.previewTitle}>{preview.title}</Text>
          )}

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
          {preview.persons && preview.persons.length > 0 && (
            <Text style={styles.previewDetail}>
              👥 {preview.persons.join(", ")}
            </Text>
          )}

          {preview.location && (
            <Text style={styles.previewDetail}>📍 {preview.location}</Text>
          )}
          {preview.locations && preview.locations.length > 0 && (
            <Text style={styles.previewDetail}>
              🗺️ {preview.locations.join(", ")}
            </Text>
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
    alignItems: "flex-start",
    backgroundColor: Colors.dark.background,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: Colors.dark.border,
    paddingHorizontal: 16,
    paddingVertical: 14,
    minHeight: 68,
  },
  input: {
    ...Typography.body,
    flex: 1,
    color: Colors.dark.text,
    maxHeight: 120,
  },
  composedInput: {
    flex: 1,
    minHeight: 40,
    justifyContent: "flex-start",
  },
  highlightLayer: {
    position: "absolute",
    top: 0,
    left: 0,
    right: 0,
    paddingTop: 0,
    flexDirection: "row",
    flexWrap: "wrap",
  },
  highlightText: {
    ...Typography.body,
    color: Colors.dark.text,
    lineHeight: 22,
  },
  inputOverlay: {
    ...Typography.body,
    color: "transparent",
    maxHeight: 160,
    lineHeight: 22,
    textAlignVertical: "top",
    flexGrow: 1,
    width: "100%",
    // Garante alinhamento
    includeFontPadding: false,
    padding: 0,
  },
  placeholderText: {
    ...Typography.body,
    color: Colors.dark.muted,
    lineHeight: 22,
  },
  hlNormal: {
    color: Colors.dark.text,
  },
  hlCommand: {
    color: Colors.dark.tint,
    fontWeight: "600",
  },
  hlCommandArg: {
    color: Colors.dark.icon,
  },
  hlTag: {
    color: Colors.dark.success,
    fontWeight: "500",
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
  previewMultiline: {
    ...Typography.body,
    color: Colors.dark.text,
    marginBottom: 4,
    fontWeight: '600',
    // preserve whitespace indentation (RN Text collapses multiple spaces unless we keep them; using unicode no-break space replacement optional)
  },
  previewLine: {
    ...Typography.body,
    color: Colors.dark.text,
    fontWeight: '600',
  },
  previewDetail: {
    ...Typography.caption,
    color: Colors.dark.muted,
    marginVertical: 1,
  },
  commandPalette: {
    marginTop: 6,
    backgroundColor: Colors.dark.surface,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: Colors.dark.border,
    overflow: "hidden",
  },
  commandItem: {
    paddingVertical: 10,
    paddingHorizontal: 14,
    borderBottomWidth: 1,
    borderBottomColor: Colors.dark.border,
  },
  commandName: {
    ...Typography.body,
    color: Colors.dark.tint,
    fontWeight: "600",
  },
  commandDesc: {
    ...Typography.caption,
    color: Colors.dark.muted,
    marginTop: 2,
  },
});
