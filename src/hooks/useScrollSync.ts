import { useCallback, useRef, useState } from "react";
import type { RefObject } from "react";
import { ScrollView } from "react-native";

interface UseScrollSyncResult {
  inputScrollRef: RefObject<ScrollView | null>;
  previewScrollRef: RefObject<ScrollView | null>;
  syncScroll: (source: "input" | "preview", offsetY: number) => void;
  setInputContentHeight: React.Dispatch<React.SetStateAction<number>>;
  setPreviewContentHeight: React.Dispatch<React.SetStateAction<number>>;
  setInputViewportHeight: React.Dispatch<React.SetStateAction<number>>;
  setPreviewViewportHeight: React.Dispatch<React.SetStateAction<number>>;
}

export const useScrollSync = (): UseScrollSyncResult => {
  const inputScrollRef = useRef<ScrollView | null>(null);
  const previewScrollRef = useRef<ScrollView | null>(null);
  const [inputContentHeight, setInputContentHeight] = useState(0);
  const [previewContentHeight, setPreviewContentHeight] = useState(0);
  const [inputViewportHeight, setInputViewportHeight] = useState(0);
  const [previewViewportHeight, setPreviewViewportHeight] = useState(0);
  const syncingRef = useRef(false);

  const syncScroll = useCallback(
    (source: "input" | "preview", offsetY: number) => {
      if (syncingRef.current) return;

      const inputScrollable = Math.max(0, inputContentHeight - inputViewportHeight);
      const previewScrollable = Math.max(
        0,
        previewContentHeight - previewViewportHeight
      );

      if (inputScrollable === 0 && previewScrollable === 0) return;

      let normalized = 0;
      if (source === "input") {
        normalized = inputScrollable ? offsetY / inputScrollable : 0;
      } else {
        normalized = previewScrollable ? offsetY / previewScrollable : 0;
      }
      normalized = Math.min(1, Math.max(0, normalized));

      const targetY =
        source === "input"
          ? normalized * previewScrollable
          : normalized * inputScrollable;
      const targetRef =
        source === "input" ? previewScrollRef.current : inputScrollRef.current;
      if (!targetRef) return;

      syncingRef.current = true;
      targetRef.scrollTo({ y: targetY, animated: false });
      requestAnimationFrame(() => {
        syncingRef.current = false;
      });
    },
    [
      inputContentHeight,
      inputViewportHeight,
      previewContentHeight,
      previewViewportHeight,
    ]
  );

  return {
    inputScrollRef,
    previewScrollRef,
    syncScroll,
    setInputContentHeight,
    setPreviewContentHeight,
    setInputViewportHeight,
    setPreviewViewportHeight,
  };
};
