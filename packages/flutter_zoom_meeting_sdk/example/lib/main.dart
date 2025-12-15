import 'package:flutter/material.dart';
import 'package:flutter_zoom_meeting_sdk/enums/status_zoom_error.dart';
import 'package:flutter_zoom_meeting_sdk/flutter_zoom_meeting_sdk.dart';
import 'package:flutter_zoom_meeting_sdk/models/zoom_meeting_sdk_request.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final FlutterZoomMeetingSdk _zoomSdk = FlutterZoomMeetingSdk();

  @override
  void dispose() {
    _zoomSdk.unInitZoom();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _zoomSdk.initZoom();

    _zoomSdk.authZoom(jwtToken: "<YOUR_JWT_TOKEN>");

    _zoomSdk.onAuthenticationReturn.listen((event) {
      if (event.params?.statusEnum == StatusZoomError.success) {
        _zoomSdk.joinMeeting(
          ZoomMeetingSdkRequest(
            meetingNumber: '<YOUR_MEETING_NUMBER>',
            password: '<YOUR_MEETING_PASSWORD>',
            displayName: '<PARTICIPANT_NAME>',
          ),
        );
      }
    });

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Flutter Zoom Meeting SDK Plugin')),
        body: Center(),
      ),
    );
  }
}
