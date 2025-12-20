#include "flutter_zoom_meeting_sdk_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <flutter/event_channel.h>

#include <memory>
#include <sstream>
#include <zoom_sdk.h>
#include "auth_service_interface.h"
#include "meeting_service_interface.h"
#include "arg_reader.h"
#include "zoom_event_listener_auth_service.h"
#include "zoom_event_stream_handler.h"
#include "zoom_event_listener_meeting_service.h"
#include "zoom_event_manager.h"
#include "helper.h"
#include "helper_enum.h"
#include "zoom_response_builder.h"

namespace flutter_zoom_meeting_sdk
{
  namespace
  {
    bool sdkInitialized = false;

    std::unique_ptr<ZoomSDKEventListenerAuthService> authListener;
    std::unique_ptr<ZoomSDKEventListenerMeetingService> meetingListener;

    std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> CreateMethodChannel(
        flutter::PluginRegistrarWindows *registrar)
    {
      return std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(),
          "flutter_zoom_meeting_sdk",
          &flutter::StandardMethodCodec::GetInstance());
    }

    std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> CreateEventChannel(
        flutter::PluginRegistrarWindows *registrar)
    {
      return std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          registrar->messenger(),
          "flutter_zoom_meeting_sdk/events",
          &flutter::StandardMethodCodec::GetInstance());
    }
  }

  // static
  void FlutterZoomMeetingSdkPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarWindows *registrar)
  {
    auto method_channel = CreateMethodChannel(registrar);
    auto event_channel = CreateEventChannel(registrar);

    auto plugin = std::make_unique<FlutterZoomMeetingSdkPlugin>();

    // Set up method call handling
    method_channel->SetMethodCallHandler(
        [plugin_ptr = plugin.get()](const auto &call, auto result)
        {
          plugin_ptr->HandleMethodCall(call, std::move(result));
        });

    // Create and assign event stream handler
    auto handler = std::make_unique<ZoomEventStreamHandler>();
    ZoomEventManager::GetInstance().SetEventHandler(handler.get());
    event_channel->SetStreamHandler(std::move(handler));

    // Add plugin to registrar
    registrar->AddPlugin(std::move(plugin));
  }

  FlutterZoomMeetingSdkPlugin::FlutterZoomMeetingSdkPlugin() {}

  FlutterZoomMeetingSdkPlugin::~FlutterZoomMeetingSdkPlugin()
  {
    ZoomEventManager::GetInstance().SetEventHandler(nullptr);
    authListener.reset();
    meetingListener.reset();
  }

  void FlutterZoomMeetingSdkPlugin::HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
  {
    auto methodName = method_call.method_name();

    if (methodName.compare("initZoom") == 0)
    {
      ZoomResponse response = InitZoom();
      result->Success(flutter::EncodableValue(response.ToEncodableMap()));
    }
    else if (methodName.compare("authZoom") == 0)
    {
      ArgReader reader(method_call);
      auto token = reader.GetWString("jwtToken").value_or(L"");

      ZoomResponse response = AuthZoom(token);
      result->Success(flutter::EncodableValue(response.ToEncodableMap()));
    }
    else if (methodName.compare("joinMeeting") == 0)
    {
      ArgReader reader(method_call);

      auto meetingNumber = reader.GetUINT64("meetingNumber").value_or(0);
      auto password = reader.GetWString("password").value_or(L"");
      auto displayName = reader.GetWString("displayName").value_or(L"Zoom User");
      auto webinarToken = reader.GetWString("webinarToken");

      ZoomResponse response = JoinMeeting(meetingNumber, password, displayName, webinarToken);
      result->Success(flutter::EncodableValue(response.ToEncodableMap()));
    }
    else if (methodName.compare("unInitZoom") == 0)
    {
      ZoomResponse response = UnInitZoom();
      result->Success(flutter::EncodableValue(response.ToEncodableMap()));
    }
    else
    {
      result->NotImplemented();
    }
  }

  ZoomResponse InitZoom()
  {
    std::string tag = "initZoom";

    if (sdkInitialized)
    {
      return ZoomResponseBuilder(tag)
          .Success(true)
          .Message("MSG_INITIALIZED")
          .Build();
    }

    ZOOM_SDK_NAMESPACE::InitParam initParam;
    initParam.strWebDomain = L"https://zoom.us";

    auto initResult = ZOOM_SDK_NAMESPACE::InitSDK(initParam);
    if (initResult == ZOOM_SDK_NAMESPACE::SDKError::SDKERR_SUCCESS)
    {
      sdkInitialized = true;

      return ZoomResponseBuilder(tag)
          .Success(true)
          .Message("MSG_INIT_SUCCESS")
          .Param("statusCode", static_cast<int>(initResult))
          .Param("statusLabel", EnumToString(initResult))
          .Build();
    }

    return ZoomResponseBuilder(tag)
        .Success(false)
        .Message("MSG_INIT_FAILED")
        .Param("statusCode", static_cast<int>(initResult))
        .Param("statusLabel", EnumToString(initResult))
        .Build();
  }

  ZoomResponse AuthZoom(std::wstring token)
  {
    std::string tag = "authZoom";

    if (!sdkInitialized)
    {
      return ZoomResponseBuilder(tag)
          .Success(false)
          .Message("MSG_NO_YET_INITIALIZED")
          .Build();
    }

    ZOOM_SDK_NAMESPACE::IAuthService *authService;
    ZOOM_SDK_NAMESPACE::SDKError authServiceInitReturnVal = ZOOM_SDK_NAMESPACE::CreateAuthService(&authService);
    if (authServiceInitReturnVal != ZOOM_SDK_NAMESPACE::SDKError::SDKERR_SUCCESS)
    {
      return ZoomResponseBuilder(tag)
          .Success(false)
          .Message("MSG_AUTH_SERVICE_NOT_AVAILABLE")
          .Param("statusCode", static_cast<int>(authServiceInitReturnVal))
          .Param("statusLabel", EnumToString(authServiceInitReturnVal))
          .Build();
    }

    auto handler = ZoomEventManager::GetInstance().GetEventHandler();
    if (!handler)
    {
      return ZoomResponseBuilder(tag)
          .Success(false)
          .Message("MSG_ZOOM_EVENT_MANAGER_HANDLER_NOT_AVAILABLE")
          .Build();
    }

    authListener = std::make_unique<ZoomSDKEventListenerAuthService>();
    authListener->SetEventHandler(handler);
    authService->SetEvent(authListener.get());

    ZOOM_SDK_NAMESPACE::SDKError authCallReturnValue(ZOOM_SDK_NAMESPACE::SDKERR_UNAUTHENTICATION);
    ZOOM_SDK_NAMESPACE::AuthContext authContext;
    authContext.jwt_token = token.c_str();

    authCallReturnValue = authService->SDKAuth(authContext);

    if (authCallReturnValue == ZOOM_SDK_NAMESPACE::SDKError::SDKERR_SUCCESS)
    {
      return ZoomResponseBuilder(tag)
          .Success(true)
          .Message("MSG_AUTH_SENT_SUCCESS")
          .Param("statusCode", static_cast<int>(authCallReturnValue))
          .Param("statusLabel", EnumToString(authCallReturnValue))
          .Build();
    }

    return ZoomResponseBuilder(tag)
        .Success(false)
        .Message("MSG_AUTH_SENT_FAILED")
        .Param("statusCode", static_cast<int>(authCallReturnValue))
        .Param("statusLabel", EnumToString(authCallReturnValue))
        .Build();
  }

  ZoomResponse JoinMeeting(uint64_t meetingNumber, std::wstring password, std::wstring displayName, std::optional<std::wstring> webinarToken)
  {
    std::string tag = "joinMeeting";

    if (!sdkInitialized)
    {
      return ZoomResponseBuilder(tag)
          .Success(false)
          .Message("MSG_NO_YET_INITIALIZED")
          .Build();
    }

    ZOOM_SDK_NAMESPACE::IMeetingService *meetingService;
    ZOOM_SDK_NAMESPACE::SDKError meetingServiceInitReturnVal = ZOOM_SDK_NAMESPACE::CreateMeetingService(&meetingService);

    if (meetingServiceInitReturnVal != ZOOM_SDK_NAMESPACE::SDKError::SDKERR_SUCCESS)
    {
      return ZoomResponseBuilder(tag)
          .Success(false)
          .Message("MSG_MEETING_SERVICE_NOT_AVAILABLE")
          .Param("statusCode", static_cast<int>(meetingServiceInitReturnVal))
          .Param("statusLabel", EnumToString(meetingServiceInitReturnVal))
          .Build();
    }

    ZOOM_SDK_NAMESPACE::JoinParam joinParam;
    joinParam.userType = ZOOM_SDK_NAMESPACE::SDK_UT_NORMALUSER;
    auto &normalParam = joinParam.param.normaluserJoin;
    normalParam.meetingNumber = meetingNumber;
    normalParam.userName = displayName.c_str();
    normalParam.psw = password.c_str();
    normalParam.isVideoOff = false;
    normalParam.isAudioOff = false;

    std::wstring tokenStr; // Holds the webinar token to keep its memory alive
    normalParam.webinarToken = webinarToken.has_value()
                                   ? (tokenStr = webinarToken.value(), tokenStr.c_str()) // Assign the value, then return a safe pointer
                                   : nullptr;                                            // No token provided, so pass nullptr

    auto handler = ZoomEventManager::GetInstance().GetEventHandler();
    if (!handler)
    {
      return ZoomResponseBuilder(tag)
          .Success(false)
          .Message("MSG_ZOOM_EVENT_MANAGER_HANDLER_NOT_AVAILABLE")
          .Build();
    }

    meetingListener = std::make_unique<ZoomSDKEventListenerMeetingService>();
    meetingListener->SetEventHandler(handler);
    meetingService->SetEvent(meetingListener.get());

    auto joinResult = meetingService->Join(joinParam);
    if (joinResult == ZOOM_SDK_NAMESPACE::SDKError::SDKERR_SUCCESS)
    {
      return ZoomResponseBuilder(tag)
          .Success(true)
          .Message("MSG_JOIN_SENT_SUCCESS")
          .Param("statusCode", static_cast<int>(joinResult))
          .Param("statusLabel", EnumToString(joinResult))
          .Build();
    }

    return ZoomResponseBuilder(tag)
        .Success(false)
        .Message("MSG_JOIN_SENT_FAILED")
        .Param("statusCode", static_cast<int>(joinResult))
        .Param("statusLabel", EnumToString(joinResult))
        .Build();
  }

  ZoomResponse UnInitZoom()
  {
    std::string tag = "unInitZoom";

    if (!sdkInitialized)
    {
      return ZoomResponseBuilder(tag)
          .Success(false)
          .Message("MSG_NO_YET_INITIALIZED")
          .Build();
    }

    ZOOM_SDK_NAMESPACE::SDKError cleanUpReturnVal = ZOOM_SDK_NAMESPACE::CleanUPSDK();
    sdkInitialized = false;
    return ZoomResponseBuilder(tag)
        .Success(cleanUpReturnVal == ZOOM_SDK_NAMESPACE::SDKError::SDKERR_SUCCESS)
        .Message(cleanUpReturnVal == ZOOM_SDK_NAMESPACE::SDKError::SDKERR_SUCCESS ? "MSG_UNINIT_SUCCESS" : "MSG_UNINIT_SUCCESS")
        .Param("statusCode", static_cast<int>(cleanUpReturnVal))
        .Param("statusLabel", EnumToString(cleanUpReturnVal))
        .Build();
  }
} // namespace flutter_zoom_meeting_sdk
