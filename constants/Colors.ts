/**
 * Below are the colors that are used in the app. The colors are defined in the light and dark mode.
 * There are many other ways to style your app. For example, [Nativewind](https://www.nativewind.dev/), [Tamagui](https://tamagui.dev/), [unistyles](https://reactnativeunistyles.vercel.app), etc.
 */

// Accent (tint) for light mode changed to black as requested
const tintColorLight = "#000000";
// Accent (tint) for dark mode changed to white as requested
const tintColorDark = "#FFFFFF";

export const Colors = {
  light: {
    text: "#000000",
    background: "#FFFFFF",
    tint: tintColorLight,
    icon: "#5E5E5E",
    tabIconDefault: "#6E6E6E",
    tabIconSelected: tintColorLight,
    surface: "#FFFFFF",
    border: "#F0F0F0",
    success: "#51CF66",
    warning: "#FFD43B",
    error: "#FF6B6B",
    muted: "#C4C4C4",
  },
  dark: {
    // Dark palette now much closer to pure black
    text: "#F2F2F2",
    background: "#000000",
    tint: tintColorDark,
    icon: "#9AA0A6",
    tabIconDefault: "#6E6E6E",
    tabIconSelected: tintColorDark,
    surface: "#0A0A0A",
    border: "#1A1A1A",
    success: "#3FB950", // keeping semantic colors for status
    warning: "#D29922",
    error: "#F85149",
    muted: "#5A5F66",
  },
};
