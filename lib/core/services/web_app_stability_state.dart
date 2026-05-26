/// Shared state surface for [WebAppStabilityService].
///
/// Lives in its own file so the conditional stub/web implementations and the
/// rest of the app can share types without a circular import via the public
/// `web_app_stability_service.dart` entry point.
class WebAppStabilityState {
  const WebAppStabilityState({
    this.anyScreenStuck = false,
    this.primaryStuckReason,
    this.isRecovering = false,
    this.lastRecoveryAt,
  });

  /// At least one screen has reported being stuck and is still unresolved.
  final bool anyScreenStuck;

  /// Human-readable reason from whichever screen most recently reported stuck.
  /// Used for the global overlay subtitle.
  final String? primaryStuckReason;

  /// True while a forceRecover() round-trip is in flight so the overlay can
  /// show a spinner instead of an action button.
  final bool isRecovering;

  /// Timestamp of the most recent successful recovery cycle. Screens may
  /// listen for changes and re-subscribe Firestore streams; a network bounce
  /// alone does not always revive wedged web listeners.
  final DateTime? lastRecoveryAt;

  WebAppStabilityState copyWith({
    bool? anyScreenStuck,
    Object? primaryStuckReason = _sentinel,
    bool? isRecovering,
    Object? lastRecoveryAt = _sentinel,
  }) {
    return WebAppStabilityState(
      anyScreenStuck: anyScreenStuck ?? this.anyScreenStuck,
      primaryStuckReason: identical(primaryStuckReason, _sentinel)
          ? this.primaryStuckReason
          : primaryStuckReason as String?,
      isRecovering: isRecovering ?? this.isRecovering,
      lastRecoveryAt: identical(lastRecoveryAt, _sentinel)
          ? this.lastRecoveryAt
          : lastRecoveryAt as DateTime?,
    );
  }

  static const Object _sentinel = Object();
}
