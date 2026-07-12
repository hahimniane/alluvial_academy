import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zoom_meeting_wrapper/flutter_zoom_meeting_wrapper_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ZoomMeetingWrapperMethodChannel platform = ZoomMeetingWrapperMethodChannel();
  const MethodChannel channel = MethodChannel('flutter_zoom_meeting_wrapper');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'initZoom') return true;
      if (methodCall.method == 'joinMeeting') return true;
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('initZoom returns true on success', () async {
    expect(await platform.initZoom('test_jwt'), true);
  });

  test('joinMeeting returns true on success', () async {
    MethodCall? methodCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      methodCall = call;
      return true;
    });

    expect(
      await platform.joinMeeting(
        meetingId: '123456789',
        meetingPassword: 'password',
        displayName: 'Test User',
        routingDisplayName: 'Test User',
        customerKey: 'zh_abc123',
        breakoutRoomName: 'Billing Test',
        breakoutRoomKey: 'shift_1',
        autoJoinBreakoutRoom: true,
        classEndsAtIso: '2026-07-06T23:00:00.000Z',
      ),
      true,
    );
    expect(methodCall?.method, 'joinMeeting');
    expect(methodCall?.arguments, {
      'meetingId': '123456789',
      'meetingPassword': 'password',
      'displayName': 'Test User',
      'routingDisplayName': 'Test User',
      'customerKey': 'zh_abc123',
      'breakoutRoomName': 'Billing Test',
      'breakoutRoomKey': 'shift_1',
      'autoJoinBreakoutRoom': true,
      'classEndsAtIso': '2026-07-06T23:00:00.000Z',
    });
  });
}
