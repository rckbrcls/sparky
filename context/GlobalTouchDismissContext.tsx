import React, { createContext, useCallback, useContext, useRef } from "react";
import { GestureResponderEvent, Keyboard, TextInput } from "react-native";

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
        // Current focused native input (may be null)
        const focused = (TextInput as any).State?.currentlyFocusedInput?.();
        if (!focused) return false; // nothing to do
        const target = e.nativeEvent.target;
        if (target === focused) return false; // tap on same input → ignore
        // If any custom registered input is focused, blur it
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
        if (anyFocused && !vetoBlur) blurAll();
      } catch {
        // Fallback safe dismiss
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
