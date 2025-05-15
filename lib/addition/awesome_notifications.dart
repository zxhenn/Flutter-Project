import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

class NotificationService {
  static Future<void> initialize() async {
    await AwesomeNotifications().initialize(
      null, // default app icon
      [
        NotificationChannel(
          channelKey: 'habit_timer_channel',
          channelName: 'Habit Timer Notifications',
          channelDescription: 'Notifications for habit timing and tracking',
          defaultColor: const Color(0xFF2196F3),
          ledColor: const Color(0xFF2196F3),
          importance: NotificationImportance.High,
        ),
        NotificationChannel(
          channelKey: 'social_channel',
          channelName: 'Friend & Social Notifications',
          channelDescription: 'For friend requests and social updates',
          defaultColor: const Color(0xFF4CAF50),
          ledColor: const Color(0xFF4CAF50),
          importance: NotificationImportance.High,
        ),
      ],
      debug: true,
    );
  }

  static Future<void> showInstantNotification(String title, String body) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: createUniqueId(),
        channelKey: 'habit_timer_channel',
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Default,
      ),
    );
  }

  static Future<void> notifyFriendRequest(String fromName) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: createUniqueId(),
        channelKey: 'social_channel',
        title: 'New Friend Request',
        body: '$fromName sent you a friend request!',
        notificationLayout: NotificationLayout.Default,
      ),
    );
  }

  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: 'habit_timer_channel',
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Default,
      ),
      schedule: NotificationCalendar(
        year: scheduledTime.year,
        month: scheduledTime.month,
        day: scheduledTime.day,
        hour: scheduledTime.hour,
        minute: scheduledTime.minute,
        second: scheduledTime.second,
        timeZone: await AwesomeNotifications().getLocalTimeZoneIdentifier(),
        preciseAlarm: true,
      ),
    );
  }

  static Future<void> cancelAll() async {
    await AwesomeNotifications().cancelAll();
  }

  static int createUniqueId() {
    return DateTime.now().millisecondsSinceEpoch.remainder(100000);
  }
}
void showFriendRequestNotification() {
  AwesomeNotifications().createNotification(
    content: NotificationContent(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      channelKey: 'friend_channel',
      title: 'New Friend Request!',
      body: 'Someone just sent you a friend request.',
      notificationLayout: NotificationLayout.Default,
    ),
  );
}