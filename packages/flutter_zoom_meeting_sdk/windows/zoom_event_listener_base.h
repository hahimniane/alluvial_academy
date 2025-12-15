#pragma once

#include <windows.h>
#include <flutter/encodable_value.h>
#include "auth_service_interface.h"
#include "meeting_service_interface.h"

// Forward declaration of the ZoomEventStreamHandler class
class ZoomEventStreamHandler;

class ZoomSDKEventListenerBase
{
public:
    ZoomSDKEventListenerBase();
    virtual ~ZoomSDKEventListenerBase();

    void SetEventHandler(ZoomEventStreamHandler *handler);

protected:
    void SendEvent(const std::string &eventName, const flutter::EncodableMap &params);

    // Pointer to the event handler that will send events to Flutter
    ZoomEventStreamHandler *event_handler_;
};
