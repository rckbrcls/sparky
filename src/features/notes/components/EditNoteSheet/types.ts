import type {
  BottomSheetBackdropProps,
  BottomSheetModal,
} from "@gorhom/bottom-sheet";
import type { ReactElement, RefObject } from "react";

import type { FolderListItem } from "../FolderListView/types";
import type { QuickNoteWithFolder } from "../NotesView/types";

export interface EditNoteSheetProps {
  sheetRef: RefObject<BottomSheetModal | null>;
  snapPoints: string[];
  renderBackdrop: (props: BottomSheetBackdropProps) => ReactElement;
  onDismiss: () => void;
  note: QuickNoteWithFolder | null;
  saving: boolean;
  editedContent: string;
  onChangeContent: (value: string) => void;
  editedTags: string;
  onChangeTags: (value: string) => void;
  editedFolderId: string | null;
  onChangeFolder: (value: string | null) => void;
  editedPinned: boolean;
  onTogglePinned: () => void;
  availableFolders: FolderListItem[];
  onClose: (force?: boolean) => void;
  onSave: () => void;
  onDelete: (noteId: string, options?: { afterDelete?: () => void }) => void;
}

export type { FolderListItem, QuickNoteWithFolder };
