import { Colors } from "@/src/constants/Colors";
import { Typography } from "@/src/constants/Typography";
import { StyleSheet } from "react-native";

export const styles = StyleSheet.create({
  inputContainer: {
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: Colors.dark.background,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: Colors.dark.border,
    paddingHorizontal: 14,
    paddingVertical: 14,
    width: "100%",
    position: "relative",
  },
  scrollArea: {
    width: "100%",
  },
  scrollContent: {
    flexGrow: 1,
  },
  layeredInput: {
    position: "relative",
    width: "100%",
  },
  composedInput: {
    flex: 1,
    justifyContent: "flex-start",
  },
  highlightLayer: {
    position: "absolute",
    top: 0,
    left: 0,
    right: 0,
    flexDirection: "row",
    flexWrap: "wrap",
  },
  highlightText: {
    ...Typography.body,
    color: Colors.dark.text,
    lineHeight: 22,
  },
  inputOverlay: {
    ...Typography.body,
    color: "transparent",
    lineHeight: 22,
    textAlignVertical: "top",
    flexGrow: 1,
    width: "100%",
    includeFontPadding: false,
    padding: 0,
  },
  placeholderText: {
    ...Typography.body,
    color: Colors.dark.muted,
    lineHeight: 20,
  },
  hlNormal: {
    color: Colors.dark.text,
  },
  hlCommand: {
    color: Colors.dark.tint,
    fontWeight: "600",
  },
  hlCommandActive: {
    color: Colors.dark.tint,
    fontWeight: "700",
  },
  hlCommandArg: {
    color: Colors.dark.icon,
  },
  hlTag: {
    color: Colors.dark.success,
    fontWeight: "500",
  },
  submitButton: {
    marginLeft: 12,
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: Colors.dark.tint,
    alignItems: "center",
    justifyContent: "center",
  },
  submitButtonDisabled: {
    backgroundColor: Colors.dark.muted,
  },
});
