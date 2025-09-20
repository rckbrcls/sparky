import React from "react";
import {
  ActivityIndicator,
  LayoutChangeEvent,
  RefreshControl,
  Text,
  TouchableOpacity,
  View,
} from "react-native";
import DraggableFlatList, {
  DragEndParams,
  RenderItemParams,
} from "react-native-draggable-flatlist";

import { Colors } from "../../constants/Colors";
import { AppIcon } from "../AppIcon";
import { NotesToolbar } from "./NotesToolbar";
import { NotesEmptyState } from "./EmptyState";
import { styles } from "./styles";
import { QuickNoteWithFolder, SettingsAction } from "./types";

interface FolderNotesViewProps {
  folderName: string;
  notesCountLabel: string;
  notes: QuickNoteWithFolder[];
  loading: boolean;
  refreshing: boolean;
  showPinnedOnly: boolean;
  settingsActions: SettingsAction[];
  onBack: () => void;
  onRefresh: () => void;
  renderNoteCard: (
    params: RenderItemParams<QuickNoteWithFolder>
  ) => React.ReactElement;
  onDragEnd: (params: DragEndParams<QuickNoteWithFolder>) => void;
  onDragBegin: (index: number) => void;
  onListLayout: (event: LayoutChangeEvent) => void;
  onContentSizeChange: (width: number, height: number) => void;
  onScrollOffsetChange: (offset: number) => void;
  isInitialized: boolean;
}

export const FolderNotesView: React.FC<FolderNotesViewProps> = ({
  folderName,
  notesCountLabel,
  notes,
  loading,
  refreshing,
  showPinnedOnly,
  settingsActions,
  onBack,
  onRefresh,
  renderNoteCard,
  onDragEnd,
  onDragBegin,
  onListLayout,
  onContentSizeChange,
  onScrollOffsetChange,
  isInitialized,
}) => {
  return (
    <View style={styles.notesStageContainer}>
      <View style={styles.notesBackWrapper}>
        <TouchableOpacity
          style={styles.notesBackButton}
          onPress={onBack}
          activeOpacity={0.85}
        >
          <AppIcon
            icon="chevronLeft"
            size={18}
            color={Colors.dark.tint}
            style={styles.notesBackIcon}
          />
          <Text style={styles.notesBackText}>Folders</Text>
        </TouchableOpacity>
      </View>

      {settingsActions.length ? <NotesToolbar actions={settingsActions} /> : null}

      <View style={styles.notesListWrapper}>
        <View style={styles.notesHeader}>
          <Text style={styles.notesHeaderTitle}>{folderName}</Text>
          <View style={styles.notesHeaderMeta}>
            {loading || refreshing ? (
              <ActivityIndicator
                size="small"
                color={Colors.dark.tint}
                style={styles.notesHeaderSpinner}
              />
            ) : null}
            <Text style={styles.notesHeaderCount}>{notesCountLabel}</Text>
          </View>
        </View>

        <DraggableFlatList
          style={styles.notesList}
          data={notes}
          renderItem={renderNoteCard}
          keyExtractor={(item) => item.id}
          onDragEnd={onDragEnd}
          onDragBegin={onDragBegin}
          activationDistance={8}
          ListEmptyComponent={
            isInitialized && !loading ? (
              <NotesEmptyState showPinnedOnly={showPinnedOnly} />
            ) : null
          }
          refreshControl={
            <RefreshControl
              refreshing={refreshing}
              onRefresh={onRefresh}
              tintColor={Colors.dark.tint}
            />
          }
          contentContainerStyle={[
            styles.listContainer,
            styles.listContentInset,
            { flexGrow: notes.length ? 0 : 1 },
          ]}
          showsVerticalScrollIndicator={false}
          onLayout={onListLayout}
          onContentSizeChange={onContentSizeChange}
          onScrollOffsetChange={onScrollOffsetChange}
          keyboardShouldPersistTaps="handled"
          bounces={false}
          alwaysBounceVertical={false}
          overScrollMode="never"
        />
      </View>
    </View>
  );
};
