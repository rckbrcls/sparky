import type { BottomSheetBackdropProps, BottomSheetModal } from "@gorhom/bottom-sheet";
import type { RefObject, ReactElement } from "react";

export interface EditFolderInput {
  name: string;
  color?: string | null;
  icon?: string | null;
}

export interface EditFolderSheetProps {
  sheetRef: RefObject<BottomSheetModal | null>;
  snapPoints: (string | number)[];
  renderBackdrop: (props: BottomSheetBackdropProps) => ReactElement;
  onDismiss: () => void;
  onClose: () => void;
  initialName: string;
  initialColor?: string | null;
  initialIcon?: string | null;
  onSave: (input: EditFolderInput) => Promise<void> | void;
}

export type { BottomSheetModal };
