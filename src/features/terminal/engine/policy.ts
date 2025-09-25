import type { CommandDefinition } from './commands/registry';
import type { IntentState } from './intent';

export function isCommandApplicable(cmd: CommandDefinition, intent: IntentState): boolean {
  const applies = cmd.appliesTo ?? ['any'];
  if (applies.includes('any')) return true;
  if (intent.type === 'auto') return true; // allow during drafting
  return applies.includes(intent.type);
}

export function conflictsWithActive(cmd: CommandDefinition, intent: IntentState): boolean {
  const conflicts = cmd.conflictsWith ?? [];
  // type group exclusivity handled separately
  const names = new Set(intent.activated.map((c) => c.name));
  for (const c of conflicts) if (names.has(c)) return true;
  if (cmd.group === 'type') {
    // there is an active type? selecting another implicitly replaces; not a conflict for listing
    return false;
  }
  return false;
}

export function filterCommandMatches(
  candidates: CommandDefinition[],
  intent: IntentState
): CommandDefinition[] {
  // If a type command is active, hide other type commands
  const activeType = intent.activated.find((c) => c.name === 'note' || c.name === 'date');
  return candidates.filter((cmd) => {
    if (!isCommandApplicable(cmd, intent)) return false;
    if (conflictsWithActive(cmd, intent)) return false;
    if (activeType && cmd.group === 'type' && cmd.name !== activeType.name) return false;
    return true;
  });
}
