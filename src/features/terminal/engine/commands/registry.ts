import { defaultNormalize } from "../utils/text";

export type ArgumentSourceKind = import("./sources").SourceKey;

export type CommandRole = 'type' | 'property' | 'action';
export type AppliesTo = 'any' | 'note' | 'reminder';

export interface CommandDefinition {
  name: string; // without leading slash
  description: string;
  role?: CommandRole;
  appliesTo?: AppliesTo[]; // where this command is valid
  group?: 'type'; // exclusive groups (e.g., type)
  conflictsWith?: string[]; // names of commands it conflicts with
  argument?: {
    mode?: 'singleWord';
    source?: ArgumentSourceKind;
    fetch?: () => Promise<string[]> | string[]; // overrides default source provider
    normalize?: (s: string) => string; // default slugify
    filter?: (candidate: string, partialNorm: string) => boolean; // custom filter logic
    allowEmptyInitialList?: boolean; // show all when partial empty
    exclude?: (value: string) => boolean; // skip values
  };
  finalizeOnSelect?: boolean; // default true
  singleUsePerInput?: boolean; // prevents suggesting again if already used
  deprecated?: boolean;
}

const registry: CommandDefinition[] = [];
const registryMap = new Map<string, CommandDefinition>();

export function registerCommand(def: CommandDefinition) {
  const key = def.name.toLowerCase();
  if (registryMap.has(key)) return; // idempotent
  const entry: CommandDefinition = {
    finalizeOnSelect: true,
    ...def,
    appliesTo: def.appliesTo ?? ['any'],
    argument: def.argument
      ? { mode: 'singleWord', normalize: defaultNormalize, ...def.argument }
      : undefined,
  };
  registry.push(entry);
  registryMap.set(key, entry);
}

export function getAllCommands(): CommandDefinition[] {
  return registry.slice();
}

export function getCommandByName(name: string): CommandDefinition | undefined {
  return registryMap.get(name.toLowerCase());
}

function bootstrap() {
  // Type selection
  registerCommand({
    name: 'date',
    description: 'Create a time-based reminder',
    role: 'type',
    group: 'type',
    appliesTo: ['any'],
    argument: { allowEmptyInitialList: true },
  });
  registerCommand({
    name: 'note',
    description: 'Create a quick note',
    role: 'type',
    group: 'type',
    appliesTo: ['any'],
  });

  // Properties
  registerCommand({
    name: 'folder',
    description: 'Assign note to a folder',
    role: 'property',
    appliesTo: ['note'],
    argument: { source: 'folders', allowEmptyInitialList: true },
  });
  registerCommand({
    name: 'tag',
    description: 'Add a tag to the note',
    role: 'property',
    appliesTo: ['note'],
    argument: { source: 'tags', allowEmptyInitialList: true },
  });
  registerCommand({
    name: 'priority',
    description: 'Set priority (!, !!, !!! | 1,2,3)',
    role: 'property',
    appliesTo: ['any'],
  });
  registerCommand({
    name: 'person',
    description: 'Trigger by person (contact name)',
    role: 'property',
    appliesTo: ['any'],
    argument: { source: 'persons', allowEmptyInitialList: true },
  });
  registerCommand({
    name: 'location',
    description: 'Trigger by location',
    role: 'property',
    appliesTo: ['any'],
    argument: { source: 'locations', allowEmptyInitialList: true },
  });
}

bootstrap();
