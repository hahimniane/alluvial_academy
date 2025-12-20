#pragma once

#include <flutter/encodable_value.h>
#include <string>
#include <map>

class ZoomResponse
{
public:
    std::string platform;
    bool isSuccess;
    std::string action;
    std::string message;
    flutter::EncodableMap params;

    flutter::EncodableMap ToEncodableMap() const;
};