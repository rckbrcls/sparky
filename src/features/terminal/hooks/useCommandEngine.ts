import { useCallback, useMemo, useRef, useState } from "react";
import type { Dispatch, SetStateAction } from "react";
import { applyArgumentInsert, computeCommandState, resolveArgumentSuggestions } from "@/src/features/terminal/engine";
import type { CommandDefinition, ComputedCommandState } from "@/src/features/terminal/engine";
import {
  createInitialIntent,
  findActivatedByNameNearIndex,
  intentAddCommand,
  intentRemoveCommand,
  intentSetCommandValue,
  intentUpdateCommandIndex,
  IntentState,
} from "@/src/features/terminal/engine/intent";
import { filterCommandMatches } from "@/src/features/terminal/engine/policy";

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
  intent: IntentState;
  removeActivatedById: (id: string) => void;
  finalizeActiveArgWithPartial: (partial: string) => void;
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
  const [intent, setIntent] = useState<IntentState>(createInitialIntent());
  const requestCounterRef = useRef(0);

  const recompute = useCallback((value: string, cursor: number) => {
    const reqId = `${++requestCounterRef.current}`;
    const base = computeCommandState({
      text: value,
      cursor,
      requestId: reqId,
      activated: intent.activated.map((a) => ({ name: a.name, index: a.index })),
    });
    let filtered = {
      ...base,
      commandMatches: base.commandMatches
        ? filterCommandMatches(base.commandMatches, intent)
        : base.commandMatches,
    } as ComputedCommandState;
    // Arg suggestions only for activated commands
    if (filtered.inArgMode && filtered.activeCommand) {
      const approxStart = filtered.argReplaceFrom != null
        ? filtered.argReplaceFrom - (filtered.activeCommand.name.length + 1)
        : undefined;
      const active = findActivatedByNameNearIndex(
        intent,
        filtered.activeCommand.name,
        approxStart
      );
      if (!active) {
        filtered = { ...filtered, inArgMode: false, activeCommand: undefined, argPartial: undefined, argReplaceFrom: undefined } as ComputedCommandState;
      } else {
        // keep index in sync best-effort
        setIntent((prev) => intentUpdateCommandIndex(prev, active.id, approxStart));
      }
    }
    setCommandState(filtered);

    if (filtered.inArgMode && filtered.activeCommand?.argument) {
      resolveArgumentSuggestions(filtered).then((resolved) => {
        if (resolved.requestId === `${requestCounterRef.current}`) {
          setCommandState(resolved);
        }
      });
    }
    // Best-effort resync of activated indices when text changes
    setIntent((prev) => {
      let changed = false;
      const updated = prev.activated.map((c) => {
        let idx = c.index ?? -1;
        const ok = idx >= 0 && value.slice(idx, idx + c.name.length) === c.name;
        if (!ok) {
          const re = new RegExp(`(^|\\s)${c.name}(?=\\s)`, 'g');
          let m: RegExpExecArray | null;
          let bestIdx = -1;
          let bestDelta = Number.POSITIVE_INFINITY;
          while ((m = re.exec(value)) !== null) {
            const start = m.index + (m[1] ? 1 : 0);
            const delta = c.index != null ? Math.abs(start - c.index) : 0;
            if (delta < bestDelta) {
              bestDelta = delta;
              bestIdx = start;
            }
          }
          if (bestIdx >= 0) {
            idx = bestIdx;
          }
        }
        if (idx !== (c.index ?? -1)) changed = true;
        return { ...c, index: idx >= 0 ? idx : c.index };
      });
      return changed ? { ...prev, activated: updated } : prev;
    });
  }, [intent]);

  const removeActivatedById = useCallback(
    (id: string) => {
      // Try to remove the token and its immediate arg from the text
      const target = intent.activated.find((c) => c.id === id);
      if (!target) {
        setIntent((prev) => intentRemoveCommand(prev, id));
        return;
      }
      const start = (target.index ?? text.indexOf(target.name));
      if (start < 0) {
        setIntent((prev) => intentRemoveCommand(prev, id));
        return;
      }
      // remove: "name" + optional space + optional single-word argument
      const nameEnd = start + target.name.length;
      let end = nameEnd;
      if (text[end] === ' ') {
        end += 1;
        while (end < text.length && text[end] !== ' ') end += 1;
      }
      const newText = (text.slice(0, start) + text.slice(end)).replace(/\s{2,}/g, ' ').trimStart();
        const newCursor = Math.min(selectionStart, newText.length);
        setText(newText);
        setSelection({ start: newCursor, end: newCursor });
        setIntent((prev) => intentRemoveCommand(prev, id));
        recompute(newText, newCursor);
      
    },
    [intent.activated, recompute, selectionStart, setSelection, setText, text]
  );

  const handleSelectCommand = useCallback(
    (cmd: CommandDefinition) => {
      const prevType = intent.activated.find((c) => c.name === 'note' || c.name === 'date');
      // Replace trailing "/partial" before cursor with "name " (no slash). If none, insert at cursor.
      const prefix = text.slice(0, selectionStart);
      const suffix = text.slice(selectionStart);
      const m = /(\/[^\s]*)$/.exec(prefix);
      let newPrefix: string;
      if (m) newPrefix = prefix.slice(0, m.index) + cmd.name + ' ';
      else newPrefix = prefix + cmd.name + ' ';
      const newText = newPrefix + suffix;
      const newCursor = newPrefix.length;
      setText(newText);
      setSelection({ start: newCursor, end: newCursor });
      // Compute index for the activated token (start of inserted name)
      const idx = (m ? m.index : prefix.length);
      const newId = `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
      setIntent((prev) => intentAddCommand(prev, { id: newId, name: cmd.name, index: idx }));
      if ((cmd.group === 'type' || cmd.name === 'note' || cmd.name === 'date') && prevType) {
        setTimeout(() => removeActivatedById(prevType.id), 0);
      }
      recompute(newText, newCursor);
    },
    [intent.activated, recompute, removeActivatedById, selectionStart, setSelection, setText, text]
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
      // map to an activated command near argReplaceFrom
      setIntent((prev) => {
        const near = findActivatedByNameNearIndex(
          prev,
          commandState.activeCommand!.name,
          argReplaceFrom - (commandState.activeCommand!.name.length + 1)
        );
        if (!near) return prev;
        return intentSetCommandValue(prev, near.id, value);
      });
      recompute(newText, newCursor);
    },
    [commandState, recompute, selectionStart, setSelection, setText, text]
  );

  

  const finalizeActiveArgWithPartial = useCallback(
    (partial: string) => {
      if (!commandState.inArgMode || !commandState.activeCommand) return;
      const approxStart = commandState.argReplaceFrom != null
        ? commandState.argReplaceFrom - (commandState.activeCommand.name.length + 1)
        : undefined;
      setIntent((prev) => {
        const near = findActivatedByNameNearIndex(prev, commandState.activeCommand!.name, approxStart);
        if (!near) return prev;
        return intentSetCommandValue(prev, near.id, partial);
      });
    },
    [commandState]
  );

  return {
    commandState,
    recompute,
    handleSelectCommand,
    handleSelectArgSuggestion,
    intent,
    removeActivatedById,
    finalizeActiveArgWithPartial,
  };
};
