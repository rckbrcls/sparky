import { useCallback, useMemo, useRef, useState } from "react";
import type { Dispatch, SetStateAction } from "react";
import { applyArgumentInsert, computeCommandState, resolveArgumentSuggestions, getCommandByName } from "@/src/features/terminal/engine";
import type { CommandDefinition, ComputedCommandState } from "@/src/features/terminal/engine";
import {
  createInitialIntent,
  findActivatedByNameNearIndex,
  intentAddCommand,
  intentRemoveCommand,
  intentSetCommandValue,
  intentUpdateCommandIndex,
  intentDetachCommandToken,
  intentAttachCommand,
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
  detachActivatedById: (id: string, rangeEnd?: number) => void;
  reopenForEdit: (id: string) => void;
  finalizeOnEnter: () => string | undefined;
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
      activated: intent.activated
        .filter((a) => !a.detached)
        .map((a) => ({ name: a.name, index: a.index })),
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
    // Best-effort resync of activated indices when text changes (skip detached)
    setIntent((prev) => {
      let changed = false;
      const updated = prev.activated.map((c) => {
        if (c.detached) return c;
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

  const detachActivatedById = useCallback(
    (id: string, rangeEnd?: number, baseText?: string) => {
      const target = intent.activated.find((c) => c.id === id);
      if (!target) return;
      const sourceText = baseText ?? text;
      const start = target.index ?? sourceText.indexOf(target.name);
      if (start < 0) {
        setIntent((prev) => intentDetachCommandToken(prev, id));
        return;
      }
      const nameEnd = start + target.name.length;
      let end = nameEnd;
      if (sourceText[end] === ' ') {
        end += 1;
        if (typeof rangeEnd === 'number' && rangeEnd >= end) {
          end = rangeEnd;
        } else {
          while (end < sourceText.length && sourceText[end] !== ' ') end += 1;
        }
      }
      const newText = (sourceText.slice(0, start) + sourceText.slice(end)).replace(/\s{2,}/g, ' ').trimStart();
      const newCursor = Math.min(selectionStart, newText.length);
      setText(newText);
      setSelection({ start: newCursor, end: newCursor });
      setIntent((prev) => intentDetachCommandToken(prev, id));
      recompute(newText, newCursor);
    },
    [intent.activated, recompute, selectionStart, setSelection, setText, text]
  );

  const removeActivatedById = useCallback(
    (id: string) => {
      // Try to remove the token and its immediate arg from the text
      const target = intent.activated.find((c) => c.id === id);
      if (!target) {
        setIntent((prev) => intentRemoveCommand(prev, id));
        return;
      }
      if (target.detached) {
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
      // Replace trailing "/partial" before cursor. For type commands, we don't insert text;
      // for others, we insert "name " to enter arg mode.
      const prefix = text.slice(0, selectionStart);
      const suffix = text.slice(selectionStart);
      const m = /(\/[^\s]*)$/.exec(prefix);
      const idx = (m ? m.index : prefix.length);
      const newId = `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;

      if (cmd.group === 'type' || cmd.name === 'note' || cmd.name === 'date') {
        // Remove the /partial and register as detached badge
        const newText = (m ? prefix.slice(0, m.index) : prefix) + suffix;
        const newCursor = m ? m.index : selectionStart;
        setText(newText);
        setSelection({ start: newCursor, end: newCursor });
        if (prevType) setTimeout(() => removeActivatedById(prevType.id), 0);
        setIntent((prev) => intentAddCommand(prev, { id: newId, name: cmd.name, detached: true } as any));
        recompute(newText, newCursor);
        return;
      }

      // Non-type: insert token and enter arg mode
      const newPrefix = (m ? prefix.slice(0, m.index) : prefix) + cmd.name + ' ';
      const newText = newPrefix + suffix;
      const newCursor = newPrefix.length;
      setText(newText);
      setSelection({ start: newCursor, end: newCursor });
      setIntent((prev) => intentAddCommand(prev, { id: newId, name: cmd.name, index: idx }));
      recompute(newText, newCursor);
    },
    [intent.activated, recompute, removeActivatedById, selectionStart, setSelection, setText, text]
  );

  const handleSelectArgSuggestion = useCallback(
    (value: string) => {
      if (!commandState.inArgMode || !commandState.activeCommand) return;
      const { argReplaceFrom } = commandState;
      if (argReplaceFrom == null) return;

      // First insert the chosen value into the text so we can compute exact removal range,
      // then detach the token to keep the final text clean.
      const { newText, newCursor } = applyArgumentInsert(
        text,
        argReplaceFrom,
        selectionStart,
        value,
        true
      );
      setText(newText);
      setSelection({ start: newCursor, end: newCursor });

      const approxStart = argReplaceFrom - (commandState.activeCommand.name.length + 1);
      let targetId: string | undefined;
      setIntent((prev) => {
        const near = findActivatedByNameNearIndex(prev, commandState.activeCommand!.name, approxStart);
        if (!near) return prev;
        targetId = near.id;
        return intentSetCommandValue(prev, near.id, value);
      });
      if (targetId) detachActivatedById(targetId, newCursor, newText);
    },
    [commandState, detachActivatedById, selectionStart, setSelection, setText, text]
  );

  

  const finalizeActiveArgWithPartial = useCallback(
    (partial: string) => {
      if (!commandState.inArgMode || !commandState.activeCommand) return;
      const argReplaceFrom = commandState.argReplaceFrom!;
      const { newText, newCursor } = applyArgumentInsert(
        text,
        argReplaceFrom,
        selectionStart,
        partial,
        true
      );
      setText(newText);
      setSelection({ start: newCursor, end: newCursor });

      const approxStart = argReplaceFrom - (commandState.activeCommand.name.length + 1);
      let targetId: string | undefined;
      setIntent((prev) => {
        const near = findActivatedByNameNearIndex(prev, commandState.activeCommand!.name, approxStart);
        if (!near) return prev;
        targetId = near.id;
        return intentSetCommandValue(prev, near.id, partial);
      });
      if (targetId) detachActivatedById(targetId, newCursor, newText);
    },
    [commandState, detachActivatedById, selectionStart, setSelection, setText, text]
  );

  const reopenForEdit = useCallback(
    (id: string) => {
      const target = intent.activated.find((c) => c.id === id);
      if (!target) return;
      const insertion = `${target.name} ${target.value ? target.value : ''}`.trimEnd() + ' ';
      const prefix = text.slice(0, selectionStart);
      const suffix = text.slice(selectionStart);
      const newText = prefix + insertion + suffix;
      const idx = prefix.length;
      const newCursor = idx + insertion.length;
      setText(newText);
      setSelection({ start: newCursor, end: newCursor });
      setIntent((prev) => intentAttachCommand(prev, id, idx));
      recompute(newText, newCursor);
    },
    [intent.activated, recompute, selectionStart, setSelection, setText, text]
  );

  const finalizeOnEnter = useCallback((): string | undefined => {
    // Priority 1: active arg mode for an activated command
    if (commandState.inArgMode && commandState.activeCommand) {
      const partial = commandState.argPartial ?? "";
      finalizeActiveArgWithPartial(partial);
      // new text will be set by finalizeActiveArgWithPartial; compute an optimistic preview
      const argStart = commandState.argReplaceFrom!;
      const before = text.slice(0, argStart - (commandState.activeCommand.name.length + 1));
      // remove the command token optimistically (name + space + partial + optional trailing space)
      const approxEnd = argStart + partial.length + 1; // include trailing space
      const optimistic = (before + text.slice(approxEnd)).replace(/\s{2,}/g, ' ').trimStart();
      return optimistic;
    }

    // Fallback: finalize a slash-typed command near the cursor
    const upto = text.slice(0, selectionStart);
    const re = /\/([a-zA-Z]+)/g;
    let m: RegExpExecArray | null;
    let last: RegExpExecArray | null = null;
    while ((m = re.exec(upto)) !== null) last = m;
    if (!last) return undefined;
    const name = last[1];
    const def = getCommandByName(name);
    if (!def) return undefined;
    const slashStart = last.index;
    const afterName = slashStart + 1 + name.length;
    if (text[afterName] !== ' ') return undefined; // need space before arg
    const argStart = afterName + 1;
    const remainder = text.slice(argStart);
    const nextBreak = remainder.search(/\s\/[a-zA-Z]+|\n/);
    const argEnd = nextBreak >= 0 ? argStart + nextBreak : text.length;
    const value = text.slice(argStart, argEnd).trim();
    if (!value) return undefined;

    const id = `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
    const newText = (text.slice(0, slashStart) + text.slice(argEnd)).replace(/\s{2,}/g, ' ').trimStart();
    const newCursor = Math.min(selectionStart, newText.length);
    setText(newText);
    setSelection({ start: newCursor, end: newCursor });
    setIntent((prev) => intentAddCommand(prev, { id, name: def.name, value, detached: true } as any));
    recompute(newText, newCursor);
    return newText;
  }, [commandState.activeCommand, commandState.argPartial, commandState.inArgMode, finalizeActiveArgWithPartial, recompute, selectionStart, setSelection, setText, text]);

  return {
    commandState,
    recompute,
    handleSelectCommand,
    handleSelectArgSuggestion,
    intent,
    removeActivatedById,
    finalizeActiveArgWithPartial,
    detachActivatedById,
    reopenForEdit,
    finalizeOnEnter,
  };
};
