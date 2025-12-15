struct StandardZoomResponse {
    let isSuccess: Bool
    let message: String
    let action: String
    let params: [String: Any]

    func toDictionary() -> [String: Any] {
        return [
            "platform": "ios",
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
        return [
            "platform": "ios",
            "event": event,
            "oriEvent": oriEvent,
            "params": params,
        ]
    }
}
