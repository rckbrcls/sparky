/**
 * Below are the colors that are used in the app. The colors are defined in the light and dark mode.
 * There are many other ways to style your app. For example, [Nativewind](https://www.nativewind.dev/), [Tamagui](https://tamagui.dev/), [unistyles](https://reactnativeunistyles.vercel.app), etc.
 */

const tintColorLight = "#339AF0";
const tintColorDark = "#00D2FF";

export const Colors = {
  light: {
    text: "#1A1A1A",
    background: "#F8F9FA",
    tint: tintColorLight,
    icon: "#6C757D",
    tabIconDefault: "#6C757D",
    tabIconSelected: tintColorLight,
    surface: "#FFFFFF",
    border: "#E9ECEF",
    success: "#51CF66",
    warning: "#FFD43B",
    error: "#FF6B6B",
    muted: "#ADB5BD",
  },
  dark: {
    text: "#E4E6EA",
    background: "#0D1117",
    tint: tintColorDark,
    icon: "#7D8590",
    tabIconDefault: "#7D8590",
    tabIconSelected: tintColorDark,
    surface: "#161B22",
    border: "#30363D",
    success: "#3FB950",
    warning: "#D29922",
    error: "#F85149",
    muted: "#6E7681",
  },
};
