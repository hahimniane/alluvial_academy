import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../utils/app_logger.dart';
import '../utils/timezone_utils.dart';
import 'notification_service.dart';
import 'prayer_time_service.dart';

/// Service that schedules accurate, location-based prayer time notifications
/// with the Adhan (call to prayer) sound.
///
/// SOUND FILE SETUP (required before notifications will play Adhan sound):
///
/// Android:
///   Place `adhan.mp3` in `android/app/src/main/res/raw/adhan.mp3`
///   The file should be ≤ 30 seconds for best compatibility.
///
/// iOS:
///   1. Add `adhan.aiff` (or `.caf`) to the `ios/Runner/` directory.
///   2. Open Xcode, select Runner > Runner (target) > Build Phases >
///      Copy Bundle Resources, and add `adhan.aiff`.
///   The file must be < 30 seconds; iOS ignores longer notification sounds.
///
/// Free Adhan recordings: search "adhan mp3 free download" or use recordings
/// from Al-Masjid Al-Haram (Makkah) or Al-Masjid An-Nabawi (Madinah).
class PrayerNotificationService {
  static const String _enabledKey = 'prayer_notification_enabled';

  /// Android notification channel ID/name for Adhan notifications.
  static const String channelId = 'prayer_times';
  static const String channelName = 'Prayer Times (Adhan)';
  static const String _channelDescription =
      'Adhan call to prayer at each of the 5 daily prayer times';

  /// Notification IDs: today 100-104, tomorrow 110-114.
  static const Map<String, int> _todayIds = {
    'Fajr': 100,
    'Dhuhr': 101,
    'Asr': 102,
    'Maghrib': 103,
    'Isha': 104,
  };
  static const Map<String, int> _tomorrowIds = {
    'Fajr': 110,
    'Dhuhr': 111,
    'Asr': 112,
    'Maghrib': 113,
    'Isha': 114,
  };

  // ───────────────────────────── Preferences ──────────────────────────────

  /// Whether prayer notifications are enabled (defaults to true).
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? true;
  }

  /// Enable or disable prayer notifications, then reschedule or cancel.
  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);

    if (enabled) {
      await scheduleAllPrayerNotifications();
    } else {
      await cancelAllPrayerNotifications();
    }

    AppLogger.info(
        'PrayerNotificationService: ${enabled ? "Enabled" : "Disabled"} prayer notifications');
  }

  // ──────────────────────────── Channel setup ─────────────────────────────

  /// Create the Android notification channel with the Adhan sound.
  ///
  /// Must be called once at app startup (after NotificationService is
  /// initialised) before scheduling any prayer notifications.
  ///
  /// NOTE: Android only allows setting a channel's sound at creation time.
  /// If the channel already exists without the Adhan sound, delete the app's
  /// notification channel data (or reinstall) to recreate it.
  static Future<void> createAndroidChannel() async {
    if (kIsWeb || !Platform.isAndroid) return;

    final androidPlugin = NotificationService.localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    const channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: _channelDescription,
      importance: Importance.high,
      sound: RawResourceAndroidNotificationSound('adhan'),
      playSound: true,
      enableVibration: false,
    );

    await androidPlugin.createNotificationChannel(channel);
    AppLogger.debug(
        'PrayerNotificationService: Android Adhan channel created/confirmed');
  }

  // ────────────────────────── Scheduling ─────────────────────────────────

  /// Schedule all 5 prayer notifications for today (remaining) and tomorrow.
  ///
  /// Call this at app startup and also whenever the user enables the feature.
  static Future<void> scheduleAllPrayerNotifications() async {
    if (kIsWeb) return;

    try {
      final enabled = await isEnabled();
      if (!enabled) return;

      // Clear any stale scheduled notifications first.
      await cancelAllPrayerNotifications();

      // Resolve the device's local IANA timezone.
      final tzName = await TimezoneUtils.detectUserTimezone();
      TimezoneUtils.initializeTimezones();
      final location =
          tz.getLocation(TimezoneUtils.normalizeTimezone(tzName));
      final now = DateTime.now();

      int count = 0;

      // Schedule today's prayers that have not yet passed.
      final todayPrayers = await PrayerTimeService.getTodayPrayerTimes();
      for (final prayer in todayPrayers) {
        final id = _todayIds[prayer.name];
        if (id == null) continue;
        if (prayer.time.isAfter(now)) {
          await _scheduleSingle(id: id, prayer: prayer, location: location);
          count++;
        }
      }

      // Always schedule tomorrow's prayers so there is no gap overnight.
      final tomorrowPrayers =
          await PrayerTimeService.getTomorrowPrayerTimes();
      for (final prayer in tomorrowPrayers) {
        final id = _tomorrowIds[prayer.name];
        if (id == null) continue;
        await _scheduleSingle(id: id, prayer: prayer, location: location);
        count++;
      }

      AppLogger.info(
          'PrayerNotificationService: Scheduled $count prayer notifications');
    } catch (e) {
      AppLogger.error(
          'PrayerNotificationService: Error scheduling prayer notifications: $e');
    }
  }

  static Future<void> _scheduleSingle({
    required int id,
    required PrayerTime prayer,
    required tz.Location location,
  }) async {
    final plugin = NotificationService.localNotificationsPlugin;

    final tzTime = tz.TZDateTime(
      location,
      prayer.time.year,
      prayer.time.month,
      prayer.time.day,
      prayer.time.hour,
      prayer.time.minute,
    );

    final androidDetails = Platform.isAndroid
        ? const AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            // Reference the raw resource without file extension.
            sound: RawResourceAndroidNotificationSound('adhan'),
            playSound: true,
            enableVibration: false,
            icon: '@mipmap/ic_launcher',
          )
        : null;

    final iosDetails = Platform.isIOS
        ? const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: false,
            presentSound: true,
            // File must be in ios/Runner/ and added to Xcode build phases.
            sound: 'adhan.aiff',
          )
        : null;

    await plugin.zonedSchedule(
      id,
      'Time for ${prayer.name}',
      'It is time for ${prayer.name} prayer',
      tzTime,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      // alarmClock mode is the most reliable for time-critical notifications
      // and shows as an alarm in the notification shade on Android.
      androidScheduleMode: AndroidScheduleMode.alarmClock,
    );

    AppLogger.debug(
        'PrayerNotificationService: Scheduled ${prayer.name} at $tzTime (id=$id)');
  }

  // ───────────────────────────── Cancellation ─────────────────────────────

  /// Cancel all scheduled prayer notifications (today and tomorrow).
  static Future<void> cancelAllPrayerNotifications() async {
    if (kIsWeb) return;

    final plugin = NotificationService.localNotificationsPlugin;
    for (final id in [
      ..._todayIds.values,
      ..._tomorrowIds.values,
    ]) {
      await plugin.cancel(id);
    }

    AppLogger.debug(
        'PrayerNotificationService: Cancelled all prayer notifications');
  }
}
