#pragma once
#include "zoom_event_listener_base.h"
#include "zoom_event_stream_handler.h"
#include "helper.h"

ZoomSDKEventListenerBase::ZoomSDKEventListenerBase() : event_handler_(nullptr) {}
ZoomSDKEventListenerBase::~ZoomSDKEventListenerBase() {}

void ZoomSDKEventListenerBase::SetEventHandler(ZoomEventStreamHandler *handler)
{
    event_handler_ = handler;
}

void ZoomSDKEventListenerBase::SendEvent(const std::string &eventName, const flutter::EncodableMap &params)
{
    const std::string tag = "SendEventToFlutter";

    if (!event_handler_)
    {
        sEventLog(tag, "=== ERROR: Event handler is NULL, cannot send: " + eventName + " event ===");
        return;
    }

    sEventLog(tag, "=== Sending event: " + eventName + " ===");

    flutter::EncodableMap eventMap;
    eventMap[flutter::EncodableValue("platform")] = flutter::EncodableValue("windows");
    eventMap[flutter::EncodableValue("event")] = flutter::EncodableValue(eventName);
    eventMap[flutter::EncodableValue("oriEvent")] = flutter::EncodableValue(eventName);
    eventMap[flutter::EncodableValue("params")] = flutter::EncodableValue(params);

    event_handler_->SendEvent(flutter::EncodableValue(eventMap));
}