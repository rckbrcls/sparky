import type { BottomSheetBackdropProps, BottomSheetModal } from "@gorhom/bottom-sheet";
import type { RefObject, ReactElement } from "react";
import type { ReminderWithFolder } from "../TimelineView/types";
import type { ReminderType } from "../create/CreateReminderSheet/types";

export interface EditReminderSheetProps {
  sheetRef: RefObject<BottomSheetModal | null>;
  snapPoints: (string | number)[];
  renderBackdrop: (props: BottomSheetBackdropProps) => ReactElement;
  onDismiss: () => void;
  onClose: () => void;
  reminder: ReminderWithFolder | null;
  onSave: (input: {
    title: string;
    type: ReminderType;
    notes?: string;
    person?: string;
    project?: string;
    location?: string;
    rrule?: string;
    fireAt?: Date;
  }) => Promise<void> | void;
}

