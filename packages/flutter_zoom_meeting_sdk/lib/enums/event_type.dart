/// All available events
enum EventType {
  // Auth
  /// Triggered when the authentication is returned
  onAuthenticationReturn,

  /// Triggered when the zoom auth identity is expired
  onZoomAuthIdentityExpired,

  // Meeting
  /// Triggered when the meeting status is changed
  onMeetingStatusChanged,

  /// Triggered right before the meeting starts.
  onMeetingParameterNotification,

  /// Only available on iOS
  onMeetingError,

  /// Only available on Android
  onMeetingEndedReason,
}
