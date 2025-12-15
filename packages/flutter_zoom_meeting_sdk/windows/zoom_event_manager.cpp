#include "zoom_event_manager.h"

ZoomEventManager &ZoomEventManager::GetInstance()
{
    static ZoomEventManager instance;
    return instance;
}

void ZoomEventManager::SetEventHandler(ZoomEventStreamHandler *handler)
{
    event_handler_ = handler;
}

ZoomEventStreamHandler *ZoomEventManager::GetEventHandler() const
{
    return event_handler_;
}
