import React, { useEffect, useMemo, useRef, useState } from "react";
import {
  Alert,
  ActivityIndicator,
  FlatList,
  KeyboardAvoidingView,
  NativeScrollEvent,
  NativeSyntheticEvent,
  Platform,
  RefreshControl,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  TouchableWithoutFeedback,
  View,
  Modal,
} from "react-native";
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
  onScroll?: (event: NativeSyntheticEvent<NativeScrollEvent>) => void;
}

export const NotesView: React.FC<NotesViewProps> = ({
  onRefresh,
  onScroll,
}) => {
  // background follows current theme to avoid black overlay artifacts
  const { isInitialized, error: initError, initializeApp } = useApp();
  const [notes, setNotes] = useState<QuickNoteWithFolder[]>([]);
  const [loading, setLoading] = useState(false);
  const [selectedFolder, setSelectedFolder] = useState<string>("all");
  const [folders, setFolders] = useState<Folder[]>([]);
  const [foldersLoaded, setFoldersLoaded] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const [editingNote, setEditingNote] = useState<QuickNoteWithFolder | null>(null);
  const [editedContent, setEditedContent] = useState("");
  const [editedTags, setEditedTags] = useState("");
  const [editedFolderId, setEditedFolderId] = useState<string | null>(null);
  const [editedPinned, setEditedPinned] = useState(false);
  const [savingEdit, setSavingEdit] = useState(false);
  const [folderPickerNote, setFolderPickerNote] =
    useState<QuickNoteWithFolder | null>(null);
  const [folderPickerSelection, setFolderPickerSelection] =
    useState<string | null>(null);
  const [savingFolderChange, setSavingFolderChange] = useState(false);
  const initialLoad = useRef(true);

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

  const handleTogglePin = async (note: QuickNoteWithFolder) => {
    const nextPinned = !note.isPinned;
    const updatedAt = new Date().toISOString();
    const orderStamp = Date.now();

    setNotes((prevNotes) => {
      const updatedNotes = prevNotes.map((item) =>
        item.id === note.id
          ? {
              ...item,
              isPinned: nextPinned,
              updatedAt,
              sortOrder: orderStamp,
            }
          : item
      );
      return sortNotes(updatedNotes);
    });

    try {
      await database.updateQuickNote(note.id, {
        isPinned: nextPinned,
        sortOrder: orderStamp,
      });
    } catch (error) {
      console.error("Error toggling pin:", error);
      setNotes((prevNotes) => {
        const revertedNotes = prevNotes.map((item) =>
          item.id === note.id
            ? {
                ...item,
                isPinned: note.isPinned,
                updatedAt: note.updatedAt,
                sortOrder: note.sortOrder,
              }
            : item
        );
        return sortNotes(revertedNotes);
      });
    }
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

  const openNoteEditor = (note: QuickNoteWithFolder) => {
    setEditingNote(note);
    setEditedContent(note.content);
    setEditedTags(formatTags(note.tags));
    setEditedFolderId(note.folderId ?? null);
    setEditedPinned(!!note.isPinned);
  };

  const closeNoteEditor = (force = false) => {
    if (savingEdit && !force) return;
    setEditingNote(null);
    setEditedContent("");
    setEditedTags("");
    setEditedFolderId(null);
    setEditedPinned(false);
  };

  const closeFolderPicker = (force = false) => {
    if (savingFolderChange && !force) return;
    setFolderPickerNote(null);
    setFolderPickerSelection(null);
  };

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

  const handleConfirmFolderChange = async () => {
    if (!folderPickerNote || savingFolderChange) return;

    const nextFolderId = folderPickerSelection;
    const previousFolderId = folderPickerNote.folderId ?? null;

    if ((nextFolderId ?? null) === previousFolderId) {
      closeFolderPicker(true);
      return;
    }

    try {
      setSavingFolderChange(true);
      await database.updateQuickNote(folderPickerNote.id, {
        folderId: nextFolderId ?? null,
      });

      const nextFolder =
        typeof nextFolderId === "string"
          ? folders.find((folder) => folder.id === nextFolderId)
          : undefined;

      setNotes((prevNotes) => {
        const noteExists = prevNotes.some(
          (note) => note.id === folderPickerNote.id
        );
        if (!noteExists) return prevNotes;

        if (
          selectedFolder !== "all" &&
          (nextFolderId ?? null) !== selectedFolder &&
          previousFolderId === selectedFolder
        ) {
          return prevNotes.filter((note) => note.id !== folderPickerNote.id);
        }

        const updatedNotes = prevNotes.map((note) =>
          note.id === folderPickerNote.id
            ? {
                ...note,
                folderId:
                  typeof nextFolderId === "string" ? nextFolderId : undefined,
                folder: nextFolder,
              }
            : note
        );

        return sortNotes(updatedNotes);
      });

      if (
        selectedFolder !== "all" &&
        (nextFolderId ?? null) === selectedFolder &&
        previousFolderId !== selectedFolder
      ) {
        loadNotes({ showLoading: false });
      }

      closeFolderPicker(true);
    } catch (error) {
      console.error("Error updating note folder:", error);
      Alert.alert("Error", "Failed to move note to folder");
    } finally {
      setSavingFolderChange(false);
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
                    <Text style={styles.folderBadgeText}>{item.folder.name}</Text>
                  </View>
                )}
              </View>
              <View style={styles.cardActions}>
                <TouchableOpacity
                  style={styles.actionButton}
                  onPress={() => openNoteEditor(item)}
                >
                  <AppIcon
                    icon="document"
                    size={18}
                    color={Colors.dark.text}
                    style={styles.actionIcon}
                  />
                </TouchableOpacity>
                <TouchableOpacity
                  style={styles.actionButton}
                  onPress={() => {
                    setFolderPickerNote(item);
                    setFolderPickerSelection(item.folderId ?? null);
                  }}
                >
                  <AppIcon
                    icon={item.folder?.icon || "folder"}
                    size={18}
                    color={Colors.dark.text}
                    style={styles.actionIcon}
                  />
                </TouchableOpacity>
                <TouchableOpacity
                  style={styles.actionButton}
                  onPress={() => handleTogglePin(item)}
                >
                  <AppIcon
                    icon={pinned ? "pin" : "location"}
                    size={18}
                    color={Colors.dark.text}
                    style={styles.actionIcon}
                  />
                </TouchableOpacity>
                <TouchableOpacity
                  style={styles.actionButton}
                  onPress={() => handleDeleteNote(item.id)}
                >
                  <AppIcon
                    icon="trash"
                    size={18}
                    color={Colors.dark.error}
                    style={styles.actionIcon}
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
  const selectedFolderMeta =
    typeof folderPickerSelection === "string"
      ? folders.find((folder) => folder.id === folderPickerSelection)
      : undefined;
  const folderPickerAccentColor =
    selectedFolderMeta?.color ?? folderPickerNote?.folder?.color ?? Colors.dark.tint;
  const folderPickerHeroIcon =
    selectedFolderMeta?.icon || folderPickerNote?.folder?.icon || "folder";
  const folderPickerHasChanged =
    (folderPickerSelection ?? null) !== (folderPickerNote?.folderId ?? null);

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
        onScroll={onScroll as unknown as (e: any) => void}
        scrollEventThrottle={onScroll ? 16 : undefined}
        keyboardShouldPersistTaps="handled"
        bounces={false}
        alwaysBounceVertical={false}
        overScrollMode="never"
      />
      </View>
      <Modal
        visible={!!editingNote}
        transparent
        animationType="fade"
        onRequestClose={() => {
          if (!savingEdit) closeNoteEditor();
        }}
      >
        <View style={styles.editModalRoot}>
          <TouchableWithoutFeedback
            onPress={() => {
              if (!savingEdit) closeNoteEditor();
            }}
          >
            <View style={styles.editBackdrop} />
          </TouchableWithoutFeedback>
          <KeyboardAvoidingView
            behavior={Platform.OS === "ios" ? "padding" : undefined}
            style={styles.editModalContainer}
          >
            <View style={styles.editModalCard}>
              {editingNote && (
                <>
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
                      onPress={() => {
                        if (!savingEdit) closeNoteEditor();
                      }}
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
                  <ScrollView
                    style={styles.editForm}
                    contentContainerStyle={styles.editFormContent}
                    keyboardShouldPersistTaps="handled"
                    showsVerticalScrollIndicator={false}
                  >
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
                                      ? Colors.dark.background
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
                  </ScrollView>
                  <View style={styles.editFooter}>
                    <TouchableOpacity
                      style={styles.editCancelButton}
                      onPress={() => {
                        if (!savingEdit) closeNoteEditor();
                      }}
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
                </>
              )}
            </View>
          </KeyboardAvoidingView>
        </View>
      </Modal>
      <Modal
        visible={!!folderPickerNote}
        transparent
        animationType="fade"
        onRequestClose={() => {
          if (!savingFolderChange) closeFolderPicker();
        }}
      >
        <View style={styles.folderModalRoot}>
          <TouchableWithoutFeedback
            onPress={() => {
              if (!savingFolderChange) closeFolderPicker();
            }}
          >
            <View style={styles.editBackdrop} />
          </TouchableWithoutFeedback>
          <View style={styles.folderModalCard}>
            {folderPickerNote && (
              <>
                <View style={styles.folderModalHeader}>
                  <View
                    style={[
                      styles.folderHeroBadge,
                      { backgroundColor: `${folderPickerAccentColor}33` },
                    ]}
                  >
                    <View
                      style={[
                        styles.folderHeroIconWrap,
                        { backgroundColor: folderPickerAccentColor },
                      ]}
                    >
                      <AppIcon
                        icon={folderPickerHeroIcon}
                        size={16}
                        color={Colors.dark.background}
                      />
                    </View>
                    <Text style={styles.folderHeroText}>Move note</Text>
                  </View>
                  <TouchableOpacity
                    style={styles.editCloseButton}
                    onPress={() => {
                      if (!savingFolderChange) closeFolderPicker();
                    }}
                    disabled={savingFolderChange}
                  >
                    <AppIcon icon="close" size={20} color={Colors.dark.muted} />
                  </TouchableOpacity>
                </View>
                <Text style={styles.folderModalTitle}>Choose a new home</Text>
                <Text style={styles.folderModalSubtitle}>
                  Keep your thoughts grouped just right
                </Text>
                <ScrollView
                  style={styles.folderOptions}
                  contentContainerStyle={styles.folderOptionsContent}
                  showsVerticalScrollIndicator={false}
                >
                  <TouchableOpacity
                    style={[
                      styles.folderOption,
                      folderPickerSelection === null &&
                        styles.folderOptionActive,
                    ]}
                    onPress={() => setFolderPickerSelection(null)}
                    disabled={savingFolderChange}
                  >
                    <View style={styles.folderOptionIconWrap}>
                      <AppIcon
                        icon="document"
                        size={18}
                        color={Colors.dark.text}
                      />
                    </View>
                    <View style={styles.folderOptionCopy}>
                      <Text style={styles.folderOptionTitle}>No folder</Text>
                      <Text style={styles.folderOptionSubtitle}>
                        Keep it floating without a category
                      </Text>
                    </View>
                    {folderPickerSelection === null && (
                      <AppIcon
                        icon="check"
                        size={18}
                        color={Colors.dark.tint}
                      />
                    )}
                  </TouchableOpacity>
                  {availableFolders.map((folder) => {
                    const isActive = folderPickerSelection === folder.id;
                    return (
                      <TouchableOpacity
                        key={folder.id}
                        style={[
                          styles.folderOption,
                          isActive && styles.folderOptionActive,
                          {
                            borderColor: isActive
                              ? folder.color
                              : Colors.dark.border,
                          },
                        ]}
                        onPress={() => setFolderPickerSelection(folder.id)}
                        disabled={savingFolderChange}
                      >
                        <View
                          style={[
                            styles.folderOptionIconWrap,
                            { backgroundColor: `${folder.color}22` },
                          ]}
                        >
                          <AppIcon
                            icon={folder.icon || "folder"}
                            size={18}
                            color={folder.color}
                          />
                        </View>
                        <View style={styles.folderOptionCopy}>
                          <Text style={styles.folderOptionTitle}>
                            {folder.name}
                          </Text>
                      <Text style={styles.folderOptionSubtitle}>
                        Organize alongside similar notes
                      </Text>
                        </View>
                        {isActive && (
                          <AppIcon
                            icon="check"
                            size={18}
                            color={folder.color}
                          />
                        )}
                      </TouchableOpacity>
                    );
                  })}
                </ScrollView>
                <View style={styles.folderActions}>
                  <TouchableOpacity
                    style={styles.editCancelButton}
                    onPress={() => {
                      if (!savingFolderChange) closeFolderPicker();
                    }}
                    disabled={savingFolderChange}
                  >
                    <Text style={styles.editCancelText}>Cancel</Text>
                  </TouchableOpacity>
                  <TouchableOpacity
                    style={[
                      styles.folderConfirmButton,
                      (!folderPickerHasChanged || savingFolderChange) &&
                        styles.editSaveButtonDisabled,
                    ]}
                    onPress={handleConfirmFolderChange}
                    disabled={!folderPickerHasChanged || savingFolderChange}
                  >
                    {savingFolderChange ? (
                      <ActivityIndicator
                        size="small"
                        color={Colors.dark.background}
                      />
                    ) : (
                      <Text style={styles.editSaveText}>Move note</Text>
                    )}
                  </TouchableOpacity>
                </View>
              </>
            )}
          </View>
        </View>
      </Modal>
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
  editModalRoot: {
    flex: 1,
    justifyContent: "center",
    padding: 20,
  },
  editBackdrop: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: "rgba(0, 0, 0, 0.45)",
  },
  editModalContainer: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
  },
  editModalCard: {
    backgroundColor: Colors.dark.surface,
    borderRadius: 20,
    padding: 20,
    borderWidth: 1,
    borderColor: Colors.dark.border,
    width: "100%",
    maxWidth: 520,
    shadowColor: "#000",
    shadowOpacity: 0.25,
    shadowRadius: 18,
    shadowOffset: { width: 0, height: 16 },
    elevation: 14,
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
  editForm: {
    maxHeight: 360,
    marginBottom: 16,
  },
  editFormContent: {
    paddingBottom: 12,
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
    color: Colors.dark.background,
  },
  editFooter: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
  },
  editCancelButton: {
    flex: 1,
    marginRight: 12,
    paddingVertical: 14,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: Colors.dark.border,
    alignItems: "center",
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
  },
  editSaveButtonDisabled: {
    backgroundColor: `${Colors.dark.tint}55`,
  },
  editSaveText: {
    ...Typography.body,
    color: Colors.dark.background,
    fontWeight: "700",
  },
  folderModalRoot: {
    flex: 1,
    justifyContent: "center",
    padding: 24,
    alignItems: "center",
  },
  folderModalCard: {
    backgroundColor: Colors.dark.surface,
    borderRadius: 20,
    padding: 24,
    borderWidth: 1,
    borderColor: Colors.dark.border,
    shadowColor: "#000",
    shadowOpacity: 0.2,
    shadowRadius: 16,
    shadowOffset: { width: 0, height: 12 },
    elevation: 10,
    width: "100%",
    maxWidth: 420,
  },
  folderModalHeader: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    marginBottom: 16,
  },
  folderHeroBadge: {
    flexDirection: "row",
    alignItems: "center",
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 20,
  },
  folderHeroIconWrap: {
    width: 28,
    height: 28,
    borderRadius: 14,
    alignItems: "center",
    justifyContent: "center",
    marginRight: 8,
  },
  folderHeroText: {
    ...Typography.caption,
    color: Colors.dark.text,
    fontWeight: "600",
  },
  folderModalTitle: {
    ...Typography.h3,
    color: Colors.dark.text,
    marginBottom: 4,
  },
  folderModalSubtitle: {
    ...Typography.caption,
    color: Colors.dark.muted,
    marginBottom: 20,
  },
  folderOptions: {
    maxHeight: 320,
    marginBottom: 16,
  },
  folderOptionsContent: {
    paddingBottom: 12,
  },
  folderOption: {
    flexDirection: "row",
    alignItems: "center",
    padding: 14,
    marginBottom: 12,
    borderRadius: 16,
    borderWidth: 1,
    borderColor: Colors.dark.border,
    backgroundColor: Colors.dark.background,
  },
  folderOptionActive: {
    borderColor: Colors.dark.tint,
    backgroundColor: `${Colors.dark.tint}20`,
  },
  folderOptionIconWrap: {
    width: 44,
    height: 44,
    borderRadius: 22,
    alignItems: "center",
    justifyContent: "center",
    marginRight: 12,
    backgroundColor: `${Colors.dark.tint}15`,
  },
  folderOptionCopy: {
    flex: 1,
  },
  folderOptionTitle: {
    ...Typography.body,
    color: Colors.dark.text,
    fontWeight: "600",
  },
  folderOptionSubtitle: {
    ...Typography.caption,
    color: Colors.dark.muted,
    marginTop: 2,
  },
  folderActions: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
  },
  folderConfirmButton: {
    flex: 1,
    paddingVertical: 14,
    borderRadius: 12,
    backgroundColor: Colors.dark.tint,
    alignItems: "center",
    marginLeft: 12,
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
  },
  actionButton: {
    padding: 8,
    marginLeft: 8,
  },
  actionIcon: {
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
