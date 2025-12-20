import 'package:flutter_zoom_meeting_sdk/models/flutter_zoom_meeting_sdk_action_response.dart';
import 'package:flutter_zoom_meeting_sdk/models/flutter_zoom_meeting_sdk_event_response.dart';
import 'package:flutter_zoom_meeting_sdk/models/jwt_response.dart';
import 'package:flutter_zoom_meeting_sdk/models/zoom_meeting_sdk_request.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_zoom_meeting_sdk_method_channel.dart';

abstract class FlutterZoomMeetingSdkPlatform extends PlatformInterface {
  /// Constructs a FlutterZoomMeetingSdkPlatform.
  FlutterZoomMeetingSdkPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterZoomMeetingSdkPlatform _instance =
      MethodChannelFlutterZoomMeetingSdk();

  /// The default instance of [FlutterZoomMeetingSdkPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterZoomMeetingSdk].
  static FlutterZoomMeetingSdkPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterZoomMeetingSdkPlatform] when
  /// they register themselves.
  static set instance(FlutterZoomMeetingSdkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  // ======== Events =========

  // ====== Auth Events ======

  /// mac | ios | android | windows
  Stream<FlutterZoomMeetingSdkEventResponse<EventAuthenticateReturnParams>>
  get onAuthenticationReturn;

  /// mac | ios | android | windows
  Stream<FlutterZoomMeetingSdkEventResponse> get onZoomAuthIdentityExpired;

  // Meeting Events

  /// mac | ios | android | windows
  Stream<FlutterZoomMeetingSdkEventResponse<EventMeetingStatusChangedParams>>
  get onMeetingStatusChanged;

  /// mac | ios | android | windows
  Stream<
    FlutterZoomMeetingSdkEventResponse<EventMeetingParameterNotificationParams>
  >
  get onMeetingParameterNotification;

  /// ios
  Stream<FlutterZoomMeetingSdkEventResponse<EventMeetingErrorParams>>
  get onMeetingError;

  /// ios
  Stream<FlutterZoomMeetingSdkEventResponse<EventMeetingEndedReasonParams>>
  get onMeetingEndedReason;

  // ---

  // ======= Functions =======

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<FlutterZoomMeetingSdkActionResponse<InitParamsResponse>> initZoom() {
    throw UnimplementedError('initZoom() has not been implemented.');
  }

  Future<FlutterZoomMeetingSdkActionResponse<AuthParamsResponse>> authZoom({
    required String jwtToken,
  }) {
    throw UnimplementedError('authZoom() has not been implemented.');
  }

  Future<FlutterZoomMeetingSdkActionResponse<JoinParamsResponse>> joinMeeting(
    ZoomMeetingSdkRequest request,
  ) {
    throw UnimplementedError('joinMeeting() has not been implemented.');
  }

  Future<JwtResponse?> getJWTToken({
    required String authEndpoint,
    required String meetingNumber,
    required int role,
  }) {
    throw UnimplementedError('getJWTToken() has not been implemented.');
  }

  Future<FlutterZoomMeetingSdkActionResponse> unInitZoom() {
    throw UnimplementedError('unInitZoom() has not been implemented.');
  }

  Future<FlutterZoomMeetingSdkActionResponse> claimHost({
    required String hostKey,
  }) {
    throw UnimplementedError('claimHost() has not been implemented.');
  }
}
