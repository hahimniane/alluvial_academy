#pragma once

#include <windows.h>
#include <flutter/encodable_value.h>
#include "auth_service_interface.h"
#include "meeting_service_interface.h"
#include "zoom_event_listener_base.h" // Include the base class header

class ZoomSDKEventListenerMeetingService : public ZoomSDKEventListenerBase, public ZOOM_SDK_NAMESPACE::IMeetingServiceEvent
{
public:
    ZoomSDKEventListenerMeetingService();
    virtual ~ZoomSDKEventListenerMeetingService();

    // Override the callback methods from IMeetingServiceEvent interface
    virtual void onMeetingStatusChanged(ZOOM_SDK_NAMESPACE::MeetingStatus status, int iResult = 0) override;
    virtual void onMeetingStatisticsWarningNotification(ZOOM_SDK_NAMESPACE::StatisticsWarningType type) override;
    virtual void onMeetingParameterNotification(const ZOOM_SDK_NAMESPACE::MeetingParameter *meeting_param) override;
    virtual void onSuspendParticipantsActivities() override;
    virtual void onAICompanionActiveChangeNotice(bool bActive) override;
    virtual void onMeetingTopicChanged(const zchar_t *sTopic) override;
    virtual void onMeetingFullToWatchLiveStream(const zchar_t *sLiveStreamUrl) override;

private:
    // Send meeting-specific events
    void SendMeetingEvent(const std::string &eventName, const flutter::EncodableMap &params);
};
