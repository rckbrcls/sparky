import {
  addDays,
  addHours,
  addMinutes,
  format,
  parseISO,
  setHours,
} from "date-fns";
import { RRule } from "rrule";
import { database } from "../database";
import type { Reminder as ReminderDTO } from "../repositories/types";
import { NotificationService } from "./NotificationService";

export class ReminderService {
  private static readonly REVIEW_INTERVALS = [1, 3, 7, 14, 30, 60, 90]; // days

  static async createReminder(reminderData: {
    title: string;
    notes?: string;
    person?: string;
    project?: string;
    location?: string;
    type: "once" | "recurring" | "by_person_project" | "by_location";
    rrule?: string;
    fireAt?: Date;
  }): Promise<string> {
    const nextFireAt = this.calculateNextFireAt(
      reminderData.fireAt,
      reminderData.rrule
    );

    // Create reminder in database
    const reminderId = await database.createReminder({
      title: reminderData.title,
      notes: reminderData.notes,
      person: reminderData.person,
      project: reminderData.project,
      location: reminderData.location,
      type: reminderData.type,
      rrule: reminderData.rrule,
      nextFireAt: nextFireAt?.toISOString(),
      status: "active",
    });

    // Schedule notification if there's a fire date
    if (nextFireAt) {
      const notificationId = await NotificationService.scheduleNotification(
        reminderData.title,
        reminderData.notes || "Reminder",
        nextFireAt,
        `reminder_${reminderId}`
      );

      await database.updateReminder(reminderId, { notificationId });
    }

    // If it's a spaced review reminder, create review stage
    if (reminderData.type === "by_person_project" && !reminderData.fireAt) {
      await database.createReviewStage({
        reminderId,
        currentStage: 0,
        lastReviewAt: new Date().toISOString(),
        ignoreCount: 0,
      });
    }

    return reminderId;
  }

  static async updateReminder(
    reminderId: string,
    updates: Partial<{
      title: string;
      notes: string;
      person: string;
      project: string;
      location: string;
      rrule: string;
      fireAt: Date;
    }>
  ): Promise<void> {
    const reminder = await database.getReminderById(reminderId);
    if (!reminder) throw new Error("Reminder not found");

    // Cancel existing notification
    if (reminder.notificationId) {
      await NotificationService.cancelNotification(reminder.notificationId);
    }

    // Calculate new fire time if date changed
    let nextFireAt: Date | undefined;
    if (updates.fireAt !== undefined) {
      nextFireAt = this.calculateNextFireAt(
        updates.fireAt,
        updates.rrule ?? reminder.rrule ?? undefined
      );
    }

    const updateData: Partial<ReminderDTO> = {
      ...updates,
      nextFireAt: nextFireAt ? nextFireAt.toISOString() : undefined,
    };

    // Schedule new notification
    if (nextFireAt) {
      const notificationId = await NotificationService.scheduleNotification(
        updates.title || reminder.title,
        updates.notes || reminder.notes || "Reminder",
        nextFireAt,
        `reminder_${reminderId}`
      );
      updateData.notificationId = notificationId;
    }

    await database.updateReminder(reminderId, updateData);
  }

  static async completeReminder(reminderId: string): Promise<void> {
    const reminder = await database.getReminderById(reminderId);
    if (!reminder) throw new Error("Reminder not found");

    // Cancel notification
    if (reminder.notificationId) {
      await NotificationService.cancelNotification(reminder.notificationId);
    }

    const now = new Date();

    // If it's recurring, calculate next occurrence
    if (reminder.type === "recurring" && reminder.rrule) {
      const nextFireAt = this.calculateNextFireAt(now, reminder.rrule);

      if (nextFireAt) {
        const notificationId = await NotificationService.scheduleNotification(
          reminder.title,
          reminder.notes || "Reminder",
          nextFireAt,
          `reminder_${reminderId}`
        );

        await database.updateReminder(reminderId, {
          nextFireAt: nextFireAt.toISOString(),
          notificationId,
          completedAt: now.toISOString(),
        });
      } else {
        await database.updateReminder(reminderId, {
          status: "completed",
          completedAt: now.toISOString(),
          notificationId: undefined,
        });
      }
    } else {
      // Mark as completed
      await database.updateReminder(reminderId, {
        status: "completed",
        completedAt: now.toISOString(),
        notificationId: undefined,
      });
    }
  }

  static async snoozeReminder(reminderId: string): Promise<void> {
    const reminder = await database.getReminderById(reminderId);
    if (!reminder) throw new Error("Reminder not found");

    if (!reminder.nextFireAt) throw new Error("Reminder has no fire date");

    const snoozeHistory = await database.getSnoozeHistoryForReminder(
      reminderId
    );
    const snoozeCount = snoozeHistory.length;

    let newFireAt: Date;

    switch (snoozeCount) {
      case 0:
        // First snooze: +10 minutes
        newFireAt = addMinutes(new Date(), 10);
        break;
      case 1:
        // Second snooze: +1 hour
        newFireAt = addHours(new Date(), 1);
        break;
      case 2:
        // Third snooze: today at 8 PM
        newFireAt = setHours(new Date(), 20);
        break;
      default:
        // Fourth+ snooze: tomorrow at 9 AM
        newFireAt = setHours(addDays(new Date(), 1), 9);
        break;
    }

    // Record snooze history
    await database.createSnoozeHistory({
      reminderId,
      snoozeCount: snoozeCount + 1,
      originalFireAt: reminder.nextFireAt as string,
      newFireAt: newFireAt.toISOString(),
    });

    // Cancel old notification
    if (reminder.notificationId) {
      await NotificationService.cancelNotification(reminder.notificationId);
    }

    // Schedule new notification
    const notificationId = await NotificationService.scheduleNotification(
      reminder.title,
      reminder.notes || "Reminder",
      newFireAt,
      `reminder_${reminderId}`
    );

    // Update reminder
    await database.updateReminder(reminderId, {
      nextFireAt: newFireAt.toISOString(),
      notificationId,
    });
  }

  static async remindLater(reminderId: string): Promise<void> {
    const reminder = await database.getReminderById(reminderId);
    if (!reminder) throw new Error("Reminder not found");

    const reviewStage = await database.getReviewStageForReminder(reminderId);
    if (!reviewStage) throw new Error("This is not a spaced review reminder");

    const currentStage = Math.min(
      reviewStage.currentStage + 1,
      this.REVIEW_INTERVALS.length - 1
    );
    const daysToAdd = this.REVIEW_INTERVALS[currentStage];
    const newFireAt = addDays(new Date(), daysToAdd);

    // Cancel old notification
    if (reminder.notificationId) {
      await NotificationService.cancelNotification(reminder.notificationId);
    }

    // Schedule new notification
    const notificationId = await NotificationService.scheduleNotification(
      reminder.title,
      reminder.notes || "Reminder",
      newFireAt,
      `reminder_${reminderId}`
    );

    // Update reminder and review stage
    await Promise.all([
      database.updateReminder(reminderId, {
        nextFireAt: newFireAt.toISOString(),
        notificationId,
      }),
      database.updateReviewStage(reminderId, {
        currentStage,
        lastReviewAt: new Date().toISOString(),
      }),
    ]);
  }

  static async ignoreReminder(reminderId: string): Promise<void> {
    const reminder = await database.getReminderById(reminderId);
    if (!reminder) throw new Error("Reminder not found");

    const reviewStage = await database.getReviewStageForReminder(reminderId);
    if (!reviewStage) return; // Not a spaced review reminder

    const ignoreCount = reviewStage.ignoreCount + 1;
    let newStage = reviewStage.currentStage;

    // Reduce stage if ignored too many times
    if (ignoreCount >= 3 && newStage > 0) {
      newStage = Math.max(0, newStage - 1);
    }

    const daysToAdd = this.REVIEW_INTERVALS[newStage];
    const newFireAt = addDays(new Date(), daysToAdd);

    // Cancel old notification
    if (reminder.notificationId) {
      await NotificationService.cancelNotification(reminder.notificationId);
    }

    // Schedule new notification
    const notificationId = await NotificationService.scheduleNotification(
      reminder.title,
      reminder.notes || "Reminder",
      newFireAt,
      `reminder_${reminderId}`
    );

    // Update reminder and review stage
    await Promise.all([
      database.updateReminder(reminderId, {
        nextFireAt: newFireAt.toISOString(),
        notificationId,
      }),
      database.updateReviewStage(reminderId, {
        currentStage: newStage,
        ignoreCount: ignoreCount >= 3 ? 0 : ignoreCount,
        lastReviewAt: new Date().toISOString(),
      }),
    ]);
  }

  static async archiveReminder(reminderId: string): Promise<void> {
    const reminder = await database.getReminderById(reminderId);
    if (!reminder) throw new Error("Reminder not found");

    // Cancel notification
    if (reminder.notificationId) {
      await NotificationService.cancelNotification(reminder.notificationId);
    }

    await database.updateReminder(reminderId, {
      status: "archived",
      notificationId: undefined,
    });
  }

  static async deleteReminder(reminderId: string): Promise<void> {
    const reminder = await database.getReminderById(reminderId);
    if (!reminder) throw new Error("Reminder not found");

    // Cancel notification
    if (reminder.notificationId) {
      await NotificationService.cancelNotification(reminder.notificationId);
    }

    await database.deleteReminder(reminderId);
  }

  static async updateReminderStatuses(): Promise<void> {
    const overdueReminders = await database.getOverdueReminders();

    for (const reminder of overdueReminders) {
      if (reminder.status === "active") {
        await database.updateReminder(reminder.id, { status: "overdue" });
      }
    }
  }

  private static calculateNextFireAt(
    fireAt?: Date,
    rrule?: string
  ): Date | undefined {
    if (!fireAt && !rrule) return undefined;

    if (rrule) {
      try {
        const rule = RRule.fromString(rrule);
        const now = new Date();
        const nextOccurrence = rule.after(now, true);
        return nextOccurrence || undefined;
      } catch (error) {
        console.error("Error parsing RRULE:", error);
        return fireAt;
      }
    }

    return fireAt;
  }

  // Important Dates Management
  static async createImportantDate(dateData: {
    title: string;
    description?: string;
    date: Date;
    type: "birthday" | "renewal" | "due_date";
    person?: string;
    leadTimes: number[]; // in days
  }): Promise<string> {
    const leadTimesJson = JSON.stringify(dateData.leadTimes);

    const dateId = await database.createImportantDate({
      title: dateData.title,
      description: dateData.description,
      date: dateData.date.toISOString(),
      type: dateData.type,
      person: dateData.person,
      leadTimes: leadTimesJson,
    });

    // Generate reminder notifications for lead times
    await this.generateLeadTimeReminders(dateId, dateData);

    return dateId;
  }

  private static async generateLeadTimeReminders(
    dateId: string,
    dateData: {
      title: string;
      description?: string;
      date: Date;
      type: "birthday" | "renewal" | "due_date";
      person?: string;
      leadTimes: number[];
    }
  ): Promise<void> {
    const now = new Date();
    const targetDate = dateData.date;

    for (const leadTimeDays of dateData.leadTimes) {
      let reminderDate: Date;

      if (leadTimeDays < 1) {
        // Hours before
        reminderDate = addHours(targetDate, -(leadTimeDays * 24));
      } else {
        // Days before
        reminderDate = addDays(targetDate, -leadTimeDays);
      }

      // Only schedule if the reminder date is in the future
      if (reminderDate > now) {
        const title =
          leadTimeDays < 1
            ? `${dateData.title} em ${Math.round(leadTimeDays * 24)} horas`
            : `${dateData.title} em ${leadTimeDays} ${
                leadTimeDays === 1 ? "dia" : "dias"
              }`;

        await NotificationService.scheduleNotification(
          title,
          dateData.description || `${dateData.type} reminder`,
          reminderDate,
          `important_date_${dateId}_${leadTimeDays}`
        );
      }
    }
  }

  // Utility methods for fetching reminders
  static async getTodayReminders(): Promise<ReminderDTO[]> {
    return await database.getTodayReminders();
  }

  static async getUpcomingReminders(): Promise<ReminderDTO[]> {
    return await database.getUpcomingReminders();
  }

  static async getOverdueReminders(): Promise<ReminderDTO[]> {
    return await database.getOverdueReminders();
  }

  static async getRemindersByPersonOrProject(
    filter: string
  ): Promise<ReminderDTO[]> {
    return await database.getRemindersByPersonOrProject(filter);
  }

  static async getAllReminders(): Promise<ReminderDTO[]> {
    return await database.getAllReminders();
  }

  // Export and Import
  static async exportData(): Promise<string> {
    const data = await database.exportData();
    return JSON.stringify(data, null, 2);
  }

  static async exportCSV(): Promise<string> {
    const reminders = await database.getAllReminders();

    const headers = [
      "ID",
      "Title",
      "Notes",
      "Person",
      "Project",
      "Location",
      "Type",
      "Next Fire At",
      "Status",
      "Created At",
      "Updated At",
    ];

    const rows = reminders.map((reminder: any) => [
      reminder.id,
      reminder.title,
      reminder.notes || "",
      reminder.person || "",
      reminder.project || "",
      reminder.location || "",
      reminder.type,
      reminder.nextFireAt
        ? format(new Date(reminder.nextFireAt), "dd/MM/yyyy HH:mm")
        : "",
      reminder.status,
      format(new Date(reminder.createdAt), "dd/MM/yyyy HH:mm"),
      format(new Date(reminder.updatedAt), "dd/MM/yyyy HH:mm"),
    ]);

    return [headers, ...rows].map((row) => row.join(",")).join("\n");
  }

  static async importData(jsonData: string): Promise<void> {
    try {
      const data = JSON.parse(jsonData);
      await database.importData(data);

      // Reschedule all notifications
      await this.rescheduleAllNotifications();
    } catch {
      throw new Error("Invalid JSON data");
    }
  }

  private static async rescheduleAllNotifications(): Promise<void> {
    // Cancel all existing notifications
    await NotificationService.cancelAllNotifications();

    // Reschedule active reminders
    const activeReminders = await database.getAllReminders();

    for (const reminder of activeReminders) {
      if (reminder.status === "active" && reminder.nextFireAt) {
        const fireAt = parseISO(reminder.nextFireAt);
        const now = new Date();

        if (fireAt > now) {
          const notificationId = await NotificationService.scheduleNotification(
            reminder.title,
            reminder.notes || "Reminder",
            fireAt,
            `reminder_${reminder.id}`
          );

          await database.updateReminder(reminder.id, { notificationId });
        }
      }
    }
  }
}
