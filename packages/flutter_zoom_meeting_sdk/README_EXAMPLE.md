# Example

## main.dart
```dart
import 'package:flutter/material.dart';
import './meeting_card_list.dart';
import './zoom_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ZoomService _zoomService = ZoomService();

  @override
  void initState() {
    super.initState();
    _zoomService.initZoom();
    _zoomService.initEventListeners();
  }

  @override
  void dispose() {
    _zoomService.dispose();
    super.dispose();
  }

  final List<Map<String, String>> meetingData = [
    {
      'meetingNumber': 'xxx',
      'password': 'xxx',
      'displayName': 'Normal Meeting Room',
    },
    // Sample Registration Link: https://zoom.us/w/aaa?tk=bbb&pwd=ccc
    {
      'meetingNumber': 'aaa',
      'password': 'ccc',
      'displayName': 'Registration Meeting Room',
      'webinarToken': 'bbb',
    },
    // Sample Webinar Link: https://us02web.zoom.us/w/aaa?tk=bbb&pwd=ccc&uuid=ddd
    {
      'meetingNumber': 'aaa',
      'password': 'ccc',
      'displayName': 'Webinar',
      'webinarToken': 'bbb',
    },
  ];

  void joinMeeting(Map<String, String> meeting) {
    _zoomService.setMeetingNumber(meeting['meetingNumber'] ?? '');
    _zoomService.setPassCode(meeting['password'] ?? '');
    _zoomService.setUserName(meeting['displayName'] ?? '');
    _zoomService.setWebinarToken(meeting['webinarToken']);

    _zoomService.authZoom();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Plugin example app')),
        body: MeetingCardList(data: meetingData, onJoinPressed: joinMeeting),
      ),
    );
  }
}
```

## meeting_card_list.dart

Create meeting card list for display purpose.

```dart
import 'package:flutter/material.dart';

class MeetingCardList extends StatelessWidget {
  final List<Map<String, String>> data;
  final Function(Map<String, String>) onJoinPressed;

  const MeetingCardList({
    super.key,
    required this.data,
    required this.onJoinPressed,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Set column count based on screen width
    int crossAxisCount;
    if (screenWidth > 1000) {
      crossAxisCount = 3;
    } else if (screenWidth > 600) {
      crossAxisCount = 2;
    } else {
      crossAxisCount = 1;
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        itemCount: data.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.3,
        ),
        itemBuilder: (context, index) {
          final meeting = data[index];
          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Meeting Number: ${meeting['meetingNumber']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('Password: ${meeting['password']}'),
                  const SizedBox(height: 8),
                  Text('Display Name: ${meeting['displayName']}'),
                  const SizedBox(height: 8),
                  Text('Webinar Token: ${meeting['webinarToken']}'),
                  const Spacer(),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: ElevatedButton(
                      onPressed: () => onJoinPressed(meeting),
                      child: const Text("Join"),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

```

## zoom_service.dart

Create Zoom Service to communicate with plugin.

```dart
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
```


## zoom_service_config.dart

Zoom Service Config is to store all getter and setter function.

```dart
part of 'zoom_service.dart';

extension ZoomServiceConfig on ZoomService {
  String get authEndpoint => _authEndpoint;
  String get meetingNumber => _meetingNumber;
  String get userName => _userName;
  String get passCode => _passCode;
  String? get webinarToken => _webinarToken;
  int get role => _role;

  void setAuthEndpoint(String endpoint) => _authEndpoint = endpoint;
  void setMeetingNumber(String meetingNumber) => _meetingNumber = meetingNumber;
  void setUserName(String userName) => _userName = userName;
  void setPassCode(String passCode) => _passCode = passCode;
  void setWebinarToken(String? webinarToken) => _webinarToken = webinarToken;
  void setRole(int role) => _role = role;
}
```

