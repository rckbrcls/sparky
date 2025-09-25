export interface ParsedReminder {
  title: string;
  type: "date" | "note" | "trigger";
  fireAt?: Date;
  triggerType?: "location" | "person" | "time" | "dayOfWeek" | "project";
  triggerConfig?: any;
  priority: 1 | 2 | 3;
  tags: string[];
  folderId?: string;
  person?: string;
  persons?: string[];
  project?: string;
  location?: string;
  locations?: string[];
  body?: string;
}

export interface Segment {
  text: string;
  kind: "command" | "commandArg" | "tag" | "normal" | "commandActive";
}
