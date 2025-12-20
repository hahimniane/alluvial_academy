#pragma once

#include <string>
#include <iostream>

inline const void sLog(const std::string tag, const std::wstring message)
{
    std::wcout << L"FlutterZoomMeetingSDK::" << std::wstring(tag.begin(), tag.end()) << " " << message << std::endl;
}

inline const void sLog(const std::string tag, const std::string message)
{
    std::cout << "FlutterZoomMeetingSDK::" << tag << " " << message << std::endl;
}

inline const void sEventLog(const std::string tag, const std::wstring message)
{
    sLog("Event::" + tag, message);
}

inline const void sEventLog(const std::string tag, const std::string message)
{
    sLog("Event::" + tag, message);
}

inline const void sActionLog(const std::string tag, const std::wstring message)
{
    sLog("Action::" + tag, message);
}

inline const void sActionLog(const std::string tag, const std::string message)
{
    sLog("Action::" + tag, message);
}

inline std::string WStringToString(const std::wstring &wstr)
{
    // Calculate the required size of the buffer
    size_t len;
    wcstombs_s(&len, nullptr, 0, wstr.c_str(), 0); // Get the length of the required buffer

    // Allocate the buffer with the required size
    char *buffer = new char[len];

    // Perform the conversion with wcstombs_s
    wcstombs_s(&len, buffer, len, wstr.c_str(), len);

    // Create the std::string from the char buffer
    std::string str(buffer);

    // Clean up the buffer
    delete[] buffer;

    return str;
}

inline std::wstring StringToWString(const std::string &str)
{
    std::wstring wstr;
    size_t size;
    wstr.resize(str.length());
    mbstowcs_s(&size, &wstr[0], wstr.size() + 1, str.c_str(), str.size());
    return wstr;
}