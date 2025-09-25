// Minimal helper: slugify only for argument values (keep accents, max 32 chars)
const ACCENT_REGEX = /[\u0300-\u036f]/g;
const NON_ALPHANUMERIC = /[^a-z0-9]+/g;
const LEADING_TRAILING_DASHES = /^-+|-+$/g;

export const slugifyForArgs = (value: string): string => {
  if (!value) return "";
  let normalized = value.trim();
  // keep accents (stripAccents=false equivalent), only normalize spaces/punctuation
  let slug = normalized.toLowerCase().replace(NON_ALPHANUMERIC, "-").replace(LEADING_TRAILING_DASHES, "");
  return slug.length > 32 ? slug.slice(0, 32) : slug;
};
