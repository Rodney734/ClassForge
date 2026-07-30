//import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // Initialize timezone
    tz.initializeTimeZones();

    // Android initialization
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(settings: settings);
  }

  // Show notification for scheduled class
  Future<void> showClassScheduledNotification({
    required String className,
    required String lecturerName,
    required String time,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'class_scheduled_channel',
          'Class Scheduled Notifications',
          channelDescription: 'Notifications for scheduled classes',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      id: 0,
      title: '📚 New Class Scheduled!',
      body: '$className with $lecturerName at $time',
      notificationDetails: details,
    );
  }

  // Show notification when class goes live
  Future<void> showClassLiveNotification({
    required String className,
    required String lecturerName,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'class_live_channel',
          'Live Class Notifications',
          channelDescription: 'Notifications when classes go live',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      id: 1,
      title: '🔴 LIVE CLASS STARTED!',
      body: '$className with $lecturerName is now live! Tap to join.',
      notificationDetails: details,
    );
  }

  // Schedule a notification for upcoming class
  Future<void> scheduleClassReminder({
    required String className,
    required String lecturerName,
    required DateTime scheduledTime,
  }) async {
    final notificationTime = scheduledTime.subtract(const Duration(minutes: 5));

    if (notificationTime.isAfter(DateTime.now())) {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'class_reminder_channel',
            'Class Reminders',
            channelDescription: 'Reminders for upcoming classes',
            importance: Importance.high,
            priority: Priority.high,
          );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.zonedSchedule(
        id: 2,
        scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        title: '⏰ Class Starting Soon!',
        body: '$className with $lecturerName starts in 5 minutes!',
        payload: null,
      );
    }
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}
