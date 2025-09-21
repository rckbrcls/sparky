import { StyleSheet } from "react-native";
import { Colors } from "../../constants/Colors";
import { Typography } from "../../constants/Typography";

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
  toolbarContainer: {
    backgroundColor: Colors.dark.surface,
    borderBottomWidth: 1,
    borderBottomColor: Colors.dark.border,
  },
  toolbarList: {
    paddingHorizontal: 16,
    paddingVertical: 12,
  },
  toolbarButton: {
    flexDirection: "row",
    alignItems: "center",
    paddingHorizontal: 14,
    paddingVertical: 10,
    marginRight: 10,
    borderRadius: 18,
    backgroundColor: Colors.dark.background,
    borderWidth: 1,
    borderColor: Colors.dark.border,
  },
  toolbarButtonActive: {
    backgroundColor: Colors.dark.tint,
    borderColor: Colors.dark.tint,
  },
  toolbarButtonDisabled: {
    opacity: 0.45,
  },
  toolbarButtonIcon: {
    marginRight: 8,
  },
  toolbarButtonText: {
    ...Typography.caption,
    color: Colors.dark.muted,
    fontWeight: "600",
  },
  toolbarButtonTextActive: {
    color: Colors.dark.background,
  },
  toolbarButtonTextDisabled: {
    color: Colors.dark.border,
  },
  folderFilterContainer: {
    flex: 1,
    paddingHorizontal: 16,
    paddingTop: 16,
    paddingBottom: 16,
    backgroundColor: Colors.dark.background,
  },
  folderListHeader: {
    ...Typography.caption,
    color: Colors.dark.muted,
    fontWeight: "700",
    letterSpacing: 0.6,
    textTransform: "uppercase",
    marginBottom: 8,
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
  notesStageContainer: {
    flex: 1,
    backgroundColor: Colors.dark.background,
  },
  notesBackWrapper: {
    paddingHorizontal: 16,
    paddingTop: 16,
    paddingBottom: 12,
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
  notesListWrapper: {
    flex: 1,
    backgroundColor: Colors.dark.background,
  },
  notesHeader: {
    paddingHorizontal: 16,
    paddingTop: 20,
    paddingBottom: 8,
  },
  notesHeaderTitle: {
    ...Typography.h3,
    color: Colors.dark.text,
  },
  notesHeaderMeta: {
    flexDirection: "row",
    alignItems: "center",
    marginTop: 8,
  },
  notesHeaderSpinner: {
    marginRight: 10,
  },
  notesHeaderCount: {
    ...Typography.caption,
    color: Colors.dark.muted,
    fontWeight: "600",
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
  reorderActiveCard: {
    borderColor: Colors.dark.tint,
    shadowColor: Colors.dark.tint,
    shadowOpacity: 0.2,
    shadowRadius: 10,
    elevation: 3,
  },
  draggingCard: {
    borderColor: Colors.dark.tint,
    backgroundColor: `${Colors.dark.tint}22`,
    shadowColor: Colors.dark.tint,
    shadowOpacity: 0.3,
    shadowRadius: 12,
    elevation: 4,
  },
  sheetBackground: {
    backgroundColor: Colors.dark.surface,
  },
  sheetHandle: {
    backgroundColor: Colors.dark.surface,
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    paddingTop: 12,
    paddingBottom: 4,
  },
  sheetHandleIndicator: {
    backgroundColor: Colors.dark.border,
  },
  editSheetContainer: {
    flex: 1,
    backgroundColor: Colors.dark.surface,
    paddingHorizontal: 20,
    paddingBottom: 24,
  },
  editSheetContent: {
    paddingBottom: 24,
  },
  editTopBar: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    marginBottom: 16,
  },
  editHeroBadge: {
    flexDirection: "row",
    alignItems: "center",
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderRadius: 18,
  },
  editHeroIconWrap: {
    width: 28,
    height: 28,
    borderRadius: 14,
    alignItems: "center",
    justifyContent: "center",
    marginRight: 8,
  },
  editHeroBadgeText: {
    ...Typography.caption,
    color: Colors.dark.text,
    fontWeight: "600",
  },
  editCloseButton: {
    padding: 6,
    marginLeft: 8,
  },
  editTitle: {
    ...Typography.h3,
    color: Colors.dark.text,
    marginBottom: 6,
  },
  editSubtitle: {
    ...Typography.caption,
    color: Colors.dark.muted,
    marginBottom: 18,
  },
  pinToggle: {
    flexDirection: "row",
    alignItems: "center",
    alignSelf: "flex-start",
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 18,
    borderWidth: 1,
    borderColor: Colors.dark.border,
    marginBottom: 20,
  },
  pinToggleActive: {
    backgroundColor: Colors.dark.tint,
    borderColor: Colors.dark.tint,
  },
  pinToggleIcon: {
    marginRight: 8,
  },
  pinToggleText: {
    ...Typography.caption,
    color: Colors.dark.muted,
    fontWeight: "600",
  },
  pinToggleTextActive: {
    color: Colors.dark.background,
  },
  editSection: {
    marginBottom: 20,
  },
  editLabel: {
    ...Typography.caption,
    color: Colors.dark.muted,
    fontWeight: "700",
    textTransform: "uppercase",
    letterSpacing: 0.6,
    marginBottom: 8,
  },
  editContentInput: {
    minHeight: 140,
    borderRadius: 14,
    borderWidth: 1,
    borderColor: Colors.dark.border,
    backgroundColor: Colors.dark.background,
    padding: 14,
    ...Typography.body,
    color: Colors.dark.text,
    textAlignVertical: "top",
  },
  editTagInput: {
    borderRadius: 14,
    borderWidth: 1,
    borderColor: Colors.dark.border,
    backgroundColor: Colors.dark.background,
    paddingHorizontal: 14,
    paddingVertical: 10,
    ...Typography.body,
    color: Colors.dark.text,
  },
  editHelperText: {
    ...Typography.caption,
    color: Colors.dark.muted,
    marginTop: 8,
  },
  editFolderChips: {
    paddingRight: 12,
  },
  folderChip: {
    flexDirection: "row",
    alignItems: "center",
    paddingHorizontal: 12,
    paddingVertical: 8,
    marginRight: 10,
    borderRadius: 18,
    borderWidth: 1,
    borderColor: Colors.dark.border,
    backgroundColor: Colors.dark.surface,
  },
  folderChipActive: {
    borderColor: Colors.dark.tint,
  },
  folderChipIcon: {
    marginRight: 6,
  },
  folderChipText: {
    ...Typography.caption,
    color: Colors.dark.muted,
    fontWeight: "600",
  },
  folderChipTextActive: {
    color: Colors.dark.tint,
  },
  editFooterArea: {
    borderTopWidth: 1,
    borderTopColor: Colors.dark.border,
    paddingTop: 16,
    marginTop: 8,
  },
  editDeleteButton: {
    flexDirection: "row",
    alignItems: "center",
    alignSelf: "flex-start",
    paddingVertical: 8,
  },
  editDeleteIcon: {
    marginRight: 8,
  },
  editDeleteText: {
    ...Typography.caption,
    color: Colors.dark.error,
    fontWeight: "600",
  },
  editFooterActions: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    marginTop: 12,
  },
  editCancelButton: {
    paddingVertical: 12,
    paddingHorizontal: 18,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: Colors.dark.border,
    backgroundColor: Colors.dark.surface,
    marginRight: 12,
  },
  editCancelText: {
    ...Typography.body,
    color: Colors.dark.muted,
    fontWeight: "600",
  },
  editSaveButton: {
    flex: 1,
    paddingVertical: 14,
    borderRadius: 12,
    backgroundColor: Colors.dark.tint,
    alignItems: "center",
    flexDirection: "row",
    justifyContent: "center",
  },
  editSaveButtonDisabled: {
    opacity: 0.5,
  },
  editSaveText: {
    ...Typography.body,
    color: Colors.dark.background,
    fontWeight: "600",
  },
  editSheetPlaceholder: {
    alignItems: "center",
    justifyContent: "center",
    paddingVertical: 32,
  },
  cardHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: 12,
  },
  cardContentRow: {
    flexDirection: "row",
    alignItems: "flex-start",
  },
  cardMain: {
    flex: 1,
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
  dragHandle: {
    paddingVertical: 6,
    paddingHorizontal: 10,
    borderRadius: 14,
    borderWidth: 1,
    borderColor: Colors.dark.border,
    backgroundColor: Colors.dark.surface,
    marginRight: 12,
    alignItems: "center",
    justifyContent: "center",
  },
  dragHandleActive: {
    borderColor: Colors.dark.tint,
    backgroundColor: `${Colors.dark.tint}12`,
  },
  dragHandleDisabled: {
    opacity: 0.4,
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
  emptyListText: {
    ...Typography.caption,
    color: Colors.dark.muted,
    textAlign: "center",
    marginTop: 24,
  },
});
