#pragma once

#include <flutter/encodable_value.h>
#include <string>
#include <map>
#include "zoom_response.h"

class ZoomResponseBuilder
{
public:
    explicit ZoomResponseBuilder(const std::string &action);

    ZoomResponseBuilder &Success(bool success);
    ZoomResponseBuilder &Message(const std::string &message);
    ZoomResponseBuilder &Param(const std::string &key, flutter::EncodableValue value);
    ZoomResponse Build() const;

private:
    std::string platform_ = "windows";
    std::string action_;
    bool success_ = false;
    std::string message_;
    flutter::EncodableMap params_;
};
