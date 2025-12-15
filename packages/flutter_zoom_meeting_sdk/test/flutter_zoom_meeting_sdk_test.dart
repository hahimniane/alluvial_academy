import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zoom_meeting_sdk/flutter_zoom_meeting_sdk.dart';
import 'package:flutter_zoom_meeting_sdk/flutter_zoom_meeting_sdk_platform_interface.dart';
import 'package:flutter_zoom_meeting_sdk/flutter_zoom_meeting_sdk_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:flutter_zoom_meeting_sdk/models/flutter_zoom_meeting_sdk_action_response.dart';
import 'package:flutter_zoom_meeting_sdk/models/flutter_zoom_meeting_sdk_event_response.dart';
import 'package:flutter_zoom_meeting_sdk/models/jwt_response.dart';
import 'package:flutter_zoom_meeting_sdk/models/zoom_meeting_sdk_request.dart';

class MockFlutterZoomMeetingSdkPlatform
    with MockPlatformInterfaceMixin
    implements FlutterZoomMeetingSdkPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Stream<FlutterZoomMeetingSdkEventResponse<EventAuthenticateReturnParams>>
  get onAuthenticationReturn => const Stream.empty();

  @override
  Stream<FlutterZoomMeetingSdkEventResponse<EventMeetingEndedReasonParams>>
  get onMeetingEndedReason => const Stream.empty();

  @override
  Stream<FlutterZoomMeetingSdkEventResponse<EventMeetingErrorParams>>
  get onMeetingError => const Stream.empty();

  @override
  Stream<
    FlutterZoomMeetingSdkEventResponse<EventMeetingParameterNotificationParams>
  >
  get onMeetingParameterNotification => const Stream.empty();

  @override
  Stream<FlutterZoomMeetingSdkEventResponse<EventMeetingStatusChangedParams>>
  get onMeetingStatusChanged => const Stream.empty();

  @override
  Stream<FlutterZoomMeetingSdkEventResponse> get onZoomAuthIdentityExpired =>
      const Stream.empty();

  @override
  Future<FlutterZoomMeetingSdkActionResponse<AuthParamsResponse>> authZoom({
    required String jwtToken,
  }) => throw UnimplementedError();

  @override
  Future<JwtResponse?> getJWTToken({
    required String authEndpoint,
    required String meetingNumber,
    required int role,
  }) => throw UnimplementedError();

  @override
  Future<FlutterZoomMeetingSdkActionResponse<InitParamsResponse>> initZoom() =>
      throw UnimplementedError();

  @override
  Future<FlutterZoomMeetingSdkActionResponse<JoinParamsResponse>> joinMeeting(
    ZoomMeetingSdkRequest request,
  ) => throw UnimplementedError();

  @override
  Future<FlutterZoomMeetingSdkActionResponse> unInitZoom() =>
      throw UnimplementedError();
}

void main() {
  final FlutterZoomMeetingSdkPlatform initialPlatform =
      FlutterZoomMeetingSdkPlatform.instance;

  test('$MethodChannelFlutterZoomMeetingSdk is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterZoomMeetingSdk>());
  });

  test('getPlatformVersion', () async {
    FlutterZoomMeetingSdk flutterZoomMeetingSdkPlugin = FlutterZoomMeetingSdk();
    MockFlutterZoomMeetingSdkPlatform fakePlatform =
        MockFlutterZoomMeetingSdkPlatform();
    FlutterZoomMeetingSdkPlatform.instance = fakePlatform;

    expect(await flutterZoomMeetingSdkPlugin.getPlatformVersion(), '42');
  });
}
