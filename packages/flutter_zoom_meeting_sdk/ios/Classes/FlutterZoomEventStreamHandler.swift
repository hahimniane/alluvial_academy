import Flutter

class FlutterZoomEventStreamHandler: NSObject, FlutterStreamHandler {
    private let plugin: FlutterZoomMeetingSdkPlugin

    init(plugin: FlutterZoomMeetingSdkPlugin) {
        self.plugin = plugin
        super.init()
    }

    public func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    )
        -> FlutterError?
    {
        plugin.setEventSink(events)
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        plugin.setEventSink(nil)
        return nil
    }
}
