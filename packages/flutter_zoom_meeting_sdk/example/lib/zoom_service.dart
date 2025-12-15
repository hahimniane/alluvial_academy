import 'dart:async';
import 'dart:convert';
import 'package:flutter_zoom_meeting_sdk/enums/status_zoom_error.dart';
import 'package:flutter_zoom_meeting_sdk/flutter_zoom_meeting_sdk.dart';
import 'package:flutter_zoom_meeting_sdk/models/flutter_zoom_meeting_sdk_action_response.dart';
import 'package:flutter_zoom_meeting_sdk/models/zoom_meeting_sdk_request.dart';
part 'zoom_service_config.dart';

class ZoomService {
  final FlutterZoomMeetingSdk _zoomSdk = FlutterZoomMeetingSdk();

  String _authEndpoint = "http://localhost:4000";
  // String _authEndpoint = "http://10.0.2.2:4000"; // android emulator

  String _meetingNumber = "";
  String _userName = "";
  String _passCode = "";
  String? _webinarToken;
  int _role = 0;

  StreamSubscription? _onAuthenticationReturn;
  StreamSubscription? _onZoomAuthIdentityExpired;
  StreamSubscription? _onMeetingStatusChanged;
  StreamSubscription? _onMeetingParameterNotification;
  StreamSubscription? _onMeetingError;
  StreamSubscription? _onMeetingEndedReason;

  Future<FlutterZoomMeetingSdkActionResponse> initZoom() async {
    final result = await _zoomSdk.initZoom();
    print('EXAMPLE_APP::ACTION::INIT - ${jsonEncode(result.toMap())}');
    return result;
  }

  Future<FlutterZoomMeetingSdkActionResponse> authZoom() async {
    final jwtToken = await getJWTToken();
    final result = await _zoomSdk.authZoom(jwtToken: jwtToken);
    print('EXAMPLE_APP::ACTION::AUTH - ${jsonEncode(result.toMap())}');
    return result;
  }

  Future<FlutterZoomMeetingSdkActionResponse> joinMeeting() async {
    final request = ZoomMeetingSdkRequest(
      meetingNumber: _meetingNumber,
      password: _passCode,
      displayName: _userName,
      webinarToken: _webinarToken,
    );

    final result = await _zoomSdk.joinMeeting(request);
    print('EXAMPLE_APP::ACTION::JOIN - ${jsonEncode(result.toMap())}');
    return result;
  }

  Future<FlutterZoomMeetingSdkActionResponse> unInitZoom() async {
    final result = await _zoomSdk.unInitZoom();
    print('EXAMPLE_APP::ACTION::UNINIT - ${jsonEncode(result.toMap())}');
    return result;
  }

  Future<String> getJWTToken() async {
    final result = await _zoomSdk.getJWTToken(
      authEndpoint: _authEndpoint,
      meetingNumber: _meetingNumber,
      role: _role,
    );

    final signature = result?.token;

    if (signature != null) {
      print('Signature: $signature');
      return signature;
    } else {
      throw Exception("Failed to get signature.");
    }
  }

  void initEventListeners() {
    _onAuthenticationReturn = _zoomSdk.onAuthenticationReturn.listen((event) {
      print(
        "EXAMPLE_APP::EVENT::onAuthenticationReturn - ${jsonEncode(event.toMap())}",
      );

      if (event.params?.statusEnum == StatusZoomError.success) {
        joinMeeting();
      }
    });

    _onZoomAuthIdentityExpired = _zoomSdk.onZoomAuthIdentityExpired.listen((
      event,
    ) {
      print("EXAMPLE_APP::EVENT::onZoomAuthIdentityExpired");
    });

    _onMeetingStatusChanged = _zoomSdk.onMeetingStatusChanged.listen((event) {
      print(
        "EXAMPLE_APP::EVENT::onMeetingStatusChanged - ${jsonEncode(event.toMap())}",
      );
    });

    _onMeetingParameterNotification = _zoomSdk.onMeetingParameterNotification
        .listen((event) {
          print(
            "EXAMPLE_APP::EVENT::onMeetingParameterNotification - ${jsonEncode(event.toMap())}",
          );
        });

    _onMeetingError = _zoomSdk.onMeetingError.listen((event) {
      print(
        "EXAMPLE_APP::EVENT::onMeetingError - ${jsonEncode(event.toMap())}",
      );
    });

    _onMeetingEndedReason = _zoomSdk.onMeetingEndedReason.listen((event) {
      print(
        "EXAMPLE_APP::EVENT::onMeetingEndedReason - ${jsonEncode(event.toMap())}",
      );
    });
  }

  void dispose() {
    // UnSubscribe Event
    _onAuthenticationReturn?.cancel();
    _onZoomAuthIdentityExpired?.cancel();
    _onMeetingStatusChanged?.cancel();
    _onMeetingParameterNotification?.cancel();
    _onMeetingError?.cancel();
    _onMeetingEndedReason?.cancel();

    unInitZoom();
  }
}
