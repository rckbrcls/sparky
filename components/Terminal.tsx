import React, {
  useCallback,
  useEffect,
  useImperativeHandle,
  useRef,
  useState,
} from "react";
import {
  Alert,
  Animated,
  Easing,
  KeyboardAvoidingView,
  Modal,
  Platform,
  ScrollView,
  StyleSheet,
  SafeAreaView,
  Text,
  TextInput,
  TouchableOpacity,
  View,
  useWindowDimensions,
} from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Colors } from "../constants/Colors";
import { Typography } from "../constants/Typography";
import { useGlobalTouchDismiss } from "../context/GlobalTouchDismissContext";
import { database } from "../database/database";
import { ReminderService } from "../services/ReminderService";
import { ParsedReminder, SmartTextParser } from "../services/SmartTextParser";
import { useCommandEngine } from "../hooks/useCommandEngine";
import { useReminderPreview } from "../hooks/useReminderPreview";
import { useFolderMap } from "../hooks/useFolderMap";
import { useScrollSync } from "../hooks/useScrollSync";
import {
  cleanSystemCommands,
  matchCreateFolderCommand,
  matchDeleteFolderCommand,
  matchFolderCommand,
  SLUG_ARG_COMMANDS,
  slugify,
  stripAllSystemCommands,
} from "../utils/terminal";
import { buildSegments, Segment } from "../services/commands/CommandHighlights";
import { CommandDefinition } from "../services/commands/CommandRegistry";

const COLLAPSED_MAX_HEIGHT = 220;
const PREVIEW_MAX_HEIGHT = 180;
const PLACEHOLDER_EXTRA_PADDING = 28;
const FALLBACK_SINGLE_LINE_HEIGHT = 22 + PLACEHOLDER_EXTRA_PADDING;
const EXPANSION_DURATION = 220;
const INPUT_VERTICAL_PADDING = 28;

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

interface TerminalProps {
  onReminderCreated: () => void;
  placeholder?: string;
  style?: any;
}

export interface TerminalHandle {
  blur: () => void;
  focus: () => void;
}

export const Terminal = React.forwardRef<TerminalHandle, TerminalProps>(
  ({ onReminderCreated, placeholder = "Add reminder...", style }, ref) => {
    const [text, setText] = useState("");
    const [segments, setSegments] = useState<Segment[]>([]);
    const [selection, setSelection] = useState({ start: 0, end: 0 });
    const [inputContentHeight, setMeasuredInputContentHeight] = useState(
      FALLBACK_SINGLE_LINE_HEIGHT
    );
    const [isOverflowing, setIsOverflowing] = useState(false);
    const [placeholderHeight, setPlaceholderHeight] = useState(0);
    const [isProcessing, setIsProcessing] = useState(false);
    const [isFullscreen, setIsFullscreen] = useState(false);

    const ignoreNextChangeRef = useRef(false);

    const {
      inputScrollRef,
      previewScrollRef,
      syncScroll,
      setInputContentHeight: setSyncedInputContentHeight,
      setPreviewContentHeight,
      setInputViewportHeight,
      setPreviewViewportHeight,
    } = useScrollSync();

    const { preview, fadeAnim, updatePreview, hidePreview } = useReminderPreview();
    const { folderMap, setFolderMap } = useFolderMap();

    const { commandState, recompute, handleSelectCommand, handleSelectArgSuggestion } =
      useCommandEngine({
        text,
        selectionStart: selection.start,
        setText,
        setSelection,
        setSegments,
      });

    const { height: windowHeight } = useWindowDimensions();
    const insets = useSafeAreaInsets();
    const animatedHeight = useRef(
      new Animated.Value(FALLBACK_SINGLE_LINE_HEIGHT)
    ).current;

    const baselineHeight = placeholderHeight
      ? placeholderHeight + PLACEHOLDER_EXTRA_PADDING
      : FALLBACK_SINGLE_LINE_HEIGHT;

    const collapsedHeight = Math.min(
      Math.max(baselineHeight, inputContentHeight),
      COLLAPSED_MAX_HEIGHT
    );

    const fullscreenHeight = Math.max(
      windowHeight - insets.top - insets.bottom,
      baselineHeight
    );

    const targetHeight = isFullscreen ? fullscreenHeight : collapsedHeight;

    // Smoothly interpolate the container height across compact/fullscreen transitions.
    useEffect(() => {
      Animated.timing(animatedHeight, {
        toValue: targetHeight,
        duration: EXPANSION_DURATION,
        easing: Easing.out(Easing.cubic),
        useNativeDriver: false,
      }).start();
    }, [animatedHeight, targetHeight]);

    const inputRef = useRef<TextInput | null>(null);
    useImperativeHandle(ref, () => ({
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
    }, [commandState, register, unregister]);

    const handleTextChange = useCallback(
      (value: string) => {
        if (ignoreNextChangeRef.current) {
          ignoreNextChangeRef.current = false;
          return;
        }

        setText(value);
        setSegments(buildSegments(value));
        updatePreview(value);
        recompute(value, selection.end);
      },
      [recompute, selection.end, updatePreview]
    );

    const resolvePreviewFolderName = useCallback(() => {
      const folderMatch = matchFolderCommand(text || "");
      if (folderMatch?.[1]?.trim()) return folderMatch[1].trim();

      const createMatch = matchCreateFolderCommand(text || "");
      if (createMatch?.[1]?.trim()) return createMatch[1].trim();

      if (preview?.folderId) {
        return (
          folderMap[preview.folderId] ||
          (preview.folderId === "all"
            ? "All"
            : preview.folderId.replace(/-/g, " "))
        );
      }

      return undefined;
    }, [folderMap, preview, text]);

    const highlightStyle = (kind: Segment["kind"]) => {
      switch (kind) {
        case "command":
          return styles.hlCommand;
        case "commandArg":
          return styles.hlCommandArg;
        case "tag":
          return styles.hlTag;
        default:
          return styles.hlNormal;
      }
    };

    const handleContentSizeChange = (height: number) => {
      const totalHeight = height + PLACEHOLDER_EXTRA_PADDING;
      setMeasuredInputContentHeight(totalHeight);
      setSyncedInputContentHeight(totalHeight);
      setIsOverflowing(totalHeight > COLLAPSED_MAX_HEIGHT);
    };

    const handleSubmitNote = useCallback(
      async (parsed: ParsedReminder & { type: "note" }, rawText: string) => {
        let chosenFolderId = parsed.folderId || "all";
        const explicitFolderMatch = matchFolderCommand(rawText);
        const createFolderInfo = SmartTextParser.extractCreateFolderName(rawText);
        const deleteFolderMatch = matchDeleteFolderCommand(rawText);
        let commandOnly = false;

        try {
          const allFolders = await database.getAllFolders();
          const slugToId: Record<string, string> = {};
          allFolders.forEach((folder) => {
            slugToId[slugify(folder.name)] = folder.id;
          });

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
            if (!parsed.folderId && actual) {
              chosenFolderId = actual;
            }
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
                setFolderMap((prev) => ({ ...prev, [newId]: rawName || "" }));
              }
              chosenFolderId = actual;
            }
          }

          if (deleteFolderMatch) {
            const raw = deleteFolderMatch[1].trim();
            if (raw && raw.toLowerCase() !== "all") {
              const normalizedSlug = slugify(raw);
              const existing = await database.getAllFolders();
              const target = existing.find(
                (folder) =>
                  folder.id === raw ||
                  folder.id === normalizedSlug ||
                  folder.name.toLowerCase() === raw.toLowerCase() ||
                  slugify(folder.name) === normalizedSlug
              );
              if (target && !target.isDefault) {
                await database.deleteFolder(target.id);
                if (chosenFolderId === target.id) {
                  chosenFolderId = "all";
                }
              }
            }
          }

          const remaining = stripAllSystemCommands(rawText).trim();
          if (!remaining) commandOnly = true;
        } catch {
          // Database lookup failures should not block quick note creation.
        }

        if (!commandOnly) {
          const cleanedTitle = cleanSystemCommands(parsed.title);
          const cleanedBody = cleanSystemCommands(parsed.body || "");
          const content = cleanedBody
            ? `${cleanedTitle}\n${cleanedBody}`.trim()
            : cleanedTitle;

          await database.createQuickNote({
            content,
            folderId: chosenFolderId,
            tags: JSON.stringify(parsed.tags),
            isPinned: parsed.priority === 3,
          });
        }
      },
      [setFolderMap]
    );

    const handleSubmitReminder = useCallback(async (parsed: ParsedReminder) => {
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

        if (parsed.persons && parsed.persons.length) {
          parsed.persons.forEach((personName) => {
            triggerPromises.push(
              database.createTrigger({
                reminderId,
                type: "person",
                config: JSON.stringify({ contactName: personName }),
                isActive: true,
              })
            );
          });
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
          parsed.locations.forEach((location) => {
            triggerPromises.push(
              database.createTrigger({
                reminderId,
                type: "location",
                config: JSON.stringify({ location }),
                isActive: true,
              })
            );
          });
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
    }, []);

    const handleSubmit = useCallback(async () => {
      if (!text.trim()) return;
      setIsProcessing(true);

      try {
        const parsed = SmartTextParser.parseText(text);

        if (parsed.type === "note") {
          await handleSubmitNote(parsed as ParsedReminder & { type: "note" }, text);
        } else {
          await handleSubmitReminder(parsed);
        }

        setText("");
        setSegments([]);
        setSelection({ start: 0, end: 0 });
        recompute("", 0);
        hidePreview();
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
        const message =
          error instanceof Error ? error.message : "Erro desconhecido";
        Alert.alert("Erro", `Falha ao criar lembrete: ${message}`);
      } finally {
        setIsProcessing(false);
      }
    }, [
      fadeAnim,
      handleSubmitNote,
      handleSubmitReminder,
      hidePreview,
      onReminderCreated,
      recompute,
      text,
    ]);

    const renderSegments = () => {
      if (text.length === 0) {
      return (
        <Text
          style={styles.placeholderText}
          onLayout={(event) => {
            const height = event.nativeEvent.layout.height;
            setPlaceholderHeight(height);
          }}
        >
          {placeholder}
        </Text>
      );
      }

      return (
        <Text style={styles.highlightText}>
          {segments.map((segment, idx) => (
            <Text key={`${segment.kind}-${idx}`} style={highlightStyle(segment.kind)}>
              {segment.text}
            </Text>
          ))}
        </Text>
      );
    };

    const renderArgSuggestions = () => {
      if (!commandState.inArgMode || !commandState.activeCommand) return null;
      const suggestions: string[] = commandState.argSuggestions ?? [];

      return (
        <View style={styles.commandPalette}>
          <ScrollView
            style={styles.commandScroll}
            contentContainerStyle={styles.commandScrollContent}
            keyboardShouldPersistTaps="handled"
            nestedScrollEnabled
          >
            {suggestions.length > 0 ? (
              suggestions.map((suggestion: string, idx: number) => (
                <TouchableOpacity
                  key={suggestion}
                  style={[
                    styles.commandItem,
                    idx === suggestions.length - 1 && { borderBottomWidth: 0 },
                  ]}
                  onPress={() => handleSelectArgSuggestion(suggestion)}
                >
                  <Text style={styles.commandName}>{suggestion}</Text>
                  <Text style={styles.commandDesc}>
                    {commandState.activeCommand?.name}
                  </Text>
                </TouchableOpacity>
              ))
            ) : (
              <View style={styles.commandItem}>
                <Text style={styles.commandDesc}>Sem sugestões</Text>
              </View>
            )}
          </ScrollView>
        </View>
      );
    };

    const renderCommandMatches = () => {
      if (
        commandState.inArgMode ||
        commandState.openCommandQuery == null ||
        (commandState.commandMatches?.length || 0) === 0
      )
        return null;

      const matches: CommandDefinition[] = commandState.commandMatches ?? [];

      return (
        <View style={styles.commandPalette}>
          <ScrollView
            style={styles.commandScroll}
            contentContainerStyle={styles.commandScrollContent}
            keyboardShouldPersistTaps="handled"
            nestedScrollEnabled
          >
            {matches.map((match: CommandDefinition, idx: number) => (
              <TouchableOpacity
                key={match.name}
                style={[
                  styles.commandItem,
                  idx === matches.length - 1 && { borderBottomWidth: 0 },
                ]}
                onPress={() => handleSelectCommand(match)}
              >
                <Text style={styles.commandName}>{`/${match.name}`}</Text>
                <Text style={styles.commandDesc}>{match.description}</Text>
              </TouchableOpacity>
            ))}
          </ScrollView>
        </View>
      );
    };

    const renderPreview = () => {
      if (!preview) return null;

      const folderName = preview.type === "note" ? resolvePreviewFolderName() : undefined;

      return (
        <Animated.View
          style={[
            styles.preview,
            isFullscreen && styles.previewFullscreen,
            { opacity: fadeAnim },
          ]}
        >
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
              isFullscreen
                ? styles.previewScrollableWrapperFullscreen
                : styles.previewScrollableWrapperCompact,
            ]}
          >
            <ScrollView
              ref={previewScrollRef}
              style={styles.previewScroll}
              contentContainerStyle={styles.previewScrollContent}
              showsVerticalScrollIndicator
              keyboardShouldPersistTaps="handled"
              onScroll={(event) =>
                syncScroll("preview", event.nativeEvent.contentOffset.y)
              }
              scrollEventThrottle={16}
              onLayout={(event) =>
                setPreviewViewportHeight(event.nativeEvent.layout.height)
              }
              onContentSizeChange={(_, height) => setPreviewContentHeight(height)}
            >
              {folderName && (
                <Text style={styles.previewDetail}>📁 {folderName}</Text>
              )}
              {preview.body && (
                <Text style={styles.previewBody}>{preview.body}</Text>
              )}
              {preview.fireAt && (
                <Text style={styles.previewDetail}>
                  📅 {preview.fireAt.toLocaleDateString()} {" "}
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
            </ScrollView>
          </View>
        </Animated.View>
      );
    };

    const shouldShowExpandButton = !isFullscreen && isOverflowing;
    const scrollAreaStyles = [
      styles.scrollArea,
      isFullscreen
        ? styles.scrollAreaFullscreen
        : { maxHeight: Math.max(collapsedHeight - INPUT_VERTICAL_PADDING, 0) },
    ];
    const scrollContentStyle = [
      styles.scrollContent,
      isFullscreen && styles.scrollContentFullscreen,
    ];
    const inputContainerStyles = [
      styles.inputContainer,
      isFullscreen ? styles.inputContainerFullscreen : styles.inputContainerCompact,
      { minHeight: baselineHeight },
      { height: animatedHeight },
    ];

    const bodyContent = (
      <>
        <Animated.View style={inputContainerStyles}>
          <View style={styles.composedInput}>
            <ScrollView
              ref={inputScrollRef}
              style={scrollAreaStyles}
              contentContainerStyle={scrollContentStyle}
              keyboardShouldPersistTaps="handled"
              showsVerticalScrollIndicator={isFullscreen || isOverflowing}
              scrollEnabled={isFullscreen || isOverflowing}
              onScroll={(event) =>
                syncScroll("input", event.nativeEvent.contentOffset.y)
              }
              scrollEventThrottle={16}
              onLayout={(event) =>
                setInputViewportHeight(event.nativeEvent.layout.height)
              }
            >
              <View style={styles.layeredInput}>
                <View style={styles.highlightLayer} pointerEvents="none">
                  {renderSegments()}
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
                  onContentSizeChange={(event) =>
                    handleContentSizeChange(event.nativeEvent.contentSize.height)
                  }
                  onSelectionChange={(event) => {
                    const { start, end } = event.nativeEvent.selection;
                    setSelection({ start, end });
                    recompute(text, start);
                  }}
                  onKeyPress={(event) => {
                    const key = event.nativeEvent.key;
                    if (key === "/") {
                      const selStart = selection.start;
                      const selEnd = selection.end;
                      const newText =
                        text.slice(0, selStart) + "/" + text.slice(selEnd);
                      ignoreNextChangeRef.current = true;
                      setText(newText);
                      setSegments(buildSegments(newText));
                      const newCursor = selStart + 1;
                      setSelection({ start: newCursor, end: newCursor });
                      recompute(newText, newCursor);
                      return;
                    }

                    if (key === "Backspace") {
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
                        recompute(newText, newCursor);
                        return;
                      }
                    }

                    if (
                      (key === " " || key === "Spacebar") &&
                      commandState.inArgMode &&
                      commandState.activeCommand?.name &&
                      SLUG_ARG_COMMANDS.has(commandState.activeCommand.name) &&
                      commandState.argReplaceFrom != null
                    ) {
                      const selStart = selection.start;
                      const selEnd = selection.end;
                      const before = text.slice(0, selStart);
                      const after = text.slice(selEnd);
                      const newText = `${before}-${after}`;
                      ignoreNextChangeRef.current = true;
                      setText(newText);
                      setSegments(buildSegments(newText));
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
          {shouldShowExpandButton && (
            <TouchableOpacity
              accessibilityRole="button"
              accessibilityLabel="Expand terminal"
              style={styles.expandButton}
              onPress={() => setIsFullscreen(true)}
            >
              <Text style={styles.expandIcon}>⤢</Text>
            </TouchableOpacity>
          )}
        </Animated.View>

        {renderArgSuggestions()}
        {renderCommandMatches()}
        {renderPreview()}
      </>
    );

    if (isFullscreen) {
      return (
        <Modal
          animationType="fade"
          transparent={false}
          visible
          onRequestClose={() => setIsFullscreen(false)}
        >
          <SafeAreaView style={styles.fullscreenModal}>
            <KeyboardAvoidingView
              behavior={Platform.OS === "ios" ? "padding" : undefined}
              keyboardVerticalOffset={insets.top + 16}
              style={styles.fullscreenAvoiding}
            >
              <View style={[styles.fullscreenInner, style]}>{bodyContent}</View>
            </KeyboardAvoidingView>
            <TouchableOpacity
              accessibilityRole="button"
              accessibilityLabel="Retract terminal"
              style={styles.collapseButton}
              onPress={() => setIsFullscreen(false)}
            >
              <Text style={styles.expandIcon}>⤡</Text>
            </TouchableOpacity>
          </SafeAreaView>
        </Modal>
      );
    }

    return <View style={[styles.container, style]}>{bodyContent}</View>;
  }
);
Terminal.displayName = "Terminal";

const styles = StyleSheet.create({
  container: {
    marginVertical: 8,
    width: "100%",
  },
  fullscreenModal: {
    flex: 1,
    backgroundColor: Colors.dark.background,
  },
  fullscreenAvoiding: {
    flex: 1,
  },
  fullscreenInner: {
    flex: 1,
    paddingHorizontal: 16,
    paddingBottom: 16,
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
    width: "100%",
    position: "relative",
  },
  inputContainerCompact: {
    alignSelf: "stretch",
  },
  inputContainerFullscreen: {
    borderRadius: 16,
  },
  scrollArea: { width: "100%" },
  scrollAreaFullscreen: { flexGrow: 1 },
  scrollContent: { flexGrow: 1 },
  scrollContentFullscreen: { paddingBottom: 8 },
  layeredInput: { position: "relative", width: "100%" },
  composedInput: { flex: 1, justifyContent: "flex-start" },
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
  expandButton: {
    position: "absolute",
    bottom: 12,
    right: 12,
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: Colors.dark.surface,
    borderWidth: 1,
    borderColor: Colors.dark.border,
    alignItems: "center",
    justifyContent: "center",
  },
  expandIcon: {
    ...Typography.body,
    color: Colors.dark.tint,
    fontWeight: "600",
  },
  collapseButton: {
    position: "absolute",
    right: 16,
    top: 16,
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: Colors.dark.surface,
    borderWidth: 1,
    borderColor: Colors.dark.border,
    alignItems: "center",
    justifyContent: "center",
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
  previewFullscreen: {
    flexGrow: 1,
  },
  previewScrollableWrapper: {
    marginTop: 4,
    overflow: "hidden",
    borderRadius: 6,
  },
  previewScrollableWrapperCompact: { maxHeight: PREVIEW_MAX_HEIGHT },
  previewScrollableWrapperFullscreen: { maxHeight: undefined, flexGrow: 1 },
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
