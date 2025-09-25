import React from "react";
import { ScrollView, Text, TouchableOpacity, View } from "react-native";
import type { CommandDefinition } from "@/src/features/terminal/engine";
import { styles } from "./styles";

interface MetaSectionProps {
  inArgMode: boolean;
  argSuggestions?: string[] | null;
  activeCommand?: CommandDefinition | null;
  commandMatches?: CommandDefinition[] | null;
  openCommandQuery?: string | null;
  onSelectArgSuggestion: (suggestion: string) => void;
  onSelectCommand: (command: CommandDefinition) => void;
}

export const MetaSection: React.FC<MetaSectionProps> = ({
  inArgMode,
  argSuggestions,
  activeCommand,
  commandMatches,
  openCommandQuery,
  onSelectArgSuggestion,
  onSelectCommand,
}) => {
  const renderArgSuggestions = () => {
    if (!inArgMode || !activeCommand) return null;

    const suggestions = argSuggestions ?? [];

    return (
      <View style={styles.commandPalette}>
        <ScrollView
          style={styles.commandScroll}
          contentContainerStyle={styles.commandScrollContent}
          keyboardShouldPersistTaps="handled"
          nestedScrollEnabled
        >
          {suggestions.length > 0 ? (
            suggestions.map((suggestion, idx) => (
              <TouchableOpacity
                key={suggestion}
                style={[
                  styles.commandItem,
                  idx === suggestions.length - 1 && { borderBottomWidth: 0 },
                ]}
                onPress={() => onSelectArgSuggestion(suggestion)}
              >
                <Text style={styles.commandName}>{suggestion}</Text>
                <Text style={styles.commandDesc}>{activeCommand.name}</Text>
              </TouchableOpacity>
            ))
          ) : (
            <View style={styles.commandItem}>
              <Text style={styles.commandDesc}>Sem sugestões</Text>
            </View>
          )}
        </ScrollView>
      </View>
    );
  };

  const renderCommandMatches = () => {
    if (
      inArgMode ||
      openCommandQuery == null ||
      (commandMatches?.length || 0) === 0
    ) {
      return null;
    }

    const matches = commandMatches ?? [];

    return (
      <View style={styles.commandPalette}>
        <ScrollView
          style={styles.commandScroll}
          contentContainerStyle={styles.commandScrollContent}
          keyboardShouldPersistTaps="handled"
          nestedScrollEnabled
        >
          {matches.map((match, idx) => (
            <TouchableOpacity
              key={match.name}
              style={[
                styles.commandItem,
                idx === matches.length - 1 && { borderBottomWidth: 0 },
              ]}
              onPress={() => onSelectCommand(match)}
            >
              <Text style={styles.commandName}>{match.name}</Text>
              <Text style={styles.commandDesc}>{match.description}</Text>
            </TouchableOpacity>
          ))}
        </ScrollView>
      </View>
    );
  };

  const argSuggestionsContent = renderArgSuggestions();
  const commandMatchesContent = renderCommandMatches();
  const hasMetaContent = Boolean(argSuggestionsContent || commandMatchesContent);

  const containerStyles = [styles.container, !hasMetaContent && styles.hidden];

  return (
    <View style={containerStyles} pointerEvents="box-none">
      {argSuggestionsContent}
      {commandMatchesContent}
    </View>
  );
};
