import React from "react";
import { ScrollView, Text, TouchableOpacity, View } from "react-native";
import { AppIcon } from "@/src/components/AppIcon";
import { Colors } from "@/src/constants/Colors";
import type { ActivatedCommand } from "@/src/features/terminal/engine/intent";
import { StyleSheet } from "react-native";

interface CommandChipsProps {
  commands: ActivatedCommand[];
  onRemove: (id: string) => void;
}

export const CommandChips: React.FC<CommandChipsProps> = ({ commands, onRemove }) => {
  if (!commands.length) return null;
  return (
    <View style={styles.container}>
      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={styles.content}
        keyboardShouldPersistTaps="handled"
      >
        {commands.map((cmd) => (
          <View key={cmd.id} style={styles.chip}>
            <Text style={styles.chipLabel}>{`/${cmd.name}`}</Text>
            {cmd.value ? <Text style={styles.chipValue}>{cmd.value}</Text> : null}
            <TouchableOpacity style={styles.chipClose} onPress={() => onRemove(cmd.id)}>
              <AppIcon icon="close" size={12} color={Colors.dark.background} />
            </TouchableOpacity>
          </View>
        ))}
      </ScrollView>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    width: "100%",
    paddingTop: 6,
  },
  content: {
    paddingHorizontal: 8,
    gap: 8,
  },
  chip: {
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: "rgba(255,255,255,0.12)",
    borderColor: Colors.dark.tint,
    borderWidth: StyleSheet.hairlineWidth,
    borderRadius: 12,
    paddingHorizontal: 8,
    paddingVertical: 4,
  },
  chipLabel: {
    color: Colors.dark.tint,
    fontWeight: "600",
    marginRight: 4,
  },
  chipValue: {
    color: Colors.dark.text,
    marginRight: 6,
  },
  chipClose: {
    marginLeft: 2,
    width: 16,
    height: 16,
    borderRadius: 8,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: Colors.dark.tint,
  },
});

export default CommandChips;
