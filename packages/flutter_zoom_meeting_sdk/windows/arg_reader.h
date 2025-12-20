#pragma once

#include <flutter/method_call.h>
#include <flutter/standard_method_codec.h>
#include <optional>
#include <string>
#include <stdint.h>
#include "helper.h"

// Helper function to convert string to UINT64
inline uint64_t StringToUINT64(const std::string &str)
{
    try
    {
        return std::stoull(str);
    }
    catch (...)
    {
        return 0;
    }
}

// Helper function to convert wstring to UINT64
inline uint64_t WStringToUINT64(const std::wstring &wstr)
{
    try
    {
        return std::stoull(wstr);
    }
    catch (...)
    {
        return 0;
    }
}

class ArgReader
{
public:
    explicit ArgReader(const flutter::MethodCall<flutter::EncodableValue> &call)
        : args_(std::get_if<flutter::EncodableMap>(call.arguments())) {}

    std::optional<std::string> GetString(const std::string &key) const
    {
        return Get<std::string>(key);
    }

    std::optional<int64_t> GetInt(const std::string &key) const
    {
        return Get<int64_t>(key);
    }

    std::optional<bool> GetBool(const std::string &key) const
    {
        return Get<bool>(key);
    }

    // Helper method to get a wide string representation directly
    std::optional<std::wstring> GetWString(const std::string &key) const
    {
        auto str = GetString(key);
        if (str.has_value())
        {
            // return std::wstring(str.value().begin(), str.value().end());
            return StringToWString(str.value());
        }
        return std::nullopt;
    }

    // Get a UINT64 from a string parameter
    std::optional<uint64_t> GetUINT64(const std::string &key) const
    {
        auto str = GetString(key);
        if (str.has_value())
        {
            return StringToUINT64(str.value());
        }

        // Try as integer if string didn't work
        auto intVal = GetInt(key);
        if (intVal.has_value())
        {
            return static_cast<uint64_t>(intVal.value());
        }

        return std::nullopt;
    }

private:
    const flutter::EncodableMap *args_;

    template <typename T>
    std::optional<T> Get(const std::string &key) const
    {
        if (!args_)
            return std::nullopt;
        auto it = args_->find(flutter::EncodableValue(key));
        if (it != args_->end())
        {
            if (auto val = std::get_if<T>(&(it->second)))
            {
                return *val;
            }
        }
        return std::nullopt;
    }
};
