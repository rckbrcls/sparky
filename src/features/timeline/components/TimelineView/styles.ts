import { StyleSheet } from "react-native";

import { Colors } from "@/src/constants/Colors";
import { Typography } from "@/src/constants/Typography";

export const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "transparent",
  },
  headerBar: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingHorizontal: 16,
    paddingTop: 12,
  },
  remindersHeaderWrapper: {
    paddingHorizontal: 16,
    paddingTop: 12,
    backgroundColor: Colors.dark.background,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
  },
  remindersHeaderCount: {
    ...Typography.caption,
    color: Colors.dark.muted,
    fontWeight: "600",
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
  addButton: {
    paddingVertical: 6,
    paddingHorizontal: 12,
    borderRadius: 14,
    backgroundColor: Colors.dark.tint,
    alignItems: "center",
    justifyContent: "center",
    marginLeft: 12,
  },
  addButtonFab: {
    position: "absolute",
    right: 16,
    bottom: 16,
    paddingVertical: 10,
    paddingHorizontal: 16,
    borderRadius: 18,
    backgroundColor: Colors.dark.tint,
    alignItems: "center",
    justifyContent: "center",
    elevation: 3,
  },
  swipeDeleteAction: {
    width: 44,
    height: 44,
    backgroundColor: Colors.dark.error,
    alignItems: "center",
    justifyContent: "center",
    borderRadius: 12,
    marginLeft: 8,
  },
  swipeEditAction: {
    width: 44,
    height: 44,
    backgroundColor: Colors.dark.tint,
    alignItems: "center",
    justifyContent: "center",
    borderRadius: 12,
  },
  swipeActionsContainer: {
    flexDirection: "row",
    alignItems: "center",
    height: "100%",
    paddingLeft: 8,
  },
});
