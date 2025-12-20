import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_zoom_meeting_sdk/flutter_zoom_meeting_sdk.dart';
import 'package:flutter_zoom_meeting_sdk/models/zoom_meeting_sdk_request.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/app_logger.dart';

/// State machine for Zoom Meeting SDK join flow
enum ZoomJoinState {
  idle,
  preflight,
  fetchingPayload,
  sdkInitializing,
  sdkAuthenticating,
  joining,
  inMeeting,
  ended,
  error,
}

/// Progress messages for each state
extension ZoomJoinStateMessages on ZoomJoinState {
  String get progressMessage {
    switch (this) {
      case ZoomJoinState.idle:
        return 'Ready to join';
      case ZoomJoinState.preflight:
        return 'Preparing to join...';
      case ZoomJoinState.fetchingPayload:
        return 'Getting meeting details...';
      case ZoomJoinState.sdkInitializing:
        return 'Initializing Zoom...';
      case ZoomJoinState.sdkAuthenticating:
        return 'Authenticating...';
      case ZoomJoinState.joining:
        return 'Joining meeting...';
      case ZoomJoinState.inMeeting:
        return 'In meeting';
      case ZoomJoinState.ended:
        return 'Meeting ended';
      case ZoomJoinState.error:
        return 'Error occurred';
    }
  }
}

/// Error types for join failures
enum ZoomJoinErrorType {
  unauthenticated,
  permissionDenied,
  tooEarly,
  tooLate,
  notFound,
  networkError,
  sdkAuthFailed,
  joinFailed,
  wrongPasscode,
  cancelled,
  unknown,
}

/// Join error with type and message
class ZoomJoinError {
  final ZoomJoinErrorType type;
  final String message;
  final String? detail;

  ZoomJoinError({
    required this.type,
    required this.message,
    this.detail,
  });

  @override
  String toString() => 'ZoomJoinError($type): $message';
}

/// Payload received from backend for SDK join
class ZoomSdkJoinPayload {
  final String shiftId;
  final String meetingNumber;
  final String meetingPasscode;
  final String meetingSdkJwt;
  final String displayName;
  final DateTime allowedStart;
  final DateTime allowedEnd;

  ZoomSdkJoinPayload({
    required this.shiftId,
    required this.meetingNumber,
    required this.meetingPasscode,
    required this.meetingSdkJwt,
    required this.displayName,
    required this.allowedStart,
    required this.allowedEnd,
  });

  factory ZoomSdkJoinPayload.fromMap(Map<String, dynamic> data) {
    final joinWindow = data['joinWindow'] is Map
        ? Map<String, dynamic>.from(data['joinWindow'] as Map)
        : {};
    return ZoomSdkJoinPayload(
      shiftId: data['shiftId']?.toString() ?? '',
      meetingNumber: data['meetingNumber']?.toString() ?? '',
      meetingPasscode: data['meetingPasscode']?.toString() ?? '',
      meetingSdkJwt: data['meetingSdkJwt']?.toString() ?? '',
      displayName: data['displayName']?.toString() ?? 'Participant',
      allowedStart:
          DateTime.tryParse(joinWindow['allowedStartIso']?.toString() ?? '') ??
              DateTime.now(),
      allowedEnd:
          DateTime.tryParse(joinWindow['allowedEndIso']?.toString() ?? '') ??
              DateTime.now(),
    );
  }
}

/// Service for joining Zoom meetings using the native Meeting SDK
///
/// This service handles the complete join flow:
/// 1. Fetch join payload from backend (meeting number, passcode, JWT)
/// 2. Initialize Zoom SDK
/// 3. Authenticate with SDK JWT
/// 4. Join meeting with meeting number and passcode
///
/// IMPORTANT: This requires the Zoom Meeting SDK binaries to be integrated.
/// See tools/setup_zoom_meeting_sdk.sh for setup instructions.
class ZoomMeetingSdkJoinService {
  static final ZoomMeetingSdkJoinService _instance =
      ZoomMeetingSdkJoinService._internal();
  factory ZoomMeetingSdkJoinService() => _instance;
  ZoomMeetingSdkJoinService._internal();

  // Singleton state
  bool _sdkInitialized = false;
  bool _sdkAuthenticated = false;

  // Instances that can be overridden for testing
  @visibleForTesting
  FlutterZoomMeetingSdk? zoomSdkOverride;

  @visibleForTesting
  FirebaseFunctions? functionsOverride;

  FlutterZoomMeetingSdk get _zoomSdk =>
      zoomSdkOverride ?? FlutterZoomMeetingSdk();
  FirebaseFunctions get _functions =>
      functionsOverride ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  // Join state management
  ZoomJoinState _state = ZoomJoinState.idle;
  ZoomJoinState get state => _state;

  final StreamController<ZoomJoinState> _stateController =
      StreamController<ZoomJoinState>.broadcast();
  Stream<ZoomJoinState> get stateStream => _stateController.stream;

  // Debounce to prevent double-tap
  bool _isJoining = false;
  DateTime? _lastJoinAttempt;
  static const Duration _joinDebounce = Duration(seconds: 2);
  String? _currentShiftId;

  /// Update state and notify listeners
  void _setState(ZoomJoinState newState) {
    _state = newState;
    _stateController.add(newState);
    AppLogger.debug('ZoomMeetingSdkJoinService: State changed to $newState');
  }

  /// Request microphone and camera permissions
  Future<void> _requestPermissions() async {
    if (kIsWeb) return; // Web doesn't use permission_handler

    try {
      final micStatus = await Permission.microphone.request();
      final cameraStatus = await Permission.camera.request();

      AppLogger.debug('ZoomMeetingSdkJoinService: Mic permission: $micStatus');
      AppLogger.debug(
          'ZoomMeetingSdkJoinService: Camera permission: $cameraStatus');

      // Don't fail if permissions denied - user can join muted
    } catch (e) {
      AppLogger.warning(
          'ZoomMeetingSdkJoinService: Permission request error: $e');
    }
  }

  /// Fetch join payload from backend
  Future<ZoomSdkJoinPayload> _fetchJoinPayload(String shiftId) async {
    _setState(ZoomJoinState.fetchingPayload);

    try {
      final callable = _functions.httpsCallable('getZoomMeetingSdkJoinPayload');
      final result = await callable.call({'shiftId': shiftId});

      final rawData = result.data;
      if (rawData == null) {
        throw Exception('Received null data from getZoomMeetingSdkJoinPayload');
      }

      // Safer map conversion
      final data = Map<String, dynamic>.from(rawData as Map);

      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Failed to get join payload');
      }

      return ZoomSdkJoinPayload.fromMap(data);
    } on FirebaseFunctionsException catch (e) {
      AppLogger.error(
          'ZoomMeetingSdkJoinService: Firebase Functions error: ${e.code}');
      throw _mapFirebaseError(e);
    } catch (e) {
      AppLogger.error('ZoomMeetingSdkJoinService: Payload fetch error: $e');
      throw ZoomJoinError(
        type: ZoomJoinErrorType.unknown,
        message: 'Failed to load meeting details.',
        detail: 'Parse error: ${e.toString()}',
      );
    }
  }

  /// Fetch Zoom host key for teachers to claim host status
  Future<String?> _fetchHostKey(String shiftId) async {
    try {
      AppLogger.debug(
          'ZoomMeetingSdkJoinService: Fetching host key for shift $shiftId');
      final callable = _functions.httpsCallable('getZoomHostKey');

      // Explicitly log what we are sending
      final dataParams = {'shiftId': shiftId};
      AppLogger.debug(
          'ZoomMeetingSdkJoinService: Calling getZoomHostKey with $dataParams');

      final result = await callable.call(dataParams);

      final data = Map<String, dynamic>.from(result.data as Map);
      AppLogger.debug('ZoomMeetingSdkJoinService: host key result: $data');
      return data['hostKey']?.toString();
    } catch (e) {
      // Don't fail the whole join flow if host key fetch fails, just log it
      // For non-teachers, this will fail with permission-denied which is expected
      AppLogger.warning(
          'ZoomMeetingSdkJoinService: Could not fetch host key for shift $shiftId: $e');
      return null;
    }
  }

  /// Map Firebase Functions errors to ZoomJoinError
  ZoomJoinError _mapFirebaseError(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'unauthenticated':
        return ZoomJoinError(
          type: ZoomJoinErrorType.unauthenticated,
          message: 'Please log in to join the meeting.',
        );
      case 'permission-denied':
        return ZoomJoinError(
          type: ZoomJoinErrorType.permissionDenied,
          message: "You're not allowed to join this meeting.",
        );
      case 'invalid-argument':
        return ZoomJoinError(
          type: ZoomJoinErrorType.unknown,
          message: 'Meeting configuration error.',
          detail: 'Backend missing shiftId: ${e.message}',
        );
      case 'failed-precondition':
        final message = e.message ?? '';
        if (message.contains('wait') || message.contains('before')) {
          return ZoomJoinError(
            type: ZoomJoinErrorType.tooEarly,
            message: message,
          );
        }
        return ZoomJoinError(
          type: ZoomJoinErrorType.tooLate,
          message: 'The meeting window has ended.',
        );
      case 'not-found':
        return ZoomJoinError(
          type: ZoomJoinErrorType.notFound,
          message: 'Meeting not configured for this shift.',
        );
      case 'unavailable':
      case 'internal':
      default:
        return ZoomJoinError(
          type: ZoomJoinErrorType.networkError,
          message: "Couldn't connect. Please try again.",
          detail: e.message,
        );
    }
  }

  /// Initialize Zoom SDK (once per app session)
  Future<void> _initializeSdk() async {
    if (_sdkInitialized) {
      AppLogger.debug('ZoomMeetingSdkJoinService: SDK already initialized');
      return;
    }

    _setState(ZoomJoinState.sdkInitializing);

    try {
      AppLogger.debug('ZoomMeetingSdkJoinService: Initializing native SDK');
      final response = await _zoomSdk.initZoom();

      if (!response.isSuccess) {
        throw Exception('Native init failed: ${response.message}');
      }

      _sdkInitialized = true;
      AppLogger.info('ZoomMeetingSdkJoinService: SDK initialized successfully');
    } catch (e) {
      AppLogger.error('ZoomMeetingSdkJoinService: SDK init failed: $e');
      throw ZoomJoinError(
        type: ZoomJoinErrorType.unknown,
        message: 'Failed to initialize Zoom.',
        detail: 'Exception during init: ${e.toString()}',
      );
    }
  }

  /// Authenticate SDK with JWT
  Future<void> _authenticateSdk(String jwt) async {
    if (_sdkAuthenticated) return;

    _setState(ZoomJoinState.sdkAuthenticating);

    try {
      // Set up auth listener
      final completer = Completer<bool>();

      _zoomSdk.onAuthenticationReturn.listen((result) {
        AppLogger.warning('ZoomMeetingSdkJoinService: Auth result received');
        if (result.params != null) {
          final params = result.params!;
          AppLogger.warning(
              'ZoomMeetingSdkJoinService: Auth Status Code: ${params.statusCode}');
          AppLogger.warning(
              'ZoomMeetingSdkJoinService: Auth Status Label: ${params.statusLabel}');
          AppLogger.warning(
              'ZoomMeetingSdkJoinService: Auth Status Enum: ${params.statusEnum}');
          if (params.internalErrorCode != null) {
            AppLogger.warning(
                'ZoomMeetingSdkJoinService: Internal Error Code: ${params.internalErrorCode}');
          }
        } else {
          AppLogger.warning('ZoomMeetingSdkJoinService: Auth params is null');
        }

        if (!completer.isCompleted) {
          // result is typically 0 for success
          // Check for success based on status code (0 usually means success)
          final isSuccess = result.params?.statusCode == 0;
          completer.complete(isSuccess);
        }
      });

      // Authenticate
      AppLogger.warning('ZoomMeetingSdkJoinService: Calling authZoom with JWT');
      await _zoomSdk.authZoom(jwtToken: jwt);

      // Wait for auth result with timeout
      final success = await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => false,
      );

      if (!success) {
        throw ZoomJoinError(
          type: ZoomJoinErrorType.sdkAuthFailed,
          message: 'Failed to authenticate Zoom session.',
        );
      }

      _sdkAuthenticated = true;
      AppLogger.info('ZoomMeetingSdkJoinService: SDK authenticated');
    } catch (e) {
      // Log raw error before rethrowing custom error
      AppLogger.warning('ZoomMeetingSdkJoinService: Raw auth error: $e');

      if (e is ZoomJoinError) rethrow;
      AppLogger.error('ZoomMeetingSdkJoinService: SDK auth failed: $e');
      throw ZoomJoinError(
        type: ZoomJoinErrorType.sdkAuthFailed,
        message: 'Unable to authenticate Zoom session.',
        detail: e.toString(),
      );
    }
  }

  /// Join the meeting
  Future<void> _joinMeeting({
    required String meetingNumber,
    required String passcode,
    required String displayName,
    String? hostKey,
  }) async {
    _setState(ZoomJoinState.joining);

    try {
      final request = ZoomMeetingSdkRequest(
        meetingNumber: meetingNumber,
        password: passcode,
        displayName: displayName,
      );

      await _zoomSdk.joinMeeting(request);
      _setState(ZoomJoinState.inMeeting);
      AppLogger.info('ZoomMeetingSdkJoinService: Joined meeting');

      // If we have a host key, attempt to claim host status
      if (hostKey != null && hostKey.isNotEmpty) {
        AppLogger.info(
            'ZoomMeetingSdkJoinService: Attempting to claim host with key');
        try {
          // Native SDK method: claimHostWithHostKey
          // We assume the Flutter wrapper exposes this as claimHost
          await _zoomSdk.claimHost(hostKey: hostKey);
          AppLogger.info(
              'ZoomMeetingSdkJoinService: Successfully claimed host status');

          // Notify backend that host has claimed and will open rooms
          // This cancels the backup bot
          try {
            AppLogger.info(
                'ZoomMeetingSdkJoinService: Marking breakout rooms as opened/handled by teacher');
            final callable =
                _functions.httpsCallable('markBreakoutRoomsOpened');
            await callable.call({'shiftId': _currentShiftId});
          } catch (e) {
            AppLogger.warning(
                'ZoomMeetingSdkJoinService: Failed to mark rooms as opened: $e');
          }
        } catch (e) {
          AppLogger.warning(
              'ZoomMeetingSdkJoinService: Failed to claim host status: $e');
          // Don't fail the join process if claiming host fails
        }
      }
    } catch (e) {
      AppLogger.error('ZoomMeetingSdkJoinService: Join failed: $e');

      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('password') || errorStr.contains('passcode')) {
        throw ZoomJoinError(
          type: ZoomJoinErrorType.wrongPasscode,
          message: 'Meeting password incorrect. Contact support.',
        );
      }

      throw ZoomJoinError(
        type: ZoomJoinErrorType.joinFailed,
        message: 'Failed to join meeting.',
        detail: e.toString(),
      );
    }
  }

  /// Main join method - orchestrates the complete join flow
  ///
  /// Returns true if join was successful, false if cancelled or failed.
  /// Throws ZoomJoinError on failure.
  Future<bool> joinShift({
    required String shiftId,
    String? customDisplayName,
  }) async {
    // Debounce check
    if (_isJoining) {
      AppLogger.warning('ZoomMeetingSdkJoinService: Join already in progress');
      return false;
    }

    final now = DateTime.now();
    if (_lastJoinAttempt != null &&
        now.difference(_lastJoinAttempt!) < _joinDebounce) {
      AppLogger.warning('ZoomMeetingSdkJoinService: Join debounced');
      return false;
    }

    _isJoining = true;
    _lastJoinAttempt = now;

    try {
      // Web platform check
      if (kIsWeb) {
        throw ZoomJoinError(
          type: ZoomJoinErrorType.unknown,
          message: 'In-app Zoom join is only available on mobile devices.',
        );
      }

      // Preflight
      _setState(ZoomJoinState.preflight);
      await _requestPermissions();

      _currentShiftId = shiftId;

      // Fetch payload from backend
      final payload = await _fetchJoinPayload(shiftId);

      // Fetch host key if available (usually for teachers)
      final hostKey = await _fetchHostKey(shiftId);

      // Initialize SDK
      await _initializeSdk();

      // Authenticate SDK (with retry logic)
      bool authSuccess = false;
      int authRetries = 0;

      while (!authSuccess && authRetries < 2) {
        try {
          _sdkAuthenticated = false; // Force re-auth
          await _authenticateSdk(payload.meetingSdkJwt);
          authSuccess = true;
        } catch (e) {
          authRetries++;
          if (authRetries >= 2) rethrow;
          AppLogger.warning(
              'ZoomMeetingSdkJoinService: Auth retry $authRetries');
          await Future.delayed(const Duration(seconds: 1));
        }
      }

      // Join meeting
      await _joinMeeting(
        meetingNumber: payload.meetingNumber,
        passcode: payload.meetingPasscode,
        displayName: customDisplayName ?? payload.displayName,
        hostKey: hostKey,
      );

      return true;
    } catch (e) {
      _setState(ZoomJoinState.error);
      if (e is ZoomJoinError) {
        rethrow;
      }
      throw ZoomJoinError(
        type: ZoomJoinErrorType.unknown,
        message: 'An unexpected error occurred.',
        detail: e.toString(),
      );
    } finally {
      _isJoining = false;
    }
  }

  /// Cancel the current join attempt
  void cancelJoin() {
    if (_state != ZoomJoinState.idle &&
        _state != ZoomJoinState.inMeeting &&
        _state != ZoomJoinState.ended) {
      _setState(ZoomJoinState.idle);
      _isJoining = false;
      AppLogger.info('ZoomMeetingSdkJoinService: Join cancelled');
    }
  }

  /// Leave the current meeting
  Future<void> leaveMeeting() async {
    if (_state == ZoomJoinState.inMeeting) {
      try {
        // SDK should handle leave automatically
        _setState(ZoomJoinState.ended);
        AppLogger.info('ZoomMeetingSdkJoinService: Left meeting');
      } catch (e) {
        AppLogger.error('ZoomMeetingSdkJoinService: Leave meeting error: $e');
      }
    }
  }

  /// Reset state to idle
  void reset() {
    _setState(ZoomJoinState.idle);
    _isJoining = false;
    _lastJoinAttempt = null;
    _sdkInitialized = false;
    _sdkAuthenticated = false;
  }

  /// Clean up SDK resources
  /// Call this when the app is being disposed
  Future<void> dispose() async {
    try {
      if (_sdkInitialized) {
        await _zoomSdk.unInitZoom();
        _sdkInitialized = false;
        _sdkAuthenticated = false;
        AppLogger.info('ZoomMeetingSdkJoinService: SDK disposed');
      }
    } catch (e) {
      AppLogger.error('ZoomMeetingSdkJoinService: Dispose error: $e');
    }

    await _stateController.close();
  }
}
