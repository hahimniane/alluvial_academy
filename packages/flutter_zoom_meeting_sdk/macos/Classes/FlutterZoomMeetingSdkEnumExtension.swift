import ZoomSDK

extension ZoomSDKMeetingStatus {
  var name: String {
    switch self {
    case ZoomSDKMeetingStatus_Idle: return "IDLE"
    case ZoomSDKMeetingStatus_Connecting: return "CONNECTING"
    case ZoomSDKMeetingStatus_WaitingForHost: return "WAITING_FOR_HOST"
    case ZoomSDKMeetingStatus_InMeeting: return "IN_MEETING"
    case ZoomSDKMeetingStatus_Disconnecting: return "DISCONNECTING"
    case ZoomSDKMeetingStatus_Reconnecting: return "RECONNECTING"
    case ZoomSDKMeetingStatus_Failed: return "FAILED"
    case ZoomSDKMeetingStatus_Ended: return "ENDED"
    case ZoomSDKMeetingStatus_AudioReady: return "AUDIO_READY"
    case ZoomSDKMeetingStatus_OtherMeetingInProgress: return "OTHER_MEETING_IN_PROGRESS"
    case ZoomSDKMeetingStatus_InWaitingRoom: return "IN_WAITING_ROOM"
    case ZoomSDKMeetingStatus_Webinar_Promote: return "WEBINAR_PROMOTE"
    case ZoomSDKMeetingStatus_Webinar_Depromote: return "WEBINAR_DEPROMOTE"
    case ZoomSDKMeetingStatus_Join_Breakout_Room: return "JOIN_BREAKOUT_ROOM"
    case ZoomSDKMeetingStatus_Leave_Breakout_Room: return "LEAVE_BREAKOUT_ROOM"
    default: return "UNDEFINED"
    }
  }
}

extension ZoomSDKAuthError {
  var name: String {
    switch self {
    case ZoomSDKAuthError_Success: return "SUCCESS"
    case ZoomSDKAuthError_KeyOrSecretWrong: return "KEY_OR_SECRET_WRONG"
    case ZoomSDKAuthError_AccountNotSupport: return "ACCOUNT_NOT_SUPPORT"
    case ZoomSDKAuthError_AccountNotEnableSDK: return "ACCOUNT_NOT_ENABLE_SDK"
    case ZoomSDKAuthError_Timeout: return "TIMEOUT"
    case ZoomSDKAuthError_NetworkIssue: return "NETWORK_ISSUE"
    case ZoomSDKAuthError_Client_Incompatible: return "CLIENT_INCOMPATIBLE"
    case ZoomSDKAuthError_JwtTokenWrong: return "JWT_TOKEN_WRONG"
    case ZoomSDKAuthError_KeyOrSecretEmpty: return "KEY_OR_SECRET_EMPTY"
    case ZoomSDKAuthError_LimitExceededException: return "LIMIT_EXCEEDED_EXCEPTION"
    case ZoomSDKAuthError_Unknown: return "UNKNOWN"
    default: return "UNDEFINED"
    }
  }
}

extension ZoomSDKError {
  var name: String {
    switch self {
    case ZoomSDKError_Success: return "SUCCESS"
    case ZoomSDKError_Failed: return "FAILED"
    case ZoomSDKError_Uninit: return "UNINIT"
    case ZoomSDKError_ServiceFailed: return "SERVICE_FAILED"
    case ZoomSDKError_WrongUsage: return "WRONG_USAGE"
    case ZoomSDKError_InvalidParameter: return "INVALID_PARAMETER"
    case ZoomSDKError_NoPermission: return "NO_PERMISSION"
    case ZoomSDKError_NoRecordingInProgress: return "NO_RECORDING_IN_PROGRESS"
    case ZoomSDKError_TooFrequentCall: return "TOO_FREQUENT_CALL"
    case ZoomSDKError_UnSupportedFeature: return "UN_SUPPORTED_FEATURE"
    case ZoomSDKError_EmailLoginIsDisabled: return "EMAIL_LOGIN_IS_DISABLED"
    case ZoomSDKError_ModuleLoadFail: return "MODULE_LOAD_FAIL"
    case ZoomSDKError_NoVideoData: return "NO_VIDEO_DATA"
    case ZoomSDKError_NoAudioData: return "NO_AUDIO_DATA"
    case ZoomSDKError_NoShareData: return "NO_SHARE_DATA"
    case ZoomSDKError_NoVideoDeviceFound: return "NO_VIDEO_DEVICE_FOUND"
    case ZoomSDKError_DeviceError: return "DEVICE_ERROR"
    case ZoomSDKError_NotInMeeting: return "NOT_IN_MEETING"
    case ZoomSDKError_initDevice: return "INIT_DEVICE"
    case ZoomSDKError_CanNotChangeVirtualDevice: return "CAN_NOT_CHANGE_VIRTUAL_DEVICE"
    case ZoomSDKError_PreprocessRawdataError: return "PREPROCESS_RAWDATA_ERROR"
    case ZoomSDKError_NoLicense: return "NO_LICENSE"
    case ZoomSDKError_Malloc_Failed: return "MALLOC_FAILED"
    case ZoomSDKError_ShareCannotSubscribeMyself: return "SHARE_CANNOT_SUBSCRIBE_MYSELF"
    case ZoomSDKError_NeedUserConfirmRecordDisclaimer: return "NEED_USER_CONFIRM_RECORD_DISCLAIMER"
    case ZoomSDKError_UnKnown: return "UNKNOWN"
    case ZoomSDKError_NotJoinAudio: return "NOT_JOIN_AUDIO"
    case ZoomSDKError_HardwareDontSupport: return "HARDWARE_DONT_SUPPORT"
    case ZoomSDKError_DomainDontSupport: return "DOMAIN_DONT_SUPPORT"
    case ZoomSDKError_FileTransferError: return "FILE_TRANSFER_ERROR"
    default: return "UNDEFINED"
    }
  }
}

extension ZoomSDKMeetingError {
  var name: String {
    switch self {
    case ZoomSDKMeetingError_Success: return "SUCCESS"
    case ZoomSDKMeetingError_NetworkUnavailable: return "NETWORK_UNAVAILABLE"
    case ZoomSDKMeetingError_ReconnectFailed: return "RECONNECT_FAILED"
    case ZoomSDKMeetingError_MMRError: return "MMR_ERROR"
    case ZoomSDKMeetingError_PasswordError: return "PASSWORD_ERROR"
    case ZoomSDKMeetingError_SessionError: return "SESSION_ERROR"
    case ZoomSDKMeetingError_MeetingOver: return "MEETING_OVER"
    case ZoomSDKMeetingError_MeetingNotStart: return "MEETING_NOT_START"
    case ZoomSDKMeetingError_MeetingNotExist: return "MEETING_NOT_EXIST"
    case ZoomSDKMeetingError_UserFull: return "USER_FULL"
    case ZoomSDKMeetingError_ClientIncompatible: return "CLIENT_INCOMPATIBLE"
    case ZoomSDKMeetingError_NoMMR: return "NO_MMR"
    case ZoomSDKMeetingError_MeetingLocked: return "MEETING_LOCKED"
    case ZoomSDKMeetingError_MeetingRestricted: return "MEETING_RESTRICTED"
    case ZoomSDKMeetingError_MeetingJBHRestricted: return "MEETING_JBH_RESTRICTED"
    case ZoomSDKMeetingError_EmitWebRequestFailed: return "EMIT_WEB_REQUEST_FAILED"
    case ZoomSDKMeetingError_StartTokenExpired: return "START_TOKEN_EXPIRED"
    case ZoomSDKMeetingError_VideoSessionError: return "VIDEO_SESSION_ERROR"
    case ZoomSDKMeetingError_AudioAutoStartError: return "AUDIO_AUTO_START_ERROR"
    case ZoomSDKMeetingError_RegisterWebinarFull: return "REGISTER_WEBINAR_FULL"
    case ZoomSDKMeetingError_RegisterWebinarHostRegister: return "REGISTER_WEBINAR_HOST_REGISTER"
    case ZoomSDKMeetingError_RegisterWebinarPanelistRegister:
      return "REGISTER_WEBINAR_PANELIST_REGISTER"
    case ZoomSDKMeetingError_RegisterWebinarDeniedEmail: return "REGISTER_WEBINAR_DENIED_EMAIL"
    case ZoomSDKMeetingError_RegisterWebinarEnforceLogin: return "REGISTER_WEBINAR_ENFORCE_LOGIN"
    case ZoomSDKMeetingError_ZCCertificateChanged: return "ZC_CERTIFICATE_CHANGED"
    case ZoomSDKMeetingError_vanityNotExist: return "VANITY_NOT_EXIST"
    case ZoomSDKMeetingError_joinWebinarWithSameEmail: return "JOIN_WEBINAR_WITH_SAME_EMAIL"
    case ZoomSDKMeetingError_disallowHostMeeting: return "DISALLOW_HOST_MEETING"
    case ZoomSDKMeetingError_ConfigFileWriteFailed: return "CONFIG_FILE_WRITE_FAILED"
    case ZoomSDKMeetingError_forbidToJoinInternalMeeting: return "FORBID_TO_JOIN_INTERNAL_MEETING"
    case ZoomSDKMeetingError_RemovedByHost: return "REMOVED_BY_HOST"
    case ZoomSDKMeetingError_HostDisallowOutsideUserJoin: return "HOST_DISALLOW_OUTSIDE_USER_JOIN"
    case ZoomSDKMeetingError_UnableToJoinExternalMeeting: return "UNABLE_TO_JOIN_EXTERNAL_MEETING"
    case ZoomSDKMeetingError_BlockedByAccountAdmin: return "BLOCKED_BY_ACCOUNT_ADMIN"
    case ZoomSDKMeetingError_NeedSigninForPrivateMeeting: return "NEED_SIGN_IN_FOR_PRIVATE_MEETING"
    case ZoomSDKMeetingError_AppPrivilegeTokenError: return "APP_PRIVILEGE_TOKEN_ERROR"
    case ZoomSDKMeetingError_JmakUserEmailNotMatch: return "JMAK_USER_EMAIL_NOT_MATCH"
    case ZoomSDKMeetingError_None: return "NONE"
    case ZoomSDKMeetingError_Unknown: return "UNKNOWN"
    default: return "UNDEFINED"
    }
  }
}

extension EndMeetingReason {
  var name: String {
    switch self {
    case EndMeetingReason_None: return "NONE"
    case EndMeetingReason_KickByHost: return "KICK_BY_HOST"
    case EndMeetingReason_EndByHost: return "END_BY_HOST"
    case EndMeetingReason_JBHTimeOut: return "JBH_TIME_OUT"
    case EndMeetingReason_NoAttendee: return "NO_ATTENDEE"
    case EndMeetingReason_HostStartAnotherMeeting: return "HOST_START_ANOTHER_MEETING"
    case EndMeetingReason_FreeMeetingTimeOut: return "FREE_MEETING_TIME_OUT"
    case EndMeetingReason_NetworkBroken: return "NETWORK_BROKEN"
    default: return "UNDEFINED"
    }
  }
}

extension ZoomSDKLoginStatus {
  var name: String {
    switch self {
    case ZoomSDKLoginStatus_Idle: return "Idle"
    case ZoomSDKLoginStatus_Success: return "Success"
    case ZoomSDKLoginStatus_Failed: return "Failed"
    case ZoomSDKLoginStatus_Processing: return "Processing"
    default: return "UNDEFINED"
    }
  }
}

extension ZoomSDKLoginFailReason {
  var name: String {
    switch self {
    case ZoomSDKLoginFailReason_None: return "None"
    case ZoomSDKLoginFailReason_EmailLoginDisabled: return "EmailLoginDisabled"
    case ZoomSDKLoginFailReason_UserNotExist: return "UserNotExist"
    case ZoomSDKLoginFailReason_WrongPassword: return "WrongPassword"
    case ZoomSDKLoginFailReason_AccountLocked: return "AccountLocked"
    case ZoomSDKLoginFailReason_SDKNeedUpdate: return "SDKNeedUpdate"
    case ZoomSDKLoginFailReason_TooManyFailedAttempts: return "TooManyFailedAttempts"
    case ZoomSDKLoginFailReason_SMSCodeError: return "SMSCodeError"
    case ZoomSDKLoginFailReason_SMSCodeExpired: return "SMSCodeExpired"
    case ZoomSDKLoginFailReason_PhoneNumberFormatInValid: return "PhoneNumberFormatInValid"
    case ZoomSDKLoginFailReason_LoginTokenInvalid: return "LoginTokenInvalid"
    case ZoomSDKLoginFailReason_UserDisagreeLoginDisclaimer: return "UserDisagreeLoginDisclaimer"
    case ZoomSDKLoginFailReason_MFARequired: return "MFARequired"
    case ZoomSDKLoginFailReason_NeedBirthdayAsk: return "NeedBirthdayAsk"
    case ZoomSDKLoginFailReason_Other_Issue: return "Other_Issue"
    default: return "UNDEFINED"
    }
  }
}

extension ZoomSDKNotificationServiceStatus {
  var name: String {
    switch self {
    case ZoomSDKNotificationServiceStatus_None: return "None"
    case ZoomSDKNotificationServiceStatus_Starting: return "Starting"
    case ZoomSDKNotificationServiceStatus_Started: return "Started"
    case ZoomSDKNotificationServiceStatus_StartFailed: return "StartFailed"
    case ZoomSDKNotificationServiceStatus_Closed: return "Closed"
    default: return "UNDEFINED"
    }
  }
}

extension ZoomSDKNotificationServiceError {
  var name: String {
    switch self {
    case ZoomSDKNotificationServiceError_Success: return "Success"
    case ZoomSDKNotificationServiceError_Unknown: return "Unknown"
    case ZoomSDKNotificationServiceError_Internal_Error: return "Internal_Error"
    case ZoomSDKNotificationServiceError_Invalid_Token: return "Invalid_Token"
    case ZoomSDKNotificationServiceError_Multi_Connect: return "Multi_Connect"
    case ZoomSDKNotificationServiceError_Network_Issue: return "Network_Issue"
    case ZoomSDKNotificationServiceError_Max_Duration: return "Max_Duration"
    default: return "UNDEFINED"
    }
  }
}

extension MeetingType {
    var name: String {
        switch self {
        case MeetingType_None: return "NONE"
        case MeetingType_Normal: return "NORMAL"
        case MeetingType_BreakoutRoom: return "BREAKOUT_ROOM"
        case MeetingType_Webinar: return "WEBINAR"
        default: return "UNDEFINED"
        }
    }
}
