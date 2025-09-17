import React, {
  useCallback,
  useEffect,
  useImperativeHandle,
  useMemo,
  useRef,
  useState,
} from "react";
import {
  Alert,
  Animated,
  Easing,
  Keyboard,
  KeyboardAvoidingView,
  Modal,
  Platform,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from "react-native";
import {
  SafeAreaView,
  useSafeAreaInsets,
} from "react-native-safe-area-context";
import { Colors } from "../constants/Colors";
import { Typography } from "../constants/Typography";
import { useGlobalTouchDismiss } from "../context/GlobalTouchDismissContext";
import { database } from "../database/database";
import { useCommandEngine } from "../hooks/useCommandEngine";
import { useFolderMap } from "../hooks/useFolderMap";
import { useReminderPreview } from "../hooks/useReminderPreview";
import { useScrollSync } from "../hooks/useScrollSync";
import { buildSegments, Segment } from "../services/commands/CommandHighlights";
import { CommandDefinition } from "../services/commands/CommandRegistry";
import { ReminderService } from "../services/ReminderService";
import { ParsedReminder, SmartTextParser } from "../services/SmartTextParser";
import {
  cleanSystemCommands,
  matchCreateFolderCommand,
  matchDeleteFolderCommand,
  matchFolderCommand,
  SLUG_ARG_COMMANDS,
  slugify,
  stripAllSystemCommands,
} from "../utils/terminal";
import { AppIcon } from "./AppIcon";
import type { AppIconKey } from "../constants/iconMappings";

const COLLAPSED_MAX_HEIGHT = 220;
const PREVIEW_MAX_HEIGHT = 180;
const PLACEHOLDER_EXTRA_PADDING = 28;
const FALLBACK_SINGLE_LINE_HEIGHT = 22 + PLACEHOLDER_EXTRA_PADDING;
const EXPANSION_DURATION = 220;
const INPUT_VERTICAL_PADDING = 28;

const getTypeIcon = (type: string, triggerType?: string): AppIconKey => {
  if (type === "date") return "clock";
  if (type === "note") return "notes";
  if (triggerType === "person") return "person";
  if (triggerType === "location") return "location";
  return "clipboard";
};

const getTypeLabel = (type: string, triggerType?: string) => {
  if (type === "date") return "Date Reminder";
  if (type === "note") return "Quick Note";
  if (triggerType === "person") return "Person Trigger";
  if (triggerType === "location") return "Location Trigger";
  return "General Reminder";
};

const getPriorityLabel = (priority: number) => {
  switch (priority) {
    case 3:
      return "Alta";
    case 2:
      return "Média";
    case 1:
      return "Baixa";
    default:
      return "Neutral";
  }
};

type BadgeTone = "neutral" | "accent" | "success" | "warning" | "danger";

interface PreviewBadge {
  key: string;
  label: string;
  icon?: AppIconKey;
  tone: BadgeTone;
  accessibilityLabel: string;
}

const BADGE_APPEARANCE: Record<
  BadgeTone,
  { backgroundColor: string; borderColor: string; textColor: string }
> = {
  neutral: {
    backgroundColor: Colors.dark.surface,
    borderColor: Colors.dark.border,
    textColor: Colors.dark.text,
  },
  accent: {
    backgroundColor: "rgba(255,255,255,0.12)",
    borderColor: Colors.dark.tint,
    textColor: Colors.dark.tint,
  },
  success: {
    backgroundColor: "rgba(63, 185, 80, 0.2)",
    borderColor: Colors.dark.success,
    textColor: Colors.dark.success,
  },
  warning: {
    backgroundColor: "rgba(210, 153, 34, 0.2)",
    borderColor: Colors.dark.warning,
    textColor: Colors.dark.warning,
  },
  danger: {
    backgroundColor: "rgba(248, 81, 73, 0.2)",
    borderColor: Colors.dark.error,
    textColor: Colors.dark.error,
  },
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

    const { preview, fadeAnim, updatePreview, hidePreview } =
      useReminderPreview();
    const { folderMap, setFolderMap } = useFolderMap();

    const {
      commandState,
      recompute,
      handleSelectCommand,
      handleSelectArgSuggestion,
    } = useCommandEngine({
      text,
      selectionStart: selection.start,
      setText,
      setSelection,
      setSegments,
    });

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
    // Smoothly interpolate the container height across compact/fullscreen transitions.
    useEffect(() => {
      Animated.timing(animatedHeight, {
        toValue: collapsedHeight,
        duration: EXPANSION_DURATION,
        easing: Easing.out(Easing.cubic),
        useNativeDriver: false,
      }).start();
    }, [animatedHeight, collapsedHeight]);

    const isFullscreenLayout = isFullscreen;

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

    const openFullscreen = useCallback(() => {
      setIsFullscreen(true);
    }, []);

    const closeFullscreen = useCallback(() => {
      if (!isFullscreen) return;
      Keyboard.dismiss();
      setIsFullscreen(false);
    }, [isFullscreen]);

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

    const previewBadges = useMemo<PreviewBadge[]>(() => {
      if (!preview) return [];

      const badges: PreviewBadge[] = [];
      const folderName =
        preview.type === "note" ? resolvePreviewFolderName() : undefined;
      const typeIcon = getTypeIcon(preview.type, preview.triggerType);
      const typeLabel = getTypeLabel(preview.type, preview.triggerType);

      badges.push({
        key: "type",
        icon: typeIcon,
        label: typeLabel,
        tone: "accent",
        accessibilityLabel: `Tipo ${typeLabel}`,
      });

      if (preview.priority) {
        const priorityLabel = getPriorityLabel(preview.priority);
        const tone: BadgeTone =
          preview.priority === 3
            ? "danger"
            : preview.priority === 2
            ? "warning"
            : "success";
        badges.push({
          key: "priority",
          icon: "lightning",
          label: `Prioridade ${priorityLabel}`,
          tone,
          accessibilityLabel: `Prioridade ${priorityLabel}`,
        });
      }

      if (
        preview.fireAt instanceof Date &&
        !Number.isNaN(preview.fireAt.getTime())
      ) {
        const datePart = preview.fireAt.toLocaleDateString();
        const timePart = preview.fireAt.toLocaleTimeString([], {
          hour: "2-digit",
          minute: "2-digit",
        });
        const label = `${datePart} ${timePart}`.trim();
        badges.push({
          key: "fireAt",
          icon: "clock",
          label,
          tone: "neutral",
          accessibilityLabel: `Agendado para ${label}`,
        });
      }

      if (folderName) {
        badges.push({
          key: "folder",
          icon: "folder",
          label: folderName,
          tone: "neutral",
          accessibilityLabel: `Pasta ${folderName}`,
        });
      }

      const people = preview.persons?.length
        ? preview.persons
        : preview.person
        ? [preview.person]
        : [];
      people.forEach((person, index) => {
        const trimmed = person.trim();
        if (!trimmed) return;
        badges.push({
          key: `person-${index}-${trimmed}`,
          icon: "person",
          label: trimmed,
          tone: "neutral",
          accessibilityLabel: `Pessoa ${trimmed}`,
        });
      });

      const locations = preview.locations?.length
        ? preview.locations
        : preview.location
        ? [preview.location]
        : [];
      locations.forEach((location, index) => {
        const trimmed = location.trim();
        if (!trimmed) return;
        badges.push({
          key: `location-${index}-${trimmed}`,
          icon: "location",
          label: trimmed,
          tone: "neutral",
          accessibilityLabel: `Local ${trimmed}`,
        });
      });

      if (preview.project) {
        badges.push({
          key: "project",
          icon: "pin",
          label: preview.project,
          tone: "neutral",
          accessibilityLabel: `Projeto ${preview.project}`,
        });
      }

      if (preview.tags?.length) {
        preview.tags.forEach((tag, index) => {
          const trimmed = tag.trim();
          if (!trimmed) return;
          badges.push({
            key: `tag-${index}-${trimmed}`,
            label: `#${trimmed}`,
            tone: "neutral",
            accessibilityLabel: `Tag ${trimmed}`,
          });
        });
      }

      return badges;
    }, [preview, resolvePreviewFolderName]);

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
        const createFolderInfo =
          SmartTextParser.extractCreateFolderName(rawText);
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
          await handleSubmitNote(
            parsed as ParsedReminder & { type: "note" },
            text
          );
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
            <Text
              key={`${segment.kind}-${idx}`}
              style={highlightStyle(segment.kind)}
            >
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

    const renderBadges = () => {
      if (!preview || previewBadges.length === 0) return null;

      const fullscreenActive = isFullscreenLayout;
      const scrollStyles = [
        styles.badgesScroll,
        fullscreenActive && styles.badgesScrollFullscreen,
      ];
      const contentStyles = [
        styles.badgesContent,
        fullscreenActive && styles.badgesContentFullscreen,
      ];

      return (
        <Animated.View
          style={[
            styles.badgesContainer,
            fullscreenActive && styles.badgesContainerFullscreen,
            { opacity: fadeAnim },
          ]}
        >
          <ScrollView
            ref={previewScrollRef}
            style={scrollStyles}
            contentContainerStyle={contentStyles}
            keyboardShouldPersistTaps="handled"
            showsVerticalScrollIndicator={previewBadges.length > 6}
            onScroll={(event) =>
              syncScroll("preview", event.nativeEvent.contentOffset.y)
            }
            scrollEventThrottle={16}
            onLayout={(event) =>
              setPreviewViewportHeight(event.nativeEvent.layout.height)
            }
            onContentSizeChange={(_, height) => setPreviewContentHeight(height)}
          >
            {previewBadges.map((badge) => {
              const appearance = BADGE_APPEARANCE[badge.tone];
              return (
                <View
                  key={badge.key}
                  style={[
                    styles.badge,
                    {
                      backgroundColor: appearance.backgroundColor,
                      borderColor: appearance.borderColor,
                    },
                  ]}
                  accessible
                  accessibilityRole="text"
                  accessibilityLabel={badge.accessibilityLabel}
                >
                  {badge.icon ? (
                    <AppIcon
                      icon={badge.icon}
                      size={16}
                      color={appearance.textColor}
                      style={styles.badgeIcon}
                    />
                  ) : null}
                  <Text
                    style={[styles.badgeLabel, { color: appearance.textColor }]}
                  >
                    {badge.label}
                  </Text>
                </View>
              );
            })}
          </ScrollView>
        </Animated.View>
      );
    };

    const shouldShowExpandButton = !isFullscreen && isOverflowing;
    const scrollAreaStyles = [
      styles.scrollArea,
      isFullscreenLayout
        ? styles.scrollAreaFullscreen
        : { maxHeight: Math.max(collapsedHeight - INPUT_VERTICAL_PADDING, 0) },
    ];
    const scrollContentStyle = [
      styles.scrollContent,
      isFullscreenLayout && styles.scrollContentFullscreen,
    ];
    const inputContainerStyles = [
      styles.inputContainer,
      isFullscreenLayout
        ? styles.inputContainerFullscreen
        : styles.inputContainerCompact,
      isFullscreenLayout
        ? { minHeight: baselineHeight, flex: 1, height: undefined }
        : { minHeight: baselineHeight, height: animatedHeight },
    ];

    const argSuggestions = renderArgSuggestions();
    const commandMatches = renderCommandMatches();
    const badgesNode = renderBadges();
    const hasMetaContent = Boolean(argSuggestions || commandMatches);
    const metaContainerStyles = [
      isFullscreenLayout ? styles.fullscreenMeta : styles.metaInline,
      !hasMetaContent && styles.metaHidden,
    ];
    const metaSection = (
      <View style={metaContainerStyles} pointerEvents="box-none">
        {argSuggestions}
        {commandMatches}
      </View>
    );

    const inputBlock = (
      <Animated.View style={inputContainerStyles}>
        <View style={styles.composedInput}>
          <ScrollView
            ref={inputScrollRef}
            style={scrollAreaStyles}
            contentContainerStyle={scrollContentStyle}
            keyboardShouldPersistTaps="handled"
            showsVerticalScrollIndicator={isFullscreenLayout || isOverflowing}
            scrollEnabled={isFullscreenLayout || isOverflowing}
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
            <AppIcon
              icon={isProcessing ? "hourglass" : "check"}
              size={18}
              color={Colors.dark.background}
            />
          </TouchableOpacity>
        )}
        {shouldShowExpandButton && (
          <TouchableOpacity
            accessibilityRole="button"
            accessibilityLabel="Expand terminal"
            style={styles.expandButton}
            onPress={openFullscreen}
          >
            <Text style={styles.expandIcon}>⤢</Text>
          </TouchableOpacity>
        )}
      </Animated.View>
    );

    const bottomPadding = Math.max(insets.bottom, 16);
    let bodyContent: React.ReactNode;

    if (isFullscreenLayout) {
      bodyContent = (
        <View style={styles.fullscreenContent}>
          {badgesNode || <View style={styles.badgesPlaceholder} />}
          <View
            style={[styles.fullscreenTop, { paddingBottom: bottomPadding }]}
          >
            {inputBlock}
            {metaSection}
          </View>
        </View>
      );
    } else {
      bodyContent = (
        <View style={styles.compactStack}>
          {inputBlock}
          {metaSection}
          {badgesNode}
        </View>
      );
    }

    if (isFullscreen) {
      return (
        <Modal
          animationType="slide"
          presentationStyle="fullScreen"
          visible
          onRequestClose={closeFullscreen}
        >
          <KeyboardAvoidingView
            behavior={Platform.OS === "ios" ? "padding" : undefined}
            keyboardVerticalOffset={insets.top}
            style={styles.fullscreenAvoider}
          >
            <SafeAreaView style={styles.fullscreenContainer}>
              <View style={styles.fullscreenHeader}>
                <View style={styles.drawerHandle} />
                <TouchableOpacity
                  accessibilityRole="button"
                  accessibilityLabel="Retract terminal"
                  style={styles.collapseButton}
                  onPress={closeFullscreen}
                >
                  <Text style={styles.expandIcon}>⤡</Text>
                </TouchableOpacity>
              </View>
              <View style={[styles.fullscreenInner, style]}>{bodyContent}</View>
            </SafeAreaView>
          </KeyboardAvoidingView>
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
  fullscreenAvoider: {
    flex: 1,
    backgroundColor: Colors.dark.background,
  },
  fullscreenContainer: {
    flex: 1,
    backgroundColor: Colors.dark.background,
  },
  fullscreenHeader: {
    paddingTop: 12,
    paddingBottom: 8,
    paddingHorizontal: 16,
    alignItems: "center",
    justifyContent: "center",
  },
  fullscreenInner: {
    flex: 1,
    paddingHorizontal: 16,
    paddingTop: 12,
    paddingBottom: 16,
    alignItems: "stretch",
  },
  fullscreenContent: {
    flex: 1,
    width: "100%",
  },
  fullscreenTop: {
    flex: 1,
    paddingTop: 0,
    minHeight: 0,
  },
  fullscreenMeta: {
    marginTop: 12,
    flexShrink: 0,
  },
  drawerHandle: {
    alignSelf: "center",
    width: 48,
    height: 4,
    borderRadius: 2,
    backgroundColor: Colors.dark.border,
    marginTop: 4,
    marginBottom: 4,
  },
  compactStack: {
    width: "100%",
  },
  metaInline: {
    marginTop: 8,
  },
  metaHidden: {
    marginTop: 0,
    height: 0,
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
    borderRadius: 0,
    borderWidth: 0,
    borderColor: "transparent",
    backgroundColor: Colors.dark.background,
    marginHorizontal: 0,
    alignSelf: "stretch",
    paddingHorizontal: 16,
    paddingVertical: 16,
  },
  scrollArea: { width: "100%" },
  scrollAreaFullscreen: { flex: 1 },
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
    top: 4,
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: Colors.dark.surface,
    borderWidth: 1,
    borderColor: Colors.dark.border,
    alignItems: "center",
    justifyContent: "center",
    zIndex: 2,
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
  badgesContainer: {
    marginTop: 12,
    borderTopWidth: 1,
    borderColor: Colors.dark.border,
    paddingTop: 12,
  },
  badgesContainerFullscreen: {
    marginTop: 0,
    marginBottom: 12,
    borderTopWidth: 0,
    paddingTop: 0,
    paddingBottom: 12,
  },
  badgesScroll: {
    width: "100%",
    maxHeight: PREVIEW_MAX_HEIGHT,
  },
  badgesScrollFullscreen: {
    flexGrow: 0,
    maxHeight: undefined,
  },
  badgesContent: {
    flexDirection: "row",
    flexWrap: "wrap",
    paddingBottom: 4,
  },
  badgesContentFullscreen: {
    paddingBottom: 16,
  },
  badge: {
    flexDirection: "row",
    alignItems: "center",
    paddingVertical: 6,
    paddingHorizontal: 12,
    borderRadius: 16,
    borderWidth: 1,
    marginRight: 8,
    marginBottom: 8,
    backgroundColor: Colors.dark.surface,
  },
  badgeIcon: {
    marginRight: 6,
  },
  badgeLabel: {
    ...Typography.caption,
    fontWeight: "600",
  },
  badgesPlaceholder: {
    height: 12,
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
