import React from "react";
import { Text, View } from "react-native";

import { AppIcon } from "@/src/components/AppIcon";
import { Colors } from "@/src/constants/Colors";
import { styles } from "./styles";
import type { TriggerSectionHeaderProps } from "./types";
export type { TriggerSectionHeaderProps } from "./types";

export const TriggerSectionHeader: React.FC<TriggerSectionHeaderProps> = ({
  section,
}) => {
  return (
    <View style={styles.container}>
      <AppIcon
        icon={section.icon}
        size={18}
        color={Colors.dark.text}
        style={styles.icon}
      />
      <Text style={styles.title}>{section.title}</Text>
      <Text style={styles.count}>({section.data.length})</Text>
    </View>
  );
};
