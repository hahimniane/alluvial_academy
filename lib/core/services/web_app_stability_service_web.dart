// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
// TODO: dart:html is deprecated; migrate this file to package:web when the
// project's Flutter/Dart web toolchain fully supports the replacement APIs.

import 'dart:async';
import 'dart:html' as html;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../constants/build_info.dart';
import '../utils/app_logger.dart';
import 'web_app_stability_state.dart';

export 'web_app_stability_state.dart';

/// Global stability watchdog for Flutter Web.
///
/// Three responsibilities, in order of "explains the freeze the user sees":
///
/// 1. Unregister any active `ServiceWorkerRegistration`. We deploy with
///    `--pwa-strategy=none` so no SW should exist, but past deploys may have
///    installed one that is now serving stale `main.dart.js` and cached
///    Firestore long-poll responses. We also evict Cache Storage entries whose
///    names look Flutter-related on the first load of a new build hash.
/// 2. Run a periodic Firestore probe. The web SDK's WebChannel can stall after
///    a network blip and never recover on its own; the symptom is a screen
///    that spins forever. Every [_probeInterval] we issue a one-shot `.get()`
///    against the signed-in user's `users/{uid}` doc with a [_probeTimeout]
///    timeout. On timeout we bounce `disableNetwork()` / `enableNetwork()` to
///    force a fresh channel.
/// 3. Aggregate "stuck screen" signals so a global banner can offer Recover /
///    Reload without each screen growing its own retry UI.
class WebAppStabilityService {
  WebAppStabilityService._();

  static final WebAppStabilityService _instance = WebAppStabilityService._();
  static WebAppStabilityService get instance => _instance;

  /// How often the watchdog timer wakes. Changing one of [_probeInterval] or
  /// [_idleBeforeProbe] without the other changes how soon the first probe can
  /// run after startup (probe only runs when idle ≥ [_idleBeforeProbe]).
  static const Duration _probeInterval = Duration(seconds: 20);
  static const Duration _probeTimeout = Duration(seconds: 6);
  static const Duration _idleBeforeProbe = Duration(seconds: 20);
  static const Duration _recoveryStepTimeout = Duration(seconds: 5);

  static const String _usersCollection = 'users';

  /// sessionStorage key: per-tab debug build id so cache purge runs once per
  /// browser session in `flutter run`, not once ever (localStorage would skip
  /// subsequent sessions if the token were a constant like `debug-session`).
  static const String _debugBuildSessionKey = 'wsst_debug_build';

  /// localStorage key for the build hash that last did a Cache Storage purge.
  static const String _cacheBustKey = 'wsst_build_cache_purged';
  static const String _fatalReloadKey = 'wsst_fatal_firestore_reload';

  bool _initialized = false;
  bool _watchdogPaused = false;
  bool _fatalFirestoreAssertionDetected = false;

  /// If we cannot persist [_cacheBustKey] (e.g. `localStorage` blocked), only
  /// run the Flutter cache purge once per service lifetime so every navigation
  /// / hot restart does not re-scan and delete caches.
  bool _cachePurgedOnceWhenStorageUnavailable = false;

  Timer? _probeTimer;
  DateTime _lastFirestoreActivity = DateTime.now();
  final Set<String> _stuckScreenIds = <String>{};
  final Map<String, String> _stuckReasons = <String, String>{};

  final ValueNotifier<WebAppStabilityState> _state =
      ValueNotifier(const WebAppStabilityState());

  ValueListenable<WebAppStabilityState> get state => _state;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Run cleanup steps in parallel; none of them block app startup if they
    // fail because each one is wrapped in its own try/catch.
    await Future.wait<void>(<Future<void>>[
      _unregisterServiceWorkers(),
      _maybeClearStaleCaches(),
    ]);

    _startProbeLoop();
    _clearFatalReloadMarkerIfFreshPageIsHealthy();
  }

  /// Stops the periodic Firestore probe while signed out (or whenever you want
  /// zero background reads). Call with [paused] false after sign-in.
  void setWatchdogPaused(bool paused) {
    if (_watchdogPaused == paused) return;
    _watchdogPaused = paused;
    if (paused) {
      _probeTimer?.cancel();
      _probeTimer = null;
    } else if (_initialized) {
      _startProbeLoop();
    }
  }

  /// Called by hot Firestore data paths so the probe loop can skip the probe
  /// when fresh data is already arriving (no point bouncing a healthy stream).
  void pokeFirestoreActivity() {
    _lastFirestoreActivity = DateTime.now();
  }

  void reportScreenStuck({required String screenId, required String reason}) {
    final added = _stuckScreenIds.add(screenId);
    _stuckReasons[screenId] = reason;
    if (added || _state.value.primaryStuckReason != reason) {
      _state.value = _state.value.copyWith(
        anyScreenStuck: true,
        primaryStuckReason: reason,
      );
    }
  }

  void clearScreenStuck(String screenId) {
    final removed = _stuckScreenIds.remove(screenId);
    _stuckReasons.remove(screenId);
    if (!removed) return;
    if (_stuckScreenIds.isEmpty) {
      _state.value = _state.value.copyWith(
        anyScreenStuck: false,
        primaryStuckReason: null,
      );
    } else {
      // Default `Set` iteration order is insertion-ordered (`LinkedHashSet`);
      // `.first` is stable today but would not be if this ever became a `HashSet`.
      final nextId = _stuckScreenIds.first;
      _state.value = _state.value.copyWith(
        primaryStuckReason: _stuckReasons[nextId],
      );
    }
  }

  void noteFirestoreError(Object error) {
    if (!_isFatalFirestoreAssertion(error)) return;
    _handleFatalFirestoreAssertion(error);
  }

  /// Force the Firestore WebChannel to reconnect by bouncing the network
  /// state. Also acts as a manual "recover" trigger from the global overlay.
  Future<void> forceRecover() async {
    if (_fatalFirestoreAssertionDetected) {
      // A full page reload is required once this SDK-level assertion happens.
      AppLogger.warning(
          'WebAppStability: forceRecover skipped because Firestore is in fatal assertion state; reload required.');
      return;
    }
    if (_state.value.isRecovering) return;
    _state.value = _state.value.copyWith(isRecovering: true);
    try {
      await FirebaseFirestore.instance
          .disableNetwork()
          .timeout(_recoveryStepTimeout, onTimeout: () {
        AppLogger.warning(
            'WebAppStability: disableNetwork timed out; continuing to enableNetwork.');
      });
      await FirebaseFirestore.instance
          .enableNetwork()
          .timeout(_recoveryStepTimeout, onTimeout: () {
        AppLogger.warning('WebAppStability: enableNetwork timed out.');
      });
      _lastFirestoreActivity = DateTime.now();
      AppLogger.info('WebAppStability: Firestore network bounced.');
      _state.value = _state.value.copyWith(
        lastRecoveryAt: DateTime.now(),
      );
    } catch (e) {
      if (_isFatalFirestoreAssertion(e)) {
        _handleFatalFirestoreAssertion(e);
      }
      AppLogger.error('WebAppStability: forceRecover failed: $e');
    } finally {
      _state.value = _state.value.copyWith(isRecovering: false);
    }
  }

  /// Called by the global overlay's reload button. Tries a recovery cycle
  /// first, then reloads the page so a fresh bundle is fetched.
  Future<void> hardReload() async {
    try {
      await forceRecover();
    } catch (_) {
      // ignore — we are about to reload anyway
    }
    try {
      html.window.location.reload();
    } catch (e) {
      AppLogger.error('WebAppStability: hardReload failed: $e');
    }
  }

  Future<void> _unregisterServiceWorkers() async {
    try {
      final sw = html.window.navigator.serviceWorker;
      if (sw == null) return;
      final registrations = await sw.getRegistrations();
      if (registrations.isEmpty) return;
      AppLogger.warning(
          'WebAppStability: unregistering ${registrations.length} stale service worker(s).');
      for (final registration in registrations) {
        try {
          await registration.unregister();
        } catch (e) {
          AppLogger.error('WebAppStability: SW unregister failed: $e');
        }
      }
    } catch (e) {
      AppLogger.error('WebAppStability: SW enumeration failed: $e');
    }
  }

  Future<void> _maybeClearStaleCaches() async {
    final hash = _currentBuildHash();
    String? previousHash;
    var localStorageReadFailed = false;
    try {
      previousHash = html.window.localStorage[_cacheBustKey];
    } catch (_) {
      localStorageReadFailed = true;
    }
    if (previousHash == hash) return;

    if (localStorageReadFailed && _cachePurgedOnceWhenStorageUnavailable) {
      return;
    }

    try {
      // dart:html exposes Window.applicationCache and Window.caches
      // (CacheStorage). Hit the latter; null means the browser does not
      // expose Cache Storage (very old Safari / Firefox in some modes).
      final dynamic caches = html.window.caches;
      if (caches != null) {
        final List<dynamic> keys = await caches.keys() as List<dynamic>;
        final flutterKeys =
            keys.where(_isFlutterWebCacheName).toList(growable: false);
        if (flutterKeys.isNotEmpty) {
          AppLogger.warning(
              'WebAppStability: purging ${flutterKeys.length} Flutter-related '
              'Cache Storage entries from prior build '
              '(${keys.length} total on origin).');
          for (final key in flutterKeys) {
            try {
              await caches.delete(key);
            } catch (e) {
              AppLogger.error('WebAppStability: cache delete failed: $e');
            }
          }
        }
      }
    } catch (e) {
      AppLogger.error('WebAppStability: cache cleanup failed: $e');
    }

    var persisted = false;
    try {
      html.window.localStorage[_cacheBustKey] = hash;
      persisted = true;
    } catch (_) {
      // ignore
    }
    if (!persisted || localStorageReadFailed) {
      _cachePurgedOnceWhenStorageUnavailable = true;
    }
  }

  String _currentBuildHash() {
    if (BuildInfo.hasWebBuildVersion) return BuildInfo.webBuildVersion;
    try {
      final storage = html.window.sessionStorage;
      final existing = storage[_debugBuildSessionKey];
      if (existing != null && existing.isNotEmpty) return existing;
      final token = 'debug-${DateTime.now().millisecondsSinceEpoch}';
      storage[_debugBuildSessionKey] = token;
      return token;
    } catch (_) {
      return 'debug-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  void _startProbeLoop() {
    if (_watchdogPaused) return;
    _probeTimer?.cancel();
    _probeTimer = Timer.periodic(_probeInterval, (_) => _runProbe());
  }

  static bool _isFlutterWebCacheName(dynamic key) {
    final s = key.toString().toLowerCase();
    return s.contains('flutter');
  }

  Future<void> _runProbe() async {
    if (_fatalFirestoreAssertionDetected) return;
    final idleFor = DateTime.now().difference(_lastFirestoreActivity);
    if (idleFor < _idleBeforeProbe) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      // Read the signed-in user's profile doc (allowed by rules) instead of a
      // dedicated sentinel collection, which would spam "permission denied" in
      // the rules monitor every probe interval.
      //
      // Not-found on a brand-new account only proves the transport answered; it
      // does not prove arbitrary collections are healthy. Stronger option: a
      // tiny always-present metadata doc (requires rules + data model buy-in).
      await FirebaseFirestore.instance
          .collection(_usersCollection)
          .doc(uid)
          .get(const GetOptions(source: Source.server))
          .timeout(_probeTimeout);
      _lastFirestoreActivity = DateTime.now();
    } on TimeoutException {
      AppLogger.warning(
          'WebAppStability: Firestore probe timed out after ${_probeTimeout.inSeconds}s; bouncing network.');
      await forceRecover();
    } catch (e) {
      if (_isFatalFirestoreAssertion(e)) {
        _handleFatalFirestoreAssertion(e);
        return;
      }
      // Any other error (permission-denied, not-found) means the channel is
      // alive and rejecting our request as expected.
      _lastFirestoreActivity = DateTime.now();
      if (kDebugMode) {
        AppLogger.debug('WebAppStability: probe got non-timeout response: $e');
      }
    }
  }

  bool _isFatalFirestoreAssertion(Object error) {
    final s = error.toString().toUpperCase();
    return s.contains('FIRESTORE') &&
        s.contains('INTERNAL ASSERTION FAILED') &&
        s.contains('UNEXPECTED STATE');
  }

  void _handleFatalFirestoreAssertion(Object error) {
    if (_fatalFirestoreAssertionDetected) return;
    _fatalFirestoreAssertionDetected = true;
    _probeTimer?.cancel();
    _probeTimer = null;
    _state.value = _state.value.copyWith(
      anyScreenStuck: true,
      primaryStuckReason:
          'Firestore entered an internal fatal state in this browser tab. Please reload the page.',
    );
    AppLogger.error(
      'WebAppStability: fatal Firestore assertion detected; switching to reload-only mode. Error: $error',
    );
    _reloadOnceForFatalFirestoreAssertion();
  }

  void _reloadOnceForFatalFirestoreAssertion() {
    try {
      final storage = html.window.sessionStorage;
      final currentBuild = _currentBuildHash();
      final previous = storage[_fatalReloadKey];
      if (previous == currentBuild) {
        AppLogger.warning(
            'WebAppStability: fatal Firestore assertion already reloaded once for this build/session; showing reload banner.');
        return;
      }
      storage[_fatalReloadKey] = currentBuild;
      Future<void>.delayed(const Duration(milliseconds: 250), () {
        try {
          html.window.location.reload();
        } catch (e) {
          AppLogger.error('WebAppStability: fatal auto-reload failed: $e');
        }
      });
    } catch (e) {
      AppLogger.error('WebAppStability: fatal auto-reload setup failed: $e');
    }
  }

  void _clearFatalReloadMarkerIfFreshPageIsHealthy() {
    Future<void>.delayed(const Duration(seconds: 20), () {
      if (_fatalFirestoreAssertionDetected) return;
      try {
        html.window.sessionStorage.remove(_fatalReloadKey);
      } catch (_) {
        // ignore
      }
    });
  }
}
