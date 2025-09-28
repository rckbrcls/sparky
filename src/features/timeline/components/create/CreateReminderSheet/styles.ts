import { StyleSheet } from "react-native";

import { Colors } from "@/src/constants/Colors";
import { Typography } from "@/src/constants/Typography";

export const styles = StyleSheet.create({
  sheetBackground: {
    backgroundColor: Colors.dark.surface,
  },
  sheetHandle: {
    backgroundColor: Colors.dark.surface,
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    paddingTop: 12,
    paddingBottom: 4,
  },
  sheetHandleIndicator: {
    backgroundColor: Colors.dark.border,
  },
  container: {
    flex: 1,
    backgroundColor: Colors.dark.surface,
    paddingHorizontal: 20,
    paddingBottom: 24,
  },
  content: {
    paddingBottom: 24,
  },
  topBar: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    marginBottom: 16,
  },
  heroBadge: {
    flexDirection: "row",
    alignItems: "center",
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderRadius: 18,
    backgroundColor: `${Colors.dark.tint}22`,
  },
  heroIconWrap: {
    width: 28,
    height: 28,
    borderRadius: 14,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: Colors.dark.tint,
    marginRight: 8,
  },
  heroBadgeText: {
    ...Typography.caption,
    color: Colors.dark.text,
    fontWeight: "600",
  },
  closeButton: {
    padding: 6,
    marginLeft: 8,
  },
  title: {
    ...Typography.h3,
    color: Colors.dark.text,
    marginBottom: 6,
  },
  subtitle: {
    ...Typography.caption,
    color: Colors.dark.muted,
    marginBottom: 18,
  },
  section: {
    marginBottom: 18,
  },
  label: {
    ...Typography.caption,
    color: Colors.dark.muted,
    fontWeight: "700",
    textTransform: "uppercase",
    letterSpacing: 0.6,
    marginBottom: 8,
  },
  input: {
    borderRadius: 14,
    borderWidth: 1,
    borderColor: Colors.dark.border,
    backgroundColor: Colors.dark.background,
    paddingHorizontal: 14,
    paddingVertical: 10,
    ...Typography.body,
    color: Colors.dark.text,
  },
  chipRow: {
    flexDirection: "row",
    flexWrap: "wrap",
  },
  chip: {
    flexDirection: "row",
    alignItems: "center",
    paddingHorizontal: 12,
    paddingVertical: 8,
    marginRight: 10,
    marginBottom: 10,
    borderRadius: 18,
    borderWidth: 1,
    borderColor: Colors.dark.border,
    backgroundColor: Colors.dark.surface,
  },
  chipActive: {
    borderColor: Colors.dark.tint,
  },
  chipText: {
    ...Typography.caption,
    color: Colors.dark.muted,
    fontWeight: "600",
  },
  chipTextActive: {
    color: Colors.dark.tint,
  },
  footerActions: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    marginTop: 8,
  },
  cancelButton: {
    paddingVertical: 12,
    paddingHorizontal: 18,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: Colors.dark.border,
    backgroundColor: Colors.dark.surface,
    marginRight: 12,
  },
  cancelText: {
    ...Typography.body,
    color: Colors.dark.muted,
    fontWeight: "600",
  },
  createButton: {
    flex: 1,
    paddingVertical: 14,
    borderRadius: 12,
    backgroundColor: Colors.dark.tint,
    alignItems: "center",
    flexDirection: "row",
    justifyContent: "center",
  },
  createButtonDisabled: {
    opacity: 0.5,
  },
  createText: {
    ...Typography.body,
    color: Colors.dark.background,
    fontWeight: "600",
  },
  pickerPanel: {
    marginTop: 6,
    borderRadius: 14,
    borderWidth: 1,
    borderColor: Colors.dark.border,
    backgroundColor: Colors.dark.background,
    overflow: "hidden",
  },
  pickerToolbar: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingHorizontal: 14,
    paddingVertical: 10,
    borderBottomWidth: 1,
    borderBottomColor: Colors.dark.border,
  },
  pickerContent: {
    height: 260,
    position: "relative",
    justifyContent: "center",
  },
  pickerSlot: {
    position: "absolute",
    left: 0,
    right: 0,
    top: 0,
    bottom: 0,
    justifyContent: "center",
  },
});
