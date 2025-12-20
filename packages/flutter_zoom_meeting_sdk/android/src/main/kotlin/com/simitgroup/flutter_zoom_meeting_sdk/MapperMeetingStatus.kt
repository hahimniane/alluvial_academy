package com.simitgroup.flutter_zoom_meeting_sdk

import us.zoom.sdk.MeetingStatus

object MapperMeetingStatus {
    private val errorNames = mapOf(
        MeetingStatus.MEETING_STATUS_IDLE to "IDLE",
        MeetingStatus.MEETING_STATUS_CONNECTING to "CONNECTING",
        MeetingStatus.MEETING_STATUS_WAITINGFORHOST to "WAITING_FOR_HOST",
        MeetingStatus.MEETING_STATUS_INMEETING to "IN_MEETING",
        MeetingStatus.MEETING_STATUS_DISCONNECTING to "DISCONNECTING",
        MeetingStatus.MEETING_STATUS_RECONNECTING to "RECONNECTING",
        MeetingStatus.MEETING_STATUS_FAILED to "FAILED",
        MeetingStatus.MEETING_STATUS_ENDED to "ENDED",
        MeetingStatus.MEETING_STATUS_UNLOCKED to "UNLOCKED",
        MeetingStatus.MEETING_STATUS_LOCKED to "LOCKED",
        MeetingStatus.MEETING_STATUS_IN_WAITING_ROOM to "IN_WAITING_ROOM",
        MeetingStatus.MEETING_STATUS_WEBINAR_PROMOTE to "WEBINAR_PROMOTE",
        MeetingStatus.MEETING_STATUS_WEBINAR_DEPROMOTE to "WEBINAR_DEPROMOTE",
        MeetingStatus.MEETING_STATUS_JOIN_BREAKOUT_ROOM to "JOIN_BREAKOUT_ROOM",
        MeetingStatus.MEETING_STATUS_LEAVE_BREAKOUT_ROOM to "LEAVE_BREAKOUT_ROOM",
        MeetingStatus.MEETING_STATUS_UNKNOWN to "UNKNOWN",
    )

    fun getErrorName(status: MeetingStatus): String {
        return errorNames[status] ?: "UNDEFINED  (${status.ordinal} - ${status.name})"
    }
}
