// import removed (forcing dark theme)

// Optional runtime override (e.g., settings screen can call setColorSchemeOverride)
let overrideScheme: "light" | "dark" | null = null;

export function setColorSchemeOverride(scheme: "light" | "dark" | null) {
  overrideScheme = scheme;
}

export function useColorScheme(): "light" | "dark" {
  // Force dark unless an explicit override is provided
  return overrideScheme ?? "dark";
}
