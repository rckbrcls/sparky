import { defaultNormalize } from "../utils/slug";

export type ArgumentSourceKind = "folders" | "persons" | "locations" | "tags";

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

export function registerCommand(def: CommandDefinition) {
  if (registry.some((r) => r.name === def.name)) return; // idempotent
  registry.push({
    finalizeOnSelect: true,
    ...def,
    argument: def.argument
      ? { normalize: defaultNormalize, ...def.argument }
      : undefined,
  });
}

export function getAllCommands(): CommandDefinition[] {
  return registry.slice();
}

// Pre-register core commands (entity + actions) — can be extended elsewhere.
function bootstrap() {
  // NOTE: We only add argument-enabled entity commands here; others remain in legacy engine until migrated fully.
  registerCommand({
    name: "folder",
    description: "Assign note/reminder to folder",
    category: "entity",
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
    name: "location",
    description: "Associate a location trigger",
    category: "entity",
    argument: { source: "locations", allowEmptyInitialList: true },
  });
  registerCommand({
    name: "tag",
    description: "Insert an existing tag",
    category: "entity",
    argument: { source: "tags", allowEmptyInitialList: true },
  });
}

bootstrap();
