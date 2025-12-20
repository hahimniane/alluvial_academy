import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

class NotificationPreferencesService {
  // Keys for shift notifications (local cache)
  static const String _shiftNotificationEnabledKey = 'shift_notification_enabled';
  static const String _shiftNotificationTimeKey = 'shift_notification_time_minutes';
  
  // Keys for task notifications (local cache)
  static const String _taskNotificationEnabledKey = 'task_notification_enabled';
  static const String _taskNotificationTimeKey = 'task_notification_time_days';
  
  // Default values
  static const int defaultShiftNotificationMinutes = 15;
  static const int defaultTaskNotificationDays = 1;
  
  // Available options
  static const List<int> shiftNotificationOptions = [10, 15, 20, 30];
  static const List<int> taskNotificationOptions = [1, 2, 3, 5, 7];
  
  // Firestore reference
  static FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  /// Get shift notification enabled status (cache first, then Firestore)
  static Future<bool> isShiftNotificationEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check cache first
      if (prefs.containsKey(_shiftNotificationEnabledKey)) {
        return prefs.getBool(_shiftNotificationEnabledKey) ?? true;
      }
      
      // No cache, fetch from Firestore
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return true;
      
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final notifPrefs = data['notificationPreferences'] as Map<String, dynamic>?;
        final enabled = notifPrefs?['shiftEnabled'] as bool? ?? true;
        
        // Cache it
        await prefs.setBool(_shiftNotificationEnabledKey, enabled);
        return enabled;
      }
      
      return true;
    } catch (e) {
      AppLogger.error('Error getting shift notification enabled status: $e');
      return true;
    }
  }

  /// Set shift notification enabled status (updates both cache and Firestore)
  static Future<void> setShiftNotificationEnabled(bool enabled) async {
    try {
      // Update local cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_shiftNotificationEnabledKey, enabled);
      
      // Update Firestore
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        await _firestore.collection('users').doc(userId).set({
          'notificationPreferences': {
            'shiftEnabled': enabled,
            'lastUpdated': FieldValue.serverTimestamp(),
          }
        }, SetOptions(merge: true));
        AppLogger.error('✅ Shift notification enabled ($enabled) saved to Firestore');
      }
    } catch (e) {
      AppLogger.error('Error setting shift notification enabled status: $e');
    }
  }

  /// Get shift notification time in minutes (cache first, then Firestore)
  static Future<int> getShiftNotificationMinutes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check cache first
      if (prefs.containsKey(_shiftNotificationTimeKey)) {
        return prefs.getInt(_shiftNotificationTimeKey) ?? defaultShiftNotificationMinutes;
      }
      
      // No cache, fetch from Firestore
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return defaultShiftNotificationMinutes;
      
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final notifPrefs = data['notificationPreferences'] as Map<String, dynamic>?;
        final minutes = notifPrefs?['shiftMinutes'] as int? ?? defaultShiftNotificationMinutes;
        
        // Cache it
        await prefs.setInt(_shiftNotificationTimeKey, minutes);
        return minutes;
      }
      
      return defaultShiftNotificationMinutes;
    } catch (e) {
      AppLogger.error('Error getting shift notification time: $e');
      return defaultShiftNotificationMinutes;
    }
  }

  /// Set shift notification time in minutes (updates both cache and Firestore)
  static Future<void> setShiftNotificationMinutes(int minutes) async {
    try {
      // Update local cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_shiftNotificationTimeKey, minutes);
      
      // Update Firestore
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        await _firestore.collection('users').doc(userId).set({
          'notificationPreferences': {
            'shiftMinutes': minutes,
            'lastUpdated': FieldValue.serverTimestamp(),
          }
        }, SetOptions(merge: true));
        AppLogger.error('✅ Shift notification time ($minutes min) saved to Firestore');
      }
    } catch (e) {
      AppLogger.error('Error setting shift notification time: $e');
    }
  }

  /// Get task notification enabled status (cache first, then Firestore)
  static Future<bool> isTaskNotificationEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check cache first
      if (prefs.containsKey(_taskNotificationEnabledKey)) {
        return prefs.getBool(_taskNotificationEnabledKey) ?? true;
      }
      
      // No cache, fetch from Firestore
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return true;
      
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final notifPrefs = data['notificationPreferences'] as Map<String, dynamic>?;
        final enabled = notifPrefs?['taskEnabled'] as bool? ?? true;
        
        // Cache it
        await prefs.setBool(_taskNotificationEnabledKey, enabled);
        return enabled;
      }
      
      return true;
    } catch (e) {
      AppLogger.error('Error getting task notification enabled status: $e');
      return true;
    }
  }

  /// Set task notification enabled status (updates both cache and Firestore)
  static Future<void> setTaskNotificationEnabled(bool enabled) async {
    try {
      // Update local cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_taskNotificationEnabledKey, enabled);
      
      // Update Firestore
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        await _firestore.collection('users').doc(userId).set({
          'notificationPreferences': {
            'taskEnabled': enabled,
            'lastUpdated': FieldValue.serverTimestamp(),
          }
        }, SetOptions(merge: true));
        AppLogger.error('✅ Task notification enabled ($enabled) saved to Firestore');
      }
    } catch (e) {
      AppLogger.error('Error setting task notification enabled status: $e');
    }
  }

  /// Get task notification time in days (cache first, then Firestore)
  static Future<int> getTaskNotificationDays() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check cache first
      if (prefs.containsKey(_taskNotificationTimeKey)) {
        return prefs.getInt(_taskNotificationTimeKey) ?? defaultTaskNotificationDays;
      }
      
      // No cache, fetch from Firestore
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return defaultTaskNotificationDays;
      
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final notifPrefs = data['notificationPreferences'] as Map<String, dynamic>?;
        final days = notifPrefs?['taskDays'] as int? ?? defaultTaskNotificationDays;
        
        // Cache it
        await prefs.setInt(_taskNotificationTimeKey, days);
        return days;
      }
      
      return defaultTaskNotificationDays;
    } catch (e) {
      AppLogger.error('Error getting task notification time: $e');
      return defaultTaskNotificationDays;
    }
  }

  /// Set task notification time in days (updates both cache and Firestore)
  static Future<void> setTaskNotificationDays(int days) async {
    try {
      // Update local cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_taskNotificationTimeKey, days);
      
      // Update Firestore
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        await _firestore.collection('users').doc(userId).set({
          'notificationPreferences': {
            'taskDays': days,
            'lastUpdated': FieldValue.serverTimestamp(),
          }
        }, SetOptions(merge: true));
        AppLogger.error('✅ Task notification time ($days days) saved to Firestore');
      }
    } catch (e) {
      AppLogger.error('Error setting task notification time: $e');
    }
  }

  /// Clear all notification preferences (for testing or reset)
  static Future<void> clearPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_shiftNotificationEnabledKey);
      await prefs.remove(_shiftNotificationTimeKey);
      await prefs.remove(_taskNotificationEnabledKey);
      await prefs.remove(_taskNotificationTimeKey);
    } catch (e) {
      AppLogger.error('Error clearing notification preferences: $e');
    }
  }

  /// Get a summary of current preferences
  static Future<Map<String, dynamic>> getPreferencesSummary() async {
    return {
      'shiftNotificationEnabled': await isShiftNotificationEnabled(),
      'shiftNotificationMinutes': await getShiftNotificationMinutes(),
      'taskNotificationEnabled': await isTaskNotificationEnabled(),
      'taskNotificationDays': await getTaskNotificationDays(),
    };
  }
}

