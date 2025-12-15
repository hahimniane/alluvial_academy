import 'package:flutter_zoom_meeting_sdk/helpers/common.dart';

enum StatusMeetingStatus {
  /// mac | ios | android
  idle,

  /// mac | ios | android
  connecting,

  /// mac | ios | android
  waitingForHost,

  /// mac | ios | android
  inMeeting,

  /// mac | ios | android
  disconnecting,

  /// mac | ios | android
  reconnecting,

  /// mac | ios | android
  failed,

  /// mac | ios | android
  ended,

  /// mac
  audioReady,

  /// mac
  otherMeetingInProgress,

  /// mac | ios | android
  inWaitingRoom,

  /// mac | ios | android
  webinarPromote,

  /// mac | ios | android
  webinarDepromote,

  /// mac | ios | android
  joinBreakoutRoom,

  /// mac | ios | android
  leaveBreakoutRoom,

  /// ios | android
  locked,

  /// ios | android
  unlocked,

  /// mac | ios | android | windows
  undefined,
}

extension StatusMeetingStatusMapper on StatusMeetingStatus {
  static final Map<String, StatusMeetingStatus> _map = generateStatusMap(
    StatusMeetingStatus.values,
    (e) => e.name,
  );

  static StatusMeetingStatus fromString(String status) {
    return _map[status.toUpperCase()] ?? StatusMeetingStatus.undefined;
  }
}
