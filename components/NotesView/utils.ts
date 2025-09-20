import { QuickNoteWithFolder } from "./types";

export const formatTags = (tagsString: string) => {
  try {
    const tags = JSON.parse(tagsString || "[]");
    return tags.length > 0
      ? tags.map((tag: string) => `#${tag}`).join(" ")
      : "";
  } catch {
    return "";
  }
};

export const parseTagsInput = (value: string) => {
  return value
    .split(/[\s,]+/)
    .map((tag) => tag.replace(/^#/, "").trim())
    .filter(Boolean);
};

export const sortNotes = (noteList: QuickNoteWithFolder[]) => {
  return [...noteList].sort((a, b) => {
    const pinnedDiff = Number(!!b.isPinned) - Number(!!a.isPinned);
    if (pinnedDiff !== 0) return pinnedDiff;

    const orderA = typeof a.sortOrder === "number" ? a.sortOrder : 0;
    const orderB = typeof b.sortOrder === "number" ? b.sortOrder : 0;
    if (orderA !== orderB) return orderB - orderA;

    const dateA = a.updatedAt ? new Date(a.updatedAt).getTime() : 0;
    const dateB = b.updatedAt ? new Date(b.updatedAt).getTime() : 0;
    return dateB - dateA;
  });
};
