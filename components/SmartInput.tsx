import React, {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import {
  Alert,
  Animated,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from "react-native";
import { Colors } from "../constants/Colors";
import { Typography } from "../constants/Typography";
import { useGlobalTouchDismiss } from "../context/GlobalTouchDismissContext";
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
export interface SmartInputHandle {
  blur: () => void;
  focus: () => void;
}

export const SmartInput = React.forwardRef<SmartInputHandle, SmartInputProps>(
  ({ onReminderCreated, placeholder = "Add reminder...", style }, ref) => {
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
    const [selection, setSelection] = useState<{ start: number; end: number }>({
      start: 0,
      end: 0,
    });
    const [isOverflowing, setIsOverflowing] = useState(false);
    const MAX_HEIGHT = 220;
    const PREVIEW_MAX_HEIGHT = 180;
    // Refs para sincronizar scroll
    const inputScrollRef = useRef<ScrollView | null>(null);
    const previewScrollRef = useRef<ScrollView | null>(null);
    const syncingRef = useRef(false);
    const lastSourceRef = useRef<"input" | "preview" | null>(null);
    const [inputContentHeight, setInputContentHeight] = useState(0);
    const [previewContentHeight, setPreviewContentHeight] = useState(0);
    const [inputViewportHeight, setInputViewportHeight] = useState(0);
    const [previewViewportHeight, setPreviewViewportHeight] = useState(0);

    const syncScroll = useCallback(
      (source: "input" | "preview", y: number) => {
        if (syncingRef.current) return;
        const inputScrollable = Math.max(
          0,
          inputContentHeight - inputViewportHeight
        );
        const previewScrollable = Math.max(
          0,
          previewContentHeight - previewViewportHeight
        );
        if (inputScrollable === 0 && previewScrollable === 0) return;
        // Normaliza posição da origem
        let normalized = 0;
        if (source === "input") {
          normalized = inputScrollable ? y / inputScrollable : 0;
        } else {
          normalized = previewScrollable ? y / previewScrollable : 0;
        }
        normalized = Math.min(1, Math.max(0, normalized));
        const targetY =
          source === "input"
            ? normalized * previewScrollable
            : normalized * inputScrollable;
        const targetRef =
          source === "input"
            ? previewScrollRef.current
            : inputScrollRef.current;
        if (!targetRef) return;
        syncingRef.current = true;
        lastSourceRef.current = source;
        targetRef.scrollTo({ y: targetY, animated: false });
        // pequeno timeout para liberar
        requestAnimationFrame(() => {
          syncingRef.current = false;
        });
      },
      [
        inputContentHeight,
        previewContentHeight,
        inputViewportHeight,
        previewViewportHeight,
      ]
    );

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
    // Folder map for preview naming
    const [folderMap, setFolderMap] = useState<Record<string, string>>({});
    const [folders, setFolders] = useState<{ id: string; name: string }[]>([]);
    interface ArgContext {
      command: string;
      partial: string;
      replaceFrom: number;
    }
    const [argContext, setArgContext] = useState<ArgContext | null>(null);
    const [argSuggestions, setArgSuggestions] = useState<string[]>([]);

    const ARG_HANDLERS = useMemo(
      () => ({
        folder: (partial: string) => {
          const norm = (s: string) => s.toLowerCase().replace(/\s+/g, "-");
          const np = norm(partial || "");
          return folders
            .map((f) => f.name)
            .filter((n, i, a) => a.indexOf(n) === i)
            .filter((n) => !np || norm(n).includes(np));
        },
        deletefolder: (partial: string) => {
          const norm = (s: string) => s.toLowerCase().replace(/\s+/g, "-");
          const np = norm(partial || "");
          return folders
            .filter((f) => f.id !== "all")
            .map((f) => f.name)
            .filter((n, i, a) => a.indexOf(n) === i)
            .filter((n) => !np || norm(n).includes(np));
        },
      }),
      [folders]
    );

    // Recompute suggestions when folder list changes while user is already in arg context
    useEffect(() => {
      if (argContext) {
        const handler = (ARG_HANDLERS as any)[argContext.command];
        setArgSuggestions(
          handler ? handler(argContext.partial).slice(0, 30) : []
        );
      }
    }, [folders, ARG_HANDLERS, argContext]);

    const detectArgContext = useCallback(
      (value: string, cursor: number): boolean => {
        try {
          const upto = value.slice(0, cursor);
          // If already completed deletefolder argument (single word) and space typed, exit arg mode
          if (/\/deletefolder\s+\S+\s$/.test(upto)) {
            if (argContext?.command === "deletefolder") {
              setArgContext(null);
              setArgSuggestions([]);
            }
            return false;
          }
          // Detect commands that take a single argument (extensible pattern)
          const m = /\/(folder|deletefolder)\s+([^\s\n]*)$/.exec(upto); // allows empty partial (hyphen slug in progress)
          if (m) {
            const command = m[1];
            const partial = m[2] || "";
            const replaceFrom = cursor - partial.length;
            // Store arg context & suggestions
            setArgContext({ command, partial, replaceFrom });
            const handler = (ARG_HANDLERS as any)[command];
            if (handler) {
              const suggestions = handler(partial).slice(0, 30);
              setArgSuggestions(suggestions);
            } else {
              setArgSuggestions([]);
            }
            // Immediately suppress command palette while in arg mode
            setShowCommands(false);
            setCommandQuery(null);
            return true;
          }
          if (argContext) {
            setArgContext(null);
            setArgSuggestions([]);
          }
          return false;
        } catch {
          if (argContext) setArgContext(null);
          setArgSuggestions([]);
          return false;
        }
      },
      [ARG_HANDLERS, argContext]
    );

    const handleSelectArgSuggestion = (name: string) => {
      if (!argContext) return;
      const before = text.slice(0, argContext.replaceFrom);
      const after = text.slice(selection.start);
      const inserted = `${name} `; // adiciona espaço para encerrar modo argumento
      const newValue = before + inserted + after;
      setText(newValue);
      const newPos = (before + inserted).length;
      setSelection({ start: newPos, end: newPos });
      // Primeiro reparse para garantir que detectContext não reabre sugestões
      handleTextChange(newValue);
      // Garante limpeza (após possíveis estados batched)
      requestAnimationFrame(() => {
        setArgContext(null);
        setArgSuggestions([]);
      });
    };

    useEffect(() => {
      (async () => {
        try {
          const list = await database.getAllFolders();
          setFolders(list);
          const map: Record<string, string> = {};
          list.forEach((f) => (map[f.id] = f.name));
          setFolderMap(map);
        } catch (e) {
          // DB pode não estar pronto ainda
          if (__DEV__) console.debug("Folders load skipped", e);
        }
      })();
    }, []);

    // buildSegments já vem do engine único

    const handleTextChange = (newText: string) => {
      // Live transform: for /folder or /createfolder arguments, replace internal spaces with '-'
      let working = newText;
      const multiArgMatch = /(\/(folder|createfolder)\s+)([^\n\/]*)$/.exec(
        working
      );
      if (multiArgMatch) {
        const prefix = multiArgMatch[1];
        const rawArg = multiArgMatch[3];
        if (rawArg.length > 0) {
          const slugged = rawArg
            // collapse leading/trailing spaces
            .replace(/\s+/g, "-")
            .replace(/-+/g, "-")
            .replace(/^-/, "")
            .replace(/-$/, "-"); // allow trailing hyphen while typing
          if (slugged !== rawArg) {
            working = working.slice(0, multiArgMatch.index) + prefix + slugged;
          }
        }
      }
      if (working !== newText) {
        setText(working);
      } else {
        setText(newText);
      }
      // Use transformed text for context detection
      const baseForCtx = working;
      const inArg = detectArgContext(baseForCtx, baseForCtx.length);
      // Only update general command context if NOT inside an arg context
      if (!inArg) {
        updateContext(baseForCtx);
      }
      setSegments(buildSegments(baseForCtx));

      // Extra fallback (should rarely run now). Ensures suggestions when space just added.
      if (!inArg && /\/(folder|deletefolder)\s+$/.test(baseForCtx)) {
        const m = /\/(folder|deletefolder)\s+$/.exec(baseForCtx);
        if (m) {
          const command = m[1];
          const handler = (ARG_HANDLERS as any)[command];
          setArgContext({
            command,
            partial: "",
            replaceFrom: baseForCtx.length,
          });
          setArgSuggestions(handler ? handler("").slice(0, 30) : []);
          setShowCommands(false);
          setCommandQuery(null);
        }
      }

      const trimmed = baseForCtx.trim();
      // Consider only create/delete as comandos puramente de sistema
      const strippedForPreview = trimmed
        .replace(/\/createfolder\s+\S+/gi, "")
        .replace(/\/deletefolder\s+\S+/gi, "")
        .trim();
      const hasOnlySystemCommands =
        strippedForPreview.length === 0 &&
        /\/createfolder\s+\S+|\/deletefolder\s+\S+/i.test(trimmed) &&
        !/\/folder\s+\S+/i.test(trimmed); // manter /folder exibindo preview

      if (hasOnlySystemCommands || strippedForPreview.length <= 3) {
        // Não mostra preview para comandos de gerenciamento isolados
        setPreview(null);
        Animated.timing(fadeAnim, {
          toValue: 0,
          duration: 150,
          useNativeDriver: true,
        }).start();
        return;
      }

      try {
        const parsed = SmartTextParser.parseText(baseForCtx);
        console.log("Parsed text:", parsed);
        setPreview(parsed);
        Animated.timing(fadeAnim, {
          toValue: 1,
          duration: 200,
          useNativeDriver: true,
        }).start();
      } catch (error) {
        console.error("Error parsing text:", error);
        setPreview(null);
        Animated.timing(fadeAnim, {
          toValue: 0,
          duration: 150,
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
      if (key === "Tab") {
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
        const newValue =
          text.slice(0, lineStart) +
          BULLET +
          " " +
          text.slice(lineStart + line.length);
        const newCursor = lineStart + (BULLET + " ").length;
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
      if (text.length > prev.length && text.endsWith("\n")) {
        // User pressed Enter
        const beforeNewline = text.slice(0, -1); // remove last \n
        const lines = beforeNewline.split("\n");
        const lastLine = lines[lines.length - 1]; // line before the newline
        const trimmed = lastLine.trim();
        const isBullet = trimmed.startsWith(BULLET);
        if (isBullet) {
          const afterBullet = trimmed.slice(BULLET.length).trim();
          if (afterBullet.length > 0) {
            // Continue list: append bullet to new empty line
            const withNext = text + BULLET + " ";
            transformingRef.current = true;
            setText(withNext);
            setSelection({ start: withNext.length, end: withNext.length });
          } else {
            // Bullet line was empty -> end list (remove bullet chars from that empty line)
            // Remove previous bullet markers from empty bullet line (replace that entire lastLine with '')
            const cleanedLine = lastLine.replace(/\s*•\s?/, "");
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
      // Usa pipeline padrão para atualizar preview/argContext
      handleTextChange(newValue);
      setShowCommands(false); // reforço
      setCommandQuery(null);
      // Move o cursor para o final após inserção
      requestAnimationFrame(() =>
        setSelection({ start: newValue.length, end: newValue.length })
      );
    };

    useEffect(() => {
      setSegments(buildSegments(text));
    }, [text]);

    const handleSubmit = async () => {
      if (!text.trim()) return;
      // Limpa qualquer contexto de argumento antes de processar
      if (argContext) {
        setArgContext(null);
        setArgSuggestions([]);
      }

      setIsProcessing(true);

      try {
        const parsed = SmartTextParser.parseText(text);
        console.log("Submitting parsed text:", parsed);

        if (parsed.type === "note") {
          // Create quick note
          // Handle folder commands (only for notes)
          let chosenFolderId = parsed.folderId || "all";
          const explicitFolderMatch = /\/folder\s+(\S+)/i.exec(text);
          const createFolderInfo =
            SmartTextParser.extractCreateFolderName(text);
          const deleteFolderMatch = /\/deletefolder\s+(\S+)/i.exec(text);
          let commandOnly = false; // true when only folder management commands present (no content for note)
          try {
            const allFolders = await database.getAllFolders();
            const slugify = (s: string) =>
              s
                .toLowerCase()
                .replace(/[^a-z0-9]+/g, "-")
                .replace(/^-+|-+$/g, "")
                .substring(0, 32);
            const slugToId: Record<string, string> = {};
            allFolders.forEach((f) => (slugToId[slugify(f.name)] = f.id));
            // /createfolder handling
            if (createFolderInfo.id && createFolderInfo.id !== "all") {
              let actual = slugToId[createFolderInfo.id];
              if (!actual) {
                const newId = await database.createFolder({
                  name: createFolderInfo.raw || createFolderInfo.id,
                  color: "#777777",
                  icon: "",
                  isDefault: false,
                  sortOrder: allFolders.length + 1,
                });
                slugToId[createFolderInfo.id] = newId;
                actual = newId;
                setFolderMap((prev) => ({
                  ...prev,
                  [newId]: (createFolderInfo.raw || createFolderInfo.id) ?? "",
                }));
              }
              if (!parsed.folderId && actual) chosenFolderId = actual;
            }
            // /folder handling (assign & auto-create if needed)
            if (explicitFolderMatch) {
              const rawName = explicitFolderMatch[1];
              const rawSlug = slugify(rawName);
              if (rawSlug && rawSlug !== "all") {
                let actual = slugToId[rawSlug];
                if (!actual) {
                  const newId = await database.createFolder({
                    name: rawName,
                    color: "#777777",
                    icon: "",
                    isDefault: false,
                    sortOrder: allFolders.length + 1,
                  });
                  actual = newId;
                  slugToId[rawSlug] = newId;
                  setFolderMap((prev) => ({ ...prev, [newId]: rawName || "" }));
                }
                chosenFolderId = actual;
              }
            }
            if (deleteFolderMatch) {
              const raw = deleteFolderMatch[1].trim();
              if (raw && raw.toLowerCase() !== "all") {
                const slug = raw
                  .toLowerCase()
                  .replace(/[^a-z0-9]+/g, "-")
                  .replace(/^-+|-+$/g, "")
                  .substring(0, 32);
                const existing = await database.getAllFolders();
                const target = existing.find(
                  (f) =>
                    f.id === raw ||
                    f.id === slug ||
                    f.name.toLowerCase() === raw.toLowerCase() ||
                    f.name
                      .toLowerCase()
                      .replace(/[^a-z0-9]+/g, "-")
                      .replace(/^-+|-+$/g, "")
                      .substring(0, 32) === slug
                );
                if (target && !target.isDefault) {
                  await database.deleteFolder(target.id);
                  if (chosenFolderId === target.id) chosenFolderId = "all";
                } else {
                  console.log(
                    "Delete folder: alvo não encontrado ou é default",
                    raw
                  );
                }
              }
            }
            // Determine if text has only folder management commands (no note content)
            const remaining = text
              .replace(/\/deletefolder\s+\S+/gi, "")
              .replace(/\/createfolder\s+\S+/gi, "")
              .replace(/\/folder\s+\S+/gi, "")
              .trim();
            if (!remaining) commandOnly = true;
          } catch (e) {
            console.warn("Folder creation failed:", e);
          }
          if (!commandOnly) {
            // Remove folder management commands from persisted content
            const cleanedTitle = parsed.title
              .replace(/\/(folder|createfolder|deletefolder)\s+\S+/gi, "")
              .trim();
            const cleanedBody = (parsed.body || "")
              .replace(/\/(folder|createfolder|deletefolder)\s+\S+/gi, "")
              .trim();
            const combined = cleanedBody
              ? `${cleanedTitle}\n${cleanedBody}`
              : cleanedTitle;
            await database.createQuickNote({
              content: combined,
              folderId: chosenFolderId,
              tags: JSON.stringify(parsed.tags),
              isPinned: parsed.priority === 3,
            });
            console.log("Quick note created successfully");
          } else {
            console.log(
              "Somente comandos de pasta processados; nenhuma nota criada"
            );
          }
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
        // Garantir limpeza total pós envio
        setArgContext(null);
        setArgSuggestions([]);
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

    // Expose imperative handlers
    const inputRef = useRef<TextInput | null>(null);
    React.useImperativeHandle(ref, () => ({
      blur: () => inputRef.current?.blur(),
      focus: () => inputRef.current?.focus(),
    }));

    const { register, unregister } = useGlobalTouchDismiss();

    // Focar ao tocar em qualquer área vazia do bloco (placeholder multiline / espaços laterais)
    const focusInput = useCallback(() => {
      inputRef.current?.focus();
    }, []);

    // Register this input with global dismiss (focus detection based on internal ref)
    useEffect(() => {
      const id = `smart-input`;
      register(id, {
        isFocused: () =>
          !!inputRef.current && (inputRef.current as any).isFocused?.(),
        blur: () => inputRef.current?.blur(),
        shouldBlur: () => {
          // Não desfoca se algum palette de sugestões/comandos ou arg estiver aberto
          if (argContext || showCommands) return false;
          return true;
        },
      });
      return () => unregister(id);
    }, [register, unregister, argContext, showCommands]);

    return (
      <View style={[styles.container, style]}>
        <View style={[styles.inputContainer, { minHeight: autoHeight }]}>
          <Pressable
            style={styles.tapWrapper}
            onPress={focusInput}
            hitSlop={{ top: 4, bottom: 4 }}
            accessible={false} // evita elemento extra para leitores; foco vai direto ao TextInput
          >
            <View style={styles.composedInput}>
              <ScrollView
                ref={inputScrollRef}
                style={[styles.scrollArea, { maxHeight: MAX_HEIGHT - 28 }]}
                contentContainerStyle={styles.scrollContent}
                keyboardShouldPersistTaps="handled"
                showsVerticalScrollIndicator={isOverflowing}
                scrollEnabled={isOverflowing}
                onScroll={(e) => {
                  const y = e.nativeEvent.contentOffset.y;
                  syncScroll("input", y);
                }}
                scrollEventThrottle={16}
                onLayout={(e) =>
                  setInputViewportHeight(e.nativeEvent.layout.height)
                }
              >
                <View style={styles.layeredInput}>
                  <View style={styles.highlightLayer} pointerEvents="none">
                    {text.length === 0 ? (
                      <Text
                        style={styles.placeholderText}
                        onLayout={(e) => {
                          const h = e.nativeEvent.layout.height;
                          setAutoHeight((prev) =>
                            Math.max(
                              BASE_MIN_HEIGHT,
                              Math.min(h + 28, MAX_HEIGHT)
                            )
                          );
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
                    ref={inputRef}
                    style={styles.inputOverlay}
                    value={text}
                    onChangeText={handleTextChange}
                    multiline
                    returnKeyType="done"
                    onSubmitEditing={handleSubmit}
                    editable={!isProcessing}
                    onContentSizeChange={(e) => {
                      const h = e.nativeEvent.contentSize.height;
                      setInputContentHeight(h + 28);
                      if (h + 28 <= MAX_HEIGHT) {
                        setIsOverflowing(false);
                        setAutoHeight(Math.max(BASE_MIN_HEIGHT, h + 28));
                      } else {
                        setIsOverflowing(true);
                        setAutoHeight(MAX_HEIGHT);
                      }
                    }}
                    onSelectionChange={(e) => {
                      const { start, end } = e.nativeEvent.selection;
                      setSelection({ start, end });
                      const inArg = detectArgContext(text, start);
                      if (inArg) return; // already handled & suppressed commands
                      if (
                        /\/(folder|deletefolder)\s+$/.test(text.slice(0, start))
                      ) {
                        const m = /\/(folder|deletefolder)\s+$/.exec(
                          text.slice(0, start)
                        );
                        if (m) {
                          const command = m[1];
                          const handler = (ARG_HANDLERS as any)[command];
                          setArgContext({
                            command,
                            partial: "",
                            replaceFrom: start,
                          });
                          setArgSuggestions(
                            handler ? handler("").slice(0, 30) : []
                          );
                          setShowCommands(false);
                          setCommandQuery(null);
                        }
                      }
                    }}
                    onKeyPress={handleKeyPress}
                    autoCapitalize="none"
                    autoCorrect={false}
                    scrollEnabled={false}
                  />
                </View>
              </ScrollView>
            </View>
          </Pressable>
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

        {argContext && (
          <View style={styles.commandPalette}>
            <ScrollView
              style={styles.commandScroll}
              contentContainerStyle={styles.commandScrollContent}
              keyboardShouldPersistTaps="handled"
              nestedScrollEnabled
            >
              {argSuggestions.map((s, idx) => (
                <TouchableOpacity
                  key={s}
                  style={[
                    styles.commandItem,
                    idx === argSuggestions.length - 1 && {
                      borderBottomWidth: 0,
                    },
                  ]}
                  onPress={() => handleSelectArgSuggestion(s)}
                >
                  <Text style={styles.commandName}>{s}</Text>
                  <Text style={styles.commandDesc}>folder</Text>
                </TouchableOpacity>
              ))}
              {argSuggestions.length === 0 && (
                <View style={styles.commandItem}>
                  <Text style={styles.commandDesc}>Sem sugestões</Text>
                </View>
              )}
            </ScrollView>
          </View>
        )}

        {showCommands && filteredCommands.length > 0 && !argContext && (
          <View style={styles.commandPalette}>
            <ScrollView
              style={styles.commandScroll}
              contentContainerStyle={styles.commandScrollContent}
              keyboardShouldPersistTaps="handled"
              nestedScrollEnabled
            >
              {filteredCommands.map((c: CommandDef, idx: number) => (
                <TouchableOpacity
                  key={c.cmd}
                  style={[
                    styles.commandItem,
                    idx === filteredCommands.length - 1 && {
                      borderBottomWidth: 0,
                    },
                  ]}
                  onPress={() => handleSelectCommand(c)}
                >
                  <Text style={styles.commandName}>{c.cmd}</Text>
                  <Text style={styles.commandDesc}>{c.desc}</Text>
                </TouchableOpacity>
              ))}
            </ScrollView>
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
            <View
              style={[
                styles.previewScrollableWrapper,
                { maxHeight: PREVIEW_MAX_HEIGHT },
              ]}
            >
              <ScrollView
                ref={previewScrollRef}
                style={styles.previewScroll}
                contentContainerStyle={styles.previewScrollContent}
                showsVerticalScrollIndicator
                keyboardShouldPersistTaps="handled"
                onScroll={(e) => {
                  const y = e.nativeEvent.contentOffset.y;
                  syncScroll("preview", y);
                }}
                scrollEventThrottle={16}
                onLayout={(e) =>
                  setPreviewViewportHeight(e.nativeEvent.layout.height)
                }
                onContentSizeChange={(_, h) => setPreviewContentHeight(h)}
              >
                {preview.type === "note" &&
                  (() => {
                    const folderCmd = /\/folder\s+(\S+)/i.exec(text || "");
                    const createFolderCmd = /\/createfolder\s+(\S+)/i.exec(
                      text || ""
                    );
                    let folderName: string | undefined;
                    if (folderCmd && folderCmd[1].trim()) {
                      folderName = folderCmd[1].trim();
                    } else if (createFolderCmd && createFolderCmd[1].trim()) {
                      folderName = createFolderCmd[1].trim();
                    } else if (preview.folderId) {
                      folderName =
                        folderMap[preview.folderId] ||
                        (preview.folderId === "all"
                          ? "All"
                          : preview.folderId.replace(/-/g, " "));
                    }
                    return folderName ? (
                      <Text style={styles.previewDetail}>📁 {folderName}</Text>
                    ) : null;
                  })()}
                {preview.body && (
                  <Text style={styles.previewBody}>{preview.body}</Text>
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
                  <Text style={styles.previewDetail}>
                    📍 {preview.location}
                  </Text>
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
              </ScrollView>
            </View>
          </Animated.View>
        )}
      </View>
    );
  }
);
SmartInput.displayName = "SmartInput";

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
    justifyContent: "flex-start",
  },
  scrollArea: { width: "100%" },
  scrollContent: { flexGrow: 1 },
  layeredInput: { position: "relative", width: "100%" },
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
  tapWrapper: {
    flex: 1,
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
  previewScrollableWrapper: {
    marginTop: 4,
    overflow: "hidden",
    borderRadius: 6,
  },
  previewScroll: {
    width: "100%",
  },
  previewScrollContent: {
    paddingBottom: 4,
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
    fontWeight: "600",
    // preserve whitespace indentation (RN Text collapses multiple spaces unless we keep them; using unicode no-break space replacement optional)
  },
  previewLine: {
    ...Typography.body,
    color: Colors.dark.text,
    fontWeight: "600",
  },
  previewBody: {
    ...Typography.caption,
    color: Colors.dark.text,
    marginBottom: 4,
    opacity: 0.85,
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
  commandScroll: {
    maxHeight: 220,
    width: "100%",
  },
  commandScrollContent: {
    flexGrow: 1,
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
