struct StandardZoomResponse {
    let isSuccess: Bool
    let message: String
    let action: String
    let params: [String: Any]

    func toDictionary() -> [String: Any] {
        print("FlutterZoomMeetingSDK::Action::\(action) - \(isSuccess) - \(message) - params: \(params)")
        return [
            "platform": "macos",
            "isSuccess": isSuccess,
            "message": message,
            "action": action,
            "params": params,
        ]
    }
}

struct StandardZoomEventResponse {
    let event: String
    let oriEvent: String
    let params: [String: Any]

    func toDictionary() -> [String: Any] {
        print("FlutterZoomMeetingSDK::Event::\(event) - params: \(params)")
        return [
            "platform": "macos",
            "event": event,
            "oriEvent": oriEvent,
            "params": params,
        ]
    }
}
