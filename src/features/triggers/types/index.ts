export interface Trigger {
  id: string;
  reminderId: string;
  type: "location" | "person" | "time" | "dayOfWeek" | "project";
  config: string;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}
