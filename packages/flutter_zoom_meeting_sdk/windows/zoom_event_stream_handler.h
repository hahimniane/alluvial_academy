#pragma once

#include <flutter/event_channel.h>
#include <flutter/standard_method_codec.h>
#include <memory>

class ZoomEventStreamHandler : public flutter::StreamHandler<flutter::EncodableValue>
{
public:
    ZoomEventStreamHandler() {}
    virtual ~ZoomEventStreamHandler() {}

    std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnListenInternal(
        const flutter::EncodableValue *arguments,
        std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> &&events) override
    {
        event_sink_ = std::move(events);
        return nullptr;
    }

    std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnCancelInternal(
        const flutter::EncodableValue *arguments) override
    {
        event_sink_.reset();
        return nullptr;
    }

    void SendEvent(const flutter::EncodableValue &event)
    {
        if (event_sink_)
        {
            event_sink_->Success(event);
        }
    }

private:
    std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;
};