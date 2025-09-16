import React, { useEffect, useRef, useState } from "react";
import {
  Alert,
  FlatList,
  FlatListProps,
  NativeScrollEvent,
  NativeSyntheticEvent,
  RefreshControl,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from "react-native";
import Animated from "react-native-reanimated";
import { Colors } from "../constants/Colors";
import { Typography } from "../constants/Typography";
import { useApp } from "../context/AppContext";
import { useGlobalTouchDismiss } from "../context/GlobalTouchDismissContext";
import { database, Folder, QuickNote } from "../database/database";

interface QuickNoteWithFolder extends QuickNote {
  folder?: Folder;
}

const AnimatedNotesList =
  Animated.createAnimatedComponent<FlatListProps<QuickNoteWithFolder>>(
    FlatList
  );

interface NotesViewProps {
  onRefresh?: () => void;
  onScroll?: (event: NativeSyntheticEvent<NativeScrollEvent>) => void;
}

export const NotesView: React.FC<NotesViewProps> = ({
  onRefresh,
  onScroll,
}) => {
  const { isInitialized, error: initError, initializeApp } = useApp();
  const [notes, setNotes] = useState<QuickNoteWithFolder[]>([]);
  const [loading, setLoading] = useState(false);
  const [searchTerm, setSearchTerm] = useState("");
  const [selectedFolder, setSelectedFolder] = useState<string>("all");
  const [folders, setFolders] = useState<Folder[]>([]);
  const searchRef = useRef<TextInput | null>(null);
  const blurSearch = () => searchRef.current?.blur();
  const { register, unregister } = useGlobalTouchDismiss();

  useEffect(() => {
    const id = `notes-search`;
    register(id, {
      isFocused: () =>
        !!searchRef.current && (searchRef.current as any).isFocused?.(),
      blur: () => searchRef.current?.blur(),
    });
    return () => unregister(id);
  }, [register, unregister]);

  useEffect(() => {
    if (isInitialized) {
      loadFolders();
      loadNotes();
    }
  }, [isInitialized]); // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => {
    if (isInitialized) {
      loadNotes();
    }
  }, [searchTerm, selectedFolder, isInitialized]); // eslint-disable-line react-hooks/exhaustive-deps

  const loadFolders = async () => {
    if (!isInitialized) return;
    try {
      const folderData = await database.getAllFolders();
      setFolders(folderData);
    } catch (error) {
      console.error("Error loading folders:", error);
    }
  };

  const loadNotes = async () => {
    if (!isInitialized) return;
    setLoading(true);
    try {
      let noteData: QuickNote[] = [];

      if (searchTerm.trim()) {
        noteData = await database.searchQuickNotes(searchTerm);
      } else if (selectedFolder !== "all") {
        noteData = await database.getQuickNotesByFolder(selectedFolder);
      } else {
        noteData = await database.getAllQuickNotes();
      }

      // Add folder information
      const notesWithFolders = await Promise.all(
        noteData.map(async (note) => {
          if (note.folderId) {
            const folder = folders.find((f) => f.id === note.folderId);
            return { ...note, folder };
          }
          return note;
        })
      );

      setNotes(notesWithFolders);
    } catch (error) {
      console.error("Error loading notes:", error);
    } finally {
      setLoading(false);
    }
  };

  const handleRefresh = () => {
    if (!isInitialized) {
      initializeApp();
      return;
    }
    loadNotes();
    onRefresh?.();
  };

  const handleDeleteNote = async (noteId: string) => {
    Alert.alert("Delete Note", "Are you sure you want to delete this note?", [
      { text: "Cancel", style: "cancel" },
      {
        text: "Delete",
        style: "destructive",
        onPress: async () => {
          try {
            await database.deleteQuickNote(noteId);
            loadNotes();
          } catch (error) {
            console.error("Error deleting note:", error);
            Alert.alert("Error", "Failed to delete note");
          }
        },
      },
    ]);
  };

  const handleTogglePin = async (note: QuickNote) => {
    try {
      await database.updateQuickNote(note.id, {
        isPinned: !note.isPinned,
      });
      loadNotes();
    } catch (error) {
      console.error("Error toggling pin:", error);
    }
  };

  const formatTags = (tagsString: string) => {
    try {
      const tags = JSON.parse(tagsString || "[]");
      return tags.length > 0
        ? tags.map((tag: string) => `#${tag}`).join(" ")
        : "";
    } catch {
      return "";
    }
  };

  const renderNoteCard = ({ item }: { item: QuickNoteWithFolder }) => {
    const pinned = !!item.isPinned; // normaliza possível 0/1 vindo do DB
    return (
      <TouchableOpacity style={[styles.card, pinned && styles.pinnedCard]}>
        <View style={styles.cardHeader}>
          <View style={styles.cardInfo}>
            {pinned && <Text style={styles.pinIcon}>📌</Text>}
            {item.folder && (
              <View
                style={[
                  styles.folderBadge,
                  { backgroundColor: item.folder.color },
                ]}
              />
            )}
          </View>
          <View style={styles.cardActions}>
            <TouchableOpacity
              style={styles.actionButton}
              onPress={() => handleTogglePin(item)}
            >
              <Text style={styles.actionIcon}>{pinned ? "📌" : "📍"}</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={styles.actionButton}
              onPress={() => handleDeleteNote(item.id)}
            >
              <Text style={styles.actionIcon}>🗑️</Text>
            </TouchableOpacity>
          </View>
        </View>

        <Text style={styles.noteContent}>{item.content}</Text>

        <View style={styles.cardFooter}>
          <Text style={styles.noteDate}>
            {new Date(item.updatedAt).toLocaleDateString()}
          </Text>
          {formatTags(item.tags) && (
            <Text style={styles.noteTags}>{formatTags(item.tags)}</Text>
          )}
        </View>
      </TouchableOpacity>
    );
  };

  const renderFolderFilter = (
    folder: Folder | { id: string; name: string; icon?: string }
  ) => (
    <TouchableOpacity
      key={folder.id}
      style={[
        styles.filterButton,
        selectedFolder === folder.id && styles.filterButtonActive,
      ]}
      onPress={() => {
        setSelectedFolder(folder.id);
        blurSearch();
      }}
    >
      <Text
        style={[
          styles.filterButtonText,
          selectedFolder === folder.id && styles.filterButtonTextActive,
        ]}
      >
        {folder.name}
      </Text>
    </TouchableOpacity>
  );

  const renderEmptyState = () => (
    <View style={styles.emptyState}>
      <Text style={styles.emptyIcon}>📝</Text>
      <Text style={styles.emptyTitle}>No Notes Yet</Text>
      <Text style={styles.emptySubtitle}>
        {searchTerm
          ? "No notes match your search"
          : "Start capturing ideas with quick notes"}
      </Text>
    </View>
  );

  return (
    <View style={styles.container}>
      {!isInitialized && (
        <View style={styles.initializingBox}>
          <Text style={styles.initializingText}>
            {initError
              ? `Erro: ${initError}`
              : "Inicializando banco de dados..."}
          </Text>
          {initError && (
            <TouchableOpacity style={styles.retryBtn} onPress={initializeApp}>
              <Text style={styles.retryBtnText}>Tentar novamente</Text>
            </TouchableOpacity>
          )}
        </View>
      )}
      {/* Search Bar */}
      <View style={styles.searchContainer}>
        <TextInput
          ref={searchRef}
          style={styles.searchInput}
          value={searchTerm}
          onChangeText={setSearchTerm}
          placeholder="Search notes..."
          placeholderTextColor={Colors.dark.muted}
        />
      </View>

      {/* Folder Filter */}
      <View style={styles.filterContainer}>
        <FlatList
          horizontal
          data={
            folders.some((f) => f.id === "all")
              ? folders
              : [{ id: "all", name: "All" }, ...folders]
          }
          renderItem={({ item }) => renderFolderFilter(item)}
          keyExtractor={(item) => item.id}
          showsHorizontalScrollIndicator={false}
          contentContainerStyle={styles.filterList}
          keyboardShouldPersistTaps="handled"
        />
      </View>

      {/* Notes List */}
      <AnimatedNotesList
        data={notes}
        renderItem={renderNoteCard}
        keyExtractor={(item) => item.id}
        ListEmptyComponent={
          isInitialized && !loading ? renderEmptyState() : null
        }
        refreshControl={
          <RefreshControl
            refreshing={loading}
            onRefresh={handleRefresh}
            tintColor={Colors.dark.tint}
          />
        }
        contentContainerStyle={[styles.listContainer, { flexGrow: 1 }]}
        showsVerticalScrollIndicator={false}
        onScrollBeginDrag={blurSearch}
        onScroll={onScroll as unknown as (e: any) => void}
        scrollEventThrottle={onScroll ? 16 : undefined}
        keyboardShouldPersistTaps="handled"
      />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.dark.background,
  },
  searchContainer: {
    paddingHorizontal: 16,
    paddingVertical: 12,
    backgroundColor: Colors.dark.surface,
    borderBottomWidth: 1,
    borderBottomColor: Colors.dark.border,
  },
  searchInput: {
    ...Typography.body,
    color: Colors.dark.text,
    backgroundColor: Colors.dark.background,
    borderRadius: 8,
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderWidth: 1,
    borderColor: Colors.dark.border,
  },
  filterContainer: {
    backgroundColor: Colors.dark.surface,
    borderBottomWidth: 1,
    borderBottomColor: Colors.dark.border,
  },
  filterList: {
    paddingHorizontal: 16,
    paddingVertical: 12,
  },
  filterButton: {
    flexDirection: "row",
    alignItems: "center",
    paddingHorizontal: 12,
    paddingVertical: 8,
    marginRight: 8,
    borderRadius: 20,
    backgroundColor: Colors.dark.background,
    borderWidth: 1,
    borderColor: Colors.dark.border,
  },
  filterButtonActive: {
    backgroundColor: Colors.dark.tint,
    borderColor: Colors.dark.tint,
  },
  filterIcon: {
    fontSize: 14,
    marginRight: 4,
  },
  filterButtonText: {
    ...Typography.caption,
    color: Colors.dark.muted,
    fontWeight: "500",
  },
  filterButtonTextActive: {
    color: Colors.dark.background,
    fontWeight: "600",
  },
  listContainer: {
    padding: 16,
  },
  card: {
    backgroundColor: Colors.dark.surface,
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    borderWidth: 1,
    borderColor: Colors.dark.border,
  },
  pinnedCard: {
    borderColor: Colors.dark.warning,
    backgroundColor: `${Colors.dark.warning}15`,
  },
  cardHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: 12,
  },
  cardInfo: {
    flexDirection: "row",
    alignItems: "center",
  },
  pinIcon: {
    fontSize: 14,
    marginRight: 8,
  },
  folderBadge: {
    width: 24,
    height: 24,
    borderRadius: 12,
    alignItems: "center",
    justifyContent: "center",
  },
  cardActions: {
    flexDirection: "row",
  },
  actionButton: {
    padding: 8,
    marginLeft: 8,
  },
  actionIcon: {
    fontSize: 16,
    opacity: 0.7,
  },
  noteContent: {
    ...Typography.body,
    color: Colors.dark.text,
    lineHeight: 22,
    marginBottom: 12,
  },
  cardFooter: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
  },
  noteDate: {
    ...Typography.caption,
    color: Colors.dark.muted,
  },
  noteTags: {
    ...Typography.caption,
    color: Colors.dark.tint,
    fontWeight: "500",
  },
  emptyState: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    paddingHorizontal: 32,
  },
  emptyIcon: {
    fontSize: 64,
    marginBottom: 16,
    opacity: 0.5,
  },
  emptyTitle: {
    ...Typography.h3,
    color: Colors.dark.text,
    marginBottom: 8,
    textAlign: "center",
  },
  emptySubtitle: {
    ...Typography.body,
    color: Colors.dark.muted,
    textAlign: "center",
    lineHeight: 24,
  },
  initializingBox: {
    padding: 16,
    alignItems: "center",
  },
  initializingText: {
    ...Typography.caption,
    color: Colors.dark.muted,
    marginBottom: 8,
  },
  retryBtn: {
    paddingHorizontal: 14,
    paddingVertical: 8,
    backgroundColor: Colors.dark.tint,
    borderRadius: 8,
  },
  retryBtnText: {
    ...Typography.caption,
    color: Colors.dark.background,
    fontWeight: "600",
  },
  emptyListText: {
    ...Typography.caption,
    color: Colors.dark.muted,
    textAlign: "center",
    marginTop: 24,
  },
});
