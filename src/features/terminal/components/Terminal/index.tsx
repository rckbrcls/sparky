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
  TextInput,
  TextInputKeyPressEvent,
  View,
} from "react-native";
import { useGlobalTouchDismiss } from "../../../../context/GlobalTouchDismissContext";
import { database } from "../../../../database";
import { useCommandEngine } from "../../hooks/useCommandEngine";
import { useFolderMap } from "../../../../hooks/useFolderMap";

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
import { Badges } from "../Badges";
import { InputBlock } from "../InputBlock";
import { MetaSection } from "../MetaSection";
import { styles } from "./styles";
import { useReminderPreview } from "../../hooks/useReminderPreview";

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
    });

    const {
      inArgMode,
      argSuggestions,
      activeCommand,
      commandMatches,
      openCommandQuery,
      argReplaceFrom,
    } = commandState;

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
        updatePreview(value);
        recompute(value, selection.end);
      },
      [recompute, selection.end, updatePreview]
    );

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

    const applyProgrammaticTextChange = useCallback(
      (newText: string, newCursor: number) => {
        ignoreNextChangeRef.current = true;
        setText(newText);
        setSelection({ start: newCursor, end: newCursor });
        recompute(newText, newCursor);
      },
      [recompute, setSelection, setText]
    );

    function onInputKeyPress(event: TextInputKeyPressEvent) {
      const key = event.nativeEvent.key;
      if (key === "/") {
        const selStart = selection.start;
        const selEnd = selection.end;
        const newText = text.slice(0, selStart) + "/" + text.slice(selEnd);
        const newCursor = selStart + 1;
        applyProgrammaticTextChange(newText, newCursor);
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
          const newCursor = cutPos;
          applyProgrammaticTextChange(newText, newCursor);
          return;
        }
      }

      if (
        (key === " " || key === "Spacebar") &&
        inArgMode &&
        activeCommand?.name &&
        SLUG_ARG_COMMANDS.has(activeCommand.name) &&
        argReplaceFrom != null
      ) {
        const selStart = selection.start;
        const selEnd = selection.end;
        const before = text.slice(0, selStart);
        const after = text.slice(selEnd);
        const newText = `${before}-${after}`;
        const newCursor = selStart + 1;
        applyProgrammaticTextChange(newText, newCursor);
      }
    }

    return (
      <View style={styles.container}>
        <View style={styles.compactStack}>
          <InputBlock
            text={text}
            isProcessing={isProcessing}
            inputRef={inputRef}
            onChangeText={handleTextChange}
            onSubmit={handleSubmit}
            onSelectionChange={(start, end) => {
              setSelection({ start, end });
              recompute(text, start);
            }}
            onKeyPress={onInputKeyPress}
          />
          <MetaSection
            inArgMode={inArgMode}
            argSuggestions={argSuggestions}
            activeCommand={activeCommand}
            commandMatches={commandMatches}
            openCommandQuery={openCommandQuery}
            onSelectArgSuggestion={handleSelectArgSuggestion}
            onSelectCommand={handleSelectCommand}
          />
          <Badges
            preview={preview}
            fadeAnim={fadeAnim}
            text={text}
            folderMap={folderMap}
          />
        </View>
      </View>
    );
  }
);

Terminal.displayName = "Terminal";
