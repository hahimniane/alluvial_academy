import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_zoom_meeting_sdk/enums/event_type.dart';
import 'package:flutter_zoom_meeting_sdk/models/flutter_zoom_meeting_sdk_action_response.dart';
import 'package:flutter_zoom_meeting_sdk/models/flutter_zoom_meeting_sdk_event_response.dart';
import 'package:flutter_zoom_meeting_sdk/models/jwt_response.dart';
import 'package:flutter_zoom_meeting_sdk/models/zoom_meeting_sdk_request.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'flutter_zoom_meeting_sdk_platform_interface.dart';

/// An implementation of [FlutterZoomMeetingSdkPlatform] that uses method channels.
class MethodChannelFlutterZoomMeetingSdk extends FlutterZoomMeetingSdkPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_zoom_meeting_sdk');

  @visibleForTesting
  final eventChannel = const EventChannel('flutter_zoom_meeting_sdk/events');

  late final Stream<Map<String, dynamic>> _eventStream = eventChannel
      .receiveBroadcastStream()
      .map((event) => Map<String, dynamic>.from(event));

  // ======== Events =========

  // ====== Auth Events ======

  /// mac | ios | android | windows
  @override
  Stream<FlutterZoomMeetingSdkEventResponse<EventAuthenticateReturnParams>>
  get onAuthenticationReturn => _eventStream
      .where((e) => e['event'] == EventType.onAuthenticationReturn.name)
      .map(
        (event) => FlutterZoomMeetingSdkEventResponse.fromMap(
          event,
          EventAuthenticateReturnParams.fromMap,
        ),
      );

  /// mac | ios | android | windows
  @override
  Stream<FlutterZoomMeetingSdkEventResponse> get onZoomAuthIdentityExpired =>
      _eventStream
          .where((e) => e['event'] == EventType.onZoomAuthIdentityExpired.name)
          .map(
            (event) => FlutterZoomMeetingSdkEventResponse.fromMap(
              event,
              Map<String, dynamic>.from,
            ),
          );

  // Meeting Events

  /// mac | ios | android | windows
  @override
  Stream<FlutterZoomMeetingSdkEventResponse<EventMeetingStatusChangedParams>>
  get onMeetingStatusChanged => _eventStream
      .where((e) => e['event'] == EventType.onMeetingStatusChanged.name)
      .map(
        (event) => FlutterZoomMeetingSdkEventResponse.fromMap(
          event,
          EventMeetingStatusChangedParams.fromMap,
        ),
      );

  /// mac | ios | android | windows
  @override
  Stream<
    FlutterZoomMeetingSdkEventResponse<EventMeetingParameterNotificationParams>
  >
  get onMeetingParameterNotification => _eventStream
      .where((e) => e['event'] == EventType.onMeetingParameterNotification.name)
      .map(
        (event) => FlutterZoomMeetingSdkEventResponse.fromMap(
          event,
          EventMeetingParameterNotificationParams.fromMap,
        ),
      );

  /// ios
  @override
  Stream<FlutterZoomMeetingSdkEventResponse<EventMeetingErrorParams>>
  get onMeetingError => _eventStream
      .where((e) => e['event'] == EventType.onMeetingError.name)
      .map(
        (event) => FlutterZoomMeetingSdkEventResponse.fromMap(
          event,
          EventMeetingErrorParams.fromMap,
        ),
      );

  /// ios
  @override
  Stream<FlutterZoomMeetingSdkEventResponse<EventMeetingEndedReasonParams>>
  get onMeetingEndedReason => _eventStream
      .where((e) => e['event'] == EventType.onMeetingEndedReason.name)
      .map(
        (event) => FlutterZoomMeetingSdkEventResponse.fromMap(
          event,
          EventMeetingEndedReasonParams.fromMap,
        ),
      );

  // ======= Functions =======

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  Future<FlutterZoomMeetingSdkActionResponse<InitParamsResponse>>
  initZoom() async {
    final result = await methodChannel.invokeMethod('initZoom');
    final Map<String, dynamic> resultMap = Map<String, dynamic>.from(result);
    return FlutterZoomMeetingSdkActionResponse.fromMap(
      resultMap,
      InitParamsResponse.fromMap,
    );
  }

  @override
  Future<FlutterZoomMeetingSdkActionResponse<AuthParamsResponse>> authZoom({
    required String jwtToken,
  }) async {
    final result = await methodChannel.invokeMethod('authZoom', {
      'jwtToken': jwtToken,
    });
    final Map<String, dynamic> resultMap = Map<String, dynamic>.from(result);
    return FlutterZoomMeetingSdkActionResponse.fromMap(
      resultMap,
      AuthParamsResponse.fromMap,
    );
  }

  @override
  Future<FlutterZoomMeetingSdkActionResponse<JoinParamsResponse>> joinMeeting(
    ZoomMeetingSdkRequest request,
  ) async {
    final result = await methodChannel.invokeMethod('joinMeeting', {
      'meetingNumber': request.meetingNumber,
      'password': request.password,
      'displayName': request.displayName,
      'webinarToken': request.webinarToken ?? "",
    });
    final Map<String, dynamic> resultMap = Map<String, dynamic>.from(result);
    return FlutterZoomMeetingSdkActionResponse.fromMap(
      resultMap,
      JoinParamsResponse.fromMap,
    );
  }

  @override
  Future<JwtResponse?> getJWTToken({
    required String authEndpoint,
    required String meetingNumber,
    required int role,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(authEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'meetingNumber': meetingNumber, 'role': role}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final signature = data['signature'] as String?;

        return JwtResponse(token: signature);
      } else {
        return JwtResponse(error: "Failed to retrieve JWT signature.");
      }
    } catch (e) {
      return JwtResponse(error: "Failed to retrieve JWT signature.");
    }
  }

  @override
  Future<FlutterZoomMeetingSdkActionResponse> unInitZoom() async {
    final result = await methodChannel.invokeMethod('unInitZoom');
    final Map<String, dynamic> resultMap = Map<String, dynamic>.from(result);
    return FlutterZoomMeetingSdkActionResponse.fromMap(
      resultMap,
      Map<String, dynamic>.from,
    );
  }
}
