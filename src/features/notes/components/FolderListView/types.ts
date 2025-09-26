export interface FolderListItem {
  id: string;
  name: string;
  icon?: string;
  color?: string;
}

export interface FolderListViewProps {
  folders: FolderListItem[];
  selectedFolderId: string | null;
  onSelect: (folderId: string) => void;
  folderNoteCounts: Record<string, number>;
  loading: boolean;
  refreshing: boolean;
  onAddFolder?: () => void;
  onDeleteFolder?: (folderId: string) => void;
}
