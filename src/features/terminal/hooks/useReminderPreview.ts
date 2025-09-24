import { useCallback, useRef, useState } from "react";
import { Animated } from "react-native";
import {
  ParsedReminder,
  SmartTextParser,
} from "../services/SmartTextParser";
import { shouldHidePreviewForText } from "../../../utils/terminal";

interface UseReminderPreviewResult {
  preview: ParsedReminder | null;
  fadeAnim: Animated.Value;
  updatePreview: (value: string) => void;
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

  const updatePreview = useCallback(
    (value: string) => {
      if (shouldHidePreviewForText(value)) {
        hidePreview();
        return;
      }

      try {
        const parsed = SmartTextParser.parseText(value);
        showPreview(parsed);
      } catch {
        hidePreview();
      }
    },
    [hidePreview, showPreview]
  );

  return { preview, fadeAnim, updatePreview, hidePreview };
};
