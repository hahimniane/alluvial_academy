package com.simitgroup.flutter_zoom_meeting_sdk

import android.util.Log

fun log(tag: String, message: String)
{
    Log.d("FlutterZoomMeetingSDK::$tag", message)
}

fun actionLog(tag: String, message: String)
{
    log("Action::$tag", message)
}

fun eventLog(tag: String, message: String)
{
    log("Event::$tag", message)
}