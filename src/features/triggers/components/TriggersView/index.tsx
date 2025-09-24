import React, { useCallback, useEffect, useMemo, useState } from "react";
import {
  RefreshControl,
  SectionList,
  SectionListProps,
  View,
} from "react-native";
import Animated from "react-native-reanimated";

import { Colors } from "@/src/constants/Colors";
import { database } from "@/src/database";
import { TriggerCard } from "../TriggerCard";
import { TriggerSectionHeader } from "../TriggerSectionHeader";
import { TriggersEmptyState } from "../TriggersEmptyState";
import { buildTriggerSections } from "../../utils/sections";
import { styles } from "./styles";
import type {
  TriggerListItem,
  TriggerSection,
  TriggersViewProps,
} from "./types";
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
  const [sections, setSections] = useState<TriggerSection[]>([]);
  const [loading, setLoading] = useState(false);

  const loadTriggers = useCallback(async () => {
    setLoading(true);
    try {
      const triggers = (await database.getActiveTriggers()) as
        | TriggerListItem[]
        | undefined;
      setSections(buildTriggerSections(triggers ?? []));
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

  const contentContainerStyle = useMemo(() => {
    const hasData = sections.some((section) => section.data.length > 0);
    return [styles.listContainer, { flexGrow: hasData ? 0 : 1 }];
  }, [sections]);

  return (
    <View style={styles.container}>
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
  );
};
