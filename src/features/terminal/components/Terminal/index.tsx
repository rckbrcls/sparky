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
import { useFolderMap } from "@/src/features/notes/hooks/useFolderMap";

import { ReminderService } from "@/src/features/timeline/services/ReminderService";
import { slugifyForArgs } from "@/src/features/terminal/engine";
import { applyArgumentInsert } from "@/src/features/terminal/engine";
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

    const { preview, fadeAnim, updateFromIntent, hidePreview } =
      useReminderPreview();
    const { folderMap, setFolderMap } = useFolderMap();

    const {
      commandState,
      recompute,
      handleSelectCommand,
      handleSelectArgSuggestion,
      intent,
      finalizeActiveArgWithPartial,
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
        updateFromIntent(value, intent);
        recompute(value, selection.end);
      },
      [intent, recompute, selection.end, updateFromIntent]
    );

    // Helpers to work only with activated commands (no slash parsing)
    const getActivatedValues = useCallback(
      (name: string) => intent.activated.filter((c) => c.name === name && (c.value ?? "").trim().length > 0).map((c) => c.value!.trim()),
      [intent.activated]
    );

    const removeActivatedTokensFromText = useCallback(
      (raw: string) => {
        if (!intent.activated.length) return raw;
        // Remove instances of "name" + optional space + single-word value at (approx) tracked indices
        let value = raw;
        // sort by index desc to avoid shifting
        const acts = [...intent.activated].sort((a, b) => (b.index ?? 0) - (a.index ?? 0));
        for (const a of acts) {
          const name = a.name;
          const idx = a.index != null ? a.index : value.indexOf(name);
          if (idx < 0) continue;
          const nameEnd = idx + name.length;
          let end = nameEnd;
          if (value[end] === " ") {
            end += 1;
            while (end < value.length && value[end] !== " ") end += 1;
          }
          value = (value.slice(0, idx) + value.slice(end)).replace(/\s{2,}/g, " ").trim();
        }
        return value.trim();
      },
      [intent.activated]
    );

    const handleSubmitUsingIntent = useCallback(async () => {
      const cleaned = removeActivatedTokensFromText(text);
      const type = intent.type === "reminder" ? "reminder" : "note";

      if (type === "note") {
        // Resolve folder by name (create if missing)
        const folderName = getActivatedValues("folder")[0];
        let chosenFolderId: string | undefined = undefined;
        try {
          const allFolders = await database.getAllFolders();
          const slugToId: Record<string, string> = {};
          allFolders.forEach((folder: any) => {
            slugToId[slugifyForArgs(folder.name)] = folder.id;
          });
          if (folderName) {
            const rawSlug = slugifyForArgs(folderName);
            let actual = slugToId[rawSlug];
            if (!actual && rawSlug && rawSlug !== "all") {
              const newId = await database.createFolder({ name: folderName, color: "#777777" });
              actual = newId;
              setFolderMap((prev) => ({ ...prev, [newId]: folderName }));
            }
            chosenFolderId = actual;
          }
        } catch {}

        if (cleaned) {
          await database.createQuickNote({
            content: cleaned,
            folderId: chosenFolderId,
          });
        }
        return;
      }

      // reminder
      const persons = getActivatedValues("person");
      const locations = getActivatedValues("location");
      const reminderId = await ReminderService.createReminder({
        title: cleaned || "",
        person: persons[0],
        project: undefined,
        location: locations[0],
        type: locations.length > 0 ? "by_location" : persons.length > 0 ? "by_person_project" : "once",
        fireAt: undefined,
      });

      const triggerPromises: Promise<string>[] = [];
      persons.forEach((p) => {
        triggerPromises.push(
          database.createTrigger({
            reminderId,
            type: "person",
            config: JSON.stringify({ contactName: p }),
            isActive: true,
          })
        );
      });
      locations.forEach((loc) => {
        triggerPromises.push(
          database.createTrigger({
            reminderId,
            type: "location",
            config: JSON.stringify({ location: loc }),
            isActive: true,
          })
        );
      });
      await Promise.all(triggerPromises);
    }, [database, getActivatedValues, intent.type, removeActivatedTokensFromText, setFolderMap, slugifyForArgs, text]);

    const handleSubmit = useCallback(async () => {
      if (!text.trim()) return;
      setIsProcessing(true);

      try {
        await handleSubmitUsingIntent();

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
      handleSubmitUsingIntent,
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

    useEffect(() => {
      updateFromIntent(text, intent);
    }, [text, intent, updateFromIntent]);

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

      if ((key === " " || key === "Spacebar") && inArgMode && activeCommand?.name && argReplaceFrom != null) {
        // finalize the current argument using the typed partial
        const partial = commandState.argPartial ?? "";
        const { newText, newCursor } = applyArgumentInsert(
          text,
          argReplaceFrom,
          selection.start,
          partial,
          true
        );
        applyProgrammaticTextChange(newText, newCursor);
        finalizeActiveArgWithPartial(partial);
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
            activatedCommands={intent.activated}
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
          <Badges preview={preview} fadeAnim={fadeAnim} folderMap={folderMap} intent={intent} />
        </View>
      </View>
    );
  }
);

Terminal.displayName = "Terminal";
