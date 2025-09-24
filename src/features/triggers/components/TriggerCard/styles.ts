import { StyleSheet } from "react-native";

import { Colors } from "@/src/constants/Colors";
import { Typography } from "@/src/constants/Typography";

export const styles = StyleSheet.create({
  card: {
    backgroundColor: Colors.dark.surface,
    borderRadius: 12,
    padding: 16,
    marginBottom: 8,
    borderWidth: 1,
    borderColor: Colors.dark.border,
  },
  cardHeader: {
    flexDirection: "row",
    alignItems: "center",
  },
  statusIndicator: {
    width: 8,
    height: 8,
    borderRadius: 4,
    marginRight: 12,
  },
  cardContent: {
    flex: 1,
  },
  reminderTitle: {
    ...Typography.body,
    color: Colors.dark.text,
    fontWeight: "600",
    marginBottom: 4,
  },
  triggerConfig: {
    ...Typography.body,
    color: Colors.dark.muted,
  },
  triggerTypeContainer: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: Colors.dark.background,
    alignItems: "center",
    justifyContent: "center",
  },
  triggerTypeIcon: {
    opacity: 0.8,
  },
});
