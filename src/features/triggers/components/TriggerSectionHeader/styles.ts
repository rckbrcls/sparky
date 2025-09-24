import { StyleSheet } from "react-native";

import { Colors } from "@/src/constants/Colors";
import { Typography } from "@/src/constants/Typography";

export const styles = StyleSheet.create({
  container: {
    flexDirection: "row",
    alignItems: "center",
    paddingVertical: 12,
    paddingHorizontal: 16,
    backgroundColor: Colors.dark.surface,
    borderRadius: 8,
    marginBottom: 8,
    borderWidth: 1,
    borderColor: Colors.dark.border,
  },
  icon: {
    marginRight: 8,
  },
  title: {
    ...Typography.h5,
    color: Colors.dark.text,
    fontWeight: "600",
    flex: 1,
  },
  count: {
    ...Typography.caption,
    color: Colors.dark.muted,
  },
});
