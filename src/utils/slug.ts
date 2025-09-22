// Utility: slugify strings for command argument normalization
export function slugify(input: string): string {
  return input
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "") // remove accents
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .substring(0, 48);
}

export function defaultNormalize(s: string): string {
  return slugify(s.trim());
}
