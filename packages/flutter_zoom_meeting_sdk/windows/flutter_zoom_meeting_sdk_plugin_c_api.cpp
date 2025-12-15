#include "include/flutter_zoom_meeting_sdk/flutter_zoom_meeting_sdk_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "flutter_zoom_meeting_sdk_plugin.h"

void FlutterZoomMeetingSdkPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  flutter_zoom_meeting_sdk::FlutterZoomMeetingSdkPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
