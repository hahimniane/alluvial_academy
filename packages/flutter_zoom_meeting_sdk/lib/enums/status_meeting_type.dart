import 'package:flutter_zoom_meeting_sdk/helpers/common.dart';

enum StatusMeetingType {
  /// mac | ios | | android | windows
  none,

  /// mac | ios | | android | windows
  normal,

  /// mac | ios | | android | windows
  webinar,

  /// mac | ios | | android | windows
  breakoutRoom,

  /// mac | ios | | android | windows
  undefined,
}

extension StatusMeetingTypeMapper on StatusMeetingType {
  static final Map<String, StatusMeetingType> _map = generateStatusMap(
    StatusMeetingType.values,
    (e) => e.name,
  );

  static StatusMeetingType fromString(String status) {
    return _map[status.toUpperCase()] ?? StatusMeetingType.undefined;
  }
}
