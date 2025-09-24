import { Colors } from "@/src/constants/Colors";
import { Typography } from "@/src/constants/Typography";
import { StyleSheet } from "react-native";

export const styles = StyleSheet.create({
  container: {
    marginTop: 8,
  },
  hidden: {
    marginTop: 0,
    height: 0,
  },
  commandPalette: {
    marginTop: 6,
    backgroundColor: Colors.dark.surface,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: Colors.dark.border,
    overflow: "hidden",
  },
  commandScroll: {
    maxHeight: 220,
    width: "100%",
  },
  commandScrollContent: {
    flexGrow: 1,
  },
  commandItem: {
    paddingVertical: 10,
    paddingHorizontal: 14,
    borderBottomWidth: 1,
    borderBottomColor: Colors.dark.border,
  },
  commandName: {
    ...Typography.body,
    color: Colors.dark.tint,
    fontWeight: "600",
  },
  commandDesc: {
    ...Typography.caption,
    color: Colors.dark.muted,
    marginTop: 2,
  },
});
