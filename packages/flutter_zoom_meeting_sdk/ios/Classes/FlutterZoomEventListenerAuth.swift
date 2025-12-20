import MobileRTC

extension FlutterZoomMeetingSdkPlugin: MobileRTCAuthDelegate {
    /*!
     @brief Specify to get the response of MobileRTC authorization.
     */
    public func onMobileRTCAuthReturn(_ returnValue: MobileRTCAuthError) {
        self.eventSink?(
            makeEventResponse(
                event: "onAuthenticationReturn",
                oriEvent: "onMobileRTCAuthReturn",
                params: [
                    "statusCode": returnValue.rawValue,
                    "statusLabel": returnValue.name,
                ]
            )
        )
    }
    
    /*!
     @brief Specify the token expired.
     */
    public func onMobileRTCAuthExpired() {
        self.eventSink?(
            makeEventResponse(
                event: "onZoomAuthIdentityExpired",
                oriEvent: "onMobileRTCAuthExpired",
                params: [:]
            )
        )
    }
    
    /*!
     @brief Specify to get the response of MobileRTC logs in.
     @warning If the callback is implemented, the Zoom UI alert tips are no longer displayed.
     */
    public func onMobileRTCLoginResult(_ resultValue: MobileRTCLoginFailReason) {
        self.eventSink?(
            makeEventResponse(
                event: "onLoginReturnWithReason",
                oriEvent: "onMobileRTCLoginResult",
                params: [
                    "statusCode": resultValue.rawValue,
                    "statusLabel": resultValue.name,
                ]
            )
        )
    }
    
    /*!
     @brief Specify to get the response of MobileRTC logs out.
     */
    public func onMobileRTCLogoutReturn(returnValue: NSInteger) {
        self.eventSink?(
            makeEventResponse(
                event: "onLogout",
                oriEvent: "onMobileRTCLogoutReturn",
                params: [
                    "statusCode": returnValue,
                ]
            )
        )
    }
    
    /*!
     @brief Notification service status changed callback.
     */
    public func onNotificationServiceStatus(status: MobileRTCNotificationServiceStatus, error : MobileRTCNotificationServiceError){
        self.eventSink?(
            makeEventResponse(
                event: "onNotificationServiceStatus",
                oriEvent: "onNotificationServiceStatus",
                params: [
                    "statusCode": status.rawValue,
                    "statusLabel": status.name,
                    "errorCode": error.rawValue,
                    "errorLabel": error.name,
                ]
            )
        )
    }
}
