#ifndef FLUTTER_PLUGIN_FLUTTER_ZOOM_MEETING_SDK_PLUGIN_H_
#define FLUTTER_PLUGIN_FLUTTER_ZOOM_MEETING_SDK_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>
#include "zoom_sdk.h"
#include "auth_service_interface.h"
#include "meeting_service_interface.h"
#include "zoom_event_stream_handler.h"
#include "zoom_response_builder.h"

namespace flutter_zoom_meeting_sdk
{
    ZoomResponse InitZoom();
    ZoomResponse AuthZoom(const std::wstring token);
    ZoomResponse JoinMeeting(uint64_t meetingNumber, const std::wstring password, const std::wstring displayName, std::optional<std::wstring> webinarToken);
    ZoomResponse UnInitZoom();

    class FlutterZoomMeetingSdkPlugin : public flutter::Plugin
    {
    public:
        static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

        FlutterZoomMeetingSdkPlugin();
        virtual ~FlutterZoomMeetingSdkPlugin();

        // Disallow copy and assign.
        FlutterZoomMeetingSdkPlugin(const FlutterZoomMeetingSdkPlugin &) = delete;
        FlutterZoomMeetingSdkPlugin &operator=(const FlutterZoomMeetingSdkPlugin &) = delete;

        // Called when a method is called on this plugin's channel from Dart.
        void HandleMethodCall(
            const flutter::MethodCall<flutter::EncodableValue> &method_call,
            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

    private:
        // Plugin-scoped members
        std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> method_channel_;
        std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> event_channel_;
        std::unique_ptr<ZoomEventStreamHandler> event_stream_handler_;

        ZOOM_SDK_NAMESPACE::IAuthService *auth_service_ = nullptr;
        ZOOM_SDK_NAMESPACE::IMeetingService *meeting_service_ = nullptr;
    };

} // namespace flutter_zoom_meeting_sdk

#endif // FLUTTER_PLUGIN_FLUTTER_ZOOM_MEETING_SDK_PLUGIN_H_
