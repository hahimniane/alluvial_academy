import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ZoomMeetingWrapper {
  static const MethodChannel _channel = MethodChannel(
    'flutter_zoom_meeting_wrapper',
  );

  /// Invoked by the native SDK when the meeting ends (user leaves or the meeting
  /// is closed). Screens showing the native meeting use this to navigate back so
  /// the user returns to the app instead of a blank screen.
  static VoidCallback? onMeetingEnded;
  static bool _handlerInstalled = false;

  static void _ensureCallHandler() {
    if (_handlerInstalled) return;
    _handlerInstalled = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onMeetingEnded') {
        onMeetingEnded?.call();
      }
    });
  }

  /// Initialize the Zoom SDK with JWT token
  ///
  /// Returns a [Future] that completes with true if the initialization was successful
  static Future<bool> initZoom(String jwt) async {
    try {
      var result = await _channel.invokeMethod('initZoom', {'jwt': jwt});
      return result;
    } catch (e) {
      debugPrint('Error initializing Zoom SDK: $e');
      return false;
    }
  }

  /// Join a Zoom meeting
  ///
  /// Parameters:
  /// - [meetingId]: The ID of the meeting to join
  /// - [meetingPassword]: The password for the meeting
  /// - [displayName]: The name to display in the meeting
  /// - [routingDisplayName]: Optional exact name used by routing systems that
  ///   cannot receive a native customer key
  ///
  /// Returns a [Future] that completes with true if joining the meeting was successful
  static Future<bool> joinMeeting({
    required String meetingId,
    required String meetingPassword,
    required String displayName,
    String? routingDisplayName,
    String? customerKey,
    String? breakoutRoomName,
    String? breakoutRoomKey,
    bool autoJoinBreakoutRoom = false,
    String? classEndsAtIso,
  }) async {
    _ensureCallHandler();
    try {
      final result = await _channel.invokeMethod('joinMeeting', {
        'meetingId': meetingId,
        'meetingPassword': meetingPassword,
        'displayName': displayName,
        if (routingDisplayName != null)
          'routingDisplayName': routingDisplayName,
        if (customerKey != null) 'customerKey': customerKey,
        if (breakoutRoomName != null) 'breakoutRoomName': breakoutRoomName,
        if (breakoutRoomKey != null) 'breakoutRoomKey': breakoutRoomKey,
        'autoJoinBreakoutRoom': autoJoinBreakoutRoom,
        if (classEndsAtIso != null) 'classEndsAtIso': classEndsAtIso,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('Error joining Zoom meeting: $e');
      return false;
    }
  }
}
