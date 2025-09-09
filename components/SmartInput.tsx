import React, { useCallback, useEffect, useRef, useState } from "react";
import {
  Alert,
  Animated,
  findNodeHandle,
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
  computeCommandState,
  ComputedCommandState,
  resolveArgumentSuggestions,
} from "../services/commands/CommandContextEngine";
import { buildSegments, Segment } from "../services/commands/CommandHighlights"; // extracted highlighter
import {
  applyArgumentInsert,
  applyCommandInsert as applyNewCommandInsert,
} from "../services/commands/CommandInsertion";
import { CommandDefinition } from "../services/commands/CommandRegistry";
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
  (props, ref) => {
    const { onReminderCreated, placeholder = "Add reminder...", style } = props;

    const [text, setText] = useState("");
    const [segments, setSegments] = useState<ReturnType<typeof buildSegments>>(
      []
    );
    const [preview, setPreview] = useState<ParsedReminder | null>(null);
    const [isProcessing, setIsProcessing] = useState(false);
    const [selection, setSelection] = useState({ start: 0, end: 0 });
    const [autoHeight, setAutoHeight] = useState(68);
    const [isOverflowing, setIsOverflowing] = useState(false);
    // Altura do placeholder (todas as linhas) para expandir a área clicável do TextInput quando vazio
    const [placeholderHeight, setPlaceholderHeight] = useState(0);
    const BASE_MIN_HEIGHT = 68;
    const MAX_HEIGHT = 220;
    const PREVIEW_MAX_HEIGHT = 180;
    const fadeAnim = useRef(new Animated.Value(0)).current;
    // Previous text ref para detectar inserção de espaço em tempo real
    const prevTextRef = useRef("");
    // Ignorar próximo onChangeText quando já tratamos manualmente via onKeyPress
    const ignoreNextChangeRef = useRef(false);

    // Commands whose single argument should be slugified (spaces -> dashes) while typing
    const slugArgCommands = useRef(new Set(["folder", "createfolder"])).current;

    // Scroll sync
    const inputScrollRef = useRef<ScrollView | null>(null);
    const previewScrollRef = useRef<ScrollView | null>(null);
    const syncingRef = useRef(false);
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
        let normalized = 0;
        if (source === "input")
          normalized = inputScrollable ? y / inputScrollable : 0;
        else normalized = previewScrollable ? y / previewScrollable : 0;
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
        targetRef.scrollTo({ y: targetY, animated: false });
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

    // Command engine
    const [commandState, setCommandState] = useState<ComputedCommandState>({
      inArgMode: false,
      segments: [],
    });
    const requestCounterRef = useRef(0);
    const recompute = useCallback((value: string, cursor: number) => {
      const reqId = `${++requestCounterRef.current}`;
      const base = computeCommandState({
        text: value,
        cursor,
        requestId: reqId,
      });
      setCommandState(base);
      if (base.inArgMode && base.activeCommand?.argument) {
        resolveArgumentSuggestions(base).then((resolved) => {
          if (resolved.requestId === `${requestCounterRef.current}`)
            setCommandState(resolved);
        });
      }
    }, []);

    const handleTextChange = (val: string) => {
      setText(val);
      setSegments(buildSegments(val));
      recompute(val, selection.end); // Use current selection

      const trimmed = val.trim();
      const stripped = trimmed
        .replace(/\/createfolder\s+\S+/gi, "")
        .replace(/\/deletefolder\s+\S+/gi, "")
        .trim();
      const onlySystem =
        stripped.length === 0 &&
        /\/createfolder\s+\S+|\/deletefolder\s+\S+/i.test(trimmed) &&
        !/\/folder\s+\S+/i.test(trimmed);

      if (onlySystem || stripped.length <= 3) {
        setPreview(null);
        Animated.timing(fadeAnim, {
          toValue: 0,
          duration: 120,
          useNativeDriver: true,
        }).start();
        return;
      }

      try {
        const parsed = SmartTextParser.parseText(val);
        setPreview(parsed);
        Animated.timing(fadeAnim, {
          toValue: 1,
          duration: 160,
          useNativeDriver: true,
        }).start();
      } catch {
        setPreview(null);
        Animated.timing(fadeAnim, {
          toValue: 0,
          duration: 120,
          useNativeDriver: true,
        }).start();
      }
    };

    // Folder names map (preview display only)
    const [folderMap, setFolderMap] = useState<Record<string, string>>({});
    useEffect(() => {
      let cancelled = false;
      (async () => {
        try {
          // @ts-ignore
          if (!(database as any).db && (database as any).initialize)
            await (database as any).initialize();
          const folders = await database.getAllFolders();
          if (cancelled) return;
          const map: Record<string, string> = {};
          folders.forEach((f) => {
            map[f.id] = f.name;
          });
          setFolderMap(map);
        } catch {}
      })();
      return () => {
        cancelled = true;
      };
    }, []);

    const handleSelectCommand = (cmd: CommandDefinition) => {
      const { newText, newCursor } = applyNewCommandInsert(
        text,
        cmd,
        selection.start
      );
      setText(newText);
      setSelection({ start: newCursor, end: newCursor });
      setSegments(buildSegments(newText));
      recompute(newText, newCursor);
    };

    const handleSelectArgSuggestion = (value: string) => {
      if (!commandState.inArgMode || !commandState.activeCommand) return;
      const { argReplaceFrom } = commandState;
      if (argReplaceFrom == null) return;
      const { newText, newCursor } = applyArgumentInsert(
        text,
        argReplaceFrom,
        selection.start,
        value,
        commandState.activeCommand.finalizeOnSelect !== false
      );
      setText(newText);
      setSelection({ start: newCursor, end: newCursor });
      setSegments(buildSegments(newText));
      recompute(newText, newCursor);
    };

    const inputRef = useRef<TextInput | null>(null);
    React.useImperativeHandle(ref, () => ({
      blur: () => inputRef.current?.blur(),
      focus: () => inputRef.current?.focus(),
    }));

    const { register, unregister } = useGlobalTouchDismiss();
    useEffect(() => {
      const id = "smart-input-refactored";
      register(id, {
        isFocused: () =>
          !!inputRef.current && (inputRef.current as any).isFocused?.(),
        blur: () => inputRef.current?.blur(),
        shouldBlur: () => {
          if (
            commandState.inArgMode ||
            (commandState.commandMatches?.length || 0) > 0
          )
            return false;
          return true;
        },
      });
      return () => unregister(id);
    }, [register, unregister, commandState]);

    // Submit
    const handleSubmit = async () => {
      if (!text.trim()) return;
      setIsProcessing(true);
      try {
        const parsed = SmartTextParser.parseText(text);
        if (parsed.type === "note") {
          let chosenFolderId = parsed.folderId || "all";
          const explicitFolderMatch = /\/folder\s+(\S+)/i.exec(text);
          const createFolderInfo =
            SmartTextParser.extractCreateFolderName(text);
          const deleteFolderMatch = /\/deletefolder\s+(\S+)/i.exec(text);
          let commandOnly = false;
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
                setFolderMap((p) => ({
                  ...p,
                  [newId]: (createFolderInfo.raw || createFolderInfo.id) ?? "",
                }));
              }
              if (!parsed.folderId && actual) chosenFolderId = actual;
            }
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
                  setFolderMap((p) => ({ ...p, [newId]: rawName || "" }));
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
                }
              }
            }
            const remaining = text
              .replace(/\/deletefolder\s+\S+/gi, "")
              .replace(/\/createfolder\s+\S+/gi, "")
              .replace(/\/folder\s+\S+/gi, "")
              .trim();
            if (!remaining) commandOnly = true;
          } catch {}
          if (!commandOnly) {
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
          }
        } else {
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
          if (parsed.type === "trigger") {
            const triggerPromises: Promise<string>[] = [];
            if (parsed.persons && parsed.persons.length)
              parsed.persons.forEach((p) =>
                triggerPromises.push(
                  database.createTrigger({
                    reminderId,
                    type: "person",
                    config: JSON.stringify({ contactName: p }),
                    isActive: true,
                  })
                )
              );
            else if (parsed.person)
              triggerPromises.push(
                database.createTrigger({
                  reminderId,
                  type: "person",
                  config: JSON.stringify({ contactName: parsed.person }),
                  isActive: true,
                })
              );
            if (parsed.locations && parsed.locations.length)
              parsed.locations.forEach((loc) =>
                triggerPromises.push(
                  database.createTrigger({
                    reminderId,
                    type: "location",
                    config: JSON.stringify({ location: loc }),
                    isActive: true,
                  })
                )
              );
            else if (parsed.location)
              triggerPromises.push(
                database.createTrigger({
                  reminderId,
                  type: "location",
                  config: JSON.stringify({ location: parsed.location }),
                  isActive: true,
                })
              );
            await Promise.all(triggerPromises);
          }
        }
        setText("");
        setPreview(null);
        onReminderCreated();
        Animated.sequence([
          Animated.timing(fadeAnim, {
            toValue: 0,
            duration: 90,
            useNativeDriver: true,
          }),
          Animated.timing(fadeAnim, {
            toValue: 1,
            duration: 90,
            useNativeDriver: true,
          }),
          Animated.timing(fadeAnim, {
            toValue: 0,
            duration: 90,
            useNativeDriver: true,
          }),
        ]).start();
      } catch (error) {
        console.error("Error creating reminder:", error);
        const msg =
          error instanceof Error ? error.message : "Erro desconhecido";
        Alert.alert("Erro", `Falha ao criar lembrete: ${msg}`);
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
          return Colors.dark.error;
        case 2:
          return Colors.dark.warning;
        case 1:
          return Colors.dark.success;
        default:
          return Colors.dark.muted;
      }
    };

    // added: container handle refs to avoid blur when tapping inside
    const containerRef = useRef<View | null>(null);
    const containerHandleRef = useRef<number | null>(null);
    useEffect(() => {
      containerHandleRef.current = findNodeHandle(containerRef.current) as
        | number
        | null;
    });

    return (
      <View ref={containerRef} style={[styles.container, style]}>
        <View style={[styles.inputContainer, { minHeight: autoHeight }]}>
          <View style={styles.composedInput}>
            <ScrollView
              ref={inputScrollRef}
              style={[styles.scrollArea, { maxHeight: MAX_HEIGHT - 28 }]}
              contentContainerStyle={styles.scrollContent}
              keyboardShouldPersistTaps="handled"
              showsVerticalScrollIndicator={isOverflowing}
              scrollEnabled={isOverflowing}
              onScroll={(e) =>
                syncScroll("input", e.nativeEvent.contentOffset.y)
              }
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
                        const h = e.nativeEvent.layout.height; // altura real do placeholder multi-linha
                        setPlaceholderHeight(h);
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
                      {segments.map((s: Segment, idx) => (
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
                  style={[
                    styles.inputOverlay,
                    placeholderHeight > 0 && !text.length
                      ? { minHeight: placeholderHeight }
                      : null,
                  ]}
                  value={text}
                  onChangeText={handleTextChange}
                  multiline
                  returnKeyType="done"
                  onSubmitEditing={handleSubmit}
                  editable={!isProcessing}
                  // onFocus / onBlur handlers removidos (controle explícito não necessário agora)
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
                    recompute(text, start);
                  }}
                  onKeyPress={(e) => {
                    const k = e.nativeEvent.key;
                    if (k === "/") {
                      // Inserimos manualmente o '/' para exibir sugestões imediatamente
                      const selStart = selection.start;
                      const selEnd = selection.end;
                      const newText =
                        text.slice(0, selStart) + "/" + text.slice(selEnd);
                      ignoreNextChangeRef.current = true; // evitar recompute duplicado quando onChangeText vier
                      setText(newText);
                      setSegments(buildSegments(newText));
                      const newCursor = selStart + 1;
                      setSelection({ start: newCursor, end: newCursor });
                      prevTextRef.current = newText;
                      recompute(newText, newCursor);
                      return; // já tratamos
                    }
                    if (k === "Backspace") {
                      // Se vamos apagar um '/' imediatamente antes do cursor, fazemos manual para esconder palette instantaneamente
                      if (
                        selection.start === selection.end &&
                        selection.start > 0 &&
                        text.charAt(selection.start - 1) === "/"
                      ) {
                        const cutPos = selection.start - 1;
                        const newText =
                          text.slice(0, cutPos) + text.slice(selection.start);
                        ignoreNextChangeRef.current = true;
                        setText(newText);
                        setSegments(buildSegments(newText));
                        const newCursor = cutPos;
                        setSelection({ start: newCursor, end: newCursor });
                        prevTextRef.current = newText;
                        recompute(newText, newCursor);
                        return; // já tratamos
                      }
                    }
                    if (
                      (k === " " || k === "Spacebar") &&
                      commandState.inArgMode &&
                      commandState.activeCommand?.name &&
                      slugArgCommands.has(commandState.activeCommand.name) &&
                      commandState.argReplaceFrom != null
                    ) {
                      // Substituir espaço imediatamente por '-'
                      const selStart = selection.start;
                      const selEnd = selection.end;
                      const before = text.slice(0, selStart);
                      const after = text.slice(selEnd);
                      const newText = before + "-" + after;
                      ignoreNextChangeRef.current = true; // vamos ajustar manualmente
                      setText(newText);
                      setSegments(buildSegments(newText));
                      prevTextRef.current = newText;
                      const newCursor = selStart + 1;
                      setSelection({ start: newCursor, end: newCursor });
                      recompute(newText, newCursor);
                    }
                  }}
                  autoCapitalize="none"
                  autoCorrect={false}
                  scrollEnabled={false}
                />
              </View>
            </ScrollView>
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

        {commandState.inArgMode && commandState.activeCommand && (
          <View style={styles.commandPalette}>
            <ScrollView
              style={styles.commandScroll}
              contentContainerStyle={styles.commandScrollContent}
              keyboardShouldPersistTaps="handled"
              nestedScrollEnabled
            >
              {commandState.argSuggestions?.map((s, idx) => (
                <TouchableOpacity
                  key={s}
                  style={[
                    styles.commandItem,
                    idx === commandState.argSuggestions!.length - 1 && {
                      borderBottomWidth: 0,
                    },
                  ]}
                  onPress={() => handleSelectArgSuggestion(s)}
                >
                  <Text style={styles.commandName}>{s}</Text>
                  <Text style={styles.commandDesc}>
                    {commandState.activeCommand?.name}
                  </Text>
                </TouchableOpacity>
              ))}
              {(commandState.argSuggestions?.length || 0) === 0 && (
                <View style={styles.commandItem}>
                  <Text style={styles.commandDesc}>Sem sugestões</Text>
                </View>
              )}
            </ScrollView>
          </View>
        )}

        {!commandState.inArgMode &&
          commandState.openCommandQuery != null &&
          (commandState.commandMatches?.length || 0) > 0 && (
            <View style={styles.commandPalette}>
              <ScrollView
                style={styles.commandScroll}
                contentContainerStyle={styles.commandScrollContent}
                keyboardShouldPersistTaps="handled"
                nestedScrollEnabled
              >
                {commandState.commandMatches!.map((c, idx) => (
                  <TouchableOpacity
                    key={c.name}
                    style={[
                      styles.commandItem,
                      idx === commandState.commandMatches!.length - 1 && {
                        borderBottomWidth: 0,
                      },
                    ]}
                    onPress={() => handleSelectCommand(c)}
                  >
                    <Text style={styles.commandName}>{`/${c.name}`}</Text>
                    <Text style={styles.commandDesc}>{c.description}</Text>
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
                onScroll={(e) =>
                  syncScroll("preview", e.nativeEvent.contentOffset.y)
                }
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
                    if (folderCmd && folderCmd[1].trim())
                      folderName = folderCmd[1].trim();
                    else if (createFolderCmd && createFolderCmd[1].trim())
                      folderName = createFolderCmd[1].trim();
                    else if (preview.folderId)
                      folderName =
                        folderMap[preview.folderId] ||
                        (preview.folderId === "all"
                          ? "All"
                          : preview.folderId.replace(/-/g, " "));
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
                    🏷️ {preview.tags.map((t) => `#${t}`).join(" ")}
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
  container: { marginVertical: 8 },
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
  composedInput: { flex: 1, minHeight: 40, justifyContent: "flex-start" },
  tapWrapper: { flex: 1, justifyContent: "flex-start" },
  highlightLayer: {
    position: "absolute",
    top: 0,
    left: 0,
    right: 0,
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
    includeFontPadding: false,
    padding: 0,
  },
  placeholderText: {
    ...Typography.body,
    color: Colors.dark.muted,
    lineHeight: 22,
  },
  hlNormal: { color: Colors.dark.text },
  hlCommand: { color: Colors.dark.tint, fontWeight: "600" },
  hlCommandArg: { color: Colors.dark.icon },
  hlTag: { color: Colors.dark.success, fontWeight: "500" },
  submitButton: {
    marginLeft: 12,
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: Colors.dark.tint,
    alignItems: "center",
    justifyContent: "center",
  },
  submitButtonDisabled: { backgroundColor: Colors.dark.muted },
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
  previewScroll: { width: "100%" },
  previewScrollContent: { paddingBottom: 4 },
  previewHeader: {
    flexDirection: "row",
    alignItems: "center",
    marginBottom: 8,
  },
  previewIcon: { fontSize: 16, marginRight: 8 },
  previewType: { ...Typography.caption, color: Colors.dark.muted, flex: 1 },
  priorityIndicator: { width: 8, height: 8, borderRadius: 4 },
  previewTitle: {
    ...Typography.body,
    color: Colors.dark.text,
    fontWeight: "600",
    marginBottom: 4,
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
  commandScroll: { maxHeight: 220, width: "100%" },
  commandScrollContent: { flexGrow: 1 },
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
