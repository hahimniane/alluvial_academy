import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../utils/app_logger.dart';
import '../utils/environment_utils.dart';

class JoinLinkService {
  static const String joinShiftParam = 'joinShift';
  static const String guestShiftParam = 'guestShift';
  static String? _pendingShiftId;
  static String? _pendingGuestShiftId;
  static bool _consumed = false;
  static bool _guestConsumed = false;

  static void initFromUri(Uri uri) {
    if (!kIsWeb) return;

    final guestShiftId = _extractGuestShiftId(uri);
    if (guestShiftId != null && guestShiftId.isNotEmpty) {
      _pendingGuestShiftId = guestShiftId;
      _guestConsumed = false;
      AppLogger.info('JoinLinkService: Found guest join link for shift $guestShiftId');
      return;
    }

    final shiftId = _extractShiftId(uri);
    if (shiftId == null || shiftId.isEmpty) return;

    _pendingShiftId = shiftId;
    _consumed = false;
    AppLogger.info('JoinLinkService: Found join link for shift $shiftId');
  }

  static String? consumePendingShiftId() {
    if (_consumed) return null;
    final shiftId = _pendingShiftId;
    if (shiftId == null || shiftId.isEmpty) return null;
    _consumed = true;
    return shiftId;
  }

  static bool get hasPendingJoin => _pendingShiftId != null && !_consumed;
  static bool get hasPendingGuestJoin =>
      _pendingGuestShiftId != null && !_guestConsumed;

  static String? consumePendingGuestShiftId() {
    if (_guestConsumed) return null;
    final shiftId = _pendingGuestShiftId;
    if (shiftId == null || shiftId.isEmpty) return null;
    _guestConsumed = true;
    return shiftId;
  }

  static Uri buildJoinUri(String shiftId) {
    final base = _resolveBaseUri();
    final nextParams = Map<String, String>.from(base.queryParameters);
    nextParams[joinShiftParam] = shiftId;
    return base.replace(queryParameters: nextParams);
  }

  static Uri buildGuestJoinUri(String shiftId) {
    final base = _resolveBaseUri();
    final nextParams = Map<String, String>.from(base.queryParameters);
    nextParams[guestShiftParam] = shiftId;
    return base.replace(queryParameters: nextParams);
  }

  static Uri _resolveBaseUri() {
    if (kIsWeb) {
      final base = Uri.base;
      if (base.scheme.isNotEmpty && base.host.isNotEmpty) {
        return base.replace(queryParameters: {}, fragment: '');
      }
    }

    final authDomain = _authDomain;
    final host = authDomain ?? _fallbackHost();
    return Uri.parse('https://$host');
  }

  static String? get _authDomain {
    try {
      if (Firebase.apps.isEmpty) return null;
      return Firebase.app().options.authDomain;
    } catch (_) {
      return null;
    }
  }

  static String _fallbackHost() {
    if (EnvironmentUtils.isDevelopment) {
      return 'alluwal-dev.web.app';
    }
    return 'alluwal-academy.firebaseapp.com';
  }

  static String? _extractShiftId(Uri uri) {
    final direct = uri.queryParameters[joinShiftParam];
    if (direct != null && direct.trim().isNotEmpty) {
      return direct.trim();
    }

    final fragment = uri.fragment.trim();
    if (fragment.isEmpty) return null;

    final normalized = fragment.startsWith('/') ? fragment.substring(1) : fragment;
    final fragmentUri = Uri.tryParse('https://placeholder/$normalized');
    final fragmentShift = fragmentUri?.queryParameters[joinShiftParam];
    if (fragmentShift != null && fragmentShift.trim().isNotEmpty) {
      return fragmentShift.trim();
    }

    return null;
  }

  static String? _extractGuestShiftId(Uri uri) {
    final direct = uri.queryParameters[guestShiftParam];
    if (direct != null && direct.trim().isNotEmpty) {
      return direct.trim();
    }

    final fragment = uri.fragment.trim();
    if (fragment.isEmpty) return null;

    final normalized =
        fragment.startsWith('/') ? fragment.substring(1) : fragment;
    final fragmentUri = Uri.tryParse('https://placeholder/$normalized');
    final fragmentShift = fragmentUri?.queryParameters[guestShiftParam];
    if (fragmentShift != null && fragmentShift.trim().isNotEmpty) {
      return fragmentShift.trim();
    }

    return null;
  }
}
