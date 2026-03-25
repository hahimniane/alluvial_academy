import 'dart:io';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:new_version_plus/new_version_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

enum VersionGateSource {
  none,
  store,
  remoteConfig,
}

class VersionGateDecision {
  final bool updateRequired;
  final VersionGateSource source;
  final String currentVersion;
  final String? targetVersion;
  final String? minimumSupportedVersion;
  final String? storeVersion;
  final String storeUrl;
  final String? releaseNotes;
  final bool storeCheckAttempted;
  final bool storeCheckSucceeded;

  const VersionGateDecision({
    required this.updateRequired,
    required this.source,
    required this.currentVersion,
    required this.targetVersion,
    required this.minimumSupportedVersion,
    required this.storeVersion,
    required this.storeUrl,
    required this.releaseNotes,
    required this.storeCheckAttempted,
    required this.storeCheckSucceeded,
  });

  const VersionGateDecision.noUpdate({
    required String currentVersion,
    String storeUrl = '',
    String? minimumSupportedVersion,
    String? storeVersion,
    String? releaseNotes,
    bool storeCheckAttempted = false,
    bool storeCheckSucceeded = false,
  }) : this(
          updateRequired: false,
          source: VersionGateSource.none,
          currentVersion: currentVersion,
          targetVersion: null,
          minimumSupportedVersion: minimumSupportedVersion,
          storeVersion: storeVersion,
          storeUrl: storeUrl,
          releaseNotes: releaseNotes,
          storeCheckAttempted: storeCheckAttempted,
          storeCheckSucceeded: storeCheckSucceeded,
        );

  bool get enforcedByStore => source == VersionGateSource.store;

  String get displayTargetVersion =>
      targetVersion ??
      storeVersion ??
      minimumSupportedVersion ??
      currentVersion;
}

class VersionPolicy {
  static final RegExp _versionRegex = RegExp(r'\d+(\.\d+){0,2}');

  static String normalizeVersion(String version) {
    final match = _versionRegex.firstMatch(version.trim());
    if (match == null) {
      return '0.0.0';
    }

    final parts = match.group(0)!.split('.').map(int.parse).toList();
    while (parts.length < 3) {
      parts.add(0);
    }
    return parts.take(3).join('.');
  }

  static int compareVersions(String left, String right) {
    final leftParts = normalizeVersion(left).split('.').map(int.parse).toList();
    final rightParts =
        normalizeVersion(right).split('.').map(int.parse).toList();

    for (var i = 0; i < leftParts.length; i++) {
      if (leftParts[i] < rightParts[i]) {
        return -1;
      }
      if (leftParts[i] > rightParts[i]) {
        return 1;
      }
    }

    return 0;
  }

  static VersionGateDecision evaluate({
    required bool forceUpdateEnabled,
    required bool enforceLatestStoreVersion,
    required String currentVersion,
    required String minimumSupportedVersion,
    required String storeUrl,
    String? storeVersion,
    String? releaseNotes,
    required bool storeCheckAttempted,
    required bool storeCheckSucceeded,
  }) {
    final normalizedCurrent = normalizeVersion(currentVersion);
    final normalizedMinimum = normalizeVersion(minimumSupportedVersion);
    final normalizedStore =
        (storeVersion == null || storeVersion.trim().isEmpty)
            ? null
            : normalizeVersion(storeVersion);

    if (!forceUpdateEnabled) {
      return VersionGateDecision.noUpdate(
        currentVersion: normalizedCurrent,
        storeUrl: storeUrl,
        minimumSupportedVersion: normalizedMinimum,
        storeVersion: normalizedStore,
        releaseNotes: releaseNotes,
        storeCheckAttempted: storeCheckAttempted,
        storeCheckSucceeded: storeCheckSucceeded,
      );
    }

    if (enforceLatestStoreVersion && normalizedStore != null) {
      final needsStoreUpdate =
          compareVersions(normalizedCurrent, normalizedStore) < 0;
      if (needsStoreUpdate) {
        return VersionGateDecision(
          updateRequired: true,
          source: VersionGateSource.store,
          currentVersion: normalizedCurrent,
          targetVersion: normalizedStore,
          minimumSupportedVersion: normalizedMinimum,
          storeVersion: normalizedStore,
          storeUrl: storeUrl,
          releaseNotes: releaseNotes,
          storeCheckAttempted: storeCheckAttempted,
          storeCheckSucceeded: storeCheckSucceeded,
        );
      }
    }

    final needsMinimumVersionUpdate =
        compareVersions(normalizedCurrent, normalizedMinimum) < 0;
    if (needsMinimumVersionUpdate) {
      return VersionGateDecision(
        updateRequired: true,
        source: VersionGateSource.remoteConfig,
        currentVersion: normalizedCurrent,
        targetVersion: normalizedMinimum,
        minimumSupportedVersion: normalizedMinimum,
        storeVersion: normalizedStore,
        storeUrl: storeUrl,
        releaseNotes: releaseNotes,
        storeCheckAttempted: storeCheckAttempted,
        storeCheckSucceeded: storeCheckSucceeded,
      );
    }

    return VersionGateDecision.noUpdate(
      currentVersion: normalizedCurrent,
      storeUrl: storeUrl,
      minimumSupportedVersion: normalizedMinimum,
      storeVersion: normalizedStore,
      releaseNotes: releaseNotes,
      storeCheckAttempted: storeCheckAttempted,
      storeCheckSucceeded: storeCheckSucceeded,
    );
  }
}

class VersionService {
  static final FirebaseRemoteConfig _remoteConfig =
      FirebaseRemoteConfig.instance;

  static VersionGateDecision? _lastDecision;

  /// Initialize Remote Config with default values.
  static Future<void> initialize() async {
    try {
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval:
            kDebugMode ? Duration.zero : const Duration(minutes: 5),
      ));

      await _remoteConfig.setDefaults(<String, dynamic>{
        'minimum_android_version': '1.0.0',
        'minimum_ios_version': '1.0.0',
        'force_update_enabled': true,
        'enforce_latest_store_version': true,
        'android_store_url': '',
        'ios_store_url': '',
        'ios_app_id': '',
        'android_store_id': '',
        'ios_app_store_country': 'US',
        'android_play_store_country': 'en_US',
      });

      await _remoteConfig.fetchAndActivate();
    } catch (e) {
      AppLogger.error('Error initializing Remote Config: $e');
    }
  }

  static VersionGateDecision? get lastDecision => _lastDecision;

  /// Check whether the current app must be updated before use.
  static Future<bool> isUpdateRequired() async {
    final decision = await getUpdateDecision();
    return decision.updateRequired;
  }

  /// Resolve the full force-update decision for the current platform.
  static Future<VersionGateDecision> getUpdateDecision() async {
    if (kIsWeb) {
      return const VersionGateDecision.noUpdate(currentVersion: '0.0.0');
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion =
          VersionPolicy.normalizeVersion(packageInfo.version);

      await _remoteConfig.fetchAndActivate();

      final forceUpdateEnabled = _remoteConfig.getBool('force_update_enabled');
      final enforceLatestStoreVersion =
          _remoteConfig.getBool('enforce_latest_store_version');
      final minimumSupportedVersion = _getPlatformMinimumVersion();

      final storeStatus = await _getStoreVersionStatus(packageInfo);
      final storeUrl = await _resolveStoreUrl(
        packageInfo: packageInfo,
        storeStatus: storeStatus,
      );

      final decision = VersionPolicy.evaluate(
        forceUpdateEnabled: forceUpdateEnabled,
        enforceLatestStoreVersion: enforceLatestStoreVersion,
        currentVersion: currentVersion,
        minimumSupportedVersion: minimumSupportedVersion,
        storeUrl: storeUrl,
        storeVersion: storeStatus?.storeVersion,
        releaseNotes: storeStatus?.releaseNotes,
        storeCheckAttempted: true,
        storeCheckSucceeded: storeStatus != null,
      );

      _lastDecision = decision;
      return decision;
    } catch (e) {
      AppLogger.error('Error checking update requirement: $e');

      final fallbackCurrentVersion = await getCurrentVersion();
      final fallbackMinimumVersion = _getPlatformMinimumVersion();
      final fallbackUrl = await getAppStoreUrl();

      final decision = VersionPolicy.evaluate(
        forceUpdateEnabled: _remoteConfig.getBool('force_update_enabled'),
        enforceLatestStoreVersion: false,
        currentVersion: fallbackCurrentVersion,
        minimumSupportedVersion: fallbackMinimumVersion,
        storeUrl: fallbackUrl,
        storeCheckAttempted: true,
        storeCheckSucceeded: false,
      );

      _lastDecision = decision;
      return decision;
    }
  }

  static String _getPlatformMinimumVersion() {
    if (kIsWeb) {
      return '0.0.0';
    }

    if (Platform.isAndroid) {
      return _remoteConfig.getString('minimum_android_version').trim();
    }

    if (Platform.isIOS) {
      return _remoteConfig.getString('minimum_ios_version').trim();
    }

    return '0.0.0';
  }

  static Future<VersionStatus?> _getStoreVersionStatus(
    PackageInfo packageInfo,
  ) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return null;
    }

    try {
      final newVersion = NewVersionPlus(
        androidId:
            _getRemoteString('android_store_id')?.trim().isNotEmpty == true
                ? _getRemoteString('android_store_id')!.trim()
                : packageInfo.packageName,
        iOSId: _getRemoteString('ios_app_id')?.trim().isNotEmpty == true
            ? _getRemoteString('ios_app_id')!.trim()
            : packageInfo.packageName,
        iOSAppStoreCountry: _getRemoteString('ios_app_store_country'),
        androidPlayStoreCountry: _getRemoteString('android_play_store_country'),
      );

      final status = await newVersion.getVersionStatus().timeout(
            const Duration(seconds: 8),
          );

      if (status == null) {
        AppLogger.warning('VersionService: store version lookup returned null');
        return null;
      }

      AppLogger.info(
        'VersionService: store version resolved '
        'local=${status.localVersion} store=${status.storeVersion}',
      );
      return status;
    } catch (e) {
      AppLogger.error('VersionService: store version lookup failed: $e');
      return null;
    }
  }

  static String? _getRemoteString(String key) {
    try {
      final value = _remoteConfig.getString(key).trim();
      return value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }

  /// Get the most relevant store URL for the current platform.
  static Future<String> getAppStoreUrl() async {
    if (kIsWeb) return '';

    final cachedUrl = _lastDecision?.storeUrl.trim();
    if (cachedUrl != null && cachedUrl.isNotEmpty) {
      return cachedUrl;
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return _resolveStoreUrl(packageInfo: packageInfo);
    } catch (e) {
      AppLogger.error('Error building store URL: $e');
      return '';
    }
  }

  static Future<String> _resolveStoreUrl({
    required PackageInfo packageInfo,
    VersionStatus? storeStatus,
  }) async {
    if (kIsWeb) return '';

    final configuredUrl = Platform.isAndroid
        ? _getRemoteString('android_store_url')
        : Platform.isIOS
            ? _getRemoteString('ios_store_url')
            : null;
    if (configuredUrl != null && configuredUrl.isNotEmpty) {
      return configuredUrl;
    }

    final storeLink = storeStatus?.appStoreLink.trim();
    if (storeLink != null && storeLink.isNotEmpty) {
      return storeLink;
    }

    if (Platform.isAndroid) {
      final packageName =
          (_getRemoteString('android_store_id') ?? packageInfo.packageName)
              .trim();
      if (packageName.isEmpty) return '';
      return 'https://play.google.com/store/apps/details?id=$packageName';
    }

    if (Platform.isIOS) {
      final appId = (_getRemoteString('ios_app_id') ?? '').trim();
      if (appId.isNotEmpty && !appId.contains('.')) {
        return 'https://apps.apple.com/app/id$appId';
      }
      return '';
    }

    return '';
  }

  /// Get current app version.
  static Future<String> getCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return VersionPolicy.normalizeVersion(packageInfo.version);
    } catch (e) {
      AppLogger.error('Error getting current version: $e');
      return '1.0.0';
    }
  }

  /// Get build number.
  static Future<String> getBuildNumber() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.buildNumber;
    } catch (e) {
      AppLogger.error('Error getting build number: $e');
      return '1';
    }
  }

  /// Get full version info (version + build).
  static Future<String> getFullVersionInfo() async {
    final version = await getCurrentVersion();
    final build = await getBuildNumber();
    return '$version+$build';
  }

  /// Get app name.
  static Future<String> getAppName() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.appName;
    } catch (e) {
      AppLogger.error('Error getting app name: $e');
      return 'Alluvial Academy';
    }
  }

  /// Get package name.
  static Future<String> getPackageName() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.packageName;
    } catch (e) {
      AppLogger.error('Error getting package name: $e');
      return '';
    }
  }
}
