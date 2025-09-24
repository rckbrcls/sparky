export interface Folder {
  id: string;
  name: string;
  color: string;
  icon: string;
  isDefault: boolean;
  sortOrder: number;
  createdAt: string;
  updatedAt: string;
}

export interface QuickNote {
  id: string;
  content: string;
  folderId?: string | null;
  tags: string;
  isPinned: boolean;
  sortOrder?: number | null;
  createdAt: string;
  updatedAt: string;
}
