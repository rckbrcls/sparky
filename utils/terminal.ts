const CREATE_FOLDER_RE = /\/createfolder\s+\S+/gi;
const DELETE_FOLDER_RE = /\/deletefolder\s+\S+/gi;
const FOLDER_RE = /\/folder\s+\S+/gi;

const CREATE_FOLDER_MATCH_RE = /\/createfolder\s+(\S+)/i;
const DELETE_FOLDER_MATCH_RE = /\/deletefolder\s+(\S+)/i;
const FOLDER_MATCH_RE = /\/folder\s+(\S+)/i;

export const SLUG_ARG_COMMANDS = new Set(["folder", "createfolder"]);

export const slugify = (value: string) =>
  value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .substring(0, 32);

export const stripCreateDeleteCommands = (value: string) =>
  value.replace(CREATE_FOLDER_RE, "").replace(DELETE_FOLDER_RE, "");

export const stripAllSystemCommands = (value: string) =>
  stripCreateDeleteCommands(value).replace(FOLDER_RE, "");

export const cleanSystemCommands = (value: string) => stripAllSystemCommands(value).trim();

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
