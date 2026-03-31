import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Logs errors to Firestore `error_logs` collection so you can trace
/// user-reported issues back to specific errors, users, and sessions.
///
/// Works on all platforms (web, Android, iOS). Complements Crashlytics
/// (native-only) by providing a queryable Firestore log.
///
/// Usage:
/// ```dart
/// // Set user context after login
/// ErrorReportingService.setUser(uid, email);
///
/// // Errors are reported automatically via AppLogger.error / .fatal
/// // Or report manually:
/// ErrorReportingService.reportError(error, stackTrace, context: 'shift_creation');
/// ```
class ErrorReportingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // User context — set after login, cleared on logout
  static String? _userId;
  static String? _userEmail;

  // Session ID — unique per app launch, correlates all errors in one session
  static final String _sessionId = const Uuid().v4().substring(0, 8);

  // Breadcrumbs — recent actions leading up to an error
  static final List<String> _breadcrumbs = [];
  static const int _maxBreadcrumbs = 20;

  // Throttle: avoid flooding Firestore with duplicate errors
  static final Map<String, DateTime> _recentErrors = {};
  static const Duration _dedupeWindow = Duration(seconds: 10);

  // Buffer for batching writes
  static final List<Map<String, dynamic>> _buffer = [];
  static Timer? _flushTimer;
  static const int _maxBufferSize = 5;
  static const Duration _flushInterval = Duration(seconds: 15);

  /// Set user context after login. All subsequent errors include this info.
  static void setUser(String userId, {String? email}) {
    _userId = userId;
    _userEmail = email;
  }

  /// Clear user context on logout.
  static void clearUser() {
    _userId = null;
    _userEmail = null;
  }

  /// Add a breadcrumb — a short string describing a user action.
  /// Recent breadcrumbs are attached to error reports for context.
  static void addBreadcrumb(String crumb) {
    final timestamped = '${DateTime.now().toIso8601String().substring(11, 19)} $crumb';
    _breadcrumbs.add(timestamped);
    if (_breadcrumbs.length > _maxBreadcrumbs) {
      _breadcrumbs.removeAt(0);
    }
  }

  /// Report an error to Firestore.
  /// [context] is a short label like 'shift_creation', 'form_submit', 'video_join'.
  static Future<void> reportError(
    dynamic error,
    StackTrace? stackTrace, {
    String? context,
    bool fatal = false,
  }) async {
    try {
      final errorKey = '${error.runtimeType}:${error.toString().hashCode}';

      // Deduplicate: skip if we reported the same error within the window
      final now = DateTime.now();
      final lastReport = _recentErrors[errorKey];
      if (lastReport != null && now.difference(lastReport) < _dedupeWindow) {
        return;
      }
      _recentErrors[errorKey] = now;

      // Clean old entries from dedup map
      _recentErrors.removeWhere((_, t) => now.difference(t) > _dedupeWindow);

      final doc = {
        'timestamp': FieldValue.serverTimestamp(),
        'clientTimestamp': now.toIso8601String(),
        'sessionId': _sessionId,
        'userId': _userId,
        'userEmail': _userEmail,
        'platform': _platformLabel(),
        'context': context,
        'fatal': fatal,
        'error': error.toString().length > 1000
            ? error.toString().substring(0, 1000)
            : error.toString(),
        'errorType': error.runtimeType.toString(),
        'stackTrace': stackTrace != null
            ? stackTrace.toString().length > 3000
                ? stackTrace.toString().substring(0, 3000)
                : stackTrace.toString()
            : null,
        'breadcrumbs': List<String>.from(_breadcrumbs),
        'appVersion': null, // filled in by init if available
      };

      _buffer.add(doc);

      // Flush immediately for fatal errors, otherwise batch
      if (fatal || _buffer.length >= _maxBufferSize) {
        await _flush();
      } else {
        _scheduleFlush();
      }
    } catch (_) {
      // Never let error reporting itself crash the app
    }
  }

  /// Flush buffered errors to Firestore.
  static Future<void> _flush() async {
    if (_buffer.isEmpty) return;

    final batch = List<Map<String, dynamic>>.from(_buffer);
    _buffer.clear();
    _flushTimer?.cancel();
    _flushTimer = null;

    try {
      final writeBatch = _firestore.batch();
      for (final doc in batch) {
        final ref = _firestore.collection('error_logs').doc();
        writeBatch.set(ref, doc);
      }
      await writeBatch.commit();
    } catch (_) {
      // If Firestore write fails, we lose these logs — acceptable tradeoff
      // to avoid infinite error loops
    }
  }

  static void _scheduleFlush() {
    _flushTimer ??= Timer(_flushInterval, _flush);
  }

  /// Get the current session ID (useful for support: "what's your session ID?")
  static String get sessionId => _sessionId;

  static String _platformLabel() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      default:
        return defaultTargetPlatform.toString();
    }
  }
}
