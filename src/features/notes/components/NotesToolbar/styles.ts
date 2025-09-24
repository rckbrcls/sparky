import { Colors } from "@/src/constants/Colors";
import { Typography } from "@/src/constants/Typography";
import { StyleSheet } from "react-native";

export const styles = StyleSheet.create({
  toolbarContainer: {
    backgroundColor: Colors.dark.surface,
    borderBottomWidth: 1,
    borderBottomColor: Colors.dark.border,
  },
  toolbarList: {
    paddingHorizontal: 16,
    paddingVertical: 12,
  },
  toolbarButton: {
    flexDirection: "row",
    alignItems: "center",
    paddingHorizontal: 14,
    paddingVertical: 10,
    marginRight: 10,
    borderRadius: 18,
    backgroundColor: Colors.dark.background,
    borderWidth: 1,
    borderColor: Colors.dark.border,
  },
  toolbarButtonActive: {
    backgroundColor: Colors.dark.tint,
    borderColor: Colors.dark.tint,
  },
  toolbarButtonDisabled: {
    opacity: 0.45,
  },
  toolbarButtonIcon: {
    marginRight: 8,
  },
  toolbarButtonText: {
    ...Typography.caption,
    color: Colors.dark.muted,
    fontWeight: "600",
  },
  toolbarButtonTextActive: {
    color: Colors.dark.background,
  },
  toolbarButtonTextDisabled: {
    color: Colors.dark.border,
  },
});
