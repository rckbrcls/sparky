export type SlugOptions = {
  maxLength?: number;
  stripAccents?: boolean;
};

const ACCENT_REGEX = /[\u0300-\u036f]/g;
const NON_ALPHANUMERIC = /[^a-z0-9]+/g;
const LEADING_TRAILING_DASHES = /^-+|-+$/g;

export const slugify = (input: string, options: SlugOptions = {}): string => {
  const { maxLength = 48, stripAccents = true } = options;
  if (!input) return "";

  let normalized = input.trim();
  if (stripAccents) {
    normalized = normalized.normalize("NFKD").replace(ACCENT_REGEX, "");
  }

  let slug = normalized
    .toLowerCase()
    .replace(NON_ALPHANUMERIC, "-")
    .replace(LEADING_TRAILING_DASHES, "");

  if (maxLength > 0) {
    slug = slug.slice(0, maxLength);
  }

  return slug;
};

export const defaultNormalize = (value: string): string => slugify(value.trim());

export const slugifyForArgs = (value: string): string =>
  slugify(value, { maxLength: 32, stripAccents: false });

const CREATE_FOLDER_RE = /\/createfolder\s+\S+/gi;
const DELETE_FOLDER_RE = /\/deletefolder\s+\S+/gi;
const FOLDER_RE = /\/folder\s+\S+/gi;

const CREATE_FOLDER_MATCH_RE = /\/createfolder\s+(\S+)/i;
const DELETE_FOLDER_MATCH_RE = /\/deletefolder\s+(\S+)/i;
const FOLDER_MATCH_RE = /\/folder\s+(\S+)/i;

export const SLUG_ARG_COMMANDS = new Set(["folder", "createfolder"]);

export const stripCreateDeleteCommands = (value: string) =>
  value.replace(CREATE_FOLDER_RE, "").replace(DELETE_FOLDER_RE, "");

export const stripAllSystemCommands = (value: string) =>
  stripCreateDeleteCommands(value).replace(FOLDER_RE, "");

export const cleanSystemCommands = (value: string) =>
  stripAllSystemCommands(value).trim();

export const shouldHidePreviewForText = (value: string) => {
  const trimmed = value.trim();
  if (!trimmed) return true;

  const stripped = stripCreateDeleteCommands(trimmed).trim();
  const hasOnlySystemCommands =
    stripped.length === 0 &&
    (CREATE_FOLDER_MATCH_RE.test(trimmed) || DELETE_FOLDER_MATCH_RE.test(trimmed)) &&
    !FOLDER_MATCH_RE.test(trimmed);

  return hasOnlySystemCommands || stripped.length <= 3;
};

export const matchFolderCommand = (value: string) => value.match(FOLDER_MATCH_RE);
export const matchCreateFolderCommand = (value: string) =>
  value.match(CREATE_FOLDER_MATCH_RE);
export const matchDeleteFolderCommand = (value: string) =>
  value.match(DELETE_FOLDER_MATCH_RE);
