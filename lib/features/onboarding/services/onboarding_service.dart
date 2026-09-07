import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

/// Service to manage onboarding state and preferences.
///
/// Completion is remembered on the student's profile in Firestore
/// (users/{uid}.student_onboarding), not only on the device, so the welcome
/// screens and the feature tour show once per account — not again after a
/// reinstall or on a second phone. Local preferences are kept as a cache.
class OnboardingService {
  static const String _profileField = 'student_onboarding';

  static String? get _uid {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> _profileState() async {
    final uid = _uid;
    if (uid == null) return const {};
    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final raw = snap.data()?[_profileField];
      return raw is Map ? Map<String, dynamic>.from(raw) : const {};
    } catch (e) {
      AppLogger.error('Error reading onboarding state from profile: $e');
      return const {};
    }
  }

  static Future<void> _saveProfileState(Map<String, dynamic> fields) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        _profileField: {...fields, 'updated_at': FieldValue.serverTimestamp()},
      }, SetOptions(merge: true));
    } catch (e) {
      AppLogger.error('Error saving onboarding state to profile: $e');
    }
  }

  static const String _keyOnboardingCompleted = 'student_onboarding_completed';
  static const String _keyFeatureTourCompleted = 'student_feature_tour_completed';
  static const String _keyOnboardingVersion = 'onboarding_version';
  
  /// Current onboarding version - increment to show onboarding again to all users
  static const int currentVersion = 1;

  /// Check if student has completed the welcome onboarding
  static Future<bool> hasCompletedOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final completed = prefs.getBool(_keyOnboardingCompleted) ?? false;
      final version = prefs.getInt(_keyOnboardingVersion) ?? 0;
      if (completed && version >= currentVersion) return true;

      // Not on this device: the account may have finished it elsewhere.
      final profile = await _profileState();
      final profileVersion = (profile['version'] as num?)?.toInt() ?? 0;
      if (profile['completed'] == true && profileVersion >= currentVersion) {
        await prefs.setBool(_keyOnboardingCompleted, true);
        await prefs.setInt(_keyOnboardingVersion, currentVersion);
        if (profile['tour_completed'] == true) await prefs.setBool(_keyFeatureTourCompleted, true);
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.error('Error checking onboarding status: $e');
      return false;
    }
  }

  /// Mark welcome onboarding as completed
  static Future<void> completeOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyOnboardingCompleted, true);
      await prefs.setInt(_keyOnboardingVersion, currentVersion);
      await _saveProfileState({'completed': true, 'version': currentVersion});
      AppLogger.info('Onboarding marked as completed');
    } catch (e) {
      AppLogger.error('Error saving onboarding status: $e');
    }
  }

  /// Check if student has completed the feature tour (coach marks)
  static Future<bool> hasCompletedFeatureTour() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_keyFeatureTourCompleted) ?? false) return true;
      final profile = await _profileState();
      if (profile['tour_completed'] == true) {
        await prefs.setBool(_keyFeatureTourCompleted, true);
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.error('Error checking feature tour status: $e');
      return false;
    }
  }

  /// Mark feature tour as completed
  static Future<void> completeFeatureTour() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyFeatureTourCompleted, true);
      await _saveProfileState({'tour_completed': true});
      AppLogger.info('Feature tour marked as completed');
    } catch (e) {
      AppLogger.error('Error saving feature tour status: $e');
    }
  }

  /// Reset onboarding (for testing or "Start Tour" button)
  static Future<void> resetOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyOnboardingCompleted);
      await prefs.remove(_keyFeatureTourCompleted);
      await prefs.remove(_keyOnboardingVersion);
      await _saveProfileState({'completed': false, 'tour_completed': false});
      AppLogger.info('Onboarding reset');
    } catch (e) {
      AppLogger.error('Error resetting onboarding: $e');
    }
  }

  /// Reset just the feature tour (for "Help" button)
  static Future<void> resetFeatureTour() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyFeatureTourCompleted);
      await _saveProfileState({'tour_completed': false});
      AppLogger.info('Feature tour reset');
    } catch (e) {
      AppLogger.error('Error resetting feature tour: $e');
    }
  }
}
