import { StyleSheet } from "react-native";

import { Colors } from "../../../../constants/Colors";
import { Typography } from "../../../../constants/Typography";

export const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "transparent",
  },
  stageArea: {
    flex: 1,
    position: "relative",
  },
  stagePlane: {
    position: "absolute",
    top: 0,
    right: 0,
    bottom: 0,
    left: 0,
  },
  notesStageContainer: {
    flex: 1,
    backgroundColor: Colors.dark.background,
  },
  notesBackWrapper: {
    paddingHorizontal: 16,
    paddingTop: 16,
    backgroundColor: Colors.dark.background,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
  },
  notesBackButton: {
    flexDirection: "row",
    alignItems: "center",
  },
  notesBackIcon: {
    marginRight: 8,
  },
  notesBackText: {
    ...Typography.bodySmall,
    color: Colors.dark.tint,
    fontWeight: "600",
  },
  notesHeaderCount: {
    ...Typography.caption,
    color: Colors.dark.muted,
    fontWeight: "600",
  },
  notesListWrapper: {
    flex: 1,
    backgroundColor: Colors.dark.background,
  },
  notesList: {
    flex: 1,
  },
  listContainer: {
    padding: 16,
  },
  listContentInset: {
    paddingBottom: 80,
  },
  card: {
    backgroundColor: Colors.dark.surface,
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    borderWidth: 1,
    borderColor: Colors.dark.border,
  },
  pinnedCard: {
    borderColor: Colors.dark.warning,
    backgroundColor: `${Colors.dark.warning}15`,
  },
  cardContentRow: {
    flexDirection: "row",
    alignItems: "flex-start",
  },
  cardMain: {
    flex: 1,
  },
  cardHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: 12,
  },
  cardInfo: {
    flexDirection: "row",
    alignItems: "center",
  },
  pinIcon: {
    marginRight: 8,
  },
  folderBadge: {
    flexDirection: "row",
    alignItems: "center",
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 16,
    marginLeft: 4,
  },
  folderBadgeIcon: {
    marginRight: 6,
  },
  folderBadgeText: {
    ...Typography.caption,
    color: Colors.dark.background,
    fontWeight: "600",
  },
  editButton: {
    paddingVertical: 6,
    paddingHorizontal: 12,
    borderRadius: 14,
    backgroundColor: Colors.dark.tint,
    alignItems: "center",
    justifyContent: "center",
  },
  noteContent: {
    ...Typography.body,
    color: Colors.dark.text,
    lineHeight: 22,
    marginBottom: 12,
  },
  cardFooter: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
  },
  noteDate: {
    ...Typography.caption,
    color: Colors.dark.muted,
  },
  noteTags: {
    ...Typography.caption,
    color: Colors.dark.tint,
    fontWeight: "500",
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
