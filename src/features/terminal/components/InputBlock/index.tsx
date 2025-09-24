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
import { buildSegments, Segment } from "@/src/features/terminal/services/commands/CommandHighlights";
import { styles } from "./styles";

interface InputBlockProps {
  text: string;
  isProcessing: boolean;
  inputRef: React.RefObject<TextInput | null>;
  onChangeText: (value: string) => void;
  onSubmit: () => void;
  onSelectionChange: (start: number, end: number) => void;
  onKeyPress: (event: TextInputKeyPressEvent) => void;
}

export const InputBlock: React.FC<InputBlockProps> = ({
  text,
  isProcessing,
  inputRef,
  onChangeText,
  onSubmit,
  onSelectionChange,
  onKeyPress,
}) => {
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

  const segments = useMemo(() => buildSegments(text), [text]);

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
