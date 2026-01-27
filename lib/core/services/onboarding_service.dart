import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_logger.dart';

/// Service to manage onboarding state and preferences
class OnboardingService {
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
      
      // If version changed, show onboarding again
      if (version < currentVersion) {
        return false;
      }
      
      return completed;
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
      AppLogger.info('Onboarding marked as completed');
    } catch (e) {
      AppLogger.error('Error saving onboarding status: $e');
    }
  }

  /// Check if student has completed the feature tour (coach marks)
  static Future<bool> hasCompletedFeatureTour() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyFeatureTourCompleted) ?? false;
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
      AppLogger.info('Feature tour reset');
    } catch (e) {
      AppLogger.error('Error resetting feature tour: $e');
    }
  }
}
