import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import 'app_logger.dart';

/// Debug-only auth diagnostics for tracking unexpected sign-outs on web.
class AuthDebugLogger {
  static bool _started = false;
  static StreamSubscription<User?>? _authSub;
  static StreamSubscription<User?>? _idTokenSub;

  static void start() {
    if (_started) return;
    _started = true;

    final initial = FirebaseAuth.instance.currentUser;
    AppLogger.debug(
      'AuthDebugLogger: start (initial user: ${initial?.uid}, email: ${initial?.email})',
    );

    _authSub = FirebaseAuth.instance.authStateChanges().listen(
      (user) {
        AppLogger.debug(
          'Auth state change: ${user == null ? "SIGNED_OUT" : "SIGNED_IN"} (uid: ${user?.uid}, email: ${user?.email})',
        );
      },
      onError: (error, stackTrace) {
        AppLogger.error(
          'Auth state stream error: $error',
          stackTrace: stackTrace,
        );
      },
    );

    _idTokenSub = FirebaseAuth.instance.idTokenChanges().listen(
      (user) async {
        if (user == null) return;
        try {
          final result = await user.getIdTokenResult();
          final claims = result.claims ?? const <String, dynamic>{};
          final role = claims['role'];
          final isAdmin =
              claims['isAdmin'] ?? claims['is_admin'] ?? claims['admin'];
          AppLogger.debug(
            'ID token refreshed (uid: ${user.uid}, role: $role, isAdmin: $isAdmin)',
          );
        } catch (e) {
          AppLogger.error('Failed to read ID token claims: $e');
        }
      },
      onError: (error, stackTrace) {
        AppLogger.error(
          'ID token stream error: $error',
          stackTrace: stackTrace,
        );
      },
    );
  }

  static Future<void> stop() async {
    await _authSub?.cancel();
    await _idTokenSub?.cancel();
    _authSub = null;
    _idTokenSub = null;
    _started = false;
  }
}

