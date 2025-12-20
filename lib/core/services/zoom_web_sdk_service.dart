import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import '../utils/app_logger.dart';

/// State machine for Zoom Web SDK join flow
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

/// JS interop for Zoom Web SDK functions
@JS('isZoomSDKAvailable')
external bool _isZoomSDKAvailable();

@JS('initZoomWebSDK')
external JSPromise<JSBoolean> _initZoomWebSDK();

@JS('joinZoomMeeting')
external JSPromise<JSBoolean> _joinZoomMeeting(JSObject config);

@JS('leaveZoomMeeting')
external JSPromise<JSBoolean> _leaveZoomMeeting();

@JS('resetZoomSDK')
external void _resetZoomSDK();

@JS('showZoomMeetingUI')
external void _showZoomMeetingUI(bool show);

@JS('setZoomStateCallback')
external void _setZoomStateCallback(JSFunction callback);

@JS('setZoomMeetingEndCallback')
external void _setZoomMeetingEndCallback(JSFunction callback);

/// Service for joining Zoom meetings using the Web SDK
/// This is the web implementation that uses JavaScript interop
class ZoomWebSdkService {
  static final ZoomWebSdkService _instance = ZoomWebSdkService._internal();
  factory ZoomWebSdkService() => _instance;
  ZoomWebSdkService._internal();

  // State management
  ZoomWebState _state = ZoomWebState.idle;
  ZoomWebState get state => _state;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  final StreamController<ZoomWebState> _stateController =
      StreamController<ZoomWebState>.broadcast();
  Stream<ZoomWebState> get stateStream => _stateController.stream;

  // Debounce to prevent double-tap
  bool _isJoining = false;
  DateTime? _lastJoinAttempt;
  static const Duration _joinDebounce = Duration(seconds: 2);

  /// Check if the Zoom Web SDK is available
  bool get isSDKAvailable {
    try {
      return _isZoomSDKAvailable();
    } catch (e) {
      AppLogger.warning('ZoomWebSdkService: SDK not available - $e');
      return false;
    }
  }

  /// Update state and notify listeners
  void _setState(ZoomWebState newState, {String? error}) {
    _state = newState;
    _errorMessage = error;
    _stateController.add(newState);
    AppLogger.debug('ZoomWebSdkService: State changed to $newState');
  }

  /// Initialize the Zoom Web SDK
  Future<bool> initialize() async {
    if (_state == ZoomWebState.initialized ||
        _state == ZoomWebState.inMeeting) {
      return true;
    }

    _setState(ZoomWebState.initializing);

    try {
      if (!isSDKAvailable) {
        throw Exception('Zoom Web SDK is not loaded');
      }

      final promise = _initZoomWebSDK();
      await promise.toDart;

      // Set up callbacks
      _setupCallbacks();

      _setState(ZoomWebState.initialized);
      AppLogger.info('ZoomWebSdkService: SDK initialized successfully');
      return true;
    } catch (e) {
      AppLogger.error('ZoomWebSdkService: Failed to initialize SDK - $e');
      _setState(ZoomWebState.error, error: 'Failed to load Zoom');
      return false;
    }
  }

  /// Set up JavaScript callbacks
  void _setupCallbacks() {
    try {
      // State change callback
      final stateCallback = ((JSString state) {
        final stateStr = state.toDart;
        AppLogger.debug('ZoomWebSdkService: JS state callback - $stateStr');
        _handleStateChange(stateStr);
      }).toJS;
      _setZoomStateCallback(stateCallback);

      // Meeting end callback
      final endCallback = (() {
        AppLogger.info('ZoomWebSdkService: Meeting ended via callback');
        _setState(ZoomWebState.ended);
        _isJoining = false;
      }).toJS;
      _setZoomMeetingEndCallback(endCallback);
    } catch (e) {
      AppLogger.warning('ZoomWebSdkService: Failed to set up callbacks - $e');
    }
  }

  /// Handle state change from JavaScript
  void _handleStateChange(String stateStr) {
    switch (stateStr) {
      case 'initialized':
        _setState(ZoomWebState.initialized);
        break;
      case 'joining':
        _setState(ZoomWebState.joining);
        break;
      case 'inMeeting':
        _setState(ZoomWebState.inMeeting);
        _isJoining = false;
        break;
      case 'ended':
        _setState(ZoomWebState.ended);
        _isJoining = false;
        break;
      case 'error':
        _setState(ZoomWebState.error);
        _isJoining = false;
        break;
    }
  }

  /// Join a Zoom meeting
  ///
  /// [meetingNumber] - The meeting ID
  /// [signature] - JWT signature from backend
  /// [displayName] - User's display name
  /// [password] - Meeting password (optional)
  /// [email] - User's email (optional)
  Future<bool> joinMeeting({
    required String meetingNumber,
    required String signature,
    required String sdkKey,
    required String displayName,
    String? password,
    String? email,
  }) async {
    // Debounce check
    if (_isJoining) {
      AppLogger.warning('ZoomWebSdkService: Join already in progress');
      return false;
    }

    final now = DateTime.now();
    if (_lastJoinAttempt != null &&
        now.difference(_lastJoinAttempt!) < _joinDebounce) {
      AppLogger.warning('ZoomWebSdkService: Join debounced');
      return false;
    }

    _isJoining = true;
    _lastJoinAttempt = now;

    try {
      // Ensure SDK is initialized
      if (_state != ZoomWebState.initialized) {
        final initialized = await initialize();
        if (!initialized) {
          throw Exception('Failed to initialize Zoom SDK');
        }
      }

      _setState(ZoomWebState.joining);

      // Create config object for JavaScript
      final config = {
        'meetingNumber': meetingNumber,
        'userName': displayName,
        'signature': signature,
        'sdkKey': sdkKey,
        'passWord': password ?? '',
        'userEmail': email ?? '',
        'lang': 'en-US',
        'leaveUrl': web.window.location.origin,
      }.jsify();

      AppLogger.info('ZoomWebSdkService: Joining meeting $meetingNumber');

      final promise = _joinZoomMeeting(config as JSObject);
      await promise.toDart;

      _setState(ZoomWebState.inMeeting);
      AppLogger.info('ZoomWebSdkService: Successfully joined meeting');
      return true;
    } catch (e) {
      AppLogger.error('ZoomWebSdkService: Failed to join meeting - $e');
      _setState(ZoomWebState.error, error: 'Failed to join meeting: $e');
      _isJoining = false;
      return false;
    }
  }

  /// Leave the current meeting
  Future<bool> leaveMeeting() async {
    if (_state != ZoomWebState.inMeeting) {
      return true;
    }

    try {
      final promise = _leaveZoomMeeting();
      await promise.toDart;

      _setState(ZoomWebState.ended);
      AppLogger.info('ZoomWebSdkService: Left meeting');
      return true;
    } catch (e) {
      AppLogger.error('ZoomWebSdkService: Failed to leave meeting - $e');
      return false;
    }
  }

  /// Show or hide the Zoom meeting UI
  void showMeetingUI(bool show) {
    try {
      _showZoomMeetingUI(show);
    } catch (e) {
      AppLogger.warning('ZoomWebSdkService: Failed to toggle meeting UI - $e');
    }
  }

  /// Reset the SDK state
  void reset() {
    try {
      _resetZoomSDK();
    } catch (e) {
      // Ignore reset errors
    }
    _state = ZoomWebState.idle;
    _errorMessage = null;
    _isJoining = false;
    _lastJoinAttempt = null;
  }

  /// Cancel the current join attempt
  void cancelJoin() {
    if (_state == ZoomWebState.joining) {
      _setState(ZoomWebState.idle);
      _isJoining = false;
      AppLogger.info('ZoomWebSdkService: Join cancelled');
    }
  }

  /// Dispose of the service
  Future<void> dispose() async {
    reset();
    await _stateController.close();
  }
}
