import React, { createContext, useCallback, useContext, useRef } from "react";
import {
  GestureResponderEvent,
  Keyboard,
  TextInput,
  findNodeHandle,
} from "react-native";

interface RegisteredInput {
  isFocused: () => boolean;
  blur: () => void;
  /**
   * Return true if this tap should blur (default). Return false to preserve focus.
   * Receives the raw gesture event so heuristics (like open suggestion palette) can be applied.
   */
  shouldBlur?: (e: GestureResponderEvent) => boolean;
}

interface GlobalTouchDismissContextValue {
  register: (id: string, handlers: RegisteredInput) => void;
  unregister: (id: string) => void;
  blurAll: () => void;
  handleCapture: (e: GestureResponderEvent) => boolean;
}

const GlobalTouchDismissContext =
  createContext<GlobalTouchDismissContextValue | null>(null);

export const GlobalTouchDismissProvider: React.FC<{
  children: React.ReactNode;
}> = ({ children }) => {
  const inputsRef = useRef<Map<string, RegisteredInput>>(new Map());

  const register = useCallback((id: string, handlers: RegisteredInput) => {
    inputsRef.current.set(id, handlers);
  }, []);

  const unregister = useCallback((id: string) => {
    inputsRef.current.delete(id);
  }, []);

  const blurAll = useCallback(() => {
    inputsRef.current.forEach((h) => {
      if (h.isFocused()) {
        h.blur();
      }
    });
    Keyboard.dismiss();
  }, []);

  const handleCapture = useCallback(
    (e: GestureResponderEvent) => {
      try {
        const State = (TextInput as any).State;
        const focusedInput = State?.currentlyFocusedInput?.();
        if (!focusedInput) return false; // nothing focused, nothing to blur

        // Normalize focused handle (can be component instance or numeric tag depending on RN version)
        let focusedHandle: number | null = null;
        if (typeof focusedInput === "number") {
          focusedHandle = focusedInput;
        } else if (focusedInput?._nativeTag != null) {
          focusedHandle = focusedInput._nativeTag;
        } else {
          const maybe = findNodeHandle(focusedInput);
          if (typeof maybe === "number") focusedHandle = maybe;
        }

        const target: any = e.nativeEvent.target;

        // If the tap target IS the focused handle, do not blur (previous code compared object vs number → false mismatch)
        if (focusedHandle != null && target === focusedHandle) return false;

        // Heuristic: Some platforms report child views inside the TextInput (e.g. the inner text node).
        // To avoid breaking text selection (double‑tap / drag) we skip blurring for quick successive taps
        // occurring inside the same focused input bounds. Without parent chain, we approximate by checking
        // that the registered focused input vetoed blur or user provided shouldBlur returning false.

        let anyFocused = false;
        let vetoBlur = false;
        inputsRef.current.forEach((h) => {
          if (h.isFocused()) {
            anyFocused = true;
            if (h.shouldBlur && h.shouldBlur(e) === false) {
              vetoBlur = true;
            }
          }
        });

        if (anyFocused && !vetoBlur) {
          // Only blur if target is not the focused handle; since we can't reliably know descendants, allow custom veto.
          blurAll();
        }
      } catch {
        // Silent fallback
      }
      return false; // never claim responder
    },
    [blurAll]
  );

  return (
    <GlobalTouchDismissContext.Provider
      value={{ register, unregister, blurAll, handleCapture }}
    >
      {children}
    </GlobalTouchDismissContext.Provider>
  );
};

export const useGlobalTouchDismiss = () => {
  const ctx = useContext(GlobalTouchDismissContext);
  if (!ctx)
    throw new Error(
      "useGlobalTouchDismiss must be used within GlobalTouchDismissProvider"
    );
  return ctx;
};
