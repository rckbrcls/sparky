import type { BottomSheetBackdropProps, BottomSheetModal } from "@gorhom/bottom-sheet";
import type { RefObject, ReactElement } from "react";

export type ReminderType = "once" | "recurring" | "by_person_project" | "by_location";

export interface CreateReminderInput {
  title: string;
  type: ReminderType;
  notes?: string;
  person?: string;
  project?: string;
  location?: string;
  rrule?: string; // for recurring
  fireAt?: Date; // for once
}

export interface CreateReminderSheetProps {
  sheetRef: RefObject<BottomSheetModal | null>;
  snapPoints: (string | number)[];
  renderBackdrop: (props: BottomSheetBackdropProps) => ReactElement;
  onDismiss: () => void;
  onClose: () => void;
  onCreate: (input: CreateReminderInput) => Promise<void> | void;
}
