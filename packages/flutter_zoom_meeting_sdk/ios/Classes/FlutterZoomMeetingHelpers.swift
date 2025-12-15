func makeActionResponse(
    action: String,
    isSuccess: Bool,
    message: String,
    params: [String: Any] = [:]
) -> [String: Any] {
    return StandardZoomResponse(
        isSuccess: isSuccess,
        message: message,
        action: action,
        params: params
    ).toDictionary()
}

func makeEventResponse(
    event: String,
    oriEvent: String,
    params: [String: Any] = [:]
) -> [String: Any] {
    return StandardZoomEventResponse(
        event: event,
        oriEvent: oriEvent,
        params: params
    ).toDictionary()
}
