import { Colors } from "@/src/constants/Colors";
import { Typography } from "@/src/constants/Typography";
import { StyleSheet } from "react-native";

export const styles = StyleSheet.create({
  emptyState: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    paddingHorizontal: 32,
  },
  emptyTitle: {
    ...Typography.h3,
    color: Colors.dark.text,
    marginBottom: 8,
    textAlign: "center",
  },
  emptySubtitle: {
    ...Typography.body,
    color: Colors.dark.muted,
    textAlign: "center",
    lineHeight: 24,
  },
});
