import { useCallback, useRef, useState } from "react";
import type { Dispatch, SetStateAction } from "react";
import {
  applyArgumentInsert,
  applyCommandInsert as applyNewCommandInsert,
} from "../services/commands/CommandInsertion";
import { CommandDefinition } from "../services/commands/CommandRegistry";
import {
  computeCommandState,
  ComputedCommandState,
  resolveArgumentSuggestions,
} from "../services/commands/CommandContextEngine";

interface UseCommandEngineParams {
  text: string;
  selectionStart: number;
  setText: Dispatch<SetStateAction<string>>;
  setSelection: Dispatch<SetStateAction<{ start: number; end: number }>>;
}

interface UseCommandEngineResult {
  commandState: ComputedCommandState;
  recompute: (value: string, cursor: number) => void;
  handleSelectCommand: (cmd: CommandDefinition) => void;
  handleSelectArgSuggestion: (value: string) => void;
}

export const useCommandEngine = ({
  text,
  selectionStart,
  setText,
  setSelection,
}: UseCommandEngineParams): UseCommandEngineResult => {
  const [commandState, setCommandState] = useState<ComputedCommandState>({
    inArgMode: false,
    segments: [],
  });
  const requestCounterRef = useRef(0);

  const recompute = useCallback((value: string, cursor: number) => {
    const reqId = `${++requestCounterRef.current}`;
    const base = computeCommandState({
      text: value,
      cursor,
      requestId: reqId,
    });
    setCommandState(base);

    if (base.inArgMode && base.activeCommand?.argument) {
      resolveArgumentSuggestions(base).then((resolved) => {
        if (resolved.requestId === `${requestCounterRef.current}`) {
          setCommandState(resolved);
        }
      });
    }
  }, []);

  const handleSelectCommand = useCallback(
    (cmd: CommandDefinition) => {
      const { newText, newCursor } = applyNewCommandInsert(
        text,
        cmd,
        selectionStart
      );
      setText(newText);
      setSelection({ start: newCursor, end: newCursor });
      recompute(newText, newCursor);
    },
    [recompute, selectionStart, setSelection, setText, text]
  );

  const handleSelectArgSuggestion = useCallback(
    (value: string) => {
      if (!commandState.inArgMode || !commandState.activeCommand) return;
      const { argReplaceFrom } = commandState;
      if (argReplaceFrom == null) return;

      const { newText, newCursor } = applyArgumentInsert(
        text,
        argReplaceFrom,
        selectionStart,
        value,
        commandState.activeCommand.finalizeOnSelect !== false
      );
      setText(newText);
      setSelection({ start: newCursor, end: newCursor });
      recompute(newText, newCursor);
    },
    [commandState, recompute, selectionStart, setSelection, setText, text]
  );

  return { commandState, recompute, handleSelectCommand, handleSelectArgSuggestion };
};
