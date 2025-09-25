export type IntentType = 'auto' | 'note' | 'reminder';

export interface ActivatedCommand {
  id: string;
  name: string;
  value?: string;
  // best-effort tracking of where the "/name" token starts in the text
  index?: number;
  // when detached, the token was removed from text and should live only as metadata (badge)
  detached?: boolean;
}

export interface IntentState {
  type: IntentType;
  activated: ActivatedCommand[];
}

export function createInitialIntent(): IntentState {
  return { type: 'auto', activated: [] };
}

export function isTypeCommand(name: string) {
  return name === 'note' || name === 'date';
}

export function intentSetType(intent: IntentState, type: IntentType): IntentState {
  return { ...intent, type };
}

export function intentAddCommand(intent: IntentState, cmd: ActivatedCommand): IntentState {
  const next = { ...intent, activated: intent.activated.slice() };
  if (isTypeCommand(cmd.name)) {
    // remove any previous type commands
    next.activated = next.activated.filter((c) => !isTypeCommand(c.name));
    next.type = cmd.name === 'note' ? 'note' : 'reminder';
  }
  next.activated.push(cmd);
  return next;
}

export function intentRemoveCommand(intent: IntentState, id: string): IntentState {
  const rem = intent.activated.find((c) => c.id === id);
  const next = { ...intent, activated: intent.activated.filter((c) => c.id !== id) };
  if (rem && isTypeCommand(rem.name)) {
    // fallback to auto if type removed
    next.type = 'auto';
  }
  return next;
}

export function intentUpdateCommandIndex(intent: IntentState, id: string, index?: number): IntentState {
  return {
    ...intent,
    activated: intent.activated.map((c) => (c.id === id ? { ...c, index } : c)),
  };
}

export function intentSetCommandValue(intent: IntentState, id: string, value?: string): IntentState {
  return {
    ...intent,
    activated: intent.activated.map((c) => (c.id === id ? { ...c, value } : c)),
  };
}

export function intentDetachCommandToken(intent: IntentState, id: string): IntentState {
  return {
    ...intent,
    activated: intent.activated.map((c) => (c.id === id ? { ...c, index: undefined, detached: true } : c)),
  };
}

export function intentAttachCommand(intent: IntentState, id: string, index: number): IntentState {
  return {
    ...intent,
    activated: intent.activated.map((c) => (c.id === id ? { ...c, index, detached: false } : c)),
  };
}

export function findActivatedByNameNearIndex(
  intent: IntentState,
  name: string,
  approxIndex: number | undefined
): ActivatedCommand | undefined {
  const candidates = intent.activated.filter((c) => c.name === name);
  if (candidates.length === 0) return undefined;
  if (approxIndex == null) return candidates[candidates.length - 1];
  let best: ActivatedCommand | undefined;
  let bestDelta = Number.POSITIVE_INFINITY;
  for (const c of candidates) {
    const delta = Math.abs((c.index ?? 0) - approxIndex);
    if (delta < bestDelta) {
      bestDelta = delta;
      best = c;
    }
  }
  return best;
}
