import ZoomSDK

extension FlutterZoomMeetingSdkPlugin: ZoomSDKAuthDelegate {
    public func onZoomSDKAuthReturn(_ returnValue: ZoomSDKAuthError) {
        self.eventSink?(
            makeEventResponse(
                event: "onAuthenticationReturn",
                oriEvent: "onZoomSDKAuthReturn",
                params: [
                    "statusCode": returnValue.rawValue,
                    "statusLabel": returnValue.name,
                ]
            )
        )
    }

    public func onZoomAuthIdentityExpired() {
        self.eventSink?(
            makeEventResponse(
                event: "onZoomAuthIdentityExpired",
                oriEvent: "onZoomAuthIdentityExpired",
                params: [:]
            )
        )
    }

    public func onZoomSDKLoginResult(
        _ loginStatus: ZoomSDKLoginStatus,
        failReason: ZoomSDKLoginFailReason
    ) {
        self.eventSink?(
            makeEventResponse(
                event: "onLoginReturnWithReason",
                oriEvent: "onZoomSDKLoginResult",
                params: [
                    "statusCode": loginStatus.rawValue,
                    "statusLabel": loginStatus.name,
                    "failReasonCode": failReason.rawValue,
                    "failReasonLabel": failReason.name,
                ]
            )
        )
    }

    public func onZoomSDKLogout() {
        self.eventSink?(
            makeEventResponse(
                event: "onLogout",
                oriEvent: "onZoomSDKLogout",
                params: [:]
            )
        )
    }

    public func onZoomIdentityExpired() {
        self.eventSink?(
            makeEventResponse(
                event: "onZoomIdentityExpired",
                oriEvent: "onZoomIdentityExpired",
                params: [:]
            )
        )
    }

    public func onNotificationServiceStatus(
        _ status: ZoomSDKNotificationServiceStatus,
        error: ZoomSDKNotificationServiceError
    ) {
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
