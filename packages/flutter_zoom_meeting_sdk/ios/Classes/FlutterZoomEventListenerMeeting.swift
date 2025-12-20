import MobileRTC

extension FlutterZoomMeetingSdkPlugin: MobileRTCMeetingServiceDelegate {
    public func onMeetingStateChange(
        _ state: MobileRTCMeetingState
    ) {
        self.eventSink?(
            makeEventResponse(
                event: "onMeetingStatusChanged",
                oriEvent: "onMeetingStateChange",
                params: [
                    "statusCode": state.rawValue,
                    "statusLabel": state.name,
                    "errorCode": -99,
                    "errorLabel": "NO_PROVIDED",
                    "endReasonCode": -99,
                    "endReasonLabel": "NO_PROVIDED",
                ]
            )
        )
    }
    
    public func onMeetingError(_ error: MobileRTCMeetError, message: String?) {
        self.eventSink?(
            makeEventResponse(
                event: "onMeetingError",
                oriEvent: "onMeetingError",
                params: [
                    "errorCode": error.rawValue,
                    "errorLabel": error.name,
                    "message": message ?? "",
                ]
            )
        )
    }
    
    public func onMeetingEndedReason(_ reason: MobileRTCMeetingEndReason) {
        self.eventSink?(
            makeEventResponse(
                event: "onMeetingEndedReason",
                oriEvent: "onMeetingEndedReason",
                params: [
                    "endReasonCode": reason.rawValue,
                    "endReasonLabel": reason.name,
                ]
            )
        )
    }
    
    public func onMeetingParameterNotification(_ meetingParam: MobileRTCMeetingParameter?) {
        guard let param = meetingParam else {
            return
        }

        let eventData: [String: Any] = [
            "isAutoRecordingCloud": param.isAutoRecordingCloud,
            "isAutoRecordingLocal": param.isAutoRecordingLocal,
            "isViewOnly": param.isViewOnly,
            "meetingHost": param.meetingHost ?? "",
            "meetingTopic": param.meetingTopic ?? "",
            "meetingNumber": param.meetingNumber,
            "meetingType": param.meetingType.rawValue,
            "meetingTypeLabel": param.meetingType.name,
        ]

        self.eventSink?(
            makeEventResponse(
                event: "onMeetingParameterNotification",
                oriEvent: "onMeetingParameterNotification",
                params: eventData
            )
        )
    }
}
