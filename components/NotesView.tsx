import React, {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import {
  Alert,
  ActivityIndicator,
  FlatList,
  LayoutChangeEvent,
  RefreshControl,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from "react-native";
import {
  BottomSheetBackdrop,
  BottomSheetBackdropProps,
  BottomSheetModal,
  BottomSheetScrollView,
  BottomSheetView,
} from "@gorhom/bottom-sheet";
import { GestureHandlerRootView } from "react-native-gesture-handler";
import DraggableFlatList, {
  DragEndParams,
  RenderItemParams,
  ScaleDecorator,
  ShadowDecorator,
} from "react-native-draggable-flatlist";
import { Colors } from "../constants/Colors";
import { Typography } from "../constants/Typography";
import { useApp } from "../context/AppContext";
import { database, Folder, QuickNote } from "../database/database";
import { AppIcon } from "./AppIcon";

interface QuickNoteWithFolder extends QuickNote {
  folder?: Folder;
}

interface NotesViewProps {
  onRefresh?: () => void;
  onScrollMetrics?: (params: {
    y: number;
    contentHeight: number;
    layoutHeight: number;
  }) => void;
}

export const NotesView: React.FC<NotesViewProps> = ({
  onRefresh,
  onScrollMetrics,
}) => {
  // background follows current theme to avoid black overlay artifacts
  const { isInitialized, error: initError, initializeApp } = useApp();
  const [notes, setNotes] = useState<QuickNoteWithFolder[]>([]);
  const [loading, setLoading] = useState(false);
  const [selectedFolder, setSelectedFolder] = useState<string>("all");
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
  const initialLoad = useRef(true);
  const editSheetRef = useRef<BottomSheetModal>(null);
  const listContentHeight = useRef(0);
  const listLayoutHeight = useRef(0);

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

  useEffect(() => {
    if (!isInitialized) return;
    loadFolders();
  }, [isInitialized]); // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => {
    if (!isInitialized || !foldersLoaded) return;
    const shouldShowLoading = initialLoad.current;
    if (initialLoad.current) {
      initialLoad.current = false;
    }
    loadNotes({ showLoading: shouldShowLoading });
  }, [selectedFolder, isInitialized, foldersLoaded, folders]); // eslint-disable-line react-hooks/exhaustive-deps

  const loadFolders = async () => {
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
  };

  const sortNotes = (noteList: QuickNoteWithFolder[]) => {
    return [...noteList].sort((a, b) => {
      const pinnedDiff = Number(!!b.isPinned) - Number(!!a.isPinned);
      if (pinnedDiff !== 0) return pinnedDiff;
      const orderA = typeof a.sortOrder === "number" ? a.sortOrder : 0;
      const orderB = typeof b.sortOrder === "number" ? b.sortOrder : 0;
      if (orderA !== orderB) return orderB - orderA;
      const dateA = a.updatedAt ? new Date(a.updatedAt).getTime() : 0;
      const dateB = b.updatedAt ? new Date(b.updatedAt).getTime() : 0;
      return dateB - dateA;
    });
  };

  const loadNotes = async ({
    showLoading = true,
  }: {
    showLoading?: boolean;
  } = {}) => {
    if (!isInitialized) return;
    if (showLoading) setLoading(true);
    try {
      let noteData: QuickNote[] = [];

      if (selectedFolder !== "all") {
        noteData = await database.getQuickNotesByFolder(selectedFolder);
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
    } catch (error) {
      console.error("Error loading notes:", error);
    } finally {
      if (showLoading) setLoading(false);
    }
  };

  const handleRefresh = () => {
    if (!isInitialized) {
      initializeApp();
      return;
    }
    setRefreshing(true);
    loadNotes({ showLoading: false })
      .then(() => {
        onRefresh?.();
      })
      .finally(() => {
        setRefreshing(false);
      });
  };

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
            loadNotes();
            options?.afterDelete?.();
          } catch (error) {
            console.error("Error deleting note:", error);
            Alert.alert("Error", "Failed to delete note");
          }
        },
      },
    ]);
  };

  const handleDragEnd = async ({
    data,
    from,
    to,
  }: DragEndParams<QuickNoteWithFolder>) => {
    if (from === to) {
      setNotes(sortNotes(data));
      return;
    }

    const pinned = data.filter((item) => !!item.isPinned);
    const others = data.filter((item) => !item.isPinned);

    const assignOrder = (items: QuickNoteWithFolder[]) => {
      const total = items.length;
      return items.map((item, index) => ({
        ...item,
        sortOrder: total - index,
      }));
    };

    const orderedPinned = assignOrder(pinned);
    const orderedOthers = assignOrder(others);
    const combined = [...orderedPinned, ...orderedOthers];

    setNotes(sortNotes(combined));

    try {
      await database.updateQuickNotesSortOrder(
        combined.map((item) => ({
          id: item.id,
          sortOrder: typeof item.sortOrder === "number" ? item.sortOrder : 0,
        }))
      );
    } catch (error) {
      console.error("Error updating sort order:", error);
      loadNotes({ showLoading: false });
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

  const parseTagsInput = (value: string) => {
    return value
      .split(/[\s,]+/)
      .map((tag) => tag.replace(/^#/, "").trim())
      .filter(Boolean);
  };

  const resetNoteEditorState = useCallback(() => {
    setEditingNote(null);
    setEditedContent("");
    setEditedTags("");
    setEditedFolderId(null);
    setEditedPinned(false);
  }, []);

  const openNoteEditor = (note: QuickNoteWithFolder) => {
    setEditingNote(note);
    setEditedContent(note.content);
    setEditedTags(formatTags(note.tags));
    setEditedFolderId(note.folderId ?? null);
    setEditedPinned(!!note.isPinned);
    requestAnimationFrame(() => {
      editSheetRef.current?.present();
    });
  };

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

      closeNoteEditor(true);
    } catch (error) {
      console.error("Error updating note:", error);
      Alert.alert("Error", "Failed to update note");
    } finally {
      setSavingEdit(false);
    }
  };

  const renderNoteCard = ({
    item,
    drag,
    isActive,
  }: RenderItemParams<QuickNoteWithFolder>) => {
    const pinned = !!item.isPinned; // normaliza possível 0/1 vindo do DB
    return (
      <ScaleDecorator activeScale={0.97}>
        <ShadowDecorator color={Colors.dark.tint} opacity={0.3}>
          <TouchableOpacity
            activeOpacity={0.95}
            onLongPress={drag}
            onPress={() => openNoteEditor(item)}
            delayLongPress={120}
            disabled={isActive}
            style={[
              styles.card,
              pinned && styles.pinnedCard,
              isActive && styles.draggingCard,
            ]}
          >
            <View style={styles.cardHeader}>
              <View style={styles.cardInfo}>
                {pinned && (
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
              <View style={styles.cardActions}>
                <TouchableOpacity
                  style={styles.editButton}
                  onPress={() => openNoteEditor(item)}
                  disabled={isActive}
                >
                  <AppIcon
                    icon="eye"
                    size={18}
                    color={Colors.dark.background}
                  />
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
        </ShadowDecorator>
      </ScaleDecorator>
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
      <AppIcon icon="notes" size={32} color={Colors.dark.muted} />
      <Text style={styles.emptyTitle}>No Notes Yet</Text>
      <Text style={styles.emptySubtitle}>
        Start capturing ideas with quick notes
      </Text>
    </View>
  );

  const editingAccentColor = editingNote?.folder?.color ?? Colors.dark.tint;
  const editingTimestampLabel = editingNote?.updatedAt
    ? new Date(editingNote.updatedAt).toLocaleString()
    : "";

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
        <DraggableFlatList
          data={notes}
          renderItem={renderNoteCard}
          keyExtractor={(item) => item.id}
          onDragEnd={handleDragEnd}
          activationDistance={8}
          ListEmptyComponent={
            isInitialized && !loading ? renderEmptyState() : null
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
            { flexGrow: notes.length ? 0 : 1 },
          ]}
          showsVerticalScrollIndicator={false}
          onLayout={handleListLayout}
          onContentSizeChange={handleContentSizeChange}
          onScrollOffsetChange={handleScrollOffsetChange}
          keyboardShouldPersistTaps="handled"
          bounces={false}
          alwaysBounceVertical={false}
          overScrollMode="never"
        />
      </View>
      <BottomSheetModal
        ref={editSheetRef}
        snapPoints={editSheetSnapPoints}
        enablePanDownToClose
        backdropComponent={renderEditSheetBackdrop}
        android_keyboardInputMode="adjustResize"
        backgroundStyle={styles.sheetBackground}
        handleStyle={styles.sheetHandle}
        handleIndicatorStyle={styles.sheetHandleIndicator}
        onDismiss={handleEditSheetDismiss}
      >
        <BottomSheetView style={styles.editSheetContainer}>
          {editingNote ? (
            <>
              <BottomSheetScrollView
                contentContainerStyle={styles.editSheetContent}
                keyboardShouldPersistTaps="handled"
                showsVerticalScrollIndicator={false}
              >
                <View style={styles.editTopBar}>
                  <View
                    style={[
                      styles.editHeroBadge,
                      { backgroundColor: `${editingAccentColor}33` },
                    ]}
                  >
                    <View
                      style={[
                        styles.editHeroIconWrap,
                        { backgroundColor: editingAccentColor },
                      ]}
                    >
                      <AppIcon
                        icon={editingNote.folder?.icon || "notes"}
                        size={16}
                        color={Colors.dark.background}
                      />
                    </View>
                    <Text style={styles.editHeroBadgeText}>Quick note</Text>
                  </View>
                  <TouchableOpacity
                    style={styles.editCloseButton}
                    onPress={() => closeNoteEditor()}
                    disabled={savingEdit}
                  >
                    <AppIcon icon="close" size={20} color={Colors.dark.muted} />
                  </TouchableOpacity>
                </View>
                <Text style={styles.editTitle}>Polish your thought</Text>
                {editingTimestampLabel ? (
                  <Text style={styles.editSubtitle}>
                    {`Updated ${editingTimestampLabel}`}
                  </Text>
                ) : null}
                <TouchableOpacity
                  style={[
                    styles.pinToggle,
                    editedPinned && styles.pinToggleActive,
                  ]}
                  onPress={() => setEditedPinned((prev) => !prev)}
                  disabled={savingEdit}
                >
                  <AppIcon
                    icon="pin"
                    size={18}
                    color={
                      editedPinned ? Colors.dark.background : Colors.dark.muted
                    }
                    style={styles.pinToggleIcon}
                  />
                  <Text
                    style={[
                      styles.pinToggleText,
                      editedPinned && styles.pinToggleTextActive,
                    ]}
                  >
                    {editedPinned ? "Pinned" : "Pin note"}
                  </Text>
                </TouchableOpacity>
                <View style={styles.editSection}>
                  <Text style={styles.editLabel}>Content</Text>
                  <TextInput
                    style={styles.editContentInput}
                    multiline
                    value={editedContent}
                    onChangeText={setEditedContent}
                    placeholder="Capture your note..."
                    placeholderTextColor={Colors.dark.muted}
                    editable={!savingEdit}
                  />
                </View>
                <View style={styles.editSection}>
                  <Text style={styles.editLabel}>Tags</Text>
                  <TextInput
                    style={styles.editTagInput}
                    value={editedTags}
                    onChangeText={setEditedTags}
                    placeholder="#focus #deepwork"
                    placeholderTextColor={Colors.dark.muted}
                    editable={!savingEdit}
                    autoCapitalize="none"
                  />
                  <Text style={styles.editHelperText}>
                    Separate tags with spaces or commas
                  </Text>
                </View>
                {!!availableFolders.length && (
                  <View style={styles.editSection}>
                    <Text style={styles.editLabel}>Folder</Text>
                    <ScrollView
                      horizontal
                      showsHorizontalScrollIndicator={false}
                      contentContainerStyle={styles.editFolderChips}
                      keyboardShouldPersistTaps="handled"
                    >
                      <TouchableOpacity
                        style={[
                          styles.folderChip,
                          editedFolderId === null && styles.folderChipActive,
                        ]}
                        onPress={() => setEditedFolderId(null)}
                        disabled={savingEdit}
                      >
                        <Text
                          style={[
                            styles.folderChipText,
                            editedFolderId === null &&
                              styles.folderChipTextActive,
                          ]}
                        >
                          No folder
                        </Text>
                      </TouchableOpacity>
                      {availableFolders.map((folder) => {
                        const isSelected = editedFolderId === folder.id;
                        return (
                          <TouchableOpacity
                            key={folder.id}
                            style={[
                              styles.folderChip,
                              isSelected && styles.folderChipActive,
                              {
                                borderColor: folder.color,
                                backgroundColor: isSelected
                                  ? `${folder.color}22`
                                  : Colors.dark.surface,
                              },
                            ]}
                            onPress={() => setEditedFolderId(folder.id)}
                            disabled={savingEdit}
                          >
                            <AppIcon
                              icon={folder.icon || "folder"}
                              size={14}
                              color={
                                isSelected
                                  ? Colors.dark.tint
                                  : Colors.dark.muted
                              }
                              style={styles.folderChipIcon}
                            />
                            <Text
                              style={[
                                styles.folderChipText,
                                isSelected && styles.folderChipTextActive,
                              ]}
                            >
                              {folder.name}
                            </Text>
                          </TouchableOpacity>
                        );
                      })}
                    </ScrollView>
                  </View>
                )}
              </BottomSheetScrollView>
              <View style={styles.editFooterArea}>
                <TouchableOpacity
                  style={styles.editDeleteButton}
                  onPress={() =>
                    handleDeleteNote(editingNote.id, {
                      afterDelete: () => closeNoteEditor(true),
                    })
                  }
                  disabled={savingEdit}
                >
                  <AppIcon
                    icon="trash"
                    size={16}
                    color={Colors.dark.error}
                    style={styles.editDeleteIcon}
                  />
                  <Text style={styles.editDeleteText}>Delete note</Text>
                </TouchableOpacity>
                <View style={styles.editFooterActions}>
                  <TouchableOpacity
                    style={styles.editCancelButton}
                    onPress={() => closeNoteEditor()}
                    disabled={savingEdit}
                  >
                    <Text style={styles.editCancelText}>Cancel</Text>
                  </TouchableOpacity>
                  <TouchableOpacity
                    style={[
                      styles.editSaveButton,
                      (savingEdit || !editedContent.trim()) &&
                        styles.editSaveButtonDisabled,
                    ]}
                    onPress={handleSaveNoteEdit}
                    disabled={savingEdit || !editedContent.trim()}
                  >
                    {savingEdit ? (
                      <ActivityIndicator
                        size="small"
                        color={Colors.dark.background}
                      />
                    ) : (
                      <Text style={styles.editSaveText}>Save changes</Text>
                    )}
                  </TouchableOpacity>
                </View>
              </View>
            </>
          ) : (
            <View style={styles.editSheetPlaceholder}>
              <ActivityIndicator size="small" color={Colors.dark.tint} />
            </View>
          )}
        </BottomSheetView>
      </BottomSheetModal>
    </GestureHandlerRootView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "transparent",
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
  listContentInset: {
    paddingBottom: 80,
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
  draggingCard: {
    borderColor: Colors.dark.tint,
  },
  sheetBackground: {
    backgroundColor: Colors.dark.surface,
  },
  sheetHandle: {
    backgroundColor: Colors.dark.surface,
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    paddingTop: 12,
    paddingBottom: 4,
  },
  sheetHandleIndicator: {
    backgroundColor: Colors.dark.border,
  },
  editSheetContainer: {
    flex: 1,
    backgroundColor: Colors.dark.surface,
    paddingHorizontal: 20,
    paddingBottom: 24,
  },
  editSheetContent: {
    paddingBottom: 24,
  },
  editTopBar: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    marginBottom: 16,
  },
  editHeroBadge: {
    flexDirection: "row",
    alignItems: "center",
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderRadius: 18,
  },
  editHeroIconWrap: {
    width: 28,
    height: 28,
    borderRadius: 14,
    alignItems: "center",
    justifyContent: "center",
    marginRight: 8,
  },
  editHeroBadgeText: {
    ...Typography.caption,
    color: Colors.dark.text,
    fontWeight: "600",
  },
  editCloseButton: {
    padding: 6,
    marginLeft: 8,
  },
  editTitle: {
    ...Typography.h3,
    color: Colors.dark.text,
    marginBottom: 6,
  },
  editSubtitle: {
    ...Typography.caption,
    color: Colors.dark.muted,
    marginBottom: 18,
  },
  pinToggle: {
    flexDirection: "row",
    alignItems: "center",
    alignSelf: "flex-start",
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 18,
    borderWidth: 1,
    borderColor: Colors.dark.border,
    marginBottom: 20,
  },
  pinToggleActive: {
    backgroundColor: Colors.dark.tint,
    borderColor: Colors.dark.tint,
  },
  pinToggleIcon: {
    marginRight: 8,
  },
  pinToggleText: {
    ...Typography.caption,
    color: Colors.dark.muted,
    fontWeight: "600",
  },
  pinToggleTextActive: {
    color: Colors.dark.background,
  },
  editSection: {
    marginBottom: 20,
  },
  editLabel: {
    ...Typography.caption,
    color: Colors.dark.muted,
    fontWeight: "700",
    textTransform: "uppercase",
    letterSpacing: 0.6,
    marginBottom: 8,
  },
  editContentInput: {
    minHeight: 140,
    borderRadius: 14,
    borderWidth: 1,
    borderColor: Colors.dark.border,
    backgroundColor: Colors.dark.background,
    padding: 14,
    ...Typography.body,
    color: Colors.dark.text,
    textAlignVertical: "top",
  },
  editTagInput: {
    borderRadius: 14,
    borderWidth: 1,
    borderColor: Colors.dark.border,
    backgroundColor: Colors.dark.background,
    paddingHorizontal: 14,
    paddingVertical: 10,
    ...Typography.body,
    color: Colors.dark.text,
  },
  editHelperText: {
    ...Typography.caption,
    color: Colors.dark.muted,
    marginTop: 8,
  },
  editFolderChips: {
    paddingRight: 12,
  },
  folderChip: {
    flexDirection: "row",
    alignItems: "center",
    paddingHorizontal: 12,
    paddingVertical: 8,
    marginRight: 10,
    borderRadius: 18,
    borderWidth: 1,
    borderColor: Colors.dark.border,
    backgroundColor: Colors.dark.surface,
  },
  folderChipActive: {
    borderColor: Colors.dark.tint,
  },
  folderChipIcon: {
    marginRight: 6,
  },
  folderChipText: {
    ...Typography.caption,
    color: Colors.dark.muted,
    fontWeight: "600",
  },
  folderChipTextActive: {
    color: Colors.dark.tint,
  },
  editFooterArea: {
    borderTopWidth: 1,
    borderTopColor: Colors.dark.border,
    paddingTop: 16,
    marginTop: 8,
  },
  editDeleteButton: {
    flexDirection: "row",
    alignItems: "center",
    alignSelf: "flex-start",
    paddingVertical: 8,
  },
  editDeleteIcon: {
    marginRight: 8,
  },
  editDeleteText: {
    ...Typography.caption,
    color: Colors.dark.error,
    fontWeight: "600",
  },
  editFooterActions: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    marginTop: 12,
  },
  editCancelButton: {
    paddingVertical: 12,
    paddingHorizontal: 18,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: Colors.dark.border,
    backgroundColor: Colors.dark.surface,
    marginRight: 12,
  },
  editCancelText: {
    ...Typography.body,
    color: Colors.dark.muted,
    fontWeight: "600",
  },
  editSaveButton: {
    flex: 1,
    paddingVertical: 14,
    borderRadius: 12,
    backgroundColor: Colors.dark.tint,
    alignItems: "center",
    flexDirection: "row",
    justifyContent: "center",
  },
  editSaveButtonDisabled: {
    opacity: 0.5,
  },
  editSaveText: {
    ...Typography.body,
    color: Colors.dark.background,
    fontWeight: "600",
  },
  editSheetPlaceholder: {
    alignItems: "center",
    justifyContent: "center",
    paddingVertical: 32,
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
    marginRight: 8,
  },
  folderBadge: {
    flexDirection: "row",
    alignItems: "center",
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 16,
    marginLeft: 4,
  },
  folderBadgeIcon: {
    marginRight: 6,
  },
  folderBadgeText: {
    ...Typography.caption,
    color: Colors.dark.background,
    fontWeight: "600",
  },
  cardActions: {
    flexDirection: "row",
    alignItems: "center",
  },
  editButton: {
    paddingVertical: 6,
    paddingHorizontal: 12,
    borderRadius: 14,
    backgroundColor: Colors.dark.tint,
    alignItems: "center",
    justifyContent: "center",
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
