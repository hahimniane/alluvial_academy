import 'package:flutter_zoom_meeting_sdk/helpers/common.dart';

enum StatusZoomError {
  /// mac | ios | android | windows
  success,

  /// android
  invalidArguments,

  /// android
  illegalAppKeyOrSecret,

  /// mac | ios | android | windows
  networkIssue,

  /// mac | ios | android | windows
  clientIncompatible,

  /// mac | ios | android | windows
  jwtTokenWrong,

  /// android
  keyOrSecretError,

  /// mac | ios | android | windows
  accountNotSupport,

  /// mac | ios | android | windows
  accountNotEnableSdk,

  /// mac | ios | android | windows
  limitExceededException,

  /// android
  deviceNotSupported,

  /// mac | ios | android | windows
  unknown,

  /// android
  domainDontSupport,

  /// mac | ios | windows
  timeout,

  /// mac | ios | windows
  keyOrSecretWrong,

  /// mac | ios | windows
  keyOrSecretEmpty,

  /// ios | windows
  serviceBusy,

  /// ios | windows
  none,

  /// mac | ios | android | windows
  undefined,
}

extension StatusZoomErrorMapper on StatusZoomError {
  static final Map<String, StatusZoomError> _map = generateStatusMap(
    StatusZoomError.values,
    (e) => e.name,
  );

  static StatusZoomError fromString(String status) {
    return _map[status.toUpperCase()] ?? StatusZoomError.undefined;
  }
}
