import { useEffect, useState } from "react";
import type { Dispatch, SetStateAction } from "react";
import { database } from "../database";

interface FolderMapResult {
  folderMap: Record<string, string>;
  setFolderMap: Dispatch<SetStateAction<Record<string, string>>>;
}

export const useFolderMap = (): FolderMapResult => {
  const [folderMap, setFolderMap] = useState<Record<string, string>>({});

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        if (!(database as any).db && (database as any).initialize) {
          await (database as any).initialize();
        }
        const folders = await database.getAllFolders();
        if (cancelled) return;
        const next: Record<string, string> = {};
        folders.forEach((folder: any) => {
          next[folder.id] = folder.name;
        });
        setFolderMap(next);
      } catch {
        // ignore folder preload errors
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  return { folderMap, setFolderMap };
};
