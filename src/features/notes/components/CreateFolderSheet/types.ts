import type { BottomSheetBackdropProps, BottomSheetModal } from "@gorhom/bottom-sheet";
import type { RefObject } from "react";

export interface CreateFolderInput {
  name: string;
  color?: string | null;
  icon?: string | null;
}

export interface CreateFolderSheetProps {
  sheetRef: RefObject<BottomSheetModal | null>;
  snapPoints: (string | number)[];
  renderBackdrop: (props: BottomSheetBackdropProps) => JSX.Element;
  onDismiss: () => void;
  onClose: () => void;
  onCreate: (input: CreateFolderInput) => Promise<void> | void;
}

export type { BottomSheetModal };

