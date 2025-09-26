import React, {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import {
  Alert,
  Animated,
  Easing,
  LayoutChangeEvent,
  Text,
  TouchableOpacity,
  View,
  RefreshControl,
  FlatList,
} from "react-native";
import {
  BottomSheetBackdrop,
  BottomSheetBackdropProps,
  BottomSheetModal,
} from "@gorhom/bottom-sheet";
import { GestureHandlerRootView } from "react-native-gesture-handler";

import { styles } from "./styles";
import type { NotesViewProps, QuickNoteWithFolder } from "./types";
import type { FolderListItem } from "../FolderListView/types";
import type { SettingsAction } from "../NotesToolbar/types";
import { formatTags, parseTagsInput, sortNotes } from "./utils";
import { AppIcon } from "@/src/components/AppIcon";
import { Colors } from "@/src/constants/Colors";
import { useApp } from "@/src/context/AppContext";
import { database } from "@/src/database";
import { EditNoteSheet } from "../EditNoteSheet";
import { NotesEmptyState } from "../EmptyState";
import { FolderListView } from "../FolderListView";
import { NotesToolbar } from "../NotesToolbar";
import { Folder, QuickNote } from "../../types";

export type { NotesViewProps, QuickNoteWithFolder };

export const NotesView: React.FC<NotesViewProps> = ({
  onRefresh,
  onScrollMetrics,
}) => {
  const { isInitialized, error: initError, initializeApp } = useApp();
  const [notes, setNotes] = useState<QuickNoteWithFolder[]>([]);
  const [loading, setLoading] = useState(false);
  const [selectedFolderId, setSelectedFolderId] = useState<string | null>(null);
  const [folders, setFolders] = useState<Folder[]>([]);
  const [foldersLoaded, setFoldersLoaded] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const [editingNote, setEditingNote] = useState<QuickNoteWithFolder | null>(
    null
  );
  const [editedContent, setEditedContent] = useState("");
  const [editedTags, setEditedTags] = useState("");
  const [editedFolderId, setEditedFolderId] = useState<string | null>(null);
  const [editedPinned, setEditedPinned] = useState(false);
  const [savingEdit, setSavingEdit] = useState(false);

  const [showPinnedOnly, setShowPinnedOnly] = useState(false);
  const [folderNoteCounts, setFolderNoteCounts] = useState<
    Record<string, number>
  >({});
  const editSheetRef = useRef<BottomSheetModal | null>(null);
  const listContentHeight = useRef(0);
  const listLayoutHeight = useRef(0);
  const stageTransition = useRef(new Animated.Value(0)).current;

  const editSheetSnapPoints = useMemo(() => ["60%", "92%"], []);

  const renderEditSheetBackdrop = useCallback(
    (backdropProps: BottomSheetBackdropProps) => (
      <BottomSheetBackdrop
        {...backdropProps}
        appearsOnIndex={0}
        disappearsOnIndex={-1}
        pressBehavior="close"
      />
    ),
    []
  );

  const availableFolders = useMemo(
    () => folders.filter((folder) => folder.id !== "all"),
    [folders]
  );

  const folderItems = useMemo<FolderListItem[]>(() => {
    const normalized = folders.map((folder) => ({
      id: folder.id,
      name: folder.name,
      icon: folder.icon,
      color: folder.color,
    }));

    const hasAllEntry = normalized.some((folder) => folder.id === "all");
    const allEntry: FolderListItem = {
      id: "all",
      name: "All notes",
      icon: "stack",
      color: Colors.dark.tint,
    };

    return hasAllEntry ? normalized : [allEntry, ...normalized];
  }, [folders]);

  // currentFolder not needed after refactor

  useEffect(() => {
    if (!folderItems.length || !selectedFolderId) return;
    if (!folderItems.some((folder) => folder.id === selectedFolderId)) {
      setSelectedFolderId(null);
    }
  }, [folderItems, selectedFolderId]);

  const hasPinnedNotes = useMemo(
    () => notes.some((note) => !!note.isPinned),
    [notes]
  );

  const displayedNotes = useMemo(
    () => (showPinnedOnly ? notes.filter((note) => note.isPinned) : notes),
    [notes, showPinnedOnly]
  );

  const loadFolderCounts = useCallback(async () => {
    if (!isInitialized) return;
    try {
      const allNotes = await database.getAllQuickNotes();
      const counts: Record<string, number> = { all: allNotes.length };
      allNotes.forEach((note: any) => {
        if (note.folderId) {
          counts[note.folderId] = (counts[note.folderId] ?? 0) + 1;
        }
      });
      setFolderNoteCounts(counts);
    } catch (error) {
      console.error("Error loading folder counts:", error);
    }
  }, [isInitialized]);

  const loadFolders = useCallback(async () => {
    if (!isInitialized) return;
    setFoldersLoaded(false);
    try {
      const folderData = await database.getAllFolders();
      setFolders(folderData);
    } catch (error) {
      console.error("Error loading folders:", error);
    } finally {
      setFoldersLoaded(true);
    }
    await loadFolderCounts();
  }, [isInitialized, loadFolderCounts]);

  const loadNotes = useCallback(
    async ({
      showLoading = true,
      targetFolderId,
    }: {
      showLoading?: boolean;
      targetFolderId?: string | null;
    } = {}) => {
      if (!isInitialized) return;
      const folderId = targetFolderId ?? selectedFolderId;
      if (!folderId) {
        setNotes([]);
        setLoading(false);
        return;
      }
      if (showLoading) setLoading(true);
      try {
        let noteData: QuickNote[] = [];

        if (folderId !== "all") {
          noteData = await database.getQuickNotesByFolder(folderId);
        } else {
          noteData = await database.getAllQuickNotes();
        }

        const notesWithFolders: QuickNoteWithFolder[] = noteData.map((note) => {
          const normalizedSortOrder =
            note.sortOrder === null || note.sortOrder === undefined
              ? undefined
              : Number(note.sortOrder);

          if (note.folderId) {
            const folder = folders.find((f) => f.id === note.folderId);
            return { ...note, sortOrder: normalizedSortOrder, folder };
          }
          return { ...note, sortOrder: normalizedSortOrder };
        });

        setNotes(sortNotes(notesWithFolders));

        if (folderId === "all") {
          const counts: Record<string, number> = { all: noteData.length };
          noteData.forEach((note) => {
            if (note.folderId) {
              counts[note.folderId] = (counts[note.folderId] ?? 0) + 1;
            }
          });
          setFolderNoteCounts(counts);
        } else {
          await loadFolderCounts();
        }
      } catch (error) {
        console.error("Error loading notes:", error);
      } finally {
        setLoading(false);
      }
    },
    [folders, isInitialized, loadFolderCounts, selectedFolderId]
  );

  const loadFoldersRef = useRef(loadFolders);
  const loadNotesRef = useRef(loadNotes);

  useEffect(() => {
    loadFoldersRef.current = loadFolders;
  }, [loadFolders]);

  useEffect(() => {
    loadNotesRef.current = loadNotes;
  }, [loadNotes]);

  useEffect(() => {
    if (showPinnedOnly) {
      // drag feature removed: ensure any related UI flags are reset
    }
  }, [showPinnedOnly]);

  useEffect(() => {
    if (!isInitialized) return;
    loadFolders();
  }, [isInitialized, loadFolders]);

  useEffect(() => {
    if (!isInitialized || !foldersLoaded) return;
    if (!selectedFolderId) {
      setNotes([]);
      setLoading(false);
      return;
    }
    loadNotes({ showLoading: true });
  }, [foldersLoaded, isInitialized, loadNotes, selectedFolderId]);

  const handleRefresh = useCallback(() => {
    if (!isInitialized) {
      initializeApp();
      return;
    }
    setRefreshing(true);
    const runRefresh = selectedFolderId
      ? () =>
          loadNotesRef.current({
            showLoading: false,
            targetFolderId: selectedFolderId,
          })
      : () => loadFoldersRef.current();

    Promise.resolve(runRefresh())
      .then(() => {
        onRefresh?.();
      })
      .finally(() => {
        setRefreshing(false);
      });
  }, [initializeApp, isInitialized, onRefresh, selectedFolderId]);

  const handleTogglePinnedOnly = useCallback(() => {
    if (!hasPinnedNotes || !selectedFolderId) return;
    setShowPinnedOnly((prev) => !prev);
  }, [hasPinnedNotes, selectedFolderId]);

  const handleSelectFolder = useCallback(
    (folderId: string) => {
      setShowPinnedOnly(false);
      // reset any drag-related UI state (feature removed)
      if (folderId === selectedFolderId) {
        setSelectedFolderId(null);
        setNotes([]);
        setLoading(false);
        return;
      }
      setSelectedFolderId(folderId);
    },
    [selectedFolderId]
  );

  const handleBackToFolders = useCallback(() => {
    setSelectedFolderId(null);
    setNotes([]);
    setLoading(false);
    // drag removed
    setShowPinnedOnly(false);
  }, []);

  const handleDeleteNote = (
    noteId: string,
    options?: { afterDelete?: () => void }
  ) => {
    Alert.alert("Delete Note", "Are you sure you want to delete this note?", [
      { text: "Cancel", style: "cancel" },
      {
        text: "Delete",
        style: "destructive",
        onPress: async () => {
          try {
            await database.deleteQuickNote(noteId);
            await loadNotes({ showLoading: false });
            options?.afterDelete?.();
          } catch (error) {
            console.error("Error deleting note:", error);
            Alert.alert("Error", "Failed to delete note");
          }
        },
      },
    ]);
  };

  // Drag-and-drop reorder functionality removed.

  const resetNoteEditorState = useCallback(() => {
    setEditingNote(null);
    setEditedContent("");
    setEditedTags("");
    setEditedFolderId(null);
    setEditedPinned(false);
  }, []);

  const openNoteEditor = useCallback((note: QuickNoteWithFolder) => {
    setEditingNote(note);
    setEditedContent(note.content);
    setEditedTags(formatTags(note.tags));
    setEditedFolderId(note.folderId ?? null);
    setEditedPinned(!!note.isPinned);
    requestAnimationFrame(() => {
      editSheetRef.current?.present();
    });
  }, []);

  const closeNoteEditor = (force = false) => {
    if (savingEdit && !force) return;
    editSheetRef.current?.dismiss();
    if (force) {
      resetNoteEditorState();
    }
  };

  const handleEditSheetDismiss = useCallback(() => {
    resetNoteEditorState();
  }, [resetNoteEditorState]);

  const handleToggleEditedPinned = useCallback(() => {
    setEditedPinned((prev) => !prev);
  }, []);

  const handleChangeEditedFolder = useCallback((folderId: string | null) => {
    setEditedFolderId(folderId);
  }, []);

  const handleSaveNoteEdit = async () => {
    if (!editingNote || savingEdit) return;

    const trimmedContent = editedContent.trim();
    if (!trimmedContent) {
      Alert.alert("Empty note", "Please add some content before saving.");
      return;
    }

    const tagsArray = parseTagsInput(editedTags);
    const serializedTags = JSON.stringify(tagsArray);
    const normalizedFolderId = editedFolderId;

    const updates: Record<string, unknown> = {
      content: trimmedContent,
      tags: serializedTags,
      isPinned: editedPinned,
    };

    if ((normalizedFolderId ?? null) !== (editingNote.folderId ?? null)) {
      updates.folderId = normalizedFolderId ?? null;
    }

    try {
      setSavingEdit(true);
      await database.updateQuickNote(
        editingNote.id,
        updates as Partial<QuickNote>
      );

      const updatedAt = new Date().toISOString();

      setNotes((prevNotes) => {
        const updatedNotes = prevNotes.map((note) => {
          if (note.id !== editingNote.id) return note;

          const nextFolder =
            typeof normalizedFolderId === "string"
              ? folders.find((folder) => folder.id === normalizedFolderId)
              : undefined;

          return {
            ...note,
            content: trimmedContent,
            tags: serializedTags,
            folderId:
              typeof normalizedFolderId === "string"
                ? normalizedFolderId
                : undefined,
            folder: nextFolder,
            isPinned: editedPinned,
            updatedAt,
          };
        });

        return sortNotes(updatedNotes);
      });

      await loadFolderCounts();

      closeNoteEditor(true);
    } catch (error) {
      console.error("Error updating note:", error);
      Alert.alert("Error", "Failed to update note");
    } finally {
      setSavingEdit(false);
    }
  };

  const settingsActions = useMemo<SettingsAction[]>(() => {
    if (!selectedFolderId) return [];
    const actions: SettingsAction[] = [];

    actions.push({
      key: "pinnedOnly",
      label: showPinnedOnly ? "Pinned only" : "Show pinned",
      icon: "pin",
      onPress: handleTogglePinnedOnly,
      active: showPinnedOnly,
      disabled: !hasPinnedNotes,
    });

    // reorder action removed

    return actions;
  }, [
    handleTogglePinnedOnly,
    hasPinnedNotes,
    selectedFolderId,
    showPinnedOnly,
  ]);

  const notesCountLabel = useMemo(() => {
    const count = displayedNotes.length;
    return `${count} ${count === 1 ? "note" : "notes"}`;
  }, [displayedNotes.length]);

  const handleContentSizeChange = useCallback((_: number, height: number) => {
    listContentHeight.current = height;
  }, []);

  const handleListLayout = useCallback((event: LayoutChangeEvent) => {
    listLayoutHeight.current = event.nativeEvent.layout.height;
  }, []);

  const handleScrollOffsetChange = useCallback(
    (offset: number) => {
      onScrollMetrics?.({
        y: offset,
        contentHeight: listContentHeight.current,
        layoutHeight: listLayoutHeight.current,
      });
    },
    [onScrollMetrics]
  );

  useEffect(() => {
    const toValue = selectedFolderId ? 1 : 0;
    Animated.timing(stageTransition, {
      toValue,
      duration: 260,
      easing: Easing.out(Easing.quad),
      useNativeDriver: true,
    }).start();
  }, [selectedFolderId, stageTransition]);

  const folderStageStyle = useMemo(
    () => ({
      opacity: stageTransition.interpolate({
        inputRange: [0, 1],
        outputRange: [1, 0],
      }),
      transform: [
        {
          translateX: stageTransition.interpolate({
            inputRange: [0, 1],
            outputRange: [0, -24],
          }),
        },
        {
          scale: stageTransition.interpolate({
            inputRange: [0, 1],
            outputRange: [1, 0.96],
          }),
        },
      ],
    }),
    [stageTransition]
  );

  const notesStageStyle = useMemo(
    () => ({
      opacity: stageTransition.interpolate({
        inputRange: [0, 1],
        outputRange: [0, 1],
      }),
      transform: [
        {
          translateX: stageTransition.interpolate({
            inputRange: [0, 1],
            outputRange: [24, 0],
          }),
        },
      ],
    }),
    [stageTransition]
  );

  const showFolderList = !selectedFolderId;

  return (
    <GestureHandlerRootView style={styles.container}>
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

        <View style={styles.stageArea}>
          <Animated.View
            style={[styles.stagePlane, folderStageStyle]}
            pointerEvents={showFolderList ? "auto" : "none"}
          >
            <FolderListView
              folders={folderItems}
              selectedFolderId={selectedFolderId}
              onSelect={handleSelectFolder}
              folderNoteCounts={folderNoteCounts}
              loading={loading}
              refreshing={refreshing}
            />
          </Animated.View>

          <Animated.View
            style={[styles.stagePlane, notesStageStyle]}
            pointerEvents={showFolderList ? "none" : "auto"}
          >
            <View style={styles.notesStageContainer}>
              {settingsActions.length ? (
                <NotesToolbar actions={settingsActions} />
              ) : null}

              <View style={styles.notesBackWrapper}>
                <TouchableOpacity
                  style={styles.notesBackButton}
                  onPress={handleBackToFolders}
                  activeOpacity={0.85}
                >
                  <AppIcon
                    icon="chevronLeft"
                    size={18}
                    color={Colors.dark.tint}
                    style={styles.notesBackIcon}
                  />
                  <Text style={styles.notesBackText}>back</Text>
                </TouchableOpacity>
                <Text style={styles.notesHeaderCount}>{notesCountLabel}</Text>
              </View>

              <View style={styles.notesListWrapper}>
                <FlatList
                  style={styles.notesList}
                  data={displayedNotes}
                  renderItem={({ item, index }) => (
                    <TouchableOpacity
                      activeOpacity={0.95}
                      style={[
                        styles.card,
                        item.isPinned && styles.pinnedCard,
                        { opacity: 1 },
                      ]}
                    >
                      <View style={styles.cardContentRow}>
                        <View style={styles.cardMain}>
                          <View style={styles.cardHeader}>
                            <View style={styles.cardInfo}>
                              {item.isPinned && (
                                <AppIcon
                                  icon="pin"
                                  size={16}
                                  color={Colors.dark.tint}
                                  style={styles.pinIcon}
                                />
                              )}
                              {item.folder && (
                                <View
                                  style={[
                                    styles.folderBadge,
                                    { backgroundColor: item.folder.color },
                                  ]}
                                >
                                  <AppIcon
                                    icon={item.folder.icon || "folder"}
                                    size={12}
                                    color={Colors.dark.background}
                                    style={styles.folderBadgeIcon}
                                  />
                                  <Text style={styles.folderBadgeText}>
                                    {item.folder.name}
                                  </Text>
                                </View>
                              )}
                            </View>
                            <TouchableOpacity
                              style={styles.editButton}
                              onPress={() => openNoteEditor(item)}
                            >
                              <AppIcon
                                icon="eye"
                                size={18}
                                color={Colors.dark.background}
                              />
                            </TouchableOpacity>
                          </View>

                          <Text style={styles.noteContent}>{item.content}</Text>

                          <View style={styles.cardFooter}>
                            <Text style={styles.noteDate}>
                              {new Date(item.updatedAt).toLocaleDateString()}
                            </Text>
                            {formatTags(item.tags) ? (
                              <Text style={styles.noteTags}>
                                {formatTags(item.tags)}
                              </Text>
                            ) : null}
                          </View>
                        </View>
                      </View>
                    </TouchableOpacity>
                  )}
                  keyExtractor={(item) => item.id}
                  ListEmptyComponent={
                    isInitialized && !loading ? (
                      <NotesEmptyState showPinnedOnly={showPinnedOnly} />
                    ) : null
                  }
                  refreshControl={
                    <RefreshControl
                      refreshing={refreshing}
                      onRefresh={handleRefresh}
                      tintColor={Colors.dark.tint}
                    />
                  }
                  contentContainerStyle={[
                    styles.listContainer,
                    styles.listContentInset,
                    { flexGrow: displayedNotes.length ? 0 : 1 },
                  ]}
                  showsVerticalScrollIndicator={false}
                  onLayout={handleListLayout}
                  onContentSizeChange={handleContentSizeChange}
                  onScroll={({ nativeEvent }) =>
                    handleScrollOffsetChange(nativeEvent.contentOffset.y)
                  }
                  keyboardShouldPersistTaps="handled"
                  bounces={false}
                  alwaysBounceVertical={false}
                  overScrollMode="never"
                />
              </View>
            </View>
          </Animated.View>
        </View>
      </View>
      <EditNoteSheet
        sheetRef={editSheetRef}
        snapPoints={editSheetSnapPoints}
        renderBackdrop={renderEditSheetBackdrop}
        onDismiss={handleEditSheetDismiss}
        note={editingNote}
        saving={savingEdit}
        editedContent={editedContent}
        onChangeContent={setEditedContent}
        editedTags={editedTags}
        onChangeTags={setEditedTags}
        editedFolderId={editedFolderId}
        onChangeFolder={handleChangeEditedFolder}
        editedPinned={editedPinned}
        onTogglePinned={handleToggleEditedPinned}
        availableFolders={availableFolders}
        onClose={closeNoteEditor}
        onSave={handleSaveNoteEdit}
        onDelete={handleDeleteNote}
      />
    </GestureHandlerRootView>
  );
};
