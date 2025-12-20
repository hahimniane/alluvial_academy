import 'dart:io';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

class VersionService {
  static final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;
  
  /// Initialize Remote Config with default values
  static Future<void> initialize() async {
    try {
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      
      // Set default values
      await _remoteConfig.setDefaults(<String, dynamic>{
        'minimum_android_version': '1.0.0',
        'minimum_ios_version': '1.0.0',
        'force_update_enabled': true,
      });
      
      // Fetch and activate
      await _remoteConfig.fetchAndActivate();
    } catch (e) {
      AppLogger.error('Error initializing Remote Config: $e');
    }
  }
  
  /// Check if update is required for the current platform
  static Future<bool> isUpdateRequired() async {
    // Skip for web
    if (kIsWeb) {
      return false;
    }
    
    try {
      // Get current app version
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version;
      
      // Fetch and activate latest remote config
      await _remoteConfig.fetchAndActivate();
      
      // Check if force update is enabled
      final bool forceUpdateEnabled = _remoteConfig.getBool('force_update_enabled');
      if (!forceUpdateEnabled) {
        return false;
      }
      
      // Get required version based on platform
      String requiredVersion;
      if (Platform.isAndroid) {
        requiredVersion = _remoteConfig.getString('minimum_android_version');
      } else if (Platform.isIOS) {
        requiredVersion = _remoteConfig.getString('minimum_ios_version');
      } else {
        return false; // Not Android or iOS
      }
      
      // Compare versions
      return _compareVersions(currentVersion, requiredVersion) < 0;
    } catch (e) {
      AppLogger.error('Error checking update requirement: $e');
      return false;
    }
  }
  
  /// Compare two version strings (e.g., "1.2.3")
  /// Returns:
  ///   -1 if currentVersion < requiredVersion
  ///    0 if currentVersion == requiredVersion
  ///    1 if currentVersion > requiredVersion
  static int _compareVersions(String currentVersion, String requiredVersion) {
    try {
      final List<int> currentParts = currentVersion.split('.').map(int.parse).toList();
      final List<int> requiredParts = requiredVersion.split('.').map(int.parse).toList();
      
      // Pad the shorter version with zeros
      while (currentParts.length < requiredParts.length) {
        currentParts.add(0);
      }
      while (requiredParts.length < currentParts.length) {
        requiredParts.add(0);
      }
      
      // Compare each part
      for (int i = 0; i < currentParts.length; i++) {
        if (currentParts[i] < requiredParts[i]) {
          return -1;
        } else if (currentParts[i] > requiredParts[i]) {
          return 1;
        }
      }
      
      return 0;
    } catch (e) {
      AppLogger.error('Error comparing versions: $e');
      return 0;
    }
  }
  
  /// Get the app store URL for the current platform
  static String getAppStoreUrl() {
    if (Platform.isIOS) {
      // Replace with your actual App Store ID
      return 'https://apps.apple.com/app/id<YOUR_APP_STORE_ID>';
    } else if (Platform.isAndroid) {
      // Replace with your actual package name
      return 'https://play.google.com/store/apps/details?id=com.alluvaleducationhub.alluwalacademyadmin';
    }
    return '';
  }
  
  /// Get current app version
  static Future<String> getCurrentVersion() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      AppLogger.error('Error getting current version: $e');
      return '1.0.0';
    }
  }
  
  /// Get build number
  static Future<String> getBuildNumber() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.buildNumber;
    } catch (e) {
      AppLogger.error('Error getting build number: $e');
      return '1';
    }
  }
  
  /// Get full version info (version + build)
  static Future<String> getFullVersionInfo() async {
    final version = await getCurrentVersion();
    final build = await getBuildNumber();
    return '$version+$build';
  }
  
  /// Get app name
  static Future<String> getAppName() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.appName;
    } catch (e) {
      AppLogger.error('Error getting app name: $e');
      return 'Alluvial Academy';
    }
  }
  
  /// Get package name
  static Future<String> getPackageName() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.packageName;
    } catch (e) {
      AppLogger.error('Error getting package name: $e');
      return '';
    }
  }
}

