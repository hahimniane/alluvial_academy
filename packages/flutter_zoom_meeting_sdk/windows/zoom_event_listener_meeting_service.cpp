#include "zoom_event_listener_meeting_service.h"
#include <iostream>
#include "helper_enum.h"
#include "helper.h"

// Constructor: Calls the base class constructor
ZoomSDKEventListenerMeetingService::ZoomSDKEventListenerMeetingService()
    : ZoomSDKEventListenerBase() // Call the base class constructor
{
}

// Destructor: Calls the base class destructor
ZoomSDKEventListenerMeetingService::~ZoomSDKEventListenerMeetingService() {}

/// \param iResult Detailed reasons for special meeting status.
/// If the status is MEETING_STATUS_FAILED, the value of iResult is one of those listed in MeetingFailCode enum.
/// If the status is MEETING_STATUS_ENDED, the value of iResult is one of those listed in MeetingEndReason.
void ZoomSDKEventListenerMeetingService::onMeetingStatusChanged(ZOOM_SDK_NAMESPACE::MeetingStatus status, int iResult)
{
    const std::string tag = "onMeetingStatusChanged";
    sEventLog(tag, L"Status: " + std::to_wstring(status) + L", iResult: " + std::to_wstring(iResult));

    flutter::EncodableMap params;

    int failReason = -99;
    std::string failReasonName = "NO_PROVIDED";
    int endReason = -99;
    std::string endReasonName = "NO_PROVIDED";
    if (status == ZOOM_SDK_NAMESPACE::MeetingStatus::MEETING_STATUS_FAILED)
    {
        failReason = iResult;
        failReasonName = EnumToString(static_cast<ZOOM_SDK_NAMESPACE::MeetingFailCode>(iResult));
    }
    else if (status == ZOOM_SDK_NAMESPACE::MeetingStatus::MEETING_STATUS_ENDED)
    {
        endReason = iResult;
        endReasonName = EnumToString(static_cast<ZOOM_SDK_NAMESPACE::MeetingEndReason>(iResult));
    }

    params[flutter::EncodableValue("statusCode")] = flutter::EncodableValue(static_cast<int>(status));
    params[flutter::EncodableValue("statusLabel")] = flutter::EncodableValue(EnumToString(status));

    params[flutter::EncodableValue("errorCode")] = flutter::EncodableValue(failReason);
    params[flutter::EncodableValue("errorLabel")] = flutter::EncodableValue(failReasonName);

    params[flutter::EncodableValue("endReasonCode")] = flutter::EncodableValue(endReason);
    params[flutter::EncodableValue("endReasonLabel")] = flutter::EncodableValue(endReasonName);

    SendEvent(tag, params);
}

void ZoomSDKEventListenerMeetingService::onMeetingStatisticsWarningNotification(ZOOM_SDK_NAMESPACE::StatisticsWarningType type)
{
    const std::string tag = "onMeetingStatisticsWarningNotification";
    sEventLog(tag, L"StatisticsWarningType: " + std::to_wstring(type));

    flutter::EncodableMap params;

    params[flutter::EncodableValue("type")] = flutter::EncodableValue(static_cast<int>(type));
    params[flutter::EncodableValue("typeName")] = flutter::EncodableValue(EnumToString(type));

    SendEvent(tag, params);
}

void ZoomSDKEventListenerMeetingService::onMeetingParameterNotification(const ZOOM_SDK_NAMESPACE::MeetingParameter *meeting_param)
{
    const std::string tag = "onMeetingParameterNotification";
    sEventLog(tag, L"");

    if (meeting_param == nullptr)
    {
        return;
    }

    flutter::EncodableMap params;

    params[flutter::EncodableValue("isAutoRecordingCloud")] = flutter::EncodableValue(meeting_param->is_auto_recording_cloud);
    params[flutter::EncodableValue("isAutoRecordingLocal")] = flutter::EncodableValue(meeting_param->is_auto_recording_local);
    params[flutter::EncodableValue("isViewOnly")] = flutter::EncodableValue(meeting_param->is_view_only);
    params[flutter::EncodableValue("meetingHost")] = flutter::EncodableValue(WStringToString(meeting_param->meeting_host ? meeting_param->meeting_host : L""));
    params[flutter::EncodableValue("meetingNumber")] = flutter::EncodableValue(static_cast<int64_t>(meeting_param->meeting_number));
    params[flutter::EncodableValue("meetingTopic")] = flutter::EncodableValue(WStringToString(meeting_param->meeting_topic ? meeting_param->meeting_topic : L""));
    params[flutter::EncodableValue("meetingType")] = flutter::EncodableValue(meeting_param->meeting_type);
    params[flutter::EncodableValue("meetingTypeLabel")] = flutter::EncodableValue(EnumToString(meeting_param->meeting_type));

    SendEvent(tag, params);
}

void ZoomSDKEventListenerMeetingService::onSuspendParticipantsActivities()
{
    const std::string tag = "onSuspendParticipantsActivities";
    sEventLog(tag, L"");

    flutter::EncodableMap params;

    SendEvent(tag, params);
}

void ZoomSDKEventListenerMeetingService::onAICompanionActiveChangeNotice(bool bActive)
{
    const std::string tag = "onAICompanionActiveChangeNotice";
    sEventLog(tag, L"");

    flutter::EncodableMap params;

    SendEvent(tag, params);
}

void ZoomSDKEventListenerMeetingService::onMeetingTopicChanged(const zchar_t *sTopic)
{
    const std::string tag = "onMeetingTopicChanged";
    sEventLog(tag, L"");

    flutter::EncodableMap params;

    SendEvent(tag, params);
}

void ZoomSDKEventListenerMeetingService::onMeetingFullToWatchLiveStream(const zchar_t *sLiveStreamUrl)
{
    const std::string tag = "onMeetingFullToWatchLiveStream";
    sEventLog(tag, L"");

    flutter::EncodableMap params;

    SendEvent(tag, params);
}
