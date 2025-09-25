import React, { useMemo } from "react";
import {
  Animated,
  ScrollView,
  Text,
  TextInput,
  TextInputKeyPressEvent,
  TouchableOpacity,
  View,
} from "react-native";
import { AppIcon } from "@/src/components/AppIcon";
import { Colors } from "@/src/constants/Colors";
import type { Segment } from "@/src/features/terminal/engine";
import type { ActivatedCommand } from "@/src/features/terminal/engine/intent";
import { styles } from "./styles";

interface InputBlockProps {
  text: string;
  isProcessing: boolean;
  inputRef: React.RefObject<TextInput | null>;
  onChangeText: (value: string) => void;
  onSubmit: () => void;
  onSelectionChange: (start: number, end: number) => void;
  onKeyPress: (event: TextInputKeyPressEvent) => void;
  activatedCommands?: ActivatedCommand[];
}

export const InputBlock: React.FC<InputBlockProps> = ({
  text,
  isProcessing,
  inputRef,
  onChangeText,
  onSubmit,
  onSelectionChange,
  onKeyPress,
  activatedCommands = [],
}) => {
  const highlightStyle = (kind: Segment["kind"]) => {
    switch (kind) {
      case "command":
        return styles.hlCommand;
      case "commandActive":
        return styles.hlCommandActive;
      case "commandArg":
        return styles.hlCommandArg;
      case "tag":
        return styles.hlTag;
      default:
        return styles.hlNormal;
    }
  };

  const segments = useMemo(() => {
    // Base rendering treats everything as normal text. We then overlay
    // activated command name ranges (without slash) as commandActive.
    const base: Segment[] = [{ text, kind: "normal" }];
    if (!activatedCommands.length) return base;

    const ranges = activatedCommands
      .map((c) => (c.index != null ? { start: c.index!, end: c.index! + c.name.length } : null))
      .filter(Boolean) as { start: number; end: number }[];
    if (!ranges.length) return base;

    const result: Segment[] = [];
    const seg = base[0];
    const start = 0;
    const end = seg.text.length;
    let cursor = start;
    while (true) {
      const nextRange = ranges.find((r) => r.start < end && r.end > cursor);
      if (!nextRange) {
        if (cursor < end) result.push({ text: seg.text.slice(cursor - start), kind: seg.kind });
        break;
      }
      if (cursor < nextRange.start && nextRange.start < end) {
        result.push({ text: seg.text.slice(cursor - start, nextRange.start - start), kind: seg.kind });
      }
      const a = Math.max(cursor, nextRange.start);
      const b = Math.min(end, nextRange.end);
      if (a < b) {
        result.push({ text: seg.text.slice(a - start, b - start), kind: "commandActive" });
      }
      cursor = b;
      if (cursor >= end) break;
    }

    return result;
  }, [activatedCommands, text]);

  const renderSegments = () => {
    if (!text.length) {
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

  return (
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
              style={styles.inputOverlay}
              value={text}
              onChangeText={onChangeText}
              multiline
              returnKeyType="done"
              onSubmitEditing={onSubmit}
              editable={!isProcessing}
              onSelectionChange={(event) => {
                const { start, end } = event.nativeEvent.selection;
                onSelectionChange(start, end);
              }}
              onKeyPress={onKeyPress}
              autoCapitalize="none"
              autoCorrect={false}
              scrollEnabled={false}
            />
          </View>
        </ScrollView>
      </View>
      {!!text.trim().length && (
        <TouchableOpacity
          style={[
            styles.submitButton,
            isProcessing && styles.submitButtonDisabled,
          ]}
          onPress={onSubmit}
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
};
