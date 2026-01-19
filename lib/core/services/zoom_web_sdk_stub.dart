// Stub file for non-web platforms (iOS, Android)
// This file is imported when dart.library.io is available (non-web)

/// State machine for Zoom Web SDK join flow (stub)
enum ZoomWebState {
  idle,
  initializing,
  initialized,
  joining,
  inMeeting,
  ended,
  error,
}

/// Extension to provide progress messages for each state
extension ZoomWebStateMessages on ZoomWebState {
  String get progressMessage {
    switch (this) {
      case ZoomWebState.idle:
        return 'Ready to join';
      case ZoomWebState.initializing:
        return 'Loading Zoom...';
      case ZoomWebState.initialized:
        return 'Zoom ready';
      case ZoomWebState.joining:
        return 'Joining meeting...';
      case ZoomWebState.inMeeting:
        return 'In meeting';
      case ZoomWebState.ended:
        return 'Meeting ended';
      case ZoomWebState.error:
        return 'Error occurred';
    }
  }
}

/// Stub service for non-web platforms
/// This class is never actually used on mobile, but needed for compilation
class ZoomWebSdkService {
  static final ZoomWebSdkService _instance = ZoomWebSdkService._internal();
  factory ZoomWebSdkService() => _instance;
  ZoomWebSdkService._internal();

  ZoomWebState get state => ZoomWebState.idle;
  String? get errorMessage => null;
  Stream<ZoomWebState> get stateStream => const Stream.empty();
  bool get isSDKAvailable => false;

  Future<bool> initialize() async => false;

  Future<bool> joinMeeting({
    required String meetingNumber,
    required String signature,
    required String sdkKey,
    required String displayName,
    String? password,
    String? email,
  }) async => false;

  Future<bool> leaveMeeting() async => false;
  void showMeetingUI(bool show) {}
  void reset() {}
  void cancelJoin() {}
  Future<void> dispose() async {}
}
