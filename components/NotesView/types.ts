import { Folder, QuickNote } from "../../database/database";

export interface QuickNoteWithFolder extends QuickNote {
  folder?: Folder;
}

export interface FolderListItem {
  id: string;
  name: string;
  icon?: string;
  color?: string;
}

export interface SettingsAction {
  key: string;
  label: string;
  icon: string;
  onPress: () => void;
  active?: boolean;
  disabled?: boolean;
}

export interface NotesViewProps {
  onRefresh?: () => void;
  onScrollMetrics?: (params: {
    y: number;
    contentHeight: number;
    layoutHeight: number;
  }) => void;
}
