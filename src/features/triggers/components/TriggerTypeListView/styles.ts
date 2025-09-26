import { Colors } from "@/src/constants/Colors";
import { Typography } from "@/src/constants/Typography";
import { StyleSheet } from "react-native";

export const styles = StyleSheet.create({
  container: {
    flex: 1,
    paddingHorizontal: 16,
    paddingTop: 16,
    paddingBottom: 16,
    backgroundColor: Colors.dark.background,
  },
  listContent: {
    paddingBottom: 8,
  },
  card: {
    flexDirection: "row",
    alignItems: "center",
    padding: 16,
    borderRadius: 16,
    borderWidth: 1,
    borderColor: Colors.dark.border,
    backgroundColor: Colors.dark.surface,
  },
  iconWrap: {
    width: 44,
    height: 44,
    borderRadius: 14,
    borderWidth: 1,
    borderColor: Colors.dark.border,
    backgroundColor: Colors.dark.background,
    alignItems: "center",
    justifyContent: "center",
    marginRight: 16,
  },
  info: {
    flex: 1,
  },
  title: {
    ...Typography.body,
    color: Colors.dark.text,
    fontWeight: "600",
  },
  subtitle: {
    ...Typography.caption,
    color: Colors.dark.muted,
    marginTop: 4,
  },
  indicator: {
    marginLeft: 12,
  },
  chevron: {
    marginLeft: 12,
  },
  separator: {
    height: 12,
  },
});

