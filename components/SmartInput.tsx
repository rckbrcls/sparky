import React, { useCallback, useMemo, useState } from "react";
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

  const COMMANDS = useMemo(
    () => [
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
        cmd: "/location",
        label: "location",
        desc: "Local: /location escritório",
        insert: "/location ",
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
      },
      {
        cmd: "/trigger",
        label: "trigger",
        desc: "Criar trigger: /trigger person João",
        insert: "/trigger ",
      },
      {
        cmd: "/help",
        label: "help",
        desc: "Lista de comandos",
        insert: "/help",
      },
    ],
    []
  );

  const filteredCommands = useMemo(() => {
    if (!commandQuery) return COMMANDS;
    const q = commandQuery.toLowerCase();
    return COMMANDS.filter(
      (c) => c.cmd.startsWith(`/${q}`) || c.label.includes(q)
    );
  }, [COMMANDS, commandQuery]);

  const detectCommandContext = useCallback((value: string) => {
    // Pega o token atual (após último espaço ou nova linha)
    const cursorToken = value.split(/\s+/).pop() || "";
    if (cursorToken.startsWith("/")) {
      const q = cursorToken.slice(1); // sem barra
      setCommandQuery(q);
      setShowCommands(true);
    } else {
      setShowCommands(false);
      setCommandQuery(null);
    }
  }, []);
  const fadeAnim = React.useRef(new Animated.Value(0)).current;

  const handleTextChange = (newText: string) => {
    setText(newText);
  detectCommandContext(newText);

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

  const handleSelectCommand = (command: { cmd: string; insert: string }) => {
    // Substitui o token atual pelo comando escolhido
    const parts = text.split(/\s+/);
    if (parts.length === 0) {
      setText(command.insert);
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
      const newValue = parts.filter(Boolean).join(" ") + " ";
      setText(newValue);
    }
    setShowCommands(false);
    setCommandQuery(null);
  };

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

        // Create triggers if needed
        if (
          parsed.type === "trigger" &&
          parsed.triggerConfig &&
          parsed.triggerType
        ) {
          const triggerId = await database.createTrigger({
            reminderId,
            type: parsed.triggerType,
            config: JSON.stringify(parsed.triggerConfig),
            isActive: true,
          });
          console.log("Trigger created with ID:", triggerId);
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
