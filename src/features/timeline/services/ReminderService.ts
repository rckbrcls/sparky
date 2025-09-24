import {
  addDays,
  addHours,
  addMinutes,
  format,
  parseISO,
  setHours,
} from "date-fns";
import { RRule } from "rrule";

import { database } from "@/src/database";
import type { Reminder as ReminderDTO } from "../types";
import { NotificationService } from "@/src/services/NotificationService";

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

  static async postponeReminder(
    reminderId: string,
    amount: number,
    unit: "minutes" | "hours" | "days"
  ): Promise<void> {
    const reminder = await database.getReminderById(reminderId);
    if (!reminder) throw new Error("Reminder not found");
    if (!reminder.nextFireAt)
      throw new Error("Cannot postpone reminder without next fire date");

    const nextFireAt = parseISO(reminder.nextFireAt);
    let postponed: Date;
    switch (unit) {
      case "minutes":
        postponed = addMinutes(nextFireAt, amount);
        break;
      case "hours":
        postponed = addHours(nextFireAt, amount);
        break;
      case "days":
        postponed = addDays(nextFireAt, amount);
        break;
      default:
        throw new Error(`Unsupported postpone unit: ${unit}`);
    }

    const notificationId = await NotificationService.scheduleNotification(
      reminder.title,
      reminder.notes || "Reminder",
      postponed,
      `reminder_${reminderId}`
    );

    await database.updateReminder(reminderId, {
      nextFireAt: postponed.toISOString(),
      notificationId,
      status: "active",
    });
  }

  static async cancelReminder(reminderId: string): Promise<void> {
    const reminder = await database.getReminderById(reminderId);
    if (!reminder) throw new Error("Reminder not found");

    if (reminder.notificationId) {
      await NotificationService.cancelNotification(reminder.notificationId);
    }

    await database.updateReminder(reminderId, {
      status: "archived",
      notificationId: undefined,
    });
  }

  static async snoozeReminder(
    reminderId: string,
    minutes: number
  ): Promise<void> {
    const reminder = await database.getReminderById(reminderId);
    if (!reminder) throw new Error("Reminder not found");

    if (!reminder.nextFireAt) {
      throw new Error("Cannot snooze reminder without next fire date");
    }

    const currentFireAt = parseISO(reminder.nextFireAt);
    const snoozedAt = addMinutes(currentFireAt, minutes);

    const notificationId = await NotificationService.scheduleNotification(
      reminder.title,
      reminder.notes || "Reminder",
      snoozedAt,
      `reminder_${reminderId}`
    );

    await database.createSnoozeHistory({
      reminderId,
      snoozeCount: 1,
      originalFireAt: reminder.nextFireAt,
      newFireAt: snoozedAt.toISOString(),
    });

    await database.updateReminder(reminderId, {
      nextFireAt: snoozedAt.toISOString(),
      notificationId,
    });
  }

  static async rescheduleReviewReminder(reminderId: string): Promise<void> {
    const reminder = await database.getReminderById(reminderId);
    if (!reminder) throw new Error("Reminder not found");

    const reviewStage = await database.getReviewStageForReminder(reminderId);
    if (!reviewStage) return;

    const nextStageIndex = Math.min(
      reviewStage.currentStage + 1,
      this.REVIEW_INTERVALS.length - 1
    );
    const intervalDays = this.REVIEW_INTERVALS[nextStageIndex];
    const nextReviewDate = addDays(new Date(), intervalDays);

    await database.updateReviewStage(reminderId, {
      currentStage: nextStageIndex,
      lastReviewAt: new Date().toISOString(),
      ignoreCount: 0,
    });

    const notificationId = await NotificationService.scheduleNotification(
      reminder.title,
      reminder.notes || "Reminder",
      nextReviewDate,
      `reminder_${reminderId}`
    );

    await database.updateReminder(reminderId, {
      nextFireAt: nextReviewDate.toISOString(),
      notificationId,
      status: "active",
    });
  }

  static async ignoreReviewReminder(reminderId: string): Promise<void> {
    const reminder = await database.getReminderById(reminderId);
    if (!reminder) throw new Error("Reminder not found");

    const reviewStage = await database.getReviewStageForReminder(reminderId);
    if (!reviewStage) return;

    const ignoredCount = reviewStage.ignoreCount + 1;

    let nextStageIndex = reviewStage.currentStage;
    if (ignoredCount >= 2 && reviewStage.currentStage > 0) {
      nextStageIndex = reviewStage.currentStage - 1;
    }

    await database.updateReviewStage(reminderId, {
      ignoreCount: ignoredCount,
      currentStage: nextStageIndex,
      lastReviewAt: new Date().toISOString(),
    });

    const nextReviewDate = addDays(
      new Date(),
      this.REVIEW_INTERVALS[nextStageIndex]
    );

    const notificationId = await NotificationService.scheduleNotification(
      reminder.title,
      reminder.notes || "Reminder",
      nextReviewDate,
      `reminder_${reminderId}`
    );

    await database.updateReminder(reminderId, {
      nextFireAt: nextReviewDate.toISOString(),
      notificationId,
      status: "active",
    });
  }

  static async dismissReminder(reminderId: string): Promise<void> {
    const reminder = await database.getReminderById(reminderId);
    if (!reminder) throw new Error("Reminder not found");

    if (reminder.notificationId) {
      await NotificationService.cancelNotification(reminder.notificationId);
    }

    await database.updateReminder(reminderId, {
      status: "archived",
      notificationId: undefined,
    });
  }

  static async refreshUpcomingReminderNotifications(): Promise<void> {
    const reminders = (await database.getUpcomingReminders()) as ReminderDTO[];

    const allNotifications = await NotificationService.getAllScheduledNotifications();

    // Cancel notifications for reminders that no longer exist
    const reminderIds = new Set(reminders.map((r: ReminderDTO) => r.id));
    for (const notification of allNotifications) {
      if (
        notification.content.categoryIdentifier === "reminder" &&
        notification.identifier.startsWith("reminder_")
      ) {
        const reminderId = notification.identifier.replace("reminder_", "");
        if (!reminderIds.has(reminderId)) {
          await NotificationService.cancelNotification(notification.identifier);
        }
      }
    }

    // Reschedule notifications for reminders
    for (const reminder of reminders) {
      if (!reminder.nextFireAt) continue;

      const existingNotification = allNotifications.find(
        (n) => n.identifier === `reminder_${reminder.id}`
      );

      const fireDate = parseISO(reminder.nextFireAt);

      if (existingNotification) {
        await NotificationService.updateNotification(
          existingNotification.identifier,
          reminder.title,
          reminder.notes || "Reminder",
          fireDate
        );
      } else {
        await NotificationService.scheduleNotification(
          reminder.title,
          reminder.notes || "Reminder",
          fireDate,
          `reminder_${reminder.id}`
        );
      }
    }
  }

  private static calculateNextFireAt(
    fireAt?: Date,
    rrule?: string
  ): Date | undefined {
    if (!fireAt && !rrule) return undefined;

    if (rrule) {
      const now = new Date();
      const rule = RRule.fromString(rrule);
      const next = rule.after(now, true);
      if (next) return next;
    }

    return fireAt;
  }

  static async rescheduleReminderToMorning(reminderId: string): Promise<void> {
    const reminder = await database.getReminderById(reminderId);
    if (!reminder) throw new Error("Reminder not found");

    const nextMorning = setHours(new Date(), 9);
    const notificationId = await NotificationService.scheduleNotification(
      reminder.title,
      reminder.notes || "Reminder",
      nextMorning,
      `reminder_${reminderId}`
    );

    await database.updateReminder(reminderId, {
      nextFireAt: nextMorning.toISOString(),
      notificationId,
      status: "active",
    });
  }

  static async syncNotifications(): Promise<void> {
    const reminders = (await database.getAllReminders()) as ReminderDTO[];
    const notifications = await NotificationService.getAllScheduledNotifications();

    const reminderIds = new Set(reminders.map((r: ReminderDTO) => r.id));

    for (const notification of notifications) {
      if (notification.identifier.startsWith("reminder_")) {
        const reminderId = notification.identifier.replace("reminder_", "");
        if (!reminderIds.has(reminderId)) {
          await NotificationService.cancelNotification(notification.identifier);
        }
      }
    }

    for (const reminder of reminders) {
      if (!reminder.nextFireAt) continue;
      const fireDate = parseISO(reminder.nextFireAt);
      await NotificationService.scheduleNotification(
        reminder.title,
        reminder.notes || "Reminder",
        fireDate,
        `reminder_${reminder.id}`
      );
    }
  }

  static async cancelAllReminderNotifications(): Promise<void> {
    await NotificationService.cancelAllNotifications();
  }

  static toHumanReadableNextFire(reminder: ReminderDTO): string | null {
    if (!reminder.nextFireAt) return null;

    const date = parseISO(reminder.nextFireAt);
    return format(date, "EEEE, MMMM d 'at' h:mm a");
  }

  static async updateReminderStatuses(): Promise<void> {
    const reminders = (await database.getAllReminders()) as ReminderDTO[];
    const now = Date.now();
    const updates: Promise<void>[] = [];

    for (const reminder of reminders) {
      if (!reminder.nextFireAt) continue;
      const fireTime = Date.parse(reminder.nextFireAt);
      if (Number.isNaN(fireTime)) continue;

      if (fireTime < now && reminder.status === "active") {
        updates.push(database.updateReminder(reminder.id, { status: "overdue" }));
      } else if (fireTime >= now && reminder.status === "overdue") {
        updates.push(database.updateReminder(reminder.id, { status: "active" }));
      }
    }

    if (updates.length) {
      await Promise.all(updates);
    }
  }

  static async exportData(): Promise<string> {
    const payload = await database.exportData();
    return JSON.stringify(payload, null, 2);
  }

  static async exportCSV(): Promise<string> {
    const reminders = (await database.getAllReminders()) as ReminderDTO[];
    const headers = [
      "id",
      "title",
      "status",
      "nextFireAt",
      "person",
      "project",
      "location",
      "tags",
      "createdAt",
      "updatedAt",
    ];

    const escape = (value: string | null | undefined) => {
      if (value === null || value === undefined) return "";
      const str = String(value).replace(/"/g, '""');
      return `"${str}"`;
    };

    const rows = reminders.map((reminder) =>
      [
        reminder.id,
        reminder.title,
        reminder.status,
        reminder.nextFireAt ?? "",
        reminder.person ?? "",
        reminder.project ?? "",
        reminder.location ?? "",
        reminder.tags ?? "",
        reminder.createdAt,
        reminder.updatedAt,
      ].map(escape).join(",")
    );

    return [headers.join(","), ...rows].join("\n");
  }

  static async importData(serialized: string): Promise<void> {
    const parsed = JSON.parse(serialized);
    await database.importData(parsed);
  }
}
