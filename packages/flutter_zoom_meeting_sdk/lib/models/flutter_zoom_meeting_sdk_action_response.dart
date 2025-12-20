import 'package:flutter_zoom_meeting_sdk/enums/action_type.dart';
import 'package:flutter_zoom_meeting_sdk/enums/platform_type.dart';
import 'package:flutter_zoom_meeting_sdk/helpers/common.dart';
import 'package:flutter_zoom_meeting_sdk/helpers/message.dart';

/// Standard action response wrapper
class FlutterZoomMeetingSdkActionResponse<T> {
  /// The platform type
  final PlatformType platform;

  /// The action type
  final ActionType action;

  /// Whether the action is successful
  final bool isSuccess;

  /// The message of the action
  final String message;

  /// The params of the action
  final T? params;

  FlutterZoomMeetingSdkActionResponse({
    required this.platform,
    required this.action,
    required this.isSuccess,
    required this.message,
    required this.params,
  });

  factory FlutterZoomMeetingSdkActionResponse.fromMap(
    Map<String, dynamic> map,
    T Function(Map<String, dynamic>) paramsParser,
  ) {
    try {
      final platformStr = map['platform']?.toString();
      final actionStr = map['action']?.toString();

      return FlutterZoomMeetingSdkActionResponse(
        platform:
            platformStr != null
                ? PlatformType.values.firstWhere(
                  (e) => e.name == platformStr,
                  orElse: () => PlatformType.android, // Fallback
                )
                : PlatformType.android,
        action:
            actionStr != null
                ? ActionType.values.firstWhere(
                  (e) => e.name == actionStr,
                  orElse: () => ActionType.initZoom, // Fallback
                )
                : ActionType.initZoom,
        isSuccess: map['isSuccess'] == true,
        message: getActionMessage(map['message']?.toString() ?? ''),
        params:
            map['params'] != null &&
                    map['params'] is Map &&
                    (map['params'] as Map).isNotEmpty
                ? paramsParser(Map<String, dynamic>.from(map['params'] as Map))
                : null,
      );
    } catch (e) {
      // If parsing fails, return a failed response instead of crashing
      return FlutterZoomMeetingSdkActionResponse(
        platform: PlatformType.android,
        action: ActionType.initZoom,
        isSuccess: false,
        message: 'Parse error: $e',
        params: null,
      );
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'platform': platform.name,
      'action': action.name,
      'isSuccess': isSuccess,
      'message': message,
      'params':
          params is MappableParams
              ? (params as MappableParams).toMap()
              : params,
    };
  }
}

/// Action response params for [ActionType.initZoom]
class InitParamsResponse implements MappableParams {
  /// The status code of the action.
  /// This value returned directly from the Zoom Meeting SDK and represent enum values defined per platform.
  /// These enum values are not guaranteed to be consistent across platforms, so prefer using statusLabel.
  final int? statusCode;

  /// The status label of the action
  final String? statusLabel;

  InitParamsResponse({this.statusCode, this.statusLabel});

  factory InitParamsResponse.fromMap(Map<String, dynamic> map) {
    return InitParamsResponse(
      statusCode:
          map['statusCode'] != null ? (map['statusCode'] as num).toInt() : null,
      statusLabel: map['statusLabel'] as String?,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {'statusCode': statusCode, 'statusLabel': statusLabel};
  }
}

/// Action response params for [ActionType.authZoom]
class AuthParamsResponse implements MappableParams {
  /// The status code of the action.
  /// This value returned directly from the Zoom Meeting SDK and represent enum values defined per platform.
  /// These enum values are not guaranteed to be consistent across platforms, so prefer using statusLabel.
  final int statusCode;

  /// The status label of the action
  final String statusLabel;

  AuthParamsResponse({required this.statusCode, required this.statusLabel});

  factory AuthParamsResponse.fromMap(Map<String, dynamic> map) {
    return AuthParamsResponse(
      statusCode: (map['statusCode'] as num?)?.toInt() ?? -1,
      statusLabel: map['statusLabel']?.toString() ?? 'unknown',
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {'statusCode': statusCode, 'statusLabel': statusLabel};
  }
}

/// Action response params for [ActionType.joinMeeting]
class JoinParamsResponse implements MappableParams {
  /// The status code of the action.
  /// This value returned directly from the Zoom Meeting SDK and represent enum values defined per platform.
  /// These enum values are not guaranteed to be consistent across platforms, so prefer using statusLabel.
  final int statusCode;

  /// The status label of the action
  final String statusLabel;

  JoinParamsResponse({required this.statusCode, required this.statusLabel});

  factory JoinParamsResponse.fromMap(Map<String, dynamic> map) {
    return JoinParamsResponse(
      statusCode: (map['statusCode'] as num?)?.toInt() ?? -1,
      statusLabel: map['statusLabel']?.toString() ?? 'unknown',
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {'statusCode': statusCode, 'statusLabel': statusLabel};
  }
}
