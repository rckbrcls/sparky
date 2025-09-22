import type { ComponentProps } from "react";
import { StyleProp, TextStyle } from "react-native";
import MaterialCommunityIcons from "@expo/vector-icons/MaterialCommunityIcons";

import {
  AppIconKey,
  ICON_DEFINITIONS,
  resolveIconKey,
} from "../constants/iconMappings";

export interface AppIconProps
  extends Omit<ComponentProps<typeof MaterialCommunityIcons>, "name"> {
  icon: string | AppIconKey;
  style?: StyleProp<TextStyle>;
}

export function AppIcon({ icon, size, color, style, ...rest }: AppIconProps) {
  const iconKey = resolveIconKey(icon);
  const definition = ICON_DEFINITIONS[iconKey];

  return (
    <MaterialCommunityIcons
      name={definition.name}
      size={size ?? definition.defaultSize ?? 20}
      color={color}
      style={style}
      {...rest}
    />
  );
}
