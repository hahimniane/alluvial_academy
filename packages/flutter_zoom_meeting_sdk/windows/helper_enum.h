#pragma once

#include <windows.h>
#include <string>
#include <unordered_map>
#include "auth_service_interface.h"

// Generalized function for mapping enums to strings
template <typename EnumType>
inline std::string ConvertEnumToString(EnumType result, const std::unordered_map<EnumType, std::string> &names)
{
    auto it = names.find(result);
    return it != names.end() ? it->second : "UNDEFINED";
}

// General
inline std::string EnumToString(ZOOM_SDK_NAMESPACE::SDKError result)
{
    static const std::unordered_map<ZOOM_SDK_NAMESPACE::SDKError, std::string> names = {
        {ZOOM_SDK_NAMESPACE::SDKError::SDKERR_SUCCESS, "SUCCESS"},
        {ZOOM_SDK_NAMESPACE::SDKError::SDKERR_NO_IMPL, "NO_IMPL"},
        {ZOOM_SDK_NAMESPACE::SDKError::SDKERR_WRONG_USAGE, "WRONG_USAGE"},
        {ZOOM_SDK_NAMESPACE::SDKError::SDKERR_INVALID_PARAMETER, "INVALID_PARAMETER"},
        {ZOOM_SDK_NAMESPACE::SDKError::SDKERR_MODULE_LOAD_FAILED, "MODULE_LOAD_FAILED"},
        {ZOOM_SDK_NAMESPACE::SDKError::SDKERR_MEMORY_FAILED, "MEMORY_FAILED"},
        {ZOOM_SDK_NAMESPACE::SDKError::SDKERR_SERVICE_FAILED, "SERVICE_FAILED"},
        {ZOOM_SDK_NAMESPACE::SDKError::SDKERR_UNINITIALIZE, "UNINITIALIZE"},
        {ZOOM_SDK_NAMESPACE::SDKError::SDKERR_UNAUTHENTICATION, "UNAUTHENTICATION"},
        {ZOOM_SDK_NAMESPACE::SDKError::SDKERR_NORECORDINGINPROCESS, "NORECORDINGINPROCESS"},
        {ZOOM_SDK_NAMESPACE::SDKError::SDKERR_TRANSCODER_NOFOUND, "TRANSCODER_NOFOUND"},
        {ZOOM_SDK_NAMESPACE::SDKError::SDKERR_VIDEO_NOTREADY, "VIDEO_NOTREADY"},
        {ZOOM_SDK_NAMESPACE::SDKError::SDKERR_NO_PERMISSION, "NO_PERMISSION"},
        {ZOOM_SDK_NAMESPACE::SDKError::SDKERR_UNKNOWN, "UNKNOWN"},
        {ZOOM_SDK_NAMESPACE::SDKError::SDKERR_OTHER_SDK_INSTANCE_RUNNING, "OTHER_SDK_INSTANCE_RUNNING"},
        {ZOOM_SDK_NAMESPACE::SDKError::SDKERR_INTERNAL_ERROR, "INTERNAL_ERROR"},
        {ZOOM_SDK_NAMESPACE::SDKError::SDKERR_NO_AUDIODEVICE_ISFOUND, "NO_AUDIODEVICE_ISFOUND"},
        {ZOOM_SDK_NAMESPACE::SDKError::SDKERR_NO_VIDEODEVICE_ISFOUND, "NO_VIDEODEVICE_ISFOUND"},
        {ZOOM_SDK_NAMESPACE::SDKError::SDKERR_TOO_FREQUENT_CALL, "TOO_FREQUENT_CALL"},
        {ZOOM_SDK_NAMESPACE::SDKError::SDKERR_FAIL_ASSIGN_USER_PRIVILEGE, "FAIL_ASSIGN_USER_PRIVILEGE"},
        {ZOOM_SDK_NAMESPACE::SDKError::SDKERR_MEETING_DONT_SUPPORT_FEATURE, "MEETING_DONT_SUPPORT_FEATURE"},
        {ZOOM_SDK_NAMESPACE::SDKError::SDKERR_MEETING_NOT_SHARE_SENDER, "MEETING_NOT_SHARE_SENDER"},
        {ZOOM_SDK_NAMESPACE::SDKError::SDKERR_MEETING_YOU_HAVE_NO_SHARE, "MEETING_YOU_HAVE_NO_SHARE"},
        {ZOOM_SDK_NAMESPACE::SDKError::SDKERR_MEETING_VIEWTYPE_PARAMETER_IS_WRONG, "MEETING_VIEWTYPE_PARAMETER_IS_WRONG"},
        {ZOOM_SDK_NAMESPACE::SDKError::SDKERR_MEETING_ANNOTATION_IS_OFF, "MEETING_ANNOTATION_IS_OFF"},
        {ZOOM_SDK_NAMESPACE::SDKError::SDKERR_SETTING_OS_DONT_SUPPORT, "SETTING_OS_DONT_SUPPORT"},
        {ZOOM_SDK_NAMESPACE::SDKError::SDKERR_EMAIL_LOGIN_IS_DISABLED, "EMAIL_LOGIN_IS_DISABLED"},
        {ZOOM_SDK_NAMESPACE::SDKError::SDKERR_HARDWARE_NOT_MEET_FOR_VB, "HARDWARE_NOT_MEET_FOR_VB"},
        {ZOOM_SDK_NAMESPACE::SDKError::SDKERR_NEED_USER_CONFIRM_RECORD_DISCLAIMER, "NEED_USER_CONFIRM_RECORD_DISCLAIMER"},
        {ZOOM_SDK_NAMESPACE::SDKError::SDKERR_NO_SHARE_DATA, "NO_SHARE_DATA"},
        {ZOOM_SDK_NAMESPACE::SDKError::SDKERR_SHARE_CANNOT_SUBSCRIBE_MYSELF, "SHARE_CANNOT_SUBSCRIBE_MYSELF"},
        {ZOOM_SDK_NAMESPACE::SDKError::SDKERR_NOT_IN_MEETING, "NOT_IN_MEETING"},
        {ZOOM_SDK_NAMESPACE::SDKError::SDKERR_NOT_JOIN_AUDIO, "NOT_JOIN_AUDIO"},
        {ZOOM_SDK_NAMESPACE::SDKError::SDKERR_HARDWARE_DONT_SUPPORT, "HARDWARE_DONT_SUPPORT"},
        {ZOOM_SDK_NAMESPACE::SDKError::SDKERR_DOMAIN_DONT_SUPPORT, "DOMAIN_DONT_SUPPORT"},
        {ZOOM_SDK_NAMESPACE::SDKError::SDKERR_MEETING_REMOTE_CONTROL_IS_OFF, "MEETING_REMOTE_CONTROL_IS_OFF"},
        {ZOOM_SDK_NAMESPACE::SDKError::SDKERR_FILETRANSFER_ERROR, "FILETRANSFER_ERROR"},
    };

    return ConvertEnumToString(result, names);
}

// Auth Service
inline std::string EnumToString(ZOOM_SDK_NAMESPACE::AuthResult result)
{
    static const std::unordered_map<ZOOM_SDK_NAMESPACE::AuthResult, std::string> names = {
        {ZOOM_SDK_NAMESPACE::AuthResult::AUTHRET_SUCCESS, "SUCCESS"},
        {ZOOM_SDK_NAMESPACE::AuthResult::AUTHRET_KEYORSECRETEMPTY, "KEY_OR_SECRET_EMPTY"},
        {ZOOM_SDK_NAMESPACE::AuthResult::AUTHRET_KEYORSECRETWRONG, "KEY_OR_SECRET_WRONG"},
        {ZOOM_SDK_NAMESPACE::AuthResult::AUTHRET_ACCOUNTNOTSUPPORT, "ACCOUNT_NOT_SUPPORT"},
        {ZOOM_SDK_NAMESPACE::AuthResult::AUTHRET_ACCOUNTNOTENABLESDK, "ACCOUNT_NOT_ENABLE_SDK"},
        {ZOOM_SDK_NAMESPACE::AuthResult::AUTHRET_UNKNOWN, "UNKNOWN"},
        {ZOOM_SDK_NAMESPACE::AuthResult::AUTHRET_SERVICE_BUSY, "SERVICE_BUSY"},
        {ZOOM_SDK_NAMESPACE::AuthResult::AUTHRET_NONE, "NONE"},
        {ZOOM_SDK_NAMESPACE::AuthResult::AUTHRET_OVERTIME, "TIMEOUT"},
        {ZOOM_SDK_NAMESPACE::AuthResult::AUTHRET_NETWORKISSUE, "NETWORK_ISSUE"},
        {ZOOM_SDK_NAMESPACE::AuthResult::AUTHRET_CLIENT_INCOMPATIBLE, "CLIENT_INCOMPATIBLE"},
        {ZOOM_SDK_NAMESPACE::AuthResult::AUTHRET_JWTTOKENWRONG, "JWT_TOKEN_WRONG"},
        {ZOOM_SDK_NAMESPACE::AuthResult::AUTHRET_LIMIT_EXCEEDED_EXCEPTION, "LIMIT_EXCEEDED_EXCEPTION"},
    };

    return ConvertEnumToString(result, names);
}

inline std::string EnumToString(ZOOM_SDK_NAMESPACE::LOGINSTATUS result)
{
    static const std::unordered_map<ZOOM_SDK_NAMESPACE::LOGINSTATUS, std::string> names = {
        {ZOOM_SDK_NAMESPACE::LOGINSTATUS::LOGIN_IDLE, "IDLE"},
        {ZOOM_SDK_NAMESPACE::LOGINSTATUS::LOGIN_PROCESSING, "PROCESSING"},
        {ZOOM_SDK_NAMESPACE::LOGINSTATUS::LOGIN_SUCCESS, "SUCCESS"},
        {ZOOM_SDK_NAMESPACE::LOGINSTATUS::LOGIN_FAILED, "FAILED"},
    };

    return ConvertEnumToString(result, names);
}

inline std::string EnumToString(ZOOM_SDK_NAMESPACE::LoginFailReason result)
{
    static const std::unordered_map<ZOOM_SDK_NAMESPACE::LoginFailReason, std::string> names = {
        {ZOOM_SDK_NAMESPACE::LoginFailReason::LoginFail_None, "None"},
        {ZOOM_SDK_NAMESPACE::LoginFailReason::LoginFail_EmailLoginDisable, "EmailLoginDisable"},
        {ZOOM_SDK_NAMESPACE::LoginFailReason::LoginFail_UserNotExist, "UserNotExist"},
        {ZOOM_SDK_NAMESPACE::LoginFailReason::LoginFail_WrongPassword, "WrongPassword"},
        {ZOOM_SDK_NAMESPACE::LoginFailReason::LoginFail_AccountLocked, "AccountLocked"},
        {ZOOM_SDK_NAMESPACE::LoginFailReason::LoginFail_SDKNeedUpdate, "SDKNeedUpdate"},
        {ZOOM_SDK_NAMESPACE::LoginFailReason::LoginFail_TooManyFailedAttempts, "TooManyFailedAttempts"},
        {ZOOM_SDK_NAMESPACE::LoginFailReason::LoginFail_SMSCodeError, "SMSCodeError"},
        {ZOOM_SDK_NAMESPACE::LoginFailReason::LoginFail_SMSCodeExpired, "SMSCodeExpired"},
        {ZOOM_SDK_NAMESPACE::LoginFailReason::LoginFail_PhoneNumberFormatInValid, "PhoneNumberFormatInValid"},
        {ZOOM_SDK_NAMESPACE::LoginFailReason::LoginFail_LoginTokenInvalid, "LoginTokenInvalid"},
        {ZOOM_SDK_NAMESPACE::LoginFailReason::LoginFail_UserDisagreeLoginDisclaimer, "UserDisagreeLoginDisclaimer"},
        {ZOOM_SDK_NAMESPACE::LoginFailReason::LoginFail_Mfa_Required, "Mfa_Required"},
        {ZOOM_SDK_NAMESPACE::LoginFailReason::LoginFail_Need_Bitrthday_ask, "Need_Bitrthday_ask"},
        {ZOOM_SDK_NAMESPACE::LoginFailReason::LoginFail_OtherIssue, "OtherIssue"},
    };

    return ConvertEnumToString(result, names);
}

inline std::string EnumToString(ZOOM_SDK_NAMESPACE::SDKNotificationServiceStatus result)
{
    static const std::unordered_map<ZOOM_SDK_NAMESPACE::SDKNotificationServiceStatus, std::string> names = {
        {ZOOM_SDK_NAMESPACE::SDKNotificationServiceStatus::SDK_Notification_Service_None, "None"},
        {ZOOM_SDK_NAMESPACE::SDKNotificationServiceStatus::SDK_Notification_Service_Starting, "Starting"},
        {ZOOM_SDK_NAMESPACE::SDKNotificationServiceStatus::SDK_Notification_Service_Started, "Started"},
        {ZOOM_SDK_NAMESPACE::SDKNotificationServiceStatus::SDK_Notification_Service_StartFailed, "StartFailed"},
        {ZOOM_SDK_NAMESPACE::SDKNotificationServiceStatus::SDK_Notification_Service_Closed, "Closed"},
    };

    return ConvertEnumToString(result, names);
}

inline std::string EnumToString(ZOOM_SDK_NAMESPACE::SDKNotificationServiceError result)
{
    static const std::unordered_map<ZOOM_SDK_NAMESPACE::SDKNotificationServiceError, std::string> names = {
        {ZOOM_SDK_NAMESPACE::SDKNotificationServiceError::SDK_Notification_Service_Error_Success, "Success"},
        {ZOOM_SDK_NAMESPACE::SDKNotificationServiceError::SDK_Notification_Service_Error_Unknown, "Unknown"},
        {ZOOM_SDK_NAMESPACE::SDKNotificationServiceError::SDK_Notification_Service_Error_Internal_Error, "Internal_Error"},
        {ZOOM_SDK_NAMESPACE::SDKNotificationServiceError::SDK_Notification_Service_Error_Invalid_Token, "Invalid_Token"},
        {ZOOM_SDK_NAMESPACE::SDKNotificationServiceError::SDK_Notification_Service_Error_Multi_Connect, "Multi_Connect"},
        {ZOOM_SDK_NAMESPACE::SDKNotificationServiceError::SDK_Notification_Service_Error_Network_Issue, "Network_Issue"},
        {ZOOM_SDK_NAMESPACE::SDKNotificationServiceError::SDK_Notification_Service_Error_Max_Duration, "Max_Duration"},
    };

    return ConvertEnumToString(result, names);
}

inline std::string EnumToString(ZOOM_SDK_NAMESPACE::LoginType result)
{
    static const std::unordered_map<ZOOM_SDK_NAMESPACE::LoginType, std::string> names = {
        {ZOOM_SDK_NAMESPACE::LoginType::LoginType_Unknown, "Unknown"},
        {ZOOM_SDK_NAMESPACE::LoginType::LoginType_SSO, "SSO"},
    };

    return ConvertEnumToString(result, names);
}

// Meeting Service
inline std::string EnumToString(ZOOM_SDK_NAMESPACE::MeetingStatus result)
{
    static const std::unordered_map<ZOOM_SDK_NAMESPACE::MeetingStatus, std::string> names = {
        {ZOOM_SDK_NAMESPACE::MeetingStatus::MEETING_STATUS_IDLE, "IDLE"},
        {ZOOM_SDK_NAMESPACE::MeetingStatus::MEETING_STATUS_CONNECTING, "CONNECTING"},
        {ZOOM_SDK_NAMESPACE::MeetingStatus::MEETING_STATUS_WAITINGFORHOST, "WAITINGFORHOST"},
        {ZOOM_SDK_NAMESPACE::MeetingStatus::MEETING_STATUS_INMEETING, "INMEETING"},
        {ZOOM_SDK_NAMESPACE::MeetingStatus::MEETING_STATUS_DISCONNECTING, "DISCONNECTING"},
        {ZOOM_SDK_NAMESPACE::MeetingStatus::MEETING_STATUS_RECONNECTING, "RECONNECTING"},
        {ZOOM_SDK_NAMESPACE::MeetingStatus::MEETING_STATUS_FAILED, "FAILED"},
        {ZOOM_SDK_NAMESPACE::MeetingStatus::MEETING_STATUS_ENDED, "ENDED"},
        {ZOOM_SDK_NAMESPACE::MeetingStatus::MEETING_STATUS_UNKNOWN, "UNKNOWN"},
        {ZOOM_SDK_NAMESPACE::MeetingStatus::MEETING_STATUS_LOCKED, "LOCKED"},
        {ZOOM_SDK_NAMESPACE::MeetingStatus::MEETING_STATUS_UNLOCKED, "UNLOCKED"},
        {ZOOM_SDK_NAMESPACE::MeetingStatus::MEETING_STATUS_IN_WAITING_ROOM, "IN_WAITING_ROOM"},
        {ZOOM_SDK_NAMESPACE::MeetingStatus::MEETING_STATUS_WEBINAR_PROMOTE, "WEBINAR_PROMOTE"},
        {ZOOM_SDK_NAMESPACE::MeetingStatus::MEETING_STATUS_WEBINAR_DEPROMOTE, "WEBINAR_DEPROMOTE"},
        {ZOOM_SDK_NAMESPACE::MeetingStatus::MEETING_STATUS_JOIN_BREAKOUT_ROOM, "JOIN_BREAKOUT_ROOM"},
        {ZOOM_SDK_NAMESPACE::MeetingStatus::MEETING_STATUS_LEAVE_BREAKOUT_ROOM, "LEAVE_BREAKOUT_ROOM"},
    };

    return ConvertEnumToString(result, names);
}

inline std::string EnumToString(ZOOM_SDK_NAMESPACE::MeetingFailCode result)
{
    static const std::unordered_map<ZOOM_SDK_NAMESPACE::MeetingFailCode, std::string> names = {
        {ZOOM_SDK_NAMESPACE::MeetingFailCode::MEETING_SUCCESS, "MEETING_SUCCESS"},
        {ZOOM_SDK_NAMESPACE::MeetingFailCode::MEETING_FAIL_NETWORK_ERR, "MEETING_FAIL_NETWORK_ERR"},
        {ZOOM_SDK_NAMESPACE::MeetingFailCode::MEETING_FAIL_RECONNECT_ERR, "MEETING_FAIL_RECONNECT_ERR"},
        {ZOOM_SDK_NAMESPACE::MeetingFailCode::MEETING_FAIL_MMR_ERR, "MEETING_FAIL_MMR_ERR"},
        {ZOOM_SDK_NAMESPACE::MeetingFailCode::MEETING_FAIL_PASSWORD_ERR, "MEETING_FAIL_PASSWORD_ERR"},
        {ZOOM_SDK_NAMESPACE::MeetingFailCode::MEETING_FAIL_SESSION_ERR, "MEETING_FAIL_SESSION_ERR"},
        {ZOOM_SDK_NAMESPACE::MeetingFailCode::MEETING_FAIL_MEETING_OVER, "MEETING_FAIL_MEETING_OVER"},
        {ZOOM_SDK_NAMESPACE::MeetingFailCode::MEETING_FAIL_MEETING_NOT_START, "MEETING_FAIL_MEETING_NOT_START"},
        {ZOOM_SDK_NAMESPACE::MeetingFailCode::MEETING_FAIL_MEETING_NOT_EXIST, "MEETING_FAIL_MEETING_NOT_EXIST"},
        {ZOOM_SDK_NAMESPACE::MeetingFailCode::MEETING_FAIL_MEETING_USER_FULL, "MEETING_FAIL_MEETING_USER_FULL"},
        {ZOOM_SDK_NAMESPACE::MeetingFailCode::MEETING_FAIL_CLIENT_INCOMPATIBLE, "MEETING_FAIL_CLIENT_INCOMPATIBLE"},
        {ZOOM_SDK_NAMESPACE::MeetingFailCode::MEETING_FAIL_NO_MMR, "MEETING_FAIL_NO_MMR"},
        {ZOOM_SDK_NAMESPACE::MeetingFailCode::MEETING_FAIL_CONFLOCKED, "MEETING_FAIL_CONFLOCKED"},
        {ZOOM_SDK_NAMESPACE::MeetingFailCode::MEETING_FAIL_MEETING_RESTRICTED, "MEETING_FAIL_MEETING_RESTRICTED"},
        {ZOOM_SDK_NAMESPACE::MeetingFailCode::MEETING_FAIL_MEETING_RESTRICTED_JBH, "MEETING_FAIL_MEETING_RESTRICTED_JBH"},
        {ZOOM_SDK_NAMESPACE::MeetingFailCode::MEETING_FAIL_CANNOT_EMIT_WEBREQUEST, "MEETING_FAIL_CANNOT_EMIT_WEBREQUEST"},
        {ZOOM_SDK_NAMESPACE::MeetingFailCode::MEETING_FAIL_CANNOT_START_TOKENEXPIRE, "MEETING_FAIL_CANNOT_START_TOKENEXPIRE"},
        {ZOOM_SDK_NAMESPACE::MeetingFailCode::SESSION_VIDEO_ERR, "SESSION_VIDEO_ERR"},
        {ZOOM_SDK_NAMESPACE::MeetingFailCode::SESSION_AUDIO_AUTOSTARTERR, "SESSION_AUDIO_AUTOSTARTERR"},
        {ZOOM_SDK_NAMESPACE::MeetingFailCode::MEETING_FAIL_REGISTERWEBINAR_FULL, "MEETING_FAIL_REGISTERWEBINAR_FULL"},
        {ZOOM_SDK_NAMESPACE::MeetingFailCode::MEETING_FAIL_REGISTERWEBINAR_HOSTREGISTER, "MEETING_FAIL_REGISTERWEBINAR_HOSTREGISTER"},
        {ZOOM_SDK_NAMESPACE::MeetingFailCode::MEETING_FAIL_REGISTERWEBINAR_PANELISTREGISTER, "MEETING_FAIL_REGISTERWEBINAR_PANELISTREGISTER"},
        {ZOOM_SDK_NAMESPACE::MeetingFailCode::MEETING_FAIL_REGISTERWEBINAR_DENIED_EMAIL, "MEETING_FAIL_REGISTERWEBINAR_DENIED_EMAIL"},
        {ZOOM_SDK_NAMESPACE::MeetingFailCode::MEETING_FAIL_ENFORCE_LOGIN, "MEETING_FAIL_ENFORCE_LOGIN"},
        {ZOOM_SDK_NAMESPACE::MeetingFailCode::CONF_FAIL_ZC_CERTIFICATE_CHANGED, "CONF_FAIL_ZC_CERTIFICATE_CHANGED"},
        {ZOOM_SDK_NAMESPACE::MeetingFailCode::CONF_FAIL_VANITY_NOT_EXIST, "CONF_FAIL_VANITY_NOT_EXIST"},
        {ZOOM_SDK_NAMESPACE::MeetingFailCode::CONF_FAIL_JOIN_WEBINAR_WITHSAMEEMAIL, "CONF_FAIL_JOIN_WEBINAR_WITHSAMEEMAIL"},
        {ZOOM_SDK_NAMESPACE::MeetingFailCode::CONF_FAIL_DISALLOW_HOST_MEETING, "CONF_FAIL_DISALLOW_HOST_MEETING"},
        {ZOOM_SDK_NAMESPACE::MeetingFailCode::MEETING_FAIL_WRITE_CONFIG_FILE, "MEETING_FAIL_WRITE_CONFIG_FILE"},
        {ZOOM_SDK_NAMESPACE::MeetingFailCode::MEETING_FAIL_FORBID_TO_JOIN_INTERNAL_MEETING, "MEETING_FAIL_FORBID_TO_JOIN_INTERNAL_MEETING"},
        {ZOOM_SDK_NAMESPACE::MeetingFailCode::CONF_FAIL_REMOVED_BY_HOST, "CONF_FAIL_REMOVED_BY_HOST"},
        {ZOOM_SDK_NAMESPACE::MeetingFailCode::MEETING_FAIL_HOST_DISALLOW_OUTSIDE_USER_JOIN, "MEETING_FAIL_HOST_DISALLOW_OUTSIDE_USER_JOIN"},
        {ZOOM_SDK_NAMESPACE::MeetingFailCode::MEETING_FAIL_UNABLE_TO_JOIN_EXTERNAL_MEETING, "MEETING_FAIL_UNABLE_TO_JOIN_EXTERNAL_MEETING"},
        {ZOOM_SDK_NAMESPACE::MeetingFailCode::MEETING_FAIL_BLOCKED_BY_ACCOUNT_ADMIN, "MEETING_FAIL_BLOCKED_BY_ACCOUNT_ADMIN"},
        {ZOOM_SDK_NAMESPACE::MeetingFailCode::MEETING_FAIL_NEED_SIGN_IN_FOR_PRIVATE_MEETING, "MEETING_FAIL_NEED_SIGN_IN_FOR_PRIVATE_MEETING"},
        {ZOOM_SDK_NAMESPACE::MeetingFailCode::MEETING_FAIL_APP_PRIVILEGE_TOKEN_ERROR, "MEETING_FAIL_APP_PRIVILEGE_TOKEN_ERROR"},
        {ZOOM_SDK_NAMESPACE::MeetingFailCode::MEETING_FAIL_JMAK_USER_EMAIL_NOT_MATCH, "MEETING_FAIL_JMAK_USER_EMAIL_NOT_MATCH"},
        {ZOOM_SDK_NAMESPACE::MeetingFailCode::MEETING_FAIL_UNKNOWN, "MEETING_FAIL_UNKNOWN"},
    };

    return ConvertEnumToString(result, names);
}

inline std::string EnumToString(ZOOM_SDK_NAMESPACE::MeetingEndReason result)
{
    static const std::unordered_map<ZOOM_SDK_NAMESPACE::MeetingEndReason, std::string> names = {
        {ZOOM_SDK_NAMESPACE::MeetingEndReason::EndMeetingReason_None, "NONE"},
        {ZOOM_SDK_NAMESPACE::MeetingEndReason::EndMeetingReason_KickByHost, "KICK_BY_HOST"},
        {ZOOM_SDK_NAMESPACE::MeetingEndReason::EndMeetingReason_EndByHost, "END_BY_HOST"},
        {ZOOM_SDK_NAMESPACE::MeetingEndReason::EndMeetingReason_JBHTimeOut, "JBH_TIME_OUT"},
        {ZOOM_SDK_NAMESPACE::MeetingEndReason::EndMeetingReason_NoAttendee, "NO_ATTENDEE"},
        {ZOOM_SDK_NAMESPACE::MeetingEndReason::EndMeetingReason_HostStartAnotherMeeting, "HOST_START_ANOTHER_MEETING"},
        {ZOOM_SDK_NAMESPACE::MeetingEndReason::EndMeetingReason_FreeMeetingTimeOut, "FREE_MEETING_TIME_OUT"},
        {ZOOM_SDK_NAMESPACE::MeetingEndReason::EndMeetingReason_NetworkBroken, "NETWORK_BROKEN"},
    };

    return ConvertEnumToString(result, names);
}

inline std::string EnumToString(ZOOM_SDK_NAMESPACE::StatisticsWarningType result)
{
    static const std::unordered_map<ZOOM_SDK_NAMESPACE::StatisticsWarningType, std::string> names = {
        {ZOOM_SDK_NAMESPACE::StatisticsWarningType::Statistics_Warning_None, "None"},
        {ZOOM_SDK_NAMESPACE::StatisticsWarningType::Statistics_Warning_Network_Quality_Bad, "Network_Quality_Bad"},
        {ZOOM_SDK_NAMESPACE::StatisticsWarningType::Statistics_Warning_Busy_System, "Busy_System"},
    };

    return ConvertEnumToString(result, names);
}

inline std::string EnumToString(ZOOM_SDK_NAMESPACE::MeetingType result)
{
    static const std::unordered_map<ZOOM_SDK_NAMESPACE::MeetingType, std::string> names = {
        {ZOOM_SDK_NAMESPACE::MeetingType::MEETING_TYPE_NONE, "NONE"},
        {ZOOM_SDK_NAMESPACE::MeetingType::MEETING_TYPE_NORMAL, "NORMAL"},
        {ZOOM_SDK_NAMESPACE::MeetingType::MEETING_TYPE_WEBINAR, "WEBINAR"},
        {ZOOM_SDK_NAMESPACE::MeetingType::MEETING_TYPE_BREAKOUTROOM, "BREAKOUT_ROOM"},
    };

    return ConvertEnumToString(result, names);
}