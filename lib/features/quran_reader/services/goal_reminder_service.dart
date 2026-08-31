/// Daily memorization-goal reminder — a local notification at a time the
/// student picks ("It's Quran time — 3 ayahs today"). Opt-in, scheduled with
/// the same plumbing as prayer notifications, repeating daily.
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/services/notification_service.dart';
import '../../../core/utils/timezone_utils.dart';

class GoalReminderService {
  static const int _notificationId = 78011;
  static const String _channelId = 'quran_goal_reminders';
  static const String _channelName = 'Quran Goal Reminders';

  static bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Ask the OS for notification permission. Returns true when granted.
  static Future<bool> requestPermission() async {
    if (!_supported) return false;
    final plugin = NotificationService.localNotificationsPlugin;
    if (Platform.isIOS) {
      final ios = plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(
          alert: true, badge: true, sound: true);
      return granted ?? false;
    }
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? true;
  }

  /// Schedule (or reschedule) the daily reminder at [hour]:[minute] local time.
  static Future<void> schedule({
    required int hour,
    required int minute,
    required int perDay,
  }) async {
    if (!_supported) return;
    final plugin = NotificationService.localNotificationsPlugin;
    await plugin.cancel(_notificationId);

    final tzName = await TimezoneUtils.detectUserTimezone();
    TimezoneUtils.initializeTimezones();
    final location = tz.getLocation(TimezoneUtils.normalizeTimezone(tzName));
    var when = tz.TZDateTime(
      location,
      tz.TZDateTime.now(location).year,
      tz.TZDateTime.now(location).month,
      tz.TZDateTime.now(location).day,
      hour,
      minute,
    );
    if (when.isBefore(tz.TZDateTime.now(location))) {
      when = when.add(const Duration(days: 1));
    }

    final ayahs = perDay == 1 ? '1 ayah' : '$perDay ayahs';
    await plugin.zonedSchedule(
      _notificationId,
      'Quran time 📖',
      "Today's goal: $ayahs. A little every day goes far — you've got this.",
      when,
      NotificationDetails(
        android: Platform.isAndroid
            ? const AndroidNotificationDetails(
                _channelId,
                _channelName,
                channelDescription: 'Daily reminder for your memorization goal',
                importance: Importance.high,
                priority: Priority.high,
                icon: '@mipmap/ic_launcher',
              )
            : null,
        iOS: Platform.isIOS
            ? const DarwinNotificationDetails(
                presentAlert: true, presentSound: true)
            : null,
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      // Repeat every day at this time.
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancel() async {
    if (!_supported) return;
    await NotificationService.localNotificationsPlugin.cancel(_notificationId);
  }
}
