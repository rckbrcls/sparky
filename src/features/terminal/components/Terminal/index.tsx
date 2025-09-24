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
  ScrollView,
  Text,
  TextInput,
  TextInputKeyPressEvent,
  TouchableOpacity,
  View,
} from "react-native";
import { Colors } from "../../../../constants/Colors";
import { useGlobalTouchDismiss } from "../../../../context/GlobalTouchDismissContext";
import { database } from "../../../../database";
import { useCommandEngine } from "../../../../hooks/useCommandEngine";
import { useFolderMap } from "../../../../hooks/useFolderMap";
import { useReminderPreview } from "../../../../hooks/useReminderPreview";
import {
  buildSegments,
  Segment,
} from "../../../../services/commands/CommandHighlights";
import { CommandDefinition } from "../../../../services/commands/CommandRegistry";
import { ReminderService } from "../../../../services/ReminderService";
import {
  ParsedReminder,
  SmartTextParser,
} from "../../../../services/SmartTextParser";
import {
  cleanSystemCommands,
  matchDeleteFolderCommand,
  matchFolderCommand,
  SLUG_ARG_COMMANDS,
  slugify,
  stripAllSystemCommands,
} from "../../../../utils/terminal";
import { AppIcon } from "../../../../components/AppIcon";
import Badges from "../Badges";
import { styles } from "./styles";

interface TerminalProps {
  onReminderCreated: () => void;
}

export interface TerminalHandle {
  blur: () => void;
  focus: () => void;
}

export const Terminal = React.forwardRef<TerminalHandle, TerminalProps>(
  ({ onReminderCreated }, ref) => {
    const [text, setText] = useState("");
    const [segments, setSegments] = useState<Segment[]>([]);
    const [selection, setSelection] = useState({ start: 0, end: 0 });
    const [isProcessing, setIsProcessing] = useState(false);
    const ignoreNextChangeRef = useRef(false);

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
          allFolders.forEach((folder: any) => {
            slugToId[slugify(folder.name)] = folder.id;
          });

          if (createFolderInfo.id && createFolderInfo.id !== "all") {
            let actual = slugToId[createFolderInfo.id];
            if (!actual) {
              const newId = await database.createFolder({
                name: createFolderInfo.raw || createFolderInfo.id,
                color: "#777777",
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
                (folder: any) =>
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
            title: content,
            body: content,
            folderId: chosenFolderId === "all" ? undefined : chosenFolderId,
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
          <Text style={styles.placeholderText}>text, /command and #tag</Text>
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

    const argSuggestions = renderArgSuggestions();
    const commandMatches = renderCommandMatches();

    const hasMetaContent = Boolean(argSuggestions || commandMatches);
    const metaContainerStyles = [
      styles.metaInline,
      !hasMetaContent && styles.metaHidden,
    ];
    const metaSection = (
      <View style={metaContainerStyles} pointerEvents="box-none">
        {argSuggestions}
        {commandMatches}
      </View>
    );

    function onInputKeyPress(event: TextInputKeyPressEvent) {
      const key = event.nativeEvent.key;
      if (key === "/") {
        const selStart = selection.start;
        const selEnd = selection.end;
        const newText = text.slice(0, selStart) + "/" + text.slice(selEnd);
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
          const newText = text.slice(0, cutPos) + text.slice(selection.start);
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
    }

    const inputBlock = (
      <Animated.View style={styles.inputContainer}>
        <View style={styles.composedInput}>
          <ScrollView
            style={styles.scrollArea}
            contentContainerStyle={styles.scrollContent}
            keyboardShouldPersistTaps="handled"
            scrollEventThrottle={16}
          >
            <View style={styles.layeredInput}>
              <View style={styles.highlightLayer} pointerEvents="none">
                {renderSegments()}
              </View>
              <TextInput
                ref={inputRef}
                style={[styles.inputOverlay]}
                value={text}
                onChangeText={handleTextChange}
                multiline
                returnKeyType="done"
                onSubmitEditing={handleSubmit}
                editable={!isProcessing}
                onSelectionChange={(event) => {
                  const { start, end } = event.nativeEvent.selection;
                  setSelection({ start, end });
                  recompute(text, start);
                }}
                onKeyPress={onInputKeyPress}
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
      </Animated.View>
    );

    let bodyContent: React.ReactNode;

    bodyContent = (
      <View style={styles.compactStack}>
        {inputBlock}
        {metaSection}
        <Badges
          preview={preview}
          fadeAnim={fadeAnim}
          text={text}
          folderMap={folderMap}
        />
      </View>
    );

    return <View style={[styles.container]}>{bodyContent}</View>;
  }
);

Terminal.displayName = "Terminal";
