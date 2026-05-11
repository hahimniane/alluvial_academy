// Public entry point for the web stability service.
//
// On web (`dart.library.html` is available) this resolves to the real
// implementation that unregisters stale service workers, evicts cache-storage
// entries from prior deploys, and runs a Firestore WebChannel watchdog. On
// non-web platforms it resolves to a no-op stub so callers can use one
// import across platforms without `kIsWeb` guards everywhere.
//
// After a successful [WebAppStabilityService.forceRecover], screens that use
// long-lived Firestore `.snapshots()` listeners should react to
// [WebAppStabilityState.lastRecoveryAt] (or listen to [WebAppStabilityService.state])
// and re-subscribe; bouncing the network alone does not always revive wedged
// web listeners.
export 'web_app_stability_service_stub.dart'
    if (dart.library.html) 'web_app_stability_service_web.dart';
