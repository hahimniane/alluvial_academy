import 'package:flutter_zoom_meeting_sdk/enums/event_type.dart';
import 'package:flutter_zoom_meeting_sdk/enums/platform_type.dart';
import 'package:flutter_zoom_meeting_sdk/enums/status_meeting_end_reason.dart';
import 'package:flutter_zoom_meeting_sdk/enums/status_meeting_error.dart';
import 'package:flutter_zoom_meeting_sdk/enums/status_meeting_status.dart';
import 'package:flutter_zoom_meeting_sdk/enums/status_meeting_type.dart';
import 'package:flutter_zoom_meeting_sdk/enums/status_zoom_error.dart';
import 'package:flutter_zoom_meeting_sdk/helpers/common.dart';

/// Standard event response wrapper
class FlutterZoomMeetingSdkEventResponse<T> {
  /// The platform type
  final PlatformType platform;

  /// The event type
  final EventType event;

  /// The original event name of each platform
  final String oriEvent;

  /// The params of the event
  final T? params;

  FlutterZoomMeetingSdkEventResponse({
    required this.platform,
    required this.event,
    required this.oriEvent,
    required this.params,
  });

  factory FlutterZoomMeetingSdkEventResponse.fromMap(
    Map<String, dynamic> map,
    T Function(Map<String, dynamic>) paramsParser,
  ) {
    return FlutterZoomMeetingSdkEventResponse(
      platform: PlatformType.values.byName(map['platform']),
      event: EventType.values.byName(map['event']),
      oriEvent: map['oriEvent'],
      params:
          map['params'] != null && map['params'].isNotEmpty
              ? paramsParser(Map<String, dynamic>.from(map['params']))
              : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'platform': platform.name,
      'event': event.name,
      'oriEvent': oriEvent,
      'params':
          params is MappableParams
              ? (params as MappableParams).toMap()
              : params,
    };
  }
}

/// Event response params for [EventType.onAuthenticationReturn]
class EventAuthenticateReturnParams implements MappableParams {
  /// The status code of the event.
  /// This value returned directly from the Zoom Meeting SDK and represent enum values defined per platform.
  /// These enum values are not guaranteed to be consistent across platforms, so prefer using statusLabel.
  final int statusCode;

  /// The status label of the event
  /// The value might not consistent across platforms, use it with caution
  final String statusLabel;

  /// The status enum of the event
  /// Same as statusLabel, convert from statusLabel to enum
  /// The value might not consistent across platforms, use it with caution
  final StatusZoomError statusEnum;

  /// Only **ANDROID** will have this field. ZOOM internal error code
  final int? internalErrorCode;

  EventAuthenticateReturnParams({
    required this.statusCode,
    required this.statusLabel,
    required this.statusEnum,
    this.internalErrorCode,
  });

  factory EventAuthenticateReturnParams.fromMap(Map<String, dynamic> map) {
    return EventAuthenticateReturnParams(
      statusCode: map['statusCode'],
      statusLabel: map['statusLabel'],
      statusEnum: StatusZoomErrorMapper.fromString(map['statusLabel']),
      internalErrorCode: map['internalErrorCode'],
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'statusCode': statusCode,
      'statusLabel': statusLabel,
      'statusEnum': statusEnum.name,
      'internalErrorCode': internalErrorCode,
    };
  }
}

/// Event response params for [EventType.onMeetingStatusChanged]
class EventMeetingStatusChangedParams implements MappableParams {
  /// The status code of the event.
  /// This value returned directly from the Zoom Meeting SDK and represent enum values defined per platform.
  /// These enum values are not guaranteed to be consistent across platforms, so prefer using statusLabel.
  final int statusCode;

  /// The status label of the event
  /// The value might not consistent across platforms, use it with caution
  final String statusLabel;

  /// The status enum of the event
  /// Same as statusLabel, convert from statusLabel to enum
  /// The value might not consistent across platforms, use it with caution
  final StatusMeetingStatus statusEnum;

  /// The error code of the event
  final int errorCode;

  /// The error label of the event
  final String errorLabel;

  /// The error enum of the event
  /// The value might not consistent across platforms, use it with caution
  final StatusMeetingError errorEnum;

  /// The end reason code of the event
  final int endReasonCode;

  /// The end reason label of the event
  final String endReasonLabel;

  /// The end reason enum of the event
  /// The value might not consistent across platforms, use it with caution
  final StatusMeetingEndReason endReasonEnum;

  /// Only **ANDROID** will have this field. ZOOM internal error code
  final int? internalErrorCode;

  EventMeetingStatusChangedParams({
    required this.statusCode,
    required this.statusLabel,
    required this.statusEnum,
    required this.errorCode,
    required this.errorLabel,
    required this.errorEnum,
    required this.endReasonCode,
    required this.endReasonLabel,
    required this.endReasonEnum,
    this.internalErrorCode,
  });

  factory EventMeetingStatusChangedParams.fromMap(Map<String, dynamic> map) {
    return EventMeetingStatusChangedParams(
      statusCode: map['statusCode'],
      statusLabel: map['statusLabel'],
      statusEnum: StatusMeetingStatusMapper.fromString(map['statusLabel']),
      errorCode: map['errorCode'],
      errorLabel: map['errorLabel'],
      errorEnum: StatusMeetingErrorMapper.fromString(map['errorLabel']),
      endReasonCode: map['endReasonCode'],
      endReasonLabel: map['endReasonLabel'],
      endReasonEnum: StatusMeetingEndReasonMapper.fromString(
        map['endReasonLabel'],
      ),
      internalErrorCode: map['internalErrorCode'],
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'statusCode': statusCode,
      'statusLabel': statusLabel,
      'statusEnum': statusEnum.name,
      'errorCode': errorCode,
      'errorLabel': errorLabel,
      'errorEnum': errorEnum.name,
      'endReasonCode': endReasonCode,
      'endReasonLabel': endReasonLabel,
      'endReasonEnum': endReasonEnum.name,
      if (internalErrorCode != null) 'internalErrorCode': internalErrorCode,
    };
  }
}

/// Event response params for [EventType.onMeetingParameterNotification]
class EventMeetingParameterNotificationParams implements MappableParams {
  final bool isAutoRecordingCloud;
  final bool isAutoRecordingLocal;
  final bool isViewOnly;
  final String meetingHost;
  final String meetingTopic;
  final int meetingNumber;
  final int meetingType;
  final String meetingTypeLabel;
  final StatusMeetingType meetingTypeEnum;

  EventMeetingParameterNotificationParams({
    required this.isAutoRecordingCloud,
    required this.isAutoRecordingLocal,
    required this.isViewOnly,
    required this.meetingHost,
    required this.meetingTopic,
    required this.meetingNumber,
    required this.meetingType,
    required this.meetingTypeLabel,
    required this.meetingTypeEnum,
  });

  factory EventMeetingParameterNotificationParams.fromMap(
    Map<String, dynamic> map,
  ) {
    return EventMeetingParameterNotificationParams(
      isAutoRecordingCloud: map['isAutoRecordingCloud'],
      isAutoRecordingLocal: map['isAutoRecordingLocal'],
      isViewOnly: map['isViewOnly'],
      meetingHost: map['meetingHost'],
      meetingTopic: map['meetingTopic'],
      meetingNumber: map['meetingNumber'],
      meetingType: map['meetingType'],
      meetingTypeLabel: map['meetingTypeLabel'],
      meetingTypeEnum: StatusMeetingTypeMapper.fromString(
        map['meetingTypeLabel'],
      ),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'isAutoRecordingCloud': isAutoRecordingCloud,
      'isAutoRecordingLocal': isAutoRecordingLocal,
      'isViewOnly': isViewOnly,
      'meetingHost': meetingHost,
      'meetingTopic': meetingTopic,
      'meetingNumber': meetingNumber,
      'meetingType': meetingType,
      'meetingTypeLabel': meetingTypeLabel,
      'meetingTypeEnum': meetingTypeEnum.name,
    };
  }
}

/// Event response params for [EventType.onMeetingError]
class EventMeetingErrorParams implements MappableParams {
  final int errorCode;
  final String errorLabel;
  final StatusMeetingError errorEnum;
  final String message;

  EventMeetingErrorParams({
    required this.errorCode,
    required this.errorLabel,
    required this.errorEnum,
    required this.message,
  });

  factory EventMeetingErrorParams.fromMap(Map<String, dynamic> map) {
    return EventMeetingErrorParams(
      errorCode: map['errorCode'],
      errorLabel: map['errorLabel'],
      errorEnum: StatusMeetingErrorMapper.fromString(map['errorLabel']),
      message: map['message'],
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'errorCode': errorCode,
      'errorLabel': errorLabel,
      'errorEnum': errorEnum.name,
      'message': message,
    };
  }
}

/// Event response params for [EventType.onMeetingEndedReason]
class EventMeetingEndedReasonParams implements MappableParams {
  final int endReasonCode;
  final String endReasonLabel;
  final StatusMeetingEndReason endReasonEnum;

  EventMeetingEndedReasonParams({
    required this.endReasonCode,
    required this.endReasonLabel,
    required this.endReasonEnum,
  });

  factory EventMeetingEndedReasonParams.fromMap(Map<String, dynamic> map) {
    return EventMeetingEndedReasonParams(
      endReasonCode: map['endReasonCode'],
      endReasonLabel: map['endReasonLabel'],
      endReasonEnum: StatusMeetingEndReasonMapper.fromString(
        map['endReasonLabel'],
      ),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'endReasonCode': endReasonCode,
      'endReasonLabel': endReasonLabel,
      'endReasonEnum': endReasonEnum.name,
    };
  }
}
