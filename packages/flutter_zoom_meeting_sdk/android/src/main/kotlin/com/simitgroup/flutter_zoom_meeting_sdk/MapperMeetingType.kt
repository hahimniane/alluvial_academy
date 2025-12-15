package com.simitgroup.flutter_zoom_meeting_sdk

import us.zoom.sdk.MeetingType

object MapperMeetingType {
    private val errorNames = mapOf(
        MeetingType.MEETING_TYPE_NONE to "NONE",
        MeetingType.MEETING_TYPE_NORMAL to "NORMAL",
        MeetingType.MEETING_TYPE_BREAKOUTROOM to "BREAKOUT_ROOM",
        MeetingType.MEETING_TYPE_WEBINAR to "WEBINAR"
    )

    fun getErrorName(type: MeetingType): String {
        return MapperMeetingType.errorNames[type] ?: "UNDEFINED  (${type.ordinal} - ${type.name})"
    }
}