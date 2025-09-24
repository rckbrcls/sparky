import { StyleSheet } from "react-native";

import { Colors } from "@/src/constants/Colors";
import { Typography } from "@/src/constants/Typography";

export const styles = StyleSheet.create({
  card: {
    backgroundColor: Colors.dark.surface,
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    borderWidth: 1,
    borderColor: Colors.dark.border,
  },
  cardHeader: {
    flexDirection: "row",
    alignItems: "flex-start",
    marginBottom: 8,
  },
  urgencyIndicator: {
    width: 4,
    height: 24,
    borderRadius: 2,
    marginRight: 12,
  },
  cardContent: {
    flex: 1,
  },
  cardTitle: {
    ...Typography.body,
    color: Colors.dark.text,
    fontWeight: "600",
    marginBottom: 2,
  },
  urgencyLabel: {
    ...Typography.caption,
    color: Colors.dark.muted,
  },
  folderBadge: {
    width: 32,
    height: 32,
    borderRadius: 16,
    alignItems: "center",
    justifyContent: "center",
  },
  fireDate: {
    ...Typography.body,
    color: Colors.dark.tint,
    fontWeight: "500",
    marginBottom: 8,
  },
  notes: {
    ...Typography.body,
    color: Colors.dark.muted,
    marginBottom: 8,
    lineHeight: 20,
  },
  cardFooter: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 8,
  },
  metadataChip: {
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: Colors.dark.background,
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 12,
    gap: 4,
  },
  metadataIcon: {
    opacity: 0.7,
  },
  metadataText: {
    ...Typography.caption,
    color: Colors.dark.muted,
  },
});
