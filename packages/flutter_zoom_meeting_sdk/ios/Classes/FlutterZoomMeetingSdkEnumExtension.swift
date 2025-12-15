import MobileRTC
extension MobileRTCMeetingState {
    var name: String {
        switch self {
        case .idle: return "IDLE"
        case .connecting: return "CONNECTING"
        case .waitingForHost: return "WAITING_FOR_HOST"
        case .inMeeting: return "IN_MEETING"
        case .disconnecting: return "DISCONNECTING"
        case .reconnecting: return "RECONNECTING"
        case .failed: return "FAILED"
        case .ended: return "ENDED"
        case .locked: return "LOCKED"
        case .unlocked: return "UNLOCKED"
        case .inWaitingRoom: return "IN_WAITING_ROOM"
        case .webinarPromote: return "WEBINAR_PROMOTE"
        case .webinarDePromote: return "WEBINAR_DEPROMOTE"
        case .joinBO: return "JOIN_BREAKOUT_ROOM"
        case .leaveBO: return "LEAVE_BREAKOUT_ROOM"
        @unknown default: return "UNDEFINED"
        }
    }
}


extension MobileRTCAuthError {
    var name: String {
        switch self {
        case .success: return "SUCCESS"
        case .keyOrSecretEmpty: return "KEY_OR_SECRET_EMPTY"
        case .keyOrSecretWrong: return "KEY_OR_SECRET_WRONG"
        case .accountNotSupport: return "ACCOUNT_NOT_SUPPORT"
        case .accountNotEnableSDK: return "ACCOUNT_NOT_ENABLE_SDK"
        case .unknown: return "UNKNOWN"
        case .serviceBusy: return "SERVICE_BUSY"
        case .none: return "NONE"
        case .overTime: return "TIMEOUT"
        case .networkIssue: return "NETWORK_ISSUE"
        case .clientIncompatible: return "CLIENT_INCOMPATIBLE"
        case .tokenWrong: return "JWT_TOKEN_WRONG"
        case .limitExceededException: return "LIMIT_EXCEEDED_EXCEPTION"
        @unknown default: return "UNDEFINED"
        }
    }
}

extension MobileRTCSDKError {
    var name: String {
        switch self {
        case .success: return "Success"
        case .noImpl: return "NoImpl"
        case .wrongUsage: return "WrongUsage"
        case .invalidParameter: return "InvalidParameter"
        case .moduleLoadFailed: return "ModuleLoadFailed"
        case .memoryFailed: return "MemoryFailed"
        case .serviceFailed: return "ServiceFailed"
        case .uninitialize: return "Uninitialize"
        case .unauthentication: return "Unauthentication"
        case .noRecordingInprocess: return "NoRecordingInprocess"
        case .transcoderNoFound: return "TranscoderNoFound"
        case .videoNotReady: return "VideoNotReady"
        case .noPermission: return "NoPermission"
        case .unknown: return "Unknown"
        case .otherSdkInstanceRunning: return "OtherSdkInstanceRunning"
        case .internalError: return "InternalError"
        case .noAudiodeviceIsFound: return "NoAudiodeviceIsFound"
        case .noVideoDeviceIsFound: return "NoVideoDeviceIsFound"
        case .tooFrequentCall: return "TooFrequentCall"
        case .failAssignUserPrivilege: return "FailAssignUserPrivilege"
        case .meetingDontSupportFeature: return "MeetingDontSupportFeature"
        case .meetingNotShareSender: return "MeetingNotShareSender"
        case .meetingYouHaveNoShare: return "MeetingYouHaveNoShare"
        case .meetingViewtypeParameterIsWrong: return "MeetingViewtypeParameterIsWrong"
        case .meetingAnnotationIsOff: return "MeetingAnnotationIsOff"
        case .settingOsDontSupport: return "SettingOsDontSupport"
        case .emailLoginIsDisabled: return "EmailLoginIsDisabled"
        case .hardwareNotMeetForVb: return "HardwareNotMeetForVb"
        case .needUserConfirmRecordDisclaimer: return "NeedUserConfirmRecordDisclaimer"
        case .noShareData: return "NoShareData"
        case .shareCannotSubscribeMyself: return "ShareCannotSubscribeMyself"
        case .notInMeeting: return "NotInMeeting"
        case .meetingCallOutFailed: return "MeetingCallOutFailed"
        case .notSupportMultiStreamVideoUser: return "NotSupportMultiStreamVideoUser"
        case .meetingRemoteControlIsOff: return "MeetingRemoteControlIsOff"
        case .fileTransferError: return "FileTransferError"
        @unknown default: return "UNDEFINED"
        }
    }
}

extension MobileRTCMeetError {
    var name: String {
        switch self {
        case .success: return "SUCCESS"
        case .networkError: return "NETWORK_UNAVAILABLE"
        case .reconnectError: return "RECONNECT_FAILED"
        case .mmrError: return "MMR_ERROR"
        case .passwordError: return "PASSWORD_ERROR"
        case .sessionError: return "SESSION_ERROR"
        case .meetingOver: return "MEETING_OVER"
        case .meetingNotStart: return "MEETING_NOT_START"
        case .meetingNotExist: return "MEETING_NOT_EXIST"
        case .meetingUserFull: return "USER_FULL"
        case .meetingClientIncompatible: return "CLIENT_INCOMPATIBLE"
        case .noMMR: return "NO_MMR"
        case .meetingLocked: return "MEETING_LOCKED"
        case .meetingRestricted: return "MEETING_RESTRICTED"
        case .meetingRestrictedJBH: return "MEETING_JBH_RESTRICTED"
        case .cannotEmitWebRequest: return "EMIT_WEB_REQUEST_FAILED"
        case .cannotStartTokenExpire: return "START_TOKEN_EXPIRED"
        case .videoError: return "VIDEO_SESSION_ERROR"
        case .audioAutoStartError: return "AUDIO_AUTO_START_ERROR"
        case .registerWebinarFull: return "REGISTER_WEBINAR_FULL"
        case .registerWebinarHostRegister: return "REGISTER_WEBINAR_HOST_REGISTER"
        case .registerWebinarPanelistRegister: return "REGISTER_WEBINAR_PANELIST_REGISTER"
        case .registerWebinarDeniedEmail: return "REGISTER_WEBINAR_DENIED_EMAIL"
        case .registerWebinarEnforceLogin: return "REGISTER_WEBINAR_ENFORCE_LOGIN"
        case .zcCertificateChanged: return "ZC_CERTIFICATE_CHANGED"
        case .vanityNotExist: return "VANITY_NOT_EXIST"
        case .joinWebinarWithSameEmail: return "JOIN_WEBINAR_WITH_SAME_EMAIL"
        case .writeConfigFile: return "CONFIG_FILE_WRITE_FAILED"
        case .removedByHost: return "REMOVED_BY_HOST"
        case .hostDisallowOutsideUserJoin: return "HOST_DISALLOW_OUTSIDE_USER_JOIN"
        case .unableToJoinExternalMeeting: return "UNABLE_TO_JOIN_EXTERNAL_MEETING"
        case .blockedByAccountAdmin: return "BLOCKED_BY_ACCOUNT_ADMIN"
        case .needSignInForPrivateMeeting: return "NEED_SIGN_IN_FOR_PRIVATE_MEETING"
        case .invalidArguments: return "INVALID_ARGUMENTS"
        case .invalidUserType: return "INVALID_USER_TYPE"
        case .inAnotherMeeting: return "IN_ANOTHER_MEETING"
        case .tooFrequenceCall: return "TOO_FREQUENCE_CALL"
        case .wrongUsage: return "WRONG_USAGE"
        case .failed: return "FAILED"
        case .vbBase: return "VB_BASE"
        case .vbSetError: return "VB_SET_ERROR"
        case .vbMaximumNum: return "VB_MAXIMUM_NUM"
        case .vbSaveImage: return "VB_SAVE_IMAGE"
        case .vbRemoveNone: return "VB_REMOVE_NONE"
        case .vbNoSupport: return "VB_NO_SUPPORT"
        case .vbGreenScreenNoSupport: return "VB_GREEN_SCREEN_NO_SUPPORT"
        case .appPrivilegeTokenError: return "APP_PRIVILEGE_TOKEN_ERROR"
        case .unknown: return "UNKNOWN"
        @unknown default: return "UNDEFINED"
        }
    }
}

extension MobileRTCMeetingEndReason {
    var name: String {
        switch self {
        case .selfLeave: return "SELF_LEAVE"
        case .removedByHost: return "KICK_BY_HOST"
        case .endByHost: return "END_BY_HOST"
        case .jbhTimeout: return "JBH_TIME_OUT"
        case .freeMeetingTimeout: return "FREE_MEETING_TIME_OUT"
        case .noAteendee: return "NO_ATTENDEE"
        case .hostEndForAnotherMeeting: return "HOST_START_ANOTHER_MEETING"
        case .connectBroken: return "NETWORK_BROKEN"
        case .unknown: return "UNKNOWN"
        @unknown default: return "UNDEFINED"
        }
    }
}

extension MobileRTCLoginFailReason {
    var name: String {
        switch self {
        case .success: return "Success"
        case .emailLoginDisable: return "EmailLoginDisable"
        case .userNotExist: return "UserNotExist"
        case .wrongPassword: return "WrongPassword"
        case .accountLocked: return "AccountLocked"
        case .sdkNeedUpdate: return "SDKNeedUpdate"
        case .tooManyFailedAttempts: return "TooManyFailedAttempts"
        case .smsCodeError: return "SMSCodeError"
        case .smsCodeExpired: return "SMSCodeExpired"
        case .phoneNumberFormatInValid: return "PhoneNumberFormatInValid"
        case .loginTokenInvalid: return "LoginTokenInvalid"
        case .userDisagreeLoginDisclaimer: return "UserDisagreeLoginDisclaimer"
        case .mfaRequired: return "MFARequired"
        case .needBirthdayAsk: return "NeedBirthdayAsk"
        case .otherIssue: return "OtherIssue"
        case .invalidArguments: return "InvalidArguments"
        case .sdkNotAuthorized: return "SDKNotAuthorized"
        case .inAutoLoginProcess: return "InAutoLoginProcess"
        case .alreayLoggedin: return "AlreayLoggedin"
        @unknown default: return "UNDEFINED"
        }
    }
}

extension MobileRTCNotificationServiceStatus {
    var name: String {
        switch self {
        case .none: return "None"
        case .starting: return "Starting"
        case .started: return "Started"
        case .startFailed: return "StartFailed"
        case .closed: return "Closed"
        @unknown default: return "UNDEFINED"
        }
    }
}

extension MobileRTCNotificationServiceError {
    var name: String {
        switch self {
        case .success: return "Success"
        case .unknown: return "Unknown"
        case .internal_Error: return "Internal_Error"
        case .invalid_Token: return "Invalid_Token"
        case .multi_Connect: return "Multi_Connect"
        case .network_Issue: return "Network_Issue"
        case .max_Duration: return "Max_Duration"
        case .app_Background: return "App_Background"
        @unknown default: return "UNDEFINED"
        }
    }
}

extension MobileRTCMeetingType{
    var name: String {
        switch self {
        case .none : return "NONE"
        case .normal: return "NORMAL"
        case .breakoutRoom: return "BREAKOUT_ROOM"
        case .webinar: return "WEBINAR"
        @unknown default: return "UNDEFINED"
        }
    }
}
 
