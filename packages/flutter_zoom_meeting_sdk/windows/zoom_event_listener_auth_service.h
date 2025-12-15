#pragma once

#include <windows.h>
#include <flutter/encodable_value.h>
#include "auth_service_interface.h"
#include "meeting_service_interface.h"
#include "zoom_event_listener_base.h" // Include the base class header

class ZoomSDKEventListenerAuthService : public ZoomSDKEventListenerBase, public ZOOM_SDK_NAMESPACE::IAuthServiceEvent
{
public:
    ZoomSDKEventListenerAuthService();
    virtual ~ZoomSDKEventListenerAuthService();

    // Override the callback methods from IAuthServiceEvent interface
    void onAuthenticationReturn(ZOOM_SDK_NAMESPACE::AuthResult ret) override;
    void onLoginReturnWithReason(ZOOM_SDK_NAMESPACE::LOGINSTATUS ret, ZOOM_SDK_NAMESPACE::IAccountInfo *pAccountInfo, ZOOM_SDK_NAMESPACE::LoginFailReason reason) override;
    void onLogout() override;
    void onZoomIdentityExpired() override;
    void onZoomAuthIdentityExpired() override;

#if defined(WIN32)
    void onNotificationServiceStatus(ZOOM_SDK_NAMESPACE::SDKNotificationServiceStatus status, ZOOM_SDK_NAMESPACE::SDKNotificationServiceError error) override;
#endif
};
