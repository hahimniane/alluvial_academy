import 'package:flutter/foundation.dart';

import 'web_app_stability_state.dart';

export 'web_app_stability_state.dart';

/// No-op implementation used on every platform that is not Flutter Web.
///
/// Mobile/desktop builds do not run into the Firestore WebChannel stalls or
/// service-worker staleness this service is designed to mitigate, so we keep a
/// trivial singleton with the same API surface as the web implementation.
class WebAppStabilityService {
  WebAppStabilityService._();

  static final WebAppStabilityService _instance = WebAppStabilityService._();
  static WebAppStabilityService get instance => _instance;

  final ValueNotifier<WebAppStabilityState> _state =
      ValueNotifier(const WebAppStabilityState());

  ValueListenable<WebAppStabilityState> get state => _state;

  Future<void> initialize() async {}

  void setWatchdogPaused(bool paused) {}

  void pokeFirestoreActivity() {}

  void reportScreenStuck({required String screenId, required String reason}) {}

  void clearScreenStuck(String screenId) {}

  void noteFirestoreError(Object error) {}

  Future<void> forceRecover() async {}

  Future<void> hardReload() async {}
}
