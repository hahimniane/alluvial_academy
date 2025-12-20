#include "zoom_response_builder.h"
#include "helper.h"

ZoomResponseBuilder::ZoomResponseBuilder(const std::string &action)
    : action_(action) {}

ZoomResponseBuilder &ZoomResponseBuilder::Success(bool success)
{
    success_ = success;
    return *this;
}

ZoomResponseBuilder &ZoomResponseBuilder::Message(const std::string &message)
{
    message_ = message;
    return *this;
}

ZoomResponseBuilder &ZoomResponseBuilder::Param(const std::string &key, flutter::EncodableValue value)
{
    params_[flutter::EncodableValue(key)] = value;
    return *this;
}

ZoomResponse ZoomResponseBuilder::Build() const // Ensure this is defined
{
    ZoomResponse response;
    response.platform = platform_;
    response.isSuccess = success_;
    response.action = action_;
    response.message = message_;
    response.params = params_;

    sActionLog(action_, message_);
    return response;
}

flutter::EncodableMap ZoomResponse::ToEncodableMap() const
{
    flutter::EncodableMap map;
    map[flutter::EncodableValue("platform")] = flutter::EncodableValue(platform);
    map[flutter::EncodableValue("isSuccess")] = flutter::EncodableValue(isSuccess);
    map[flutter::EncodableValue("action")] = flutter::EncodableValue(action);
    map[flutter::EncodableValue("message")] = flutter::EncodableValue(message);
    map[flutter::EncodableValue("params")] = flutter::EncodableValue(params);

    return map;
}
