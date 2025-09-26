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
  folderListHeader: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    marginBottom: 12,
  },
  folderListHeaderTitle: {
    ...Typography.bodySmall,
    color: Colors.dark.muted,
    fontWeight: "600",
  },
  addButton: {
    paddingVertical: 6,
    paddingHorizontal: 12,
    borderRadius: 14,
    backgroundColor: Colors.dark.tint,
    alignItems: "center",
    justifyContent: "center",
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
  folderCardActions: {
    flexDirection: "row",
    alignItems: "center",
    marginLeft: 8,
  },
  actionIconBtn: {
    padding: 6,
    borderRadius: 10,
    marginLeft: 8,
  },
  folderCardChevron: {
    marginLeft: 8,
  },
  folderCardSeparator: {
    height: 12,
  },
  swipeDeleteAction: {
    width: 110,
    backgroundColor: Colors.dark.error,
    alignItems: "center",
    justifyContent: "center",
    borderRadius: 16,
    marginVertical: 0,
    marginLeft: 8,
  },
  swipeDeleteText: {
    ...Typography.caption,
    color: Colors.dark.background,
    marginTop: 6,
    fontWeight: "700",
  },
});
