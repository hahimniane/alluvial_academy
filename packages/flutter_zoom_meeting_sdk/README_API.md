# API Reference

> ⚠️ **Platform Differences Notice**
>  
> Zoom Meeting SDK behavior is not fully consistent across all platforms. Some functions or event streams may behave slightly differently or be unavailable depending on the target platform (`macOS`, `iOS`, `Android`, `Windows`). Always test platform-specific behavior thoroughly.  
>  
> For returned status values, check platform-specific availability via inline hints in your IDE (e.g., `/// mac | ios | android | windows`). These hints indicate which platforms support the value.
>
> ![VSCode Hint](https://github.com/user-attachments/assets/22196478-473d-4cf5-b817-56c7fe08e8d1)
>  
> **Note**: All the `code` values like `statusCode`, `errorCode`, and `endReasonCode` are returned directly from the Zoom Meeting SDK and represent enum values defined per platform. These enum values are **not guaranteed to be consistent across platforms**, so prefer using `statusLabel` or `statusEnum` when writing your code.

---

## 1. Functions

### `initZoom`

- **Description**: Initialize the SDK.
- **Request**: None
- **Response**: Future<[FlutterZoomMeetingSdkActionResponse](#flutterzoommeetingsdkactionresponset)<[InitParamsResponse](#initparamsresponse)>>
- **Example**:
  ```dart
  await FlutterZoomMeetingSdk().initZoom();
  ```

---

### `authZoom`

- **Description**: Authenticate SDK using your JWT token.
- **Request**:
  - `jwtToken`: `String` — The JWT token used for authentication.
- **Response**: Future<[FlutterZoomMeetingSdkActionResponse](#flutterzoommeetingsdkactionresponset)<[AuthParamsResponse](#authparamsresponse)>>
- **Example**:
  ```dart
  await FlutterZoomMeetingSdk().authZoom(jwtToken: jwtToken);
  ```

---

### `joinMeeting`

- **Description**: Join a meeting using a Meeting ID and password. For webinars or meetings with registration, you must also pass a `webinarToken`.
- **Request**:
  - `meetingNumber`: `String` — The Zoom meeting ID.
  - `password`: `String` — The meeting password.
  - `displayName`: `String` — The participant's display name.
  - `webinarToken`: `String` — *(Optional)* The webinar token for webinars or registered meetings.
- **Response**: Future<[FlutterZoomMeetingSdkActionResponse](#flutterzoommeetingsdkactionresponset)<[JoinParamsResponse](#joinparamsresponse)>>
- **Example**:
  ```dart
  await FlutterZoomMeetingSdk().joinMeeting(ZoomMeetingSdkRequest(
    meetingNumber: _meetingNumber,
    password: _passCode,
    displayName: _userName,
    webinarToken: _webinarToken,
  ));
  ```

---

### `unInitZoom`

- **Description**: Uninitialize and clean up the SDK.
- **Request**: None
- **Response**: Future<[FlutterZoomMeetingSdkActionResponse](#flutterzoommeetingsdkactionresponset)>
- **Example**:
  ```dart
  await FlutterZoomMeetingSdk().unInitZoom();
  ```

---

### `getJWTToken`

- **Description**: Retrieve a JWT token (signature) from a custom authentication endpoint. This token is required to authenticate the Zoom Meeting SDK using JWT.
- **Request**:
  - `authEndpoint`: `String` — The URL of your server that returns a Zoom JWT token.
  - `meetingNumber`: `String` — The Zoom meeting ID.
  - `role`: `int` — The user's role in the meeting:
    - `0`: Participant
    - `1`: Host / Co-Host
- **Response**: Future<JwtResponse?>
- **Example**:
  ```dart
  final result = await _zoomSdk.getJWTToken(
    authEndpoint: _authEndpoint,
    meetingNumber: _meetingNumber,
    role: _role,
  );

  final signature = result?.token;
  ```

---

## 2. Event Streams

### `onAuthenticationReturn`

- **Description**: Triggered when the SDK authentication succeeds or fails.
- **Response**: Stream<[FlutterZoomMeetingSdkEventResponse](#flutterzoommeetingsdkeventresponset)<[EventAuthenticateReturnParams](#eventauthenticatereturnparams)>>
- **Platform**: `macOS` | `iOS` | `android` | `windows`
- **Example**:
  ```dart
  FlutterZoomMeetingSdk().onAuthenticationReturn.listen((event) {
    if (event.params?.statusEnum == StatusZoomError.success) {
      joinMeeting();
    }
  });
  ```

---

### `onZoomAuthIdentityExpired`

- **Description**: Triggered when the JWT token is expired. Generate a new token.
- **Response**: Stream<[FlutterZoomMeetingSdkEventResponse](#flutterzoommeetingsdkeventresponset)>
- **Platform**: `macOS` | `iOS` | `android` | `windows`
- **Example**:
  ```dart
  FlutterZoomMeetingSdk().onZoomAuthIdentityExpired.listen((event) {
    // Refresh JWT token here
  });
  ```

---

### `onMeetingStatusChanged`

- **Description**: Triggered when the meeting status changes.
- **Response**: Stream<[FlutterZoomMeetingSdkEventResponse](#flutterzoommeetingsdkeventresponset)<[EventMeetingStatusChangedParams](#eventmeetingstatuschangedparams)>>
- **Platform**: `macOS` | `iOS` | `android` | `windows`
- **Example**:
  ```dart
  FlutterZoomMeetingSdk().onMeetingStatusChanged.listen((event) {
    // Handle meeting status
  });
  ```

---

### `onMeetingParameterNotification`

- **Description**: Triggered right before the meeting starts.
- **Response**: Stream<[FlutterZoomMeetingSdkEventResponse](#flutterzoommeetingsdkeventresponset)<[EventMeetingParameterNotificationParams](#eventmeetingparameternotificationparams)>>
- **Platform**: `macOS` | `iOS` | `android` | `windows`
- **Example**:
  ```dart
  FlutterZoomMeetingSdk().onMeetingParameterNotification.listen((event) {
    // Handle meeting parameters
  });
  ```

---

### `onMeetingError`

- **Description**: Triggered when a meeting encounters an error (e.g., connection issues, invalid parameters).
- **Response**: Stream<[FlutterZoomMeetingSdkEventResponse](#flutterzoommeetingsdkeventresponset)<[EventMeetingErrorParams](#eventmeetingerrorparams)>>
- **Platform**: `iOS` only
- **Note**: Only available on `iOS` due to SDK inconsistencies.
- **Example**:
  ```dart
  FlutterZoomMeetingSdk().onMeetingError.listen((event) {
    // Handle meeting error
  });
  ```

---

### `onMeetingEndedReason`

- **Description**: Triggered when a meeting ends, providing the end reason.
- **Response**: Stream<[FlutterZoomMeetingSdkEventResponse](#flutterzoommeetingsdkeventresponset)<[EventMeetingEndedReasonParams](#eventmeetingendedreasonparams)>>
- **Platform**: `iOS` only
- **Note**: Only available on `iOS` due to SDK inconsistencies.
- **Example**:
  ```dart
  FlutterZoomMeetingSdk().onMeetingEndedReason.listen((event) {
    // Handle meeting end reason
  });
  ```

---

## 3. Types

### 3.1 Function Responses

#### `FlutterZoomMeetingSdkActionResponse<T>`

Generic wrapper for all SDK function responses.

- **Fields**:
  - `platform`: `PlatformType` — `android`, `ios`, `macos`, `windows`
  - `action`: `ActionType` — `initZoom`, `authZoom`, `joinMeeting`, `unInitZoom`
  - `isSuccess`: `bool` — Whether the action succeeded.
  - `message`: `String` — Message or error info.
  - `params`: `T?` — Optional platform-specific data.

---

#### `InitParamsResponse`

- **Fields**:
  - `statusCode`: `int?`
  - `statusLabel`: `String?`
 
---

#### `AuthParamsResponse`

- **Fields**:
  - `statusCode`: `int?`
  - `statusLabel`: `String?`
 
---

#### `JoinParamsResponse`

- **Fields**:
  - `statusCode`: `int?`
  - `statusLabel`: `String?`

---

### 3.2 Event Responses

#### `FlutterZoomMeetingSdkEventResponse<T>`

Generic wrapper for all SDK events.

- **Fields**:
  - `platform`: `PlatformType`
  - `event`: `EventType`
  - `oriEvent`: `String` — Original Zoom SDK event name (platform-specific).
  - `params`: `T?` — Optional function-specific parameters.

---

#### `EventAuthenticateReturnParams`

> ⚠️ Use `statusLabel` or `statusEnum` instead of `statusCode` as values may differ across platforms.

- **Fields**:
  - `statusCode`: `int`
  - `statusLabel`: `String`
  - `statusEnum`: `StatusZoomError`

---

#### `EventMeetingStatusChangedParams`

> ⚠️ Behavior differs across platforms:
> - `iOS`: `errorCode` and `endReasonCode` are separate events.
> - `android`: `endReasonCode` not available.
> - `windows`: provides `errorCode` or `endReasonCode` based on status.

- **Fields**:
  - `statusCode`: `int`
  - `statusLabel`: `String`
  - `statusEnum`: `StatusZoomError`
  - `errorCode`: `int`
  - `errorLabel`: `String`
  - `errorEnum`: `StatusMeetingError`
  - `endReasonCode`: `int`
  - `endReasonLabel`: `String`
  - `endReasonEnum`: `StatusMeetingEndReason`

---

#### `EventMeetingParameterNotificationParams`

- **Fields**:
  - `isAutoRecordingCloud`: `bool`
  - `isAutoRecordingLocal`: `bool`
  - `isViewOnly`: `bool`
  - `meetingHost`: `String`
  - `meetingTopic`: `String`
  - `meetingNumber`: `int`
  - `meetingType`: `int`
  - `meetingTypeLabel`: `String`
  - `meetingTypeEnum`: `StatusMeetingType`

---

#### `EventMeetingErrorParams`

- **Fields**:
  - `errorCode`: `int`
  - `errorLabel`: `String`
  - `errorEnum`: `StatusMeetingError`
  - `message`: `String`

---

#### `EventMeetingEndedReasonParams`

- **Fields**:
  - `endReasonCode`: `int`
  - `endReasonLabel`: `String`
  - `endReasonEnum`: `StatusMeetingEndReason`
