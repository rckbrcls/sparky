import { useCallback, useRef, useState } from "react";
import { Animated } from "react-native";
import type { ParsedReminder } from "@/src/features/terminal/engine";
import { buildPreviewFromIntent } from "@/src/features/terminal/engine/preview";
import type { IntentState } from "@/src/features/terminal/engine/intent";

interface UseReminderPreviewResult {
  preview: ParsedReminder | null;
  fadeAnim: Animated.Value;
  updateFromIntent: (text: string, intent: IntentState) => void;
  hidePreview: () => void;
}

const animateFade = (
  anim: Animated.Value,
  toValue: number,
  duration: number
) => {
  Animated.timing(anim, {
    toValue,
    duration,
    useNativeDriver: true,
  }).start();
};

export const useReminderPreview = (): UseReminderPreviewResult => {
  const fadeAnim = useRef(new Animated.Value(0)).current;
  const [preview, setPreview] = useState<ParsedReminder | null>(null);

  const hidePreview = useCallback(() => {
    setPreview(null);
    animateFade(fadeAnim, 0, 120);
  }, [fadeAnim]);

  const showPreview = useCallback(
    (value: ParsedReminder) => {
      setPreview(value);
      animateFade(fadeAnim, 1, 160);
    },
    [fadeAnim]
  );

  const updateFromIntent = useCallback(
    (text: string, intent: IntentState) => {
      const parsed = buildPreviewFromIntent(text, intent);
      const cleanedTitle = (parsed.title || "").trim();
      if (!cleanedTitle) {
        hidePreview();
        return;
      }
      showPreview(parsed);
    },
    [hidePreview, showPreview]
  );

  return { preview, fadeAnim, updateFromIntent, hidePreview };
};
