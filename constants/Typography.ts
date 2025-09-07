import { StyleSheet } from "react-native";
import { Colors } from "./Colors";

export const Typography = StyleSheet.create({
  // Headers
  h1: {
    fontSize: 32,
    fontWeight: "700",
    fontFamily: "SpaceMono",
    color: Colors.dark.text,
  },
  h2: {
    fontSize: 28,
    fontWeight: "700",
    fontFamily: "SpaceMono",
    color: Colors.dark.text,
  },
  h3: {
    fontSize: 24,
    // Added explicit lineHeight to avoid glyph clipping (SpaceMono ascenders)
    lineHeight: 30,
    // Removed fontWeight: "600" because custom font likely only has regular weight,
    // synthetic bolding can cause vertical clipping on some platforms.
    fontFamily: "SpaceMono",
    color: Colors.dark.text,
  },
  h4: {
    fontSize: 20,
    fontWeight: "600",
    fontFamily: "SpaceMono",
    color: Colors.dark.text,
  },
  h5: {
    fontSize: 18,
    fontWeight: "600",
    fontFamily: "SpaceMono",
    color: Colors.dark.text,
  },
  h6: {
    fontSize: 16,
    fontWeight: "500",
    fontFamily: "SpaceMono",
    color: Colors.dark.text,
  },

  // Body text
  body: {
    fontSize: 16,
    fontFamily: "SpaceMono",
    color: Colors.dark.text,
  },
  bodySmall: {
    fontSize: 14,
    fontFamily: "SpaceMono",
    color: Colors.dark.text,
  },
  caption: {
    fontSize: 12,
    fontFamily: "SpaceMono",
    color: Colors.dark.muted,
  },

  // Button text
  button: {
    fontSize: 16,
    fontWeight: "600",
    fontFamily: "SpaceMono",
  },
  buttonSmall: {
    fontSize: 14,
    fontWeight: "500",
    fontFamily: "SpaceMono",
  },

  // Input text
  input: {
    fontSize: 16,
    fontFamily: "SpaceMono",
    color: Colors.dark.text,
  },

  // Special text
  code: {
    fontSize: 14,
    fontFamily: "SpaceMono",
    color: Colors.dark.tint,
    backgroundColor: Colors.dark.border,
    paddingHorizontal: 4,
    paddingVertical: 2,
    borderRadius: 4,
  },
});

// Utility function to merge typography with custom styles
export const textStyle = (baseStyle: any, customStyle?: any) => [
  baseStyle,
  customStyle,
];
