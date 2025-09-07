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
  const [forcedSuggestions, setForcedSuggestions] = useState<any[] | null>(
    null
  );

  const COMMANDS = useMemo(() => {
    const list = [
      {
        cmd: "/date",
        label: "date",
        desc: "Definir data/hora: /date amanhã 18:00",
        insert: "/date ",
      },
      {
        cmd: "/note",
        label: "note",
        desc: "Título rápido da nota: /note Comprar leite",
        insert: "/note ",
      },
      {
        cmd: "/title",
        label: "title",
        desc: "Definir título: /title Reunião equipe",
        insert: "/title ",
      },
      {
        cmd: "/person",
        label: "person",
        desc: "Pessoa relacionada: /person João",
        insert: "/person ",
      },
      {
        cmd: "/people",
        label: "people",
        desc: "Bloco de pessoas: /people João; Maria /endpeople",
        insert: "/people ",
        type: "block",
        end: "/endpeople",
      },
      {
        cmd: "/location",
        label: "location",
        desc: "Local: /location escritório",
        insert: "/location ",
      },
      {
        cmd: "/locations",
        label: "locations",
        desc: "Bloco de locais: /locations escritório; casa /endlocations",
        insert: "/locations ",
        type: "block",
        end: "/endlocations",
      },
      {
        cmd: "/project",
        label: "project",
        desc: "Projeto: /project Novo App",
        insert: "/project ",
      },
      {
        cmd: "/priority",
        label: "priority",
        desc: "Prioridade: /priority !!! | !! | ! | 1..3",
        insert: "/priority ",
      },
      {
        cmd: "/tags",
        label: "tags",
        desc: "Tags: /tags urgente backend",
        insert: "/tags ",
        type: "block",
        end: "/endtags",
      },
      {
        cmd: "/help",
        label: "help",
        desc: "Lista de comandos",
        insert: "/help",
      },
      // closing commands for suggestions
      {
        cmd: "/endtags",
        label: "endtags",
        desc: "Fechar bloco de tags",
        insert: "/endtags",
      },
      {
        cmd: "/endpeople",
        label: "endpeople",
        desc: "Fechar bloco de pessoas",
        insert: "/endpeople",
      },
      {
        cmd: "/endlocations",
        label: "endlocations",
        desc: "Fechar bloco de locais",
        insert: "/endlocations",
      },
    ];
    return list;
  }, []);

  const filteredCommands = useMemo(() => {
    if (forcedSuggestions) return forcedSuggestions;
    if (!commandQuery) return COMMANDS.filter((c) => !c.cmd.startsWith("/end")); // hide end* by default unless queried
    const q = commandQuery.toLowerCase();
    const base = COMMANDS.filter(
      (c) => c.cmd.startsWith(`/${q}`) || c.label.includes(q)
    );
    // ensure closing commands show on explicit query /end
    return base;
  }, [COMMANDS, commandQuery, forcedSuggestions]);

  const detectCommandContext = useCallback(
    (value: string) => {
      const tokens = value.split(/\s+/).filter(Boolean);
      const cursorToken = tokens.length ? tokens[tokens.length - 1] : "";
      const BLOCK_STARTS: Record<string, string> = {
        "/tags": "/endtags",
        "/people": "/endpeople",
        "/locations": "/endlocations",
      };
      if (cursorToken.startsWith("/")) {
        setShowCommands(true);
        setCommandQuery(cursorToken.slice(1));
        if (BLOCK_STARTS[cursorToken]) {
          // show only closing command suggestion
          const endCmd = BLOCK_STARTS[cursorToken];
          const found = COMMANDS.find((c) => c.cmd === endCmd);
          if (found) setForcedSuggestions([found]);
          else setForcedSuggestions(null);
        } else if (cursorToken.startsWith("/end")) {
          setForcedSuggestions(null);
        } else {
          setForcedSuggestions(null);
        }
      } else {
        setShowCommands(false);
        setCommandQuery(null);
        setForcedSuggestions(null);
      }
    },
    [COMMANDS]
  );
  const fadeAnim = React.useRef(new Animated.Value(0)).current;

  // Highlight segments
  interface Segment {
    text: string;
    kind: "command" | "commandArg" | "tag" | "normal";
  }
  const [segments, setSegments] = useState<Segment[]>([]);

  const splitTags = useCallback(
    (textChunk: string, baseKind: Segment["kind"] = "normal"): Segment[] => {
      if (!textChunk) return [];
      const tagRegex = /#[a-zA-Z\u00C0-\u017F0-9_]+/g; // inclui acentos
      const segs: Segment[] = [];
      let last = 0;
      let m: RegExpExecArray | null;
      while ((m = tagRegex.exec(textChunk)) !== null) {
        if (m.index > last)
          segs.push({ text: textChunk.slice(last, m.index), kind: baseKind });
        segs.push({ text: m[0], kind: "tag" });
        last = m.index + m[0].length;
      }
      if (last < textChunk.length)
        segs.push({ text: textChunk.slice(last), kind: baseKind });
      return segs;
    },
    []
  );

  const buildSegments = useCallback(
    (value: string): Segment[] => {
      if (!value) return [];

      const result: Segment[] = [];
      const regex = /(\/[a-zA-Z]+)([\s\S]*?)(?=(?:\s\/[a-zA-Z]+)|$)/g;
      let lastIndex = 0;
      let match: RegExpExecArray | null;
      while ((match = regex.exec(value)) !== null) {
        if (match.index > lastIndex) {
          const normalChunk = value.slice(lastIndex, match.index);
          result.push(...splitTags(normalChunk));
        }
        const commandToken = match[1];
        const argText = match[2] || "";
        result.push({ text: commandToken, kind: "command" });
        if (argText) result.push(...splitTags(argText, "commandArg"));
        lastIndex = match.index + commandToken.length + argText.length;
      }
      if (lastIndex < value.length) {
        const tail = value.slice(lastIndex);
        result.push(...splitTags(tail));
      }
      return result;
    },
    [splitTags]
  );

  const handleTextChange = (newText: string) => {
    setText(newText);
    detectCommandContext(newText);
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

  const handleSelectCommand = (command: {
    cmd: string;
    insert: string;
    type?: string;
    end?: string;
  }) => {
    // Substitui o token atual pelo comando escolhido
    const parts = text.split(/\s+/);
    if (parts.length === 0) {
      let base = command.insert;
      if (command.type === "block" && command.end) {
        base = base + command.end; // /tags /endtags
        // Coloca cursor lógico antes do end adicionando espaço
        base = base.replace(command.end, "") + command.end; // já posicionado
      }
      setText(base);
    } else {
      // Encontrar índice do ultimo token real (não vazio)
      let idx = parts.length - 1;
      // Remover tokens vazios no final
      while (idx >= 0 && parts[idx] === "") idx--;
      if (idx >= 0 && parts[idx].startsWith("/")) {
        parts[idx] = command.insert.trimEnd();
      } else {
        parts.push(command.insert.trimEnd());
      }
      let newValue = parts.filter(Boolean).join(" ") + " ";
      if (command.type === "block" && command.end) {
        newValue = newValue + command.end + " ";
      }
      setText(newValue);
    }
    setShowCommands(false);
    setCommandQuery(null);
  };

  useEffect(() => {
    setSegments(buildSegments(text));
  }, [text, buildSegments]);

  const handleSubmit = async () => {
    if (!text.trim()) return;

    setIsProcessing(true);

    try {
      const parsed = SmartTextParser.parseText(text);
      console.log("Submitting parsed text:", parsed);

      if (parsed.type === "note") {
        // Create quick note
        await database.createQuickNote({
          content: parsed.title,
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
      <View style={styles.inputContainer}>
        <View style={styles.composedInput}>
          <View style={styles.highlightLayer} pointerEvents="none">
            {text.length === 0 ? (
              <Text style={styles.placeholderText}>{placeholder}</Text>
            ) : (
              <Text style={styles.highlightText}>
                {segments.map((s, idx) => (
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
            // Evitar autoCap que atrapalha comandos
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
          {filteredCommands.map((c) => (
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
    backgroundColor: Colors.dark.surface,
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
