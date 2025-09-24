export interface Reminder {
  id: string;
  title: string;
  notes?: string | null;
  person?: string | null;
  project?: string | null;
  location?: string | null;
  type: string;
  rrule?: string | null;
  nextFireAt?: string | null;
  status: "active" | "completed" | "overdue" | "archived";
  completedAt?: string | null;
  notificationId?: string | null;
  folderId?: string | null;
  tags?: string | null;
  priority?: number;
  createdAt: string;
  updatedAt: string;
}

export interface SnoozeHistory {
  id: string;
  reminderId: string;
  snoozeCount: number;
  originalFireAt: string;
  newFireAt: string;
  createdAt: string;
}

export interface ImportantDate {
  id: string;
  title: string;
  description?: string | null;
  date: string;
  type: "birthday" | "renewal" | "due_date";
  person?: string | null;
  leadTimes: string;
  createdAt: string;
  updatedAt: string;
}

export interface ReviewStage {
  id: string;
  reminderId: string;
  currentStage: number;
  lastReviewAt: string;
  ignoreCount: number;
  createdAt: string;
  updatedAt: string;
}
