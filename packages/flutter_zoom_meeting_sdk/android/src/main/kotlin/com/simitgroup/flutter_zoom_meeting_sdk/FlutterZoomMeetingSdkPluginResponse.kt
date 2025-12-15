package com.simitgroup.flutter_zoom_meeting_sdk

data class StandardZoomResponse(
    val isSuccess: Boolean,
    val message: String,
    val action: String,
    val params: Map<String, Any>? = null
) {
    init {
        actionLog(action, " - $isSuccess - $message - $params")
    }

    fun toMap(): Map<String, Any> {
        return mapOf(
            "platform" to "android",
            "isSuccess" to isSuccess,
            "message" to message,
            "action" to action,
            "params" to (params ?: emptyMap<String, Any>())
        )
    }
}