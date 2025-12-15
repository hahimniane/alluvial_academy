package com.simitgroup.flutter_zoom_meeting_sdk

import com.simitgroup.flutter_zoom_meeting_sdk.FlutterZoomMeetingSdkPlugin.Companion.PLATFORM
import io.flutter.plugin.common.EventChannel
import us.zoom.sdk.MeetingParameter
import us.zoom.sdk.MeetingServiceListener
import us.zoom.sdk.MeetingStatus
import us.zoom.sdk.ZoomSDK

class FlutterZoomEventListenerMeeting(private val eventSink: EventChannel.EventSink?):
    MeetingServiceListener {
    override fun onMeetingStatusChanged(
        meetingStatus: MeetingStatus,
        errorCode: Int,
        internalErrorCode: Int
    ) {
        eventLog("onMeetingStatusChanged", "Zoom Meeting Status Changed: $meetingStatus")
        eventSink?.success(
            mapOf(
                "platform" to PLATFORM,
                "event" to "onMeetingStatusChanged",
                "oriEvent" to "onMeetingStatusChanged",
                "params" to mapOf(
                    "statusCode" to meetingStatus.ordinal,
                    "statusLabel" to MapperMeetingStatus.getErrorName(meetingStatus),
                    "errorCode" to errorCode,
                    "errorLabel" to MapperMeetingError.getErrorName(errorCode),
                    "endReasonCode" to -99,
                    "endReasonLabel" to "NO_PROVIDED",
                    "internalErrorCode" to internalErrorCode
                )
            )
        )

        if (meetingStatus == MeetingStatus.MEETING_STATUS_INMEETING) {
            val audioController = ZoomSDK.getInstance()
                .inMeetingService
                ?.inMeetingAudioController
        
            audioController?.let {
                if (!it.isAudioConnected) {
                    it.connectAudioWithVoIP()
                }
            }
        }
        
    }

    override fun onMeetingParameterNotification(params: MeetingParameter) {
        eventLog("eventOnMeetingParameterNotification", "Params: $params")

        val paramMap = mapOf(
            "isAutoRecordingCloud" to params.is_auto_recording_cloud,
            "isAutoRecordingLocal" to params.is_auto_recording_local,
            "isViewOnly" to params.isViewOnly,
            "meetingHost" to (params.meeting_host ?: ""),
            "meetingNumber" to params.meeting_number,
            "meetingTopic" to (params.meeting_topic ?: ""),
            "meetingType" to params.meeting_type.ordinal,
            "meetingTypeLabel" to MapperMeetingType.getErrorName(params.meeting_type)
        )

        val eventMap = mapOf(
            "platform" to PLATFORM,
            "event" to "onMeetingParameterNotification",
            "oriEvent" to "onMeetingParameterNotification",
            "params" to paramMap
        )

        eventSink?.success(eventMap)
    }

}