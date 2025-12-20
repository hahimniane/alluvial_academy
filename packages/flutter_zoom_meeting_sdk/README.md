# Flutter Zoom Meeting SDK

A Flutter plugin for integrating the [Zoom Meeting SDK](https://developers.zoom.us/docs/meeting-sdk/) across multiple platforms.

Tested with SDK version `v6.4.3.28970`.

> This plugin assumes you have basic knowledge of the Zoom application and the [Zoom Meeting SDK](https://developers.zoom.us/docs/meeting-sdk/), including concepts like JWT authentication and meeting numbers.

**Supported Platforms**

- Android  
- iOS  
- macOS  
- Windows

> ⚠️ This plugin does **NOT** bundle the SDK binaries. You must [download the Zoom Meeting SDK manually](#getting-started) and configure it for each platform.

---

## Getting Started

### 1. Download the SDK

1. Go to the [Zoom App Marketplace](https://marketplace.zoom.us/)
2. Sign in to your Zoom account.
3. Click **Develop** → **Build App**
4. Create a **General App**.
5. Under **Build your app** > **Features** > **Embed**, enable the **Meeting SDK**.
6. Download the SDK files for each target platform.

> 📖 For more information: see [Get Credentials](https://developers.zoom.us/docs/meeting-sdk/get-credentials/)

### 2. Platform Setup

Follow the platform-specific setup guides:

- [Android Setup](./README_ANDROID.md)  
- [iOS Setup](./README_IOS.md)  
- [macOS Setup](./README_MACOS.md)  
- [Windows Setup](./README_WINDOWS.md)

---

## Usage

After completing the platform-specific setup, you can start using the plugin to integrate Zoom meeting functionality into your Flutter app. Below is a step-by-step example demonstrating how to initialize the SDK, authenticate with a JWT token, handle events, and join a meeting.

### 1. Initialize the SDK  
```dart
_zoomSdk.initZoom();
```

### 2. Authenticate using your JWT token  
```dart
_zoomSdk.authZoom(
  jwtToken: "<YOUR_JWT_TOKEN>",
);
```

> 🔐 Refer to the [Zoom docs on JWT tokens](https://developers.zoom.us/docs/meeting-sdk/auth/)

### 3. Listen for authentication results and join the meeting  
```dart
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
```

### 4. Uninitialize the SDK (recommended when done)  
```dart
_zoomSdk.unInitZoom();
```

> 💡 You can call this in the `dispose()` method of your widget.

### 5. Complete Example  
```dart
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
```

---

## SDK Authorization (JWT Token)

Zoom Meeting SDK requires a valid JWT (JSON Web Token) for authentication before joining meetings. This section explains how to generate and use the token within your Flutter app.

### 1. How to Generate a JWT Token

Zoom provides a [sample JWT auth endpoint](https://github.com/zoom/meetingsdk-auth-endpoint-sample/) you can use to generate tokens securely:

1. Clone the GitHub repo linked above.
2. Set up and run the sample auth server locally or on your own backend.
3. From your Flutter app, use the getJWTToken() method to request a token:

```dart
final result = await FlutterZoomMeetingSdk().getJWTToken(
  authEndpoint: _authEndpoint,
  meetingNumber: _meetingNumber,
  role: _role, // 0: Participant, 1: Host / Co-Host
);

final signature = result?.token;

if (signature != null) {
  print('Signature: $signature');
  return signature;
} else {
  throw Exception("Failed to get signature.");
}
```
> ℹ️ For detailed information, refer to the official [Meeting SDK authorization](https://developers.zoom.us/docs/meeting-sdk/auth/) guide.

---

## Example

For a complete usage reference, see the [full example code](./README_EXAMPLE.md).

---

## API Reference

For a full list of available methods, event streams, and data models, refer to the [API Reference](./README_API.md).

---

## Contributing

Contributions are welcome! Feel free to open an issue or submit a pull request for improvements, bug fixes, or new features.

---

## License

MIT License — see [LICENSE](./LICENSE) for details.
