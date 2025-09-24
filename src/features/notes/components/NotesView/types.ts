import { Folder, QuickNote } from "../../../../repositories/types";

export interface QuickNoteWithFolder extends QuickNote {
  folder?: Folder;
}

export interface NotesViewProps {
  onRefresh?: () => void;
  onScrollMetrics?: (params: {
    y: number;
    contentHeight: number;
    layoutHeight: number;
  }) => void;
}
