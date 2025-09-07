import * as Notifications from "expo-notifications";
import { Platform } from "react-native";

export class NotificationService {
  static async initialize(): Promise<void> {
    // Configure notification behavior
    Notifications.setNotificationHandler({
      handleNotification: async () => ({
        shouldShowAlert: true,
        shouldPlaySound: true,
        shouldSetBadge: true,
        shouldShowBanner: true,
        shouldShowList: true,
      }),
    });

    // Request permissions
    const { status } = await Notifications.requestPermissionsAsync();
    if (status !== "granted") {
      throw new Error("Notification permissions not granted");
    }

    // Configure notification channel for Android
    if (Platform.OS === "android") {
      await Notifications.setNotificationChannelAsync("reminders", {
        name: "Reminders",
        importance: Notifications.AndroidImportance.HIGH,
        vibrationPattern: [0, 250, 250, 250],
        lightColor: "#FF231F7C",
        sound: "default",
      });
    }
  }

  static async scheduleNotification(
    title: string,
    body: string,
    fireAt: Date,
    identifier?: string
  ): Promise<string> {
    const notificationId = await Notifications.scheduleNotificationAsync({
      identifier,
      content: {
        title,
        body,
        sound: "default",
        priority: Notifications.AndroidNotificationPriority.HIGH,
        categoryIdentifier: "reminder",
      },
      trigger: {
        type: Notifications.SchedulableTriggerInputTypes.DATE,
        date: fireAt,
      },
    });

    return notificationId;
  }

  static async cancelNotification(identifier: string): Promise<void> {
    await Notifications.cancelScheduledNotificationAsync(identifier);
  }

  static async cancelAllNotifications(): Promise<void> {
    await Notifications.cancelAllScheduledNotificationsAsync();
  }

  static async getAllScheduledNotifications(): Promise<
    Notifications.NotificationRequest[]
  > {
    return await Notifications.getAllScheduledNotificationsAsync();
  }

  static async updateNotification(
    identifier: string,
    title: string,
    body: string,
    fireAt: Date
  ): Promise<string> {
    // Cancel the old notification
    await this.cancelNotification(identifier);

    // Schedule a new one
    return await this.scheduleNotification(title, body, fireAt, identifier);
  }
}
