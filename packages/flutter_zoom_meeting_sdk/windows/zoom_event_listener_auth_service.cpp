#include "zoom_event_listener_auth_service.h"
#include <iostream>
#include "zoom_event_stream_handler.h"
#include "helper_enum.h"
#include "helper.h"

// Constructor: Calls the base class constructor
ZoomSDKEventListenerAuthService::ZoomSDKEventListenerAuthService()
    : ZoomSDKEventListenerBase() // Call the base class constructor
{
}

// Destructor: Calls the base class destructor
ZoomSDKEventListenerAuthService::~ZoomSDKEventListenerAuthService() {}

void ZoomSDKEventListenerAuthService::onAuthenticationReturn(ZOOM_SDK_NAMESPACE::AuthResult ret)
{
    const std::string tag = "onAuthenticationReturn";
    sEventLog(tag, L"Authentication result: " + std::to_wstring(ret));

    if (ret == ZOOM_SDK_NAMESPACE::AuthResult::AUTHRET_SUCCESS)
    {
        sEventLog(tag, L"Authentication successful");
    }
    else
    {
        sEventLog(tag, L"Authentication failed");
    }

    flutter::EncodableMap params;

    params[flutter::EncodableValue("statusCode")] = flutter::EncodableValue(static_cast<int>(ret));
    params[flutter::EncodableValue("statusLabel")] = flutter::EncodableValue(EnumToString(ret));

    SendEvent(tag, params);
}

void ZoomSDKEventListenerAuthService::onLoginReturnWithReason(ZOOM_SDK_NAMESPACE::LOGINSTATUS ret,
                                                              ZOOM_SDK_NAMESPACE::IAccountInfo *pAccountInfo,
                                                              ZOOM_SDK_NAMESPACE::LoginFailReason reason)
{
    const std::string tag = "onLoginReturnWithReason";
    sEventLog(tag, L"Login status: " + std::to_wstring(ret));
    sEventLog(tag, L"Login Fail Reason: " + std::to_wstring(reason));

    flutter::EncodableMap params;
    params[flutter::EncodableValue("statusCode")] = flutter::EncodableValue(static_cast<int>(ret));
    params[flutter::EncodableValue("statusLabel")] = flutter::EncodableValue(EnumToString(ret));
    params[flutter::EncodableValue("failReasonCode")] = flutter::EncodableValue(static_cast<int>(reason));
    params[flutter::EncodableValue("failReasonLabel")] = flutter::EncodableValue(EnumToString(reason));

    flutter::EncodableMap accountInfo;

    if (pAccountInfo)
    {
        const ZOOMSDK::LoginType loginType = pAccountInfo->GetLoginType();
        std::wstring displayName = pAccountInfo->GetDisplayName();

        accountInfo[flutter::EncodableValue("loginType")] = flutter::EncodableValue(static_cast<int>(loginType));
        accountInfo[flutter::EncodableValue("loginTypeName")] = flutter::EncodableValue(EnumToString(loginType));
        accountInfo[flutter::EncodableValue("displayName")] = flutter::EncodableValue(WStringToString(displayName));
    }

    params[flutter::EncodableValue("accountInfo")] = flutter::EncodableValue(accountInfo);

    SendEvent(tag, params);
}

void ZoomSDKEventListenerAuthService::onLogout()
{
    const std::string tag = "onLogout";
    sEventLog(tag, L"");

    flutter::EncodableMap params;
    SendEvent(tag, params);
}

void ZoomSDKEventListenerAuthService::onZoomIdentityExpired()
{
    const std::string tag = "onZoomIdentityExpired";
    sEventLog(tag, L"");

    flutter::EncodableMap params;
    SendEvent(tag, params);
}

void ZoomSDKEventListenerAuthService::onZoomAuthIdentityExpired()
{
    const std::string tag = "onZoomAuthIdentityExpired";
    sEventLog(tag, L"");

    flutter::EncodableMap params;
    SendEvent(tag, params);
}

#if defined(WIN32)
void ZoomSDKEventListenerAuthService::onNotificationServiceStatus(ZOOM_SDK_NAMESPACE::SDKNotificationServiceStatus status,
                                                                  ZOOM_SDK_NAMESPACE::SDKNotificationServiceError error)
{
    const std::string tag = "onNotificationServiceStatus";
    sEventLog(tag, L"Status: " + std::to_wstring(status));
    sEventLog(tag, L"Error: " + std::to_wstring(error));

    flutter::EncodableMap params;
    params[flutter::EncodableValue("statusCode")] = flutter::EncodableValue(static_cast<int>(status));
    params[flutter::EncodableValue("statusLabel")] = flutter::EncodableValue(EnumToString(status));
    params[flutter::EncodableValue("errorCode")] = flutter::EncodableValue(static_cast<int>(error));
    params[flutter::EncodableValue("errorLabel")] = flutter::EncodableValue(EnumToString(error));

    SendEvent(tag, params);
}
#endif
