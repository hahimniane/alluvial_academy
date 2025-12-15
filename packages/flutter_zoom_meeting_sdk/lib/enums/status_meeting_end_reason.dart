import 'package:flutter_zoom_meeting_sdk/helpers/common.dart';

enum StatusMeetingEndReason {
  /// mac | windows
  none,

  /// mac | ios | windows
  kickByHost,

  /// mac | ios | windows
  endByHost,

  /// mac | ios | windows
  jbhTimeOut,

  /// mac | ios | windows
  noAttendee,

  /// mac | ios | windows
  hostStartAnotherMeeting,

  /// mac | ios | windows
  freeMeetingTimeOut,

  /// mac | ios | windows
  networkBroken,

  /// ios
  selfLeave,

  /// ios
  unknown,

  /// mac | ios | windows
  undefined,
}

extension StatusMeetingEndReasonMapper on StatusMeetingEndReason {
  static final Map<String, StatusMeetingEndReason> _map = generateStatusMap(
    StatusMeetingEndReason.values,
    (e) => e.name,
  );

  static StatusMeetingEndReason fromString(String status) {
    return _map[status.toUpperCase()] ?? StatusMeetingEndReason.undefined;
  }
}
