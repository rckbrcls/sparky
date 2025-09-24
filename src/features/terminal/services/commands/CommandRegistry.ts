import { defaultNormalize } from "@/src/utils/slug";
import type { SourceKey } from "./CommandArgumentSources";

export type ArgumentSourceKind = SourceKey;

export interface CommandDefinition {
  name: string; // without leading slash
  description: string;
  category?: "entity" | "action" | "mode";
  argument?: {
    source: ArgumentSourceKind;
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
    argument: def.argument
      ? { normalize: defaultNormalize, ...def.argument }
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

// Pre-register core commands (entity + actions) — can be extended elsewhere.
function bootstrap() {
  // NOTE: We only add argument-enabled entity commands here; others remain in legacy engine until migrated fully.
  // Legacy parity additions: date, note, title, createfolder, priority, tags, people, locations, help
  registerCommand({
    name: "date",
    description: "Insert a date/time command (/date ...)",
    category: "entity",
  });
  registerCommand({
    name: "note",
    description: "Start quick note title (/note ...)",
    category: "mode",
  });
  registerCommand({
    name: "title",
    description: "Explicit title (/title ...)",
    category: "mode",
  });
  registerCommand({
    name: "folder",
    description: "Assign note/reminder to folder",
    category: "entity",
    argument: { source: "folders", allowEmptyInitialList: true },
  });
  registerCommand({
    name: "createfolder",
    description: "Create a new folder (/createfolder name)",
    category: "action",
    argument: { source: "folders", allowEmptyInitialList: true },
  });
  registerCommand({
    name: "deletefolder",
    description: "Delete an existing folder",
    category: "action",
    argument: {
      source: "folders",
      allowEmptyInitialList: true,
      exclude: (v) => v.toLowerCase() === "all",
    },
  });
  registerCommand({
    name: "person",
    description: "Link to a person trigger",
    category: "entity",
    argument: { source: "persons", allowEmptyInitialList: true },
  });
  registerCommand({
    name: "people",
    description: "Start people block (/people ... /endpeople)",
    category: "mode",
  });
  registerCommand({
    name: "location",
    description: "Associate a location trigger",
    category: "entity",
    argument: { source: "locations", allowEmptyInitialList: true },
  });
  registerCommand({
    name: "locations",
    description: "Start locations block (/locations ... /endlocations)",
    category: "mode",
  });
  registerCommand({
    name: "tag",
    description: "Insert an existing tag",
    category: "entity",
    argument: { source: "tags", allowEmptyInitialList: true },
  });
  registerCommand({
    name: "tags",
    description: "Start tags block (/tags ... /endtags)",
    category: "mode",
  });
  registerCommand({
    name: "priority",
    description: "Set priority (/priority !!! | !! | ! | 3 | 2 | 1)",
    category: "entity",
  });
  registerCommand({
    name: "help",
    description: "Show help list (/help)",
    category: "action",
  });
  // Closing block commands (no arguments) for legacy block mode support
  registerCommand({
    name: "endtags",
    description: "Close tags block (/endtags)",
    category: "action",
  });
  registerCommand({
    name: "endpeople",
    description: "Close people block (/endpeople)",
    category: "action",
  });
  registerCommand({
    name: "endlocations",
    description: "Close locations block (/endlocations)",
    category: "action",
  });
}

bootstrap();
