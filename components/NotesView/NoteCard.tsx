import React, { memo, useCallback, useMemo } from "react";
import { Text, TouchableOpacity, View } from "react-native";
import { ScaleDecorator, ShadowDecorator } from "react-native-draggable-flatlist";

import { Colors } from "../../constants/Colors";
import { AppIcon } from "../AppIcon";
import { styles } from "./styles";
import { QuickNoteWithFolder } from "./types";
import { formatTags } from "./utils";

export interface NoteCardProps {
  item: QuickNoteWithFolder;
  drag: () => void;
  isActive: boolean;
  onOpen: (note: QuickNoteWithFolder) => void;
  onDragHandleActivate: (noteId: string) => void;
  onDragHandleRelease: (noteId: string) => void;
  isReorderMode: boolean;
  activeDragId: string | null;
}

const NoteCardComponent: React.FC<NoteCardProps> = ({
  item,
  drag,
  isActive,
  onOpen,
  onDragHandleActivate,
  onDragHandleRelease,
  isReorderMode,
  activeDragId,
}) => {
  const pinned = !!item.isPinned;
  const formattedTags = useMemo(() => formatTags(item.tags), [item.tags]);
  const isActiveDragTarget = activeDragId === item.id;

  const cardScale = useMemo(() => {
    if (!isReorderMode) return 1;
    if (isActive) return 1.05;
    return isActiveDragTarget ? 1.03 : 0.97;
  }, [isActive, isActiveDragTarget, isReorderMode]);

  const cardOpacity = useMemo(() => {
    if (!isReorderMode) return 1;
    return isActiveDragTarget ? 1 : 0.82;
  }, [isActiveDragTarget, isReorderMode]);

  const handleCardPress = useCallback(() => {
    if (isActive) return;
    onOpen(item);
  }, [isActive, item, onOpen]);

  const handleDragHandlePressIn = useCallback(() => {
    if (isActive || !isReorderMode) return;
    onDragHandleActivate(item.id);
    drag();
  }, [drag, isActive, isReorderMode, item.id, onDragHandleActivate]);

  const handleDragHandlePressOut = useCallback(() => {
    if (!isReorderMode) return;
    onDragHandleRelease(item.id);
  }, [isReorderMode, item.id, onDragHandleRelease]);

  return (
    <ScaleDecorator activeScale={0.97}>
      <ShadowDecorator color={Colors.dark.tint} opacity={0.3}>
        <TouchableOpacity
          activeOpacity={0.95}
          onPress={handleCardPress}
          disabled={isActive}
          style={[
            styles.card,
            pinned && styles.pinnedCard,
            isActive && styles.draggingCard,
            isActiveDragTarget && styles.reorderActiveCard,
            {
              transform: [{ scale: cardScale }],
              opacity: cardOpacity,
            },
          ]}
        >
          <View style={styles.cardContentRow}>
            <TouchableOpacity
              style={[
                styles.dragHandle,
                (isActiveDragTarget || isReorderMode) && styles.dragHandleActive,
                !isReorderMode && styles.dragHandleDisabled,
              ]}
              onPressIn={handleDragHandlePressIn}
              onPressOut={handleDragHandlePressOut}
              disabled={isActive || !isReorderMode}
              hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}
            >
              <AppIcon
                icon="drag"
                size={18}
                color={
                  isActiveDragTarget || isReorderMode
                    ? Colors.dark.tint
                    : Colors.dark.muted
                }
              />
            </TouchableOpacity>
            <View style={styles.cardMain}>
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
                <TouchableOpacity
                  style={styles.editButton}
                  onPress={() => onOpen(item)}
                  disabled={isActive}
                >
                  <AppIcon icon="eye" size={18} color={Colors.dark.background} />
                </TouchableOpacity>
              </View>

              <Text style={styles.noteContent}>{item.content}</Text>

              <View style={styles.cardFooter}>
                <Text style={styles.noteDate}>
                  {new Date(item.updatedAt).toLocaleDateString()}
                </Text>
                {formattedTags ? (
                  <Text style={styles.noteTags}>{formattedTags}</Text>
                ) : null}
              </View>
            </View>
          </View>
        </TouchableOpacity>
      </ShadowDecorator>
    </ScaleDecorator>
  );
};

NoteCardComponent.displayName = "NoteCard";

export const NoteCard = memo(NoteCardComponent);
