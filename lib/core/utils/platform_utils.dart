import 'package:flutter/foundation.dart';

/// Utility class for platform detection
class PlatformUtils {
  /// Detect the current platform for clock-in tracking
  /// Returns: 'web', 'android', 'ios', or 'other'
  static String detectPlatform() {
    if (kIsWeb) {
      return 'web';
    }
    
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }
  
  /// Get a human-readable platform name
  static String getPlatformDisplayName() {
    final platform = detectPlatform();
    switch (platform) {
      case 'web':
        return 'Web Browser';
      case 'android':
        return 'Android';
      case 'ios':
        return 'iOS';
      case 'macos':
        return 'macOS';
      case 'windows':
        return 'Windows';
      case 'linux':
        return 'Linux';
      default:
        return 'Unknown Platform';
    }
  }
  
  /// Check if running on mobile (Android or iOS)
  static bool isMobile() {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
           defaultTargetPlatform == TargetPlatform.iOS;
  }
  
  /// Check if running on desktop (macOS, Windows, Linux)
  static bool isDesktop() {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.macOS ||
           defaultTargetPlatform == TargetPlatform.windows ||
           defaultTargetPlatform == TargetPlatform.linux;
  }
}

