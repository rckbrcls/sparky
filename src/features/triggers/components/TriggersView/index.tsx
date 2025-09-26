import React, { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  RefreshControl,
  SectionList,
  SectionListProps,
  Text,
  TouchableOpacity,
  View,
  Animated as RNAnimated,
  Easing,
} from "react-native";
import Animated from "react-native-reanimated";

import { Colors } from "@/src/constants/Colors";
import { database } from "@/src/database";
import { AppIcon } from "@/src/components/AppIcon";
import { TriggerCard } from "../TriggerCard";
import { TriggerSectionHeader } from "../TriggerSectionHeader";
import { TriggersEmptyState } from "../TriggersEmptyState";
import { buildTriggerSections } from "../../utils/sections";
import { buildTriggerTypeList } from "../../utils/typeList";
import { TriggerTypeListView } from "../TriggerTypeListView";
import { styles } from "./styles";
import type {
  TriggerListItem,
  TriggerSection,
  TriggersViewProps,
} from "./types";
import type { TriggerTypeId } from "../TriggerTypeListView";
export type {
  TriggerListItem,
  TriggerSection,
  TriggersViewProps,
} from "./types";

const AnimatedSectionList =
  Animated.createAnimatedComponent<
    SectionListProps<TriggerListItem, TriggerSection>
  >(SectionList);

export const TriggersView: React.FC<TriggersViewProps> = ({
  onRefresh,
  onScroll,
}) => {
  const [triggers, setTriggers] = useState<TriggerListItem[]>([]);
  const [selectedTypeId, setSelectedTypeId] = useState<TriggerTypeId | null>(
    null
  );
  const [loading, setLoading] = useState(false);
  const stageTransition = useRef(new RNAnimated.Value(0)).current;

  const loadTriggers = useCallback(async () => {
    setLoading(true);
    try {
      const triggers = (await database.getActiveTriggers()) as
        | TriggerListItem[]
        | undefined;
      setTriggers(triggers ?? []);
    } catch (error) {
      console.error("Error loading triggers:", error);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadTriggers();
  }, [loadTriggers]);

  const handleRefresh = () => {
    void loadTriggers();
    onRefresh?.();
  };

  const emptyComponent = useMemo(() => {
    if (loading) return null;
    return <TriggersEmptyState />;
  }, [loading]);

  const { items: triggerTypeItems, counts: triggerTypeCounts } = useMemo(
    () => buildTriggerTypeList(triggers),
    [triggers]
  );

  const filteredTriggers = useMemo(() => {
    if (!selectedTypeId || selectedTypeId === "all") return triggers;
    return triggers.filter((t) => t.type === selectedTypeId);
  }, [selectedTypeId, triggers]);

  const sections = useMemo(
    () => buildTriggerSections(filteredTriggers),
    [filteredTriggers]
  );

  const contentContainerStyle = useMemo(() => {
    const hasData = sections.some((section) => section.data.length > 0);
    return [styles.listContainer, { flexGrow: hasData ? 0 : 1 }];
  }, [sections]);

  const triggersCountLabel = useMemo(() => {
    const count = filteredTriggers.length;
    return `${count} ${count === 1 ? "trigger" : "triggers"}`;
  }, [filteredTriggers.length]);

  useEffect(() => {
    const toValue = selectedTypeId ? 1 : 0;
    RNAnimated.timing(stageTransition, {
      toValue,
      duration: 260,
      easing: Easing.out(Easing.quad),
      useNativeDriver: true,
    }).start();
  }, [selectedTypeId, stageTransition]);

  const typeStageStyle = useMemo(
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

  const listStageStyle = useMemo(
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

  return (
    <View style={styles.container}>
      <View style={styles.stageArea}>
        <RNAnimated.View
          style={[styles.stagePlane, typeStageStyle]}
          pointerEvents={!selectedTypeId ? "auto" : "none"}
        >
          <View style={styles.stageContainer}>
            <TriggerTypeListView
              triggerTypes={triggerTypeItems}
              selectedTypeId={selectedTypeId}
              onSelect={(id) =>
                setSelectedTypeId((prev) => (prev === id ? null : id))
              }
              triggerTypeCounts={triggerTypeCounts}
              loading={loading}
              refreshing={false}
            />
          </View>
        </RNAnimated.View>

        <RNAnimated.View
          style={[styles.stagePlane, listStageStyle]}
          pointerEvents={selectedTypeId ? "auto" : "none"}
        >
          <View style={styles.stageContainer}>
            <View style={styles.headerRow}>
              <TouchableOpacity
                style={styles.backButton}
                onPress={() => setSelectedTypeId(null)}
                activeOpacity={0.88}
              >
                <AppIcon
                  icon="chevronLeft"
                  size={18}
                  color={Colors.dark.tint}
                  style={styles.backIcon}
                />
                <Text style={styles.backText}>back</Text>
              </TouchableOpacity>
              <Text style={styles.headerCount}>{triggersCountLabel}</Text>
            </View>
            <AnimatedSectionList
              sections={sections}
              renderItem={({ item }) => <TriggerCard trigger={item} />}
              renderSectionHeader={({ section }) => (
                <TriggerSectionHeader section={section} />
              )}
              keyExtractor={(item) => item.id}
              ListEmptyComponent={emptyComponent}
              refreshControl={
                <RefreshControl
                  refreshing={loading}
                  onRefresh={handleRefresh}
                  tintColor={Colors.dark.tint}
                />
              }
              contentContainerStyle={contentContainerStyle}
              showsVerticalScrollIndicator={false}
              stickySectionHeadersEnabled={false}
              onScroll={onScroll}
              scrollEventThrottle={onScroll ? 16 : undefined}
              keyboardShouldPersistTaps="handled"
              bounces={false}
              alwaysBounceVertical={false}
              overScrollMode="never"
            />
          </View>
        </RNAnimated.View>
      </View>
    </View>
  );
};
