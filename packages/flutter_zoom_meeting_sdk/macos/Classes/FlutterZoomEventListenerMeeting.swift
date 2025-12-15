import ZoomSDK
// onMeetingParameterNotification
extension FlutterZoomMeetingSdkPlugin: ZoomSDKMeetingServiceDelegate {
    public func onMeetingStatusChange(
        _ state: ZoomSDKMeetingStatus,
        meetingError error: ZoomSDKMeetingError,
        end reason: EndMeetingReason
    ) {
        self.eventSink?(
            makeEventResponse(
                event: "onMeetingStatusChanged",
                oriEvent: "onMeetingStatusChange",
                params: [
                    "statusCode": state.rawValue,
                    "statusLabel": state.name,
                    "errorCode": error.rawValue,
                    "errorLabel": error.name,
                    "endReasonCode": reason.rawValue,
                    "endReasonLabel": reason.name,
                ]
            )
        )
    }
    
    public func onMeetingParameterNotification(_ meetingParam: ZoomSDKMeetingParameter?) {
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
            "meetingTypeLabel": param.meetingType.name
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
