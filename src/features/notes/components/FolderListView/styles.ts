import { Colors } from "@/src/constants/Colors";
import { Typography } from "@/src/constants/Typography";
import { StyleSheet } from "react-native";

export const styles = StyleSheet.create({
  folderFilterContainer: {
    flex: 1,
    paddingHorizontal: 16,
    paddingTop: 16,
    paddingBottom: 16,
    backgroundColor: Colors.dark.background,
  },
  folderFilterList: {
    paddingBottom: 8,
  },
  folderCard: {
    flexDirection: "row",
    alignItems: "center",
    padding: 16,
    borderRadius: 16,
    borderWidth: 1,
    borderColor: Colors.dark.border,
    backgroundColor: Colors.dark.surface,
  },
  folderCardIconWrap: {
    width: 44,
    height: 44,
    borderRadius: 14,
    borderWidth: 1,
    borderColor: Colors.dark.border,
    backgroundColor: Colors.dark.background,
    alignItems: "center",
    justifyContent: "center",
    marginRight: 16,
  },
  folderCardInfo: {
    flex: 1,
  },
  folderCardTitle: {
    ...Typography.body,
    color: Colors.dark.text,
    fontWeight: "600",
  },
  folderCardSubtitle: {
    ...Typography.caption,
    color: Colors.dark.muted,
    marginTop: 4,
  },
  folderCardIndicator: {
    marginLeft: 12,
  },
  folderCardChevron: {
    marginLeft: 12,
  },
  folderCardSeparator: {
    height: 12,
  },
});
