import { Colors } from "@/src/constants/Colors";
import { Typography } from "@/src/constants/Typography";
import { StyleSheet } from "react-native";

export const styles = StyleSheet.create({
  container: {
    marginTop: 12,
    borderTopWidth: 1,
    borderColor: Colors.dark.border,
    paddingTop: 12,
  },
  scroll: {
    width: "100%",
    maxHeight: 180,
  },
  content: {
    flexDirection: "row",
    flexWrap: "wrap",
    paddingBottom: 4,
  },
  badge: {
    flexDirection: "row",
    alignItems: "center",
    paddingVertical: 6,
    paddingHorizontal: 12,
    borderRadius: 16,
    borderWidth: 1,
    marginRight: 8,
    marginBottom: 8,
    backgroundColor: Colors.dark.surface,
  },
  badgeIcon: {
    marginRight: 6,
  },
  badgeLabel: {
    ...Typography.caption,
    fontWeight: "600",
  },
  badgeClose: {
    marginLeft: 8,
    width: 18,
    height: 18,
    borderRadius: 9,
    alignItems: "center",
    justifyContent: "center",
  },
});
