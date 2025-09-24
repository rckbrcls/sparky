import type { StyleProp, ViewStyle } from "react-native";

export interface SettingsAction {
  key: string;
  label: string;
  icon: string;
  onPress: () => void;
  active?: boolean;
  disabled?: boolean;
}

export interface NotesToolbarProps {
  actions: SettingsAction[];
  style?: StyleProp<ViewStyle>;
}
