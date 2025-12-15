import 'package:flutter_zoom_meeting_sdk/helpers/common.dart';

enum StatusMeetingError {
  /// android | mac | ios
  success,

  /// android
  incorrectMeetingNumber,

  /// android
  timeout,

  /// android | mac | ios
  netowrkUnavailable,

  /// android | mac | ios
  clientIncompatible,

  /// android
  networkError,

  /// android | mac | ios
  mmrError,

  /// android | mac | ios
  sessionError,

  /// android | mac | ios
  meetingOver,

  /// android | mac | ios
  meetingNotExist,

  /// android | mac | ios
  userFull,

  /// android | mac | ios
  noMMR,

  /// android | mac | ios
  meetingLocked,

  /// android | mac | ios
  meetingRestricted,

  /// android | mac | ios
  meetingJbhRestricted,

  /// android
  webServiceFailed,

  /// android | mac | ios
  registerWebinarFull,

  /// android | mac | ios
  registerWebinarHostRegister,

  /// android | mac | ios
  registerWebinarPanelistRegister,

  /// android | mac | ios
  registerWebinarDeniedEmail,

  /// android | mac | ios
  registerWebinarEnforceLogin,

  /// android
  exitWhenWaitingHostStart,

  /// android | mac | ios
  removedByHost,

  /// android | mac | ios
  hostDisallowOutsideUserJoin,

  /// android | mac | ios
  unableToJoinExternalMeeting,

  /// android | mac | ios
  blockedByAccountAdmin,

  /// android | mac | ios
  needSignInForPrivateMeeting,

  /// android | ios
  invalidArguments,

  /// android | mac | ios
  unknown,

  /// android
  invalidStatus,

  /// android | mac
  jmakUserEmailNotMatch,

  /// android | mac | ios
  appPrivilegeTokenError,

  /// android | mac | ios
  undefined,

  /// mac | ios
  reconnectFailed,

  /// mac | ios
  passwordError,

  /// mac | ios
  meetingNotStart,

  /// mac | ios
  emitWebRequestFailed,

  /// mac | ios
  startTokenExpired,

  /// mac | ios
  videoSessionError,

  /// mac | ios
  audioAutoStartError,

  /// mac
  none,

  /// mac | ios
  joinWebinarWithSameEmail,

  /// mac
  disallowHostMeeting,

  /// mac | ios
  configFileWriteFailed,

  /// mac | ios
  zcCertificateChanged,

  /// mac | ios
  vanityNotExist,

  /// mac
  forbidToJoinInternalMeeting,

  /// ios
  invalidUserType,

  /// ios
  inAnotherMeeting,

  /// ios
  tooFrequenceCall,

  /// ios
  wrongUsage,

  /// ios
  failed,

  /// ios
  vbBase,

  /// ios
  vbSetError,

  /// ios
  vbMaximumNum,

  /// ios
  vbSaveImage,

  /// ios
  vbRemoveNone,

  /// ios
  vbNoSupport,

  /// ios
  vbGreenScreenNoSupport,
}

extension StatusMeetingErrorMapper on StatusMeetingError {
  static final Map<String, StatusMeetingError> _map = generateStatusMap(
    StatusMeetingError.values,
    (e) => e.name,
  );

  static StatusMeetingError fromString(String status) {
    return _map[status.toUpperCase()] ?? StatusMeetingError.undefined;
  }
}
