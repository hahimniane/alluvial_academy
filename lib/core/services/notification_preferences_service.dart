import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

class NotificationPreferencesService {
  // Keys for shift notifications (local cache) - for teachers
  static const String _shiftNotificationEnabledKey = 'shift_notification_enabled';
  static const String _shiftNotificationTimeKey = 'shift_notification_time_minutes';
  
  // Keys for class notifications (local cache) - for students
  static const String _classNotificationEnabledKey = 'class_notification_enabled';
  static const String _classNotificationTimeKey = 'class_notification_time_minutes';
  
  // Keys for task notifications (local cache)
  static const String _taskNotificationEnabledKey = 'task_notification_enabled';
  static const String _taskNotificationTimeKey = 'task_notification_time_days';
  
  // Keys for chat notifications (local cache)
  static const String _chatNotificationEnabledKey = 'chat_notification_enabled';
  
  // Default values
  static const int defaultShiftNotificationMinutes = 15;
  static const int defaultClassNotificationMinutes = 15;
  static const int defaultTaskNotificationDays = 1;
  
  // Available options
  static const List<int> shiftNotificationOptions = [10, 15, 20, 30];
  static const List<int> classNotificationOptions = [5, 10, 15, 20, 30];
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

  /// Set shift notification enabled status (updates both cache and Cloud Function)
  static Future<void> setShiftNotificationEnabled(bool enabled) async {
    try {
      // Update local cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_shiftNotificationEnabledKey, enabled);
      
      // Update via Cloud Function
      final callable = FirebaseFunctions.instance.httpsCallable('updateNotificationPreferences');
      await callable.call<Map<String, dynamic>>({'shiftEnabled': enabled});
      AppLogger.info('✅ Shift notification enabled ($enabled) saved');
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

  /// Set shift notification time in minutes (updates both cache and Cloud Function)
  static Future<void> setShiftNotificationMinutes(int minutes) async {
    try {
      // Update local cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_shiftNotificationTimeKey, minutes);
      
      // Update via Cloud Function
      final callable = FirebaseFunctions.instance.httpsCallable('updateNotificationPreferences');
      await callable.call<Map<String, dynamic>>({'shiftMinutes': minutes});
      AppLogger.info('✅ Shift notification time ($minutes min) saved');
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

  /// Set task notification enabled status (updates both cache and Cloud Function)
  static Future<void> setTaskNotificationEnabled(bool enabled) async {
    try {
      // Update local cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_taskNotificationEnabledKey, enabled);
      
      // Update via Cloud Function
      final callable = FirebaseFunctions.instance.httpsCallable('updateNotificationPreferences');
      await callable.call<Map<String, dynamic>>({'taskEnabled': enabled});
      AppLogger.info('✅ Task notification enabled ($enabled) saved');
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

  /// Set task notification time in days (updates both cache and Cloud Function)
  static Future<void> setTaskNotificationDays(int days) async {
    try {
      // Update local cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_taskNotificationTimeKey, days);
      
      // Update via Cloud Function
      final callable = FirebaseFunctions.instance.httpsCallable('updateNotificationPreferences');
      await callable.call<Map<String, dynamic>>({'taskDays': days});
      AppLogger.info('✅ Task notification time ($days days) saved');
    } catch (e) {
      AppLogger.error('Error setting task notification time: $e');
    }
  }

  // ============================================================
  // STUDENT CLASS NOTIFICATIONS
  // ============================================================

  /// Get class notification enabled status for students (cache first, then Firestore)
  static Future<bool> isClassNotificationEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check cache first
      if (prefs.containsKey(_classNotificationEnabledKey)) {
        return prefs.getBool(_classNotificationEnabledKey) ?? true;
      }
      
      // No cache, fetch from Firestore
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return true; // Default to enabled
      
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final notifPrefs = data['notificationPreferences'] as Map<String, dynamic>?;
        final enabled = notifPrefs?['classEnabled'] as bool? ?? true; // Default enabled
        
        // Cache it
        await prefs.setBool(_classNotificationEnabledKey, enabled);
        return enabled;
      }
      
      return true; // Default to enabled for students
    } catch (e) {
      AppLogger.error('Error getting class notification enabled status: $e');
      return true;
    }
  }

  /// Set class notification enabled status for students (updates both cache and Cloud Function)
  static Future<void> setClassNotificationEnabled(bool enabled) async {
    try {
      // Update local cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_classNotificationEnabledKey, enabled);
      
      // Update via Cloud Function
      final callable = FirebaseFunctions.instance.httpsCallable('updateNotificationPreferences');
      await callable.call<Map<String, dynamic>>({'classEnabled': enabled});
      AppLogger.info('✅ Class notification enabled ($enabled) saved');
    } catch (e) {
      AppLogger.error('Error setting class notification enabled status: $e');
    }
  }

  /// Get class notification time in minutes for students (cache first, then Firestore)
  static Future<int> getClassNotificationMinutes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check cache first
      if (prefs.containsKey(_classNotificationTimeKey)) {
        return prefs.getInt(_classNotificationTimeKey) ?? defaultClassNotificationMinutes;
      }
      
      // No cache, fetch from Firestore
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return defaultClassNotificationMinutes;
      
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final notifPrefs = data['notificationPreferences'] as Map<String, dynamic>?;
        final minutes = notifPrefs?['classMinutes'] as int? ?? defaultClassNotificationMinutes;
        
        // Cache it
        await prefs.setInt(_classNotificationTimeKey, minutes);
        return minutes;
      }
      
      return defaultClassNotificationMinutes;
    } catch (e) {
      AppLogger.error('Error getting class notification time: $e');
      return defaultClassNotificationMinutes;
    }
  }

  /// Set class notification time in minutes for students (updates both cache and Cloud Function)
  static Future<void> setClassNotificationMinutes(int minutes) async {
    try {
      // Update local cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_classNotificationTimeKey, minutes);
      
      // Update via Cloud Function
      final callable = FirebaseFunctions.instance.httpsCallable('updateNotificationPreferences');
      await callable.call<Map<String, dynamic>>({'classMinutes': minutes});
      AppLogger.info('✅ Class notification time ($minutes min) saved');
    } catch (e) {
      AppLogger.error('Error setting class notification time: $e');
    }
  }

  // ============================================================
  // CHAT NOTIFICATIONS
  // ============================================================

  /// Get chat notification enabled status (cache first, then Firestore)
  static Future<bool> isChatNotificationEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check cache first
      if (prefs.containsKey(_chatNotificationEnabledKey)) {
        return prefs.getBool(_chatNotificationEnabledKey) ?? true;
      }
      
      // No cache, fetch from Firestore
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return true;
      
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final notifPrefs = data['notificationPreferences'] as Map<String, dynamic>?;
        final enabled = notifPrefs?['chatEnabled'] as bool? ?? true;
        
        // Cache it
        await prefs.setBool(_chatNotificationEnabledKey, enabled);
        return enabled;
      }
      
      return true;
    } catch (e) {
      AppLogger.error('Error getting chat notification enabled status: $e');
      return true;
    }
  }

  /// Set chat notification enabled status (updates both cache and Cloud Function)
  static Future<void> setChatNotificationEnabled(bool enabled) async {
    try {
      // Update local cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_chatNotificationEnabledKey, enabled);
      
      // Update via Cloud Function
      final callable = FirebaseFunctions.instance.httpsCallable('updateChatNotificationPreference');
      await callable.call<Map<String, dynamic>>({'chatEnabled': enabled});
      AppLogger.info('✅ Chat notification enabled ($enabled) saved');
    } catch (e) {
      AppLogger.error('Error setting chat notification enabled status: $e');
    }
  }

  /// Clear all notification preferences (for testing or reset)
  static Future<void> clearPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_shiftNotificationEnabledKey);
      await prefs.remove(_shiftNotificationTimeKey);
      await prefs.remove(_classNotificationEnabledKey);
      await prefs.remove(_classNotificationTimeKey);
      await prefs.remove(_taskNotificationEnabledKey);
      await prefs.remove(_taskNotificationTimeKey);
      await prefs.remove(_chatNotificationEnabledKey);
    } catch (e) {
      AppLogger.error('Error clearing notification preferences: $e');
    }
  }

  /// Get a summary of current preferences
  static Future<Map<String, dynamic>> getPreferencesSummary() async {
    return {
      'shiftNotificationEnabled': await isShiftNotificationEnabled(),
      'shiftNotificationMinutes': await getShiftNotificationMinutes(),
      'classNotificationEnabled': await isClassNotificationEnabled(),
      'classNotificationMinutes': await getClassNotificationMinutes(),
      'taskNotificationEnabled': await isTaskNotificationEnabled(),
      'taskNotificationDays': await getTaskNotificationDays(),
      'chatNotificationEnabled': await isChatNotificationEnabled(),
    };
  }
}

