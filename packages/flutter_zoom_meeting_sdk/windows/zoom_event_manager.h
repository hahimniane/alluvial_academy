#pragma once

#include "zoom_event_stream_handler.h"

class ZoomEventManager
{
public:
    // Get the singleton instance
    static ZoomEventManager &GetInstance();

    // Set the event handler from Flutter
    void SetEventHandler(ZoomEventStreamHandler *handler);

    // Get the current event handler
    ZoomEventStreamHandler *GetEventHandler() const;

private:
    ZoomEventManager() = default;
    ~ZoomEventManager() = default;
    ZoomEventManager(const ZoomEventManager &) = delete;
    ZoomEventManager &operator=(const ZoomEventManager &) = delete;

    ZoomEventStreamHandler *event_handler_ = nullptr;
};
