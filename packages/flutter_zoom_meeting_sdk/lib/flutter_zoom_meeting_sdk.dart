import 'package:flutter_zoom_meeting_sdk/models/flutter_zoom_meeting_sdk_action_response.dart';
import 'package:flutter_zoom_meeting_sdk/models/flutter_zoom_meeting_sdk_event_response.dart';
import 'package:flutter_zoom_meeting_sdk/models/jwt_response.dart';
import 'package:flutter_zoom_meeting_sdk/models/zoom_meeting_sdk_request.dart';
import 'flutter_zoom_meeting_sdk_platform_interface.dart';

export 'models/zoom_meeting_sdk_response.dart';

class FlutterZoomMeetingSdk {
  // ======== Events =========

  // ====== Auth Events ======

  /// mac | ios | android | windows
  /// Triggered when the SDK authentication succeeds or fails.
  Stream<FlutterZoomMeetingSdkEventResponse<EventAuthenticateReturnParams>>
  get onAuthenticationReturn =>
      FlutterZoomMeetingSdkPlatform.instance.onAuthenticationReturn;

  /// mac | ios | android | windows
  /// Triggered when the JWT token is expired. Generate a new token.
  Stream<FlutterZoomMeetingSdkEventResponse> get onZoomAuthIdentityExpired =>
      FlutterZoomMeetingSdkPlatform.instance.onZoomAuthIdentityExpired;

  // ====== Meeting Events ======

  /// mac | ios | android | windows
  /// Triggered when the meeting status changes.
  Stream<FlutterZoomMeetingSdkEventResponse<EventMeetingStatusChangedParams>>
  get onMeetingStatusChanged =>
      FlutterZoomMeetingSdkPlatform.instance.onMeetingStatusChanged;

  /// mac | ios | android | windows
  /// Triggered right before the meeting starts.
  Stream<
    FlutterZoomMeetingSdkEventResponse<EventMeetingParameterNotificationParams>
  >
  get onMeetingParameterNotification =>
      FlutterZoomMeetingSdkPlatform.instance.onMeetingParameterNotification;

  /// ios
  /// Triggered when a meeting encounters an error
  Stream<FlutterZoomMeetingSdkEventResponse<EventMeetingErrorParams>>
  get onMeetingError => FlutterZoomMeetingSdkPlatform.instance.onMeetingError;

  /// ios
  /// Triggered when a meeting ends, providing the end reason.
  Stream<FlutterZoomMeetingSdkEventResponse<EventMeetingEndedReasonParams>>
  get onMeetingEndedReason =>
      FlutterZoomMeetingSdkPlatform.instance.onMeetingEndedReason;

  // ---

  // ======= Functions =======

  Future<String?> getPlatformVersion() {
    return FlutterZoomMeetingSdkPlatform.instance.getPlatformVersion();
  }

  /// Initialize the SDK
  Future<FlutterZoomMeetingSdkActionResponse<InitParamsResponse>> initZoom() {
    return FlutterZoomMeetingSdkPlatform.instance.initZoom();
  }

  /// Authenticate the SDK
  Future<FlutterZoomMeetingSdkActionResponse<AuthParamsResponse>> authZoom({
    required String jwtToken,
  }) {
    return FlutterZoomMeetingSdkPlatform.instance.authZoom(jwtToken: jwtToken);
  }

  /// Join a meeting
  Future<FlutterZoomMeetingSdkActionResponse<JoinParamsResponse>> joinMeeting(
    ZoomMeetingSdkRequest request,
  ) {
    return FlutterZoomMeetingSdkPlatform.instance.joinMeeting(request);
  }

  /// Uninitialize the SDK
  Future<FlutterZoomMeetingSdkActionResponse> unInitZoom() {
    return FlutterZoomMeetingSdkPlatform.instance.unInitZoom();
  }

  /// Get a JWT token
  Future<JwtResponse?> getJWTToken({
    required String authEndpoint,
    required String meetingNumber,
    required int role,
  }) {
    return FlutterZoomMeetingSdkPlatform.instance.getJWTToken(
      authEndpoint: authEndpoint,
      meetingNumber: meetingNumber,
      role: role,
    );
  }

  /// Claim host status using a 6-digit host key
  Future<FlutterZoomMeetingSdkActionResponse> claimHost({
    required String hostKey,
  }) {
    return FlutterZoomMeetingSdkPlatform.instance.claimHost(hostKey: hostKey);
  }
}
