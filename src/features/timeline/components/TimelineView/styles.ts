import { StyleSheet } from "react-native";

import { Colors } from "@/src/constants/Colors";
import { Typography } from "@/src/constants/Typography";

export const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "transparent",
  },
  listContainer: {
    padding: 16,
  },
  initializingBox: {
    padding: 16,
    alignItems: "center",
  },
  initializingText: {
    ...Typography.caption,
    color: Colors.dark.muted,
    marginBottom: 8,
  },
  retryBtn: {
    paddingHorizontal: 14,
    paddingVertical: 8,
    backgroundColor: Colors.dark.tint,
    borderRadius: 8,
  },
  retryBtnText: {
    ...Typography.caption,
    color: Colors.dark.background,
    fontWeight: "600",
  },
});
