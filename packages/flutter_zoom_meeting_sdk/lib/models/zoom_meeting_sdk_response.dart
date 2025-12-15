class StandardZoomMeetingResponse {
  final bool success;
  final String message;
  final int statusCode;
  final String statusText;

  StandardZoomMeetingResponse({
    required this.success,
    required this.message,
    required this.statusCode,
    required this.statusText,
  });

  // Factory method to create the object from a Map
  factory StandardZoomMeetingResponse.fromMap(Map<String, dynamic> map) {
    return StandardZoomMeetingResponse(
      success: map['success'] ?? false,
      message: map['message'] ?? '',
      statusCode: map['statusCode'] ?? 0,
      statusText: map['statusText'] ?? '',
    );
  }

  // Optional: toDictionary method if you want to send data back from Flutter to Swift
  Map<String, dynamic> toMap() {
    return {
      'success': success,
      'message': message,
      'statusCode': statusCode,
      'statusText': statusText,
    };
  }
}

class ZoomMeetingMeetingEventResponse {
  final String event;
  final int meetingStatus;
  final String meetingStatusText;
  final int meetingError;
  final String meetingErrorText;
  final int endMeetingReason;
  final String endMeetingReasonText;

  ZoomMeetingMeetingEventResponse({
    required this.event,
    required this.meetingStatus,
    required this.meetingStatusText,
    required this.meetingError,
    required this.meetingErrorText,
    required this.endMeetingReason,
    required this.endMeetingReasonText,
  });

  // Factory method to create the object from a Map
  factory ZoomMeetingMeetingEventResponse.fromMap(Map<String, dynamic> map) {
    return ZoomMeetingMeetingEventResponse(
      event: map['event'] ?? '',
      meetingStatus: map['meetingStatus'] ?? 0,
      meetingStatusText: map['meetingStatusText'] ?? '',
      meetingError: map['meetingError'] ?? 0,
      meetingErrorText: map['meetingErrorText'] ?? '',
      endMeetingReason: map['endMeetingReason'] ?? 0,
      endMeetingReasonText: map['endMeetingReasonText'] ?? '',
    );
  }

  // Optional: toDictionary method if you want to send data back from Flutter to Swift
  Map<String, dynamic> toMap() {
    return {
      'event': event,
      'meetingStatus': meetingStatus,
      'meetingStatusText': meetingStatusText,
      'meetingError': meetingError,
      'meetingErrorText': meetingErrorText,
      'endMeetingReason': endMeetingReason,
      'endMeetingReasonText': endMeetingReasonText,
    };
  }
}

class ZoomMeetingAuthEventResponse {
  final String event;
  final bool success;
  final String message;
  final int statusCode;
  final String statusText;

  ZoomMeetingAuthEventResponse({
    required this.event,
    required this.success,
    required this.message,
    required this.statusCode,
    required this.statusText,
  });

  // Factory method to create the object from a Map
  factory ZoomMeetingAuthEventResponse.fromMap(Map<String, dynamic> map) {
    return ZoomMeetingAuthEventResponse(
      event: map['event'] ?? '',
      success: map['success'] ?? false,
      message: map['message'] ?? '',
      statusCode: map['statusCode'] ?? 0,
      statusText: map['statusText'] ?? '',
    );
  }

  // Optional: toDictionary method if you want to send data back from Flutter to Swift
  Map<String, dynamic> toMap() {
    return {
      'event': event,
      'success': success,
      'message': message,
      'statusCode': statusCode,
      'statusText': statusText,
    };
  }
}
