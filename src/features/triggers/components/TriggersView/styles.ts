import { StyleSheet } from "react-native";
import { Colors } from "@/src/constants/Colors";
import { Typography } from "@/src/constants/Typography";

export const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "transparent",
  },
  stageArea: {
    flex: 1,
    position: "relative",
  },
  stagePlane: {
    position: "absolute",
    top: 0,
    right: 0,
    bottom: 0,
    left: 0,
  },
  listContainer: {
    padding: 16,
  },
  stageContainer: {
    flex: 1,
    backgroundColor: Colors.dark.background,
  },
  backWrapper: {
    paddingHorizontal: 16,
    paddingTop: 16,
    backgroundColor: Colors.dark.background,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
  },
  backButton: {
    flexDirection: "row",
    alignItems: "center",
    paddingVertical: 8,
    paddingHorizontal: 4,
  },
  backIcon: {
    marginRight: 6,
  },
  backText: {
    ...Typography.caption,
    color: Colors.dark.tint,
    fontWeight: "600",
  },
  headerCount: {
    ...Typography.caption,
    color: Colors.dark.muted,
    fontWeight: "500",
  },
  listWrapper: {
    flex: 1,
    backgroundColor: Colors.dark.background,
  },
  listContentInset: {
    paddingBottom: 80,
  },
});
