import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:alluwalacademyadmin/core/services/zoom_meeting_sdk_join_service.dart';
import 'package:flutter_zoom_meeting_sdk/flutter_zoom_meeting_sdk.dart';
import 'package:flutter_zoom_meeting_sdk/enums/platform_type.dart';
import 'package:flutter_zoom_meeting_sdk/enums/action_type.dart';
import 'package:flutter_zoom_meeting_sdk/enums/event_type.dart';
import 'package:flutter_zoom_meeting_sdk/enums/status_zoom_error.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_zoom_meeting_sdk/models/flutter_zoom_meeting_sdk_event_response.dart';
import 'package:flutter_zoom_meeting_sdk/models/flutter_zoom_meeting_sdk_action_response.dart';

// Manual Mocks
class MockZoomSdk extends FlutterZoomMeetingSdk {
  bool initCalled = false;
  bool authCalled = false;
  bool joinCalled = false;
  bool claimCalled = false;
  String? hostKeyProvided;

  final _authController = StreamController<
      FlutterZoomMeetingSdkEventResponse<
          EventAuthenticateReturnParams>>.broadcast();

  @override
  Stream<FlutterZoomMeetingSdkEventResponse<EventAuthenticateReturnParams>>
      get onAuthenticationReturn => _authController.stream;

  @override
  Future<FlutterZoomMeetingSdkActionResponse<InitParamsResponse>>
      initZoom() async {
    initCalled = true;
    return FlutterZoomMeetingSdkActionResponse(
      platform: PlatformType.android,
      action: ActionType.initZoom,
      isSuccess: true,
      message: 'SUCCESS',
      params: InitParamsResponse(statusCode: 0, statusLabel: 'SUCCESS'),
    );
  }

  @override
  Future<FlutterZoomMeetingSdkActionResponse<AuthParamsResponse>> authZoom(
      {required String jwtToken}) async {
    authCalled = true;
    // Simulate successful auth event
    Timer(Duration(milliseconds: 10), () {
      _authController.add(FlutterZoomMeetingSdkEventResponse(
        platform: PlatformType.android,
        event: EventType.onAuthenticationReturn,
        oriEvent: 'onAuthenticationReturn',
        params: EventAuthenticateReturnParams(
            statusCode: 0,
            statusLabel: 'SUCCESS',
            statusEnum: StatusZoomError.success),
      ));
    });
    return FlutterZoomMeetingSdkActionResponse(
      platform: PlatformType.android,
      action: ActionType.authZoom,
      isSuccess: true,
      message: 'SUCCESS',
      params: AuthParamsResponse(statusCode: 0, statusLabel: 'SUCCESS'),
    );
  }

  @override
  Future<FlutterZoomMeetingSdkActionResponse<JoinParamsResponse>> joinMeeting(
      dynamic request) async {
    joinCalled = true;
    return FlutterZoomMeetingSdkActionResponse(
      platform: PlatformType.android,
      action: ActionType.joinMeeting,
      isSuccess: true,
      message: 'SUCCESS',
      params: JoinParamsResponse(statusCode: 0, statusLabel: 'SUCCESS'),
    );
  }

  @override
  Future<FlutterZoomMeetingSdkActionResponse> claimHost(
      {required String hostKey}) async {
    claimCalled = true;
    hostKeyProvided = hostKey;
    return FlutterZoomMeetingSdkActionResponse(
      platform: PlatformType.android,
      action: ActionType.claimHost,
      isSuccess: true,
      message: 'SUCCESS',
      params: null,
    );
  }

  void dispose() {
    _authController.close();
  }
}

class MockFunctions implements FirebaseFunctions {
  Map<String, dynamic> results = {};
  List<String> calledFunctions = [];

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    return MockCallable(name, this);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockCallable implements HttpsCallable {
  final String name;
  final MockFunctions parent;

  MockCallable(this.name, this.parent);

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    parent.calledFunctions.add(name);
    return MockResult<T>(parent.results[name]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockResult<T> implements HttpsCallableResult<T> {
  final dynamic _data;
  MockResult(this._data);

  @override
  T get data => _data as T;
}

void main() {
  late ZoomMeetingSdkJoinService service;
  late MockZoomSdk mockSdk;
  late MockFunctions mockFunctions;

  setUp(() {
    service = ZoomMeetingSdkJoinService();
    mockSdk = MockZoomSdk();
    mockFunctions = MockFunctions();

    service.zoomSdkOverride = mockSdk;
    service.functionsOverride = mockFunctions;
    service.reset();
  });

  tearDown(() {
    mockSdk.dispose();
  });

  group('Zoom Hybrid Logic Tests', () {
    test('Teacher join flow with auto-claim host and mark rooms opened',
        () async {
      // Setup payload and host key
      mockFunctions.results['getZoomMeetingSdkJoinPayload'] = {
        'success': true,
        'meetingNumber': '123456789',
        'meetingPasscode': 'p123',
        'meetingSdkJwt': 'jwt123',
        'displayName': 'Teacher User',
      };
      mockFunctions.results['getZoomHostKey'] = {
        'hostKey': '346048',
      };
      mockFunctions.results['markBreakoutRoomsOpened'] = {
        'success': true,
      };

      // Execute join
      final success = await service.joinShift(shiftId: 'test_shift_id');

      // Verify results
      expect(success, isTrue);
      expect(mockSdk.initCalled, isTrue);
      expect(mockSdk.authCalled, isTrue);
      expect(mockSdk.joinCalled, isTrue);
      expect(mockSdk.claimCalled, isTrue);
      expect(mockSdk.hostKeyProvided, '346048');

      expect(mockFunctions.calledFunctions,
          contains('getZoomMeetingSdkJoinPayload'));
      expect(mockFunctions.calledFunctions, contains('getZoomHostKey'));
      expect(
          mockFunctions.calledFunctions, contains('markBreakoutRoomsOpened'));
    });

    test('Student join flow (no host key)', () async {
      // Setup payload only
      mockFunctions.results['getZoomMeetingSdkJoinPayload'] = {
        'success': true,
        'meetingNumber': '123456789',
        'meetingPasscode': 'p123',
        'meetingSdkJwt': 'jwt123',
        'displayName': 'Student User',
      };
      // Host key fetch fails or returns null for students
      mockFunctions.results['getZoomHostKey'] = {
        'success': false,
        'error': 'Permission denied'
      };

      // Execute join
      final success = await service.joinShift(shiftId: 'student_shift_id');

      // Verify results
      expect(success, isTrue);
      expect(mockSdk.initCalled, isTrue);
      expect(mockSdk.authCalled, isTrue);
      expect(mockSdk.joinCalled, isTrue);
      expect(mockSdk.claimCalled, isFalse); // Should NOT claim host

      expect(mockFunctions.calledFunctions,
          contains('getZoomMeetingSdkJoinPayload'));
      expect(mockFunctions.calledFunctions, contains('getZoomHostKey'));
      expect(mockFunctions.calledFunctions,
          isNot(contains('markBreakoutRoomsOpened')));
    });
  });
}
