import { ComponentProps } from "react";
import MaterialCommunityIcons from "@expo/vector-icons/MaterialCommunityIcons";

export type AppIconKey =
  | "calendar"
  | "trigger"
  | "notes"
  | "clock"
  | "folder"
  | "briefcase"
  | "home"
  | "hospital"
  | "target"
  | "books"
  | "palette"
  | "idea"
  | "tools"
  | "chart"
  | "music"
  | "star"
  | "lightning"
  | "rocket"
  | "earth"
  | "fire"
  | "person"
  | "location"
  | "clipboard"
  | "pin"
  | "building"
  | "trash"
  | "tag"
  | "hourglass"
  | "check"
  | "close"
  | "plus"
  | "document"
  | "edit"
  | "eye"
  | "drag";

type MaterialCommunityIconName = ComponentProps<
  typeof MaterialCommunityIcons
>["name"];

interface IconDefinition {
  name: MaterialCommunityIconName;
  defaultSize?: number;
}

export const ICON_DEFINITIONS: Record<AppIconKey, IconDefinition> = {
  calendar: { name: "calendar-month-outline" },
  trigger: { name: "flash-outline" },
  notes: { name: "note-text-outline" },
  clock: { name: "clock-outline" },
  folder: { name: "folder-outline" },
  briefcase: { name: "briefcase-outline" },
  home: { name: "home-outline" },
  hospital: { name: "hospital-building" },
  target: { name: "target-variant" },
  books: { name: "book-outline" },
  palette: { name: "palette-outline" },
  idea: { name: "lightbulb-outline" },
  tools: { name: "toolbox-outline" },
  chart: { name: "chart-bar" },
  music: { name: "music-note-outline" },
  star: { name: "star-outline" },
  lightning: { name: "flash-outline" },
  rocket: { name: "rocket-outline" },
  earth: { name: "earth" },
  fire: { name: "fire" },
  person: { name: "account-outline" },
  location: { name: "map-marker-outline" },
  clipboard: { name: "clipboard-text-outline" },
  pin: { name: "pin-outline" },
  building: { name: "office-building-outline" },
  trash: { name: "trash-can-outline" },
  tag: { name: "tag-outline" },
  hourglass: { name: "timer-sand" },
  check: { name: "check", defaultSize: 20 },
  close: { name: "close" },
  plus: { name: "plus" },
  document: { name: "file-outline" },
  edit: { name: "pencil" },
  eye: { name: "eye-outline" },
  drag: { name: "drag-vertical" },
};

export const folderIconKeys: AppIconKey[] = [
  "folder",
  "briefcase",
  "home",
  "hospital",
  "target",
  "books",
  "palette",
  "idea",
  "tools",
  "chart",
  "music",
  "star",
  "lightning",
  "rocket",
  "earth",
  "fire",
];

export const resolveIconKey = (icon: string | AppIconKey): AppIconKey => {
  if (icon in ICON_DEFINITIONS) {
    return icon as AppIconKey;
  }
  return "folder";
};
