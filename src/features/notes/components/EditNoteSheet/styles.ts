import { Colors } from "@/src/constants/Colors";
import { Typography } from "@/src/constants/Typography";
import { StyleSheet } from "react-native";

export const styles = StyleSheet.create({
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
});
