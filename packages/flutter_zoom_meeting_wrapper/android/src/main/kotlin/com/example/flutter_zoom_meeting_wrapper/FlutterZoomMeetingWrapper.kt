package com.example.flutter_zoom_meeting_wrapper

import android.annotation.SuppressLint
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import us.zoom.sdk.BOOption
import us.zoom.sdk.BOStatus
import us.zoom.sdk.IBOAdmin
import us.zoom.sdk.IBOAssistant
import us.zoom.sdk.IBOAttendee
import us.zoom.sdk.IBOCreator
import us.zoom.sdk.IBOData
import us.zoom.sdk.IShareAction
import us.zoom.sdk.InMeetingBOControllerListener
import us.zoom.sdk.JoinMeetingOptions
import us.zoom.sdk.JoinMeetingParams
import us.zoom.sdk.MeetingParameter
import us.zoom.sdk.MeetingServiceListener
import us.zoom.sdk.MeetingStatus
import us.zoom.sdk.ReturnToMainSessionHandler
import us.zoom.sdk.SharingStatus
import us.zoom.sdk.ZoomError
import us.zoom.sdk.ZoomSDK
import us.zoom.sdk.ZoomSDKInitParams
import us.zoom.sdk.ZoomSDKInitializeListener
import us.zoom.sdk.ZoomSDKRawDataMemoryMode

/**
 * FlutterZoomMeetingWrapper is the main plugin class that handles Zoom SDK integration
 * It implements FlutterPlugin for Flutter engine communication, MethodCallHandler for method channel,
 * ActivityAware for activity lifecycle handling, and ZoomSDKInitializeListener for SDK initialization callbacks
 */
class FlutterZoomMeetingWrapper: FlutterPlugin, MethodCallHandler, ActivityAware, ZoomSDKInitializeListener {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel

  // Application context to be used throughout the plugin
  private lateinit var context: Context

  // Instance of ZoomSDK
  private lateinit var zoomSDK: ZoomSDK

  // Binding to track activity state for proper UI integration
  private var activityPluginBinding: ActivityPluginBinding? = null

  // Flag to track SDK initialization status
  private var pendingStatus: Boolean? = false
  private val mainHandler = Handler(Looper.getMainLooper())
  private var meetingListenerRegistered = false
  private var breakoutListenerRegistered = false
  private var shouldAutoJoinBreakoutRoom = false
  private var expectedBreakoutRoomName: String? = null
  private var breakoutJoinAttempts = 0
  private val maxBreakoutJoinAttempts = 20

  private val meetingServiceListener = object : MeetingServiceListener {
    override fun onMeetingStatusChanged(
      meetingStatus: MeetingStatus?,
      errorCode: Int,
      internalErrorCode: Int
    ) {
      Log.d("ZOOM_SDK", "Meeting status changed: $meetingStatus error=$errorCode internal=$internalErrorCode")
      when (meetingStatus) {
        MeetingStatus.MEETING_STATUS_INMEETING,
        MeetingStatus.MEETING_STATUS_JOIN_BREAKOUT_ROOM -> {
          registerBreakoutListener()
          scheduleBreakoutAutoJoin(0)
        }
        MeetingStatus.MEETING_STATUS_ENDED,
        MeetingStatus.MEETING_STATUS_IDLE,
        MeetingStatus.MEETING_STATUS_FAILED -> {
          resetBreakoutAutoJoinState()
        }
        else -> {}
      }
    }

    override fun onMeetingParameterNotification(meetingParameter: MeetingParameter?) {
    }
  }

  private val breakoutControllerListener = object : InMeetingBOControllerListener {
    override fun onHasCreatorRightsNotification(creator: IBOCreator?) {
    }

    override fun onHasAdminRightsNotification(iboAdmin: IBOAdmin?) {
    }

    override fun onHasAssistantRightsNotification(iboAssistant: IBOAssistant?) {
    }

    override fun onHasAttendeeRightsNotification(iboAttendee: IBOAttendee?) {
      Log.d("ZOOM_SDK", "Breakout attendee rights received")
      attemptBreakoutAutoJoin(iboAttendee)
    }

    override fun onHasDataHelperRightsNotification(iboData: IBOData?) {
    }

    override fun onLostCreatorRightsNotification() {
    }

    override fun onLostAdminRightsNotification() {
    }

    override fun onLostAssistantRightsNotification() {
    }

    override fun onLostAttendeeRightsNotification() {
    }

    override fun onLostDataHelperRightsNotification() {
    }

    override fun onNewBroadcastMessageReceived(message: String?, senderId: Long, senderName: String?) {
    }

    override fun onBOStopCountDown(seconds: Int) {
    }

    override fun onHostInviteReturnToMainSession(name: String?, handler: ReturnToMainSessionHandler?) {
    }

    override fun onBOStatusChanged(status: BOStatus?) {
      Log.d("ZOOM_SDK", "Breakout status changed: $status")
      scheduleBreakoutAutoJoin(250)
    }

    override fun onBOSwitchRequestReceived(strNewBOName: String?, strNewBOID: String?) {
      Log.d("ZOOM_SDK", "Breakout switch request received: name=$strNewBOName id=$strNewBOID")
      attemptBreakoutAutoJoin()
    }

    override fun onBroadcastBOVoiceStatus(start: Boolean) {
    }

    override fun onBOOptionChanged(newOption: BOOption?) {
    }

    override fun onShareFromMainSession(sharingId: Long, status: SharingStatus?, shareAction: IShareAction?) {
    }
  }

  /**
   * Called when the plugin is attached to the Flutter engine
   * Initializes the method channel and sets up basic plugin configuration
   */
  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    // Set up method channel for communication between Flutter and native code
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_zoom_meeting_wrapper")
    channel.setMethodCallHandler(this)
    context = flutterPluginBinding.applicationContext
    zoomSDK = ZoomSDK.getInstance()
  }

  /**
   * Handles method calls from Flutter
   * Routes different methods to appropriate handlers
   */
  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
      "getPlatformVersion" -> {
        // Return Android version
        result.success("Android ${android.os.Build.VERSION.RELEASE}")
      }
      "initZoom" -> {
        // Initialize Zoom SDK with JWT token
        val jwt = call.argument<String>("jwt")
        if (jwt != null) {
          initializeZoomSDK(jwt, result)
        } else {
          result.error("INVALID_ARGS", "Missing JWT token", null)
        }
      }
      "joinMeeting" -> {
        // Join a Zoom meeting with provided credentials
        joinZoomMeeting(
          call.argument("meetingId"),
          call.argument("meetingPassword"),
          call.argument("displayName"),
          call.argument("routingDisplayName"),
          call.argument("customerKey"),
          call.argument("breakoutRoomName"),
          call.argument<Boolean>("autoJoinBreakoutRoom") == true,
          result
        )
      }
      else -> {
        // Method not implemented
        result.notImplemented()
      }
    }
  }

  /**
   * Called when the plugin is detached from the Flutter engine
   * Cleans up resources
   */
  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    unregisterMeetingListeners()
    channel.setMethodCallHandler(null)
  }

  // Activity Aware implementation - for managing activity lifecycle

  /**
   * Called when the plugin is attached to an activity
   */
  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activityPluginBinding = binding
  }

  /**
   * Called when activity is detached due to configuration changes
   */
  override fun onDetachedFromActivityForConfigChanges() {
    activityPluginBinding = null
  }

  /**
   * Called when activity is reattached after configuration changes
   */
  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activityPluginBinding = binding
  }

  /**
   * Called when plugin is detached from activity
   */
  override fun onDetachedFromActivity() {
    activityPluginBinding = null
  }

  // Zoom SDK implementation

  /**
   * Initializes the Zoom SDK with JWT token
   * @param jwt JWT token for authentication
   * @param result Flutter method call result callback
   */
  @SuppressLint("SuspiciousIndentation")
  private fun initializeZoomSDK(jwt: String, result: MethodChannel.Result) {
    Log.d("ZOOM_SDK", "JWT Token received: $jwt")
    Log.d("ZOOM_SDK", "JWT Token length: ${jwt.length}")
    zoomSDK = ZoomSDK.getInstance()

    try {
      // Check if SDK is already initialized
      if (zoomSDK.isInitialized()){
        Log.d("ZOOM_SDK", "Zoom SDK already initialized")
        result.success(true)
      }
      // Only initialize if not already initialized
      if (!zoomSDK.isInitialized()) {
        // Configure SDK initialization parameters
        var initParams =  ZoomSDKInitParams()
        initParams.jwtToken = jwt;
        initParams.enableLog = true;
        initParams.enableGenerateDump = true;
        initParams.logSize = 5;
        initParams.domain="zoom.us";
        initParams.videoRawDataMemoryMode = ZoomSDKRawDataMemoryMode.ZoomSDKRawDataMemoryModeStack;

        // Create listener for initialization callbacks
        val listener = object : ZoomSDKInitializeListener {
          /**
           * Callback for SDK initialization result
           * @param errorCode Error code from initialization
           * @param internalErrorCode Internal error code from initialization
           */
          override fun onZoomSDKInitializeResult(errorCode: Int, internalErrorCode: Int) {
            if (errorCode != ZoomError.ZOOM_ERROR_SUCCESS) {
              Log.d("Failed", "Failed to initialize Zoom SDK")
              Log.d(
                "Failed to initialize Zoom SDK. Error: \" + $errorCode + \"",
                "internalErrorCode=\" + $internalErrorCode"
              )
               return result.error("INIT_ERROR", "\"Failed to initialize Zoom SDK. Error: \" + $errorCode + \",\n" +
                       "\"internalErrorCode=\" + $internalErrorCode\"", null)
            } else {
              Log.d("Success", "Initialize Zoom SDK successfully.")
              return result.success(true)
            }
          }

          /**
           * Callback when Zoom auth identity expires
           */
          override fun onZoomAuthIdentityExpired() {

          }
        }

        // Initialize SDK with prepared parameters
        zoomSDK.initialize(context, listener, initParams)

      }
    } catch (e: Exception) {
      Log.e("ZOOM_SDK", "Error while initializing ZoomSDK: ${e.message}", e)
      result.error("INIT_ERROR", "Failed to initialize Zoom SDK: ${e.message}", null)
    }
  }

  /**
   * Joins a Zoom meeting with provided credentials
   * @param meetingId The ID of the meeting to join
   * @param password The password for the meeting
   * @param displayName The name to display for the user
   * @param result Flutter method call result callback
   */
  private fun joinZoomMeeting(
          meetingId: String?,
          password: String?,
          displayName: String?,
          routingDisplayName: String?,
          customerKey: String?,
          breakoutRoomName: String?,
          autoJoinBreakoutRoom: Boolean,
          result: Result
  ) {
    // Validate required parameters
    if (meetingId.isNullOrEmpty() || password.isNullOrEmpty() || displayName.isNullOrEmpty()) {
      result.error("INVALID_ARGS", "Meeting ID, password, or display name is empty", null)
      return
    }

    // Check if SDK is initialized
    if (!zoomSDK.isInitialized()) {
      result.error("SDK_ERROR", "Zoom SDK is not initialized", null)
      return
    }

    // Configure meeting parameters
    val meetingService = zoomSDK.meetingService
    shouldAutoJoinBreakoutRoom = autoJoinBreakoutRoom
    expectedBreakoutRoomName = breakoutRoomName?.trim()?.takeIf { it.isNotEmpty() }
    breakoutJoinAttempts = 0
    registerMeetingServiceListener()
    zoomSDK.meetingSettingsHelper?.apply {
      setHideShareButtonInMeetingToolbar(false)
      setNoVideoTileOnShareScreenEnabled(false)
      setHideNoVideoUsersEnabled(false)
      setAlwaysShowMeetingToolbarEnabled(true)
      applyOptionalMeetingSetting(this, "setLargeShareVideoSceneEnabled", true)
      applyOptionalMeetingSetting(this, "setVideoOnWhenMyShare", true)
    }
    val joinMeetingOptions = JoinMeetingOptions()
    val trimmedCustomerKey = customerKey?.trim()?.takeIf { it.isNotEmpty() }
    if (trimmedCustomerKey != null) {
      joinMeetingOptions.customer_key = trimmedCustomerKey.take(35)
    }
    joinMeetingOptions.no_share = false
    val joinDisplayName = routingDisplayName?.trim()?.takeIf { it.isNotEmpty() } ?: displayName
    val joinMeetingParams = JoinMeetingParams().apply {
      this.meetingNo = meetingId
      this.password = password
      this.displayName = joinDisplayName
    }

    // Join meeting using activity or application context
    activityPluginBinding?.activity?.let { activity ->
      meetingService.joinMeetingWithParams(activity, joinMeetingParams, joinMeetingOptions)
      result.success(true)
    } ?: run {
      // If activity is not available, use the application context
      meetingService.joinMeetingWithParams(context, joinMeetingParams, joinMeetingOptions)
      result.success(true)
    }
  }

  private fun applyOptionalMeetingSetting(helper: Any, methodName: String, enabled: Boolean) {
    try {
      val method = helper.javaClass.methods.firstOrNull { method ->
        method.name == methodName &&
          method.parameterTypes.size == 1 &&
          method.parameterTypes[0] == java.lang.Boolean.TYPE
      } ?: return
      method.invoke(helper, enabled)
    } catch (e: Exception) {
      Log.d("ZOOM_SDK", "Optional meeting setting skipped: $methodName ${e.message}")
    }
  }

  private fun registerMeetingServiceListener() {
    if (meetingListenerRegistered) return
    try {
      zoomSDK.meetingService?.addListener(meetingServiceListener)
      meetingListenerRegistered = true
    } catch (e: Exception) {
      Log.w("ZOOM_SDK", "Unable to register meeting listener: ${e.message}", e)
    }
  }

  private fun registerBreakoutListener() {
    if (breakoutListenerRegistered) return
    try {
      zoomSDK.inMeetingService?.inMeetingBOController?.addListener(breakoutControllerListener)
      breakoutListenerRegistered = true
    } catch (e: Exception) {
      Log.w("ZOOM_SDK", "Unable to register breakout listener: ${e.message}", e)
    }
  }

  private fun unregisterMeetingListeners() {
    mainHandler.removeCallbacksAndMessages(null)
    try {
      if (breakoutListenerRegistered) {
        zoomSDK.inMeetingService?.inMeetingBOController?.removeListener(breakoutControllerListener)
      }
      if (meetingListenerRegistered) {
        zoomSDK.meetingService?.removeListener(meetingServiceListener)
      }
    } catch (e: Exception) {
      Log.w("ZOOM_SDK", "Unable to unregister Zoom listeners: ${e.message}", e)
    }
    breakoutListenerRegistered = false
    meetingListenerRegistered = false
    resetBreakoutAutoJoinState()
  }

  private fun resetBreakoutAutoJoinState() {
    shouldAutoJoinBreakoutRoom = false
    expectedBreakoutRoomName = null
    breakoutJoinAttempts = 0
  }

  private fun scheduleBreakoutAutoJoin(delayMs: Long) {
    if (!shouldAutoJoinBreakoutRoom) return
    mainHandler.postDelayed({ attemptBreakoutAutoJoin() }, delayMs)
  }

  private fun attemptBreakoutAutoJoin(attendeeFromEvent: IBOAttendee? = null) {
    if (!shouldAutoJoinBreakoutRoom || breakoutJoinAttempts >= maxBreakoutJoinAttempts) return
    try {
      val boController = zoomSDK.inMeetingService?.inMeetingBOController ?: run {
        scheduleBreakoutRetry()
        return
      }
      registerBreakoutListener()
      if (boController.isInBOMeeting()) return

      val attendee = attendeeFromEvent ?: boController.getBOAttendeeHelper()
      val joiningName = boController.getJoiningBOName()?.trim()?.takeIf { it.isNotEmpty() }
      val attendeeRoomName = attendee?.getBoName()?.trim()?.takeIf { it.isNotEmpty() }
      val exposedRoomName = joiningName ?: attendeeRoomName
      val expectedRoom = expectedBreakoutRoomName
      if (
        expectedRoom != null &&
        exposedRoomName != null &&
        !exposedRoomName.equals(expectedRoom, ignoreCase = true)
      ) {
        Log.w(
          "ZOOM_SDK",
          "Skipping breakout auto-join; expected=$expectedRoom exposed=$exposedRoomName"
        )
        return
      }
      if (attendee == null) {
        scheduleBreakoutRetry()
        return
      }

      breakoutJoinAttempts += 1
      val joined = attendee.joinBo()
      Log.d("ZOOM_SDK", "Breakout joinBo attempt=$breakoutJoinAttempts result=$joined room=$exposedRoomName")
      if (!joined) {
        scheduleBreakoutRetry()
      }
    } catch (e: Exception) {
      Log.w("ZOOM_SDK", "Breakout auto-join failed: ${e.message}", e)
      scheduleBreakoutRetry()
    }
  }

  private fun scheduleBreakoutRetry() {
    if (breakoutJoinAttempts >= maxBreakoutJoinAttempts) return
    breakoutJoinAttempts += 1
    mainHandler.postDelayed({ attemptBreakoutAutoJoin() }, 1500)
  }

  // ZoomSDKInitializeListener implementation

  /**
   * Callback for Zoom SDK initialization result
   * @param errorCode Error code from initialization
   * @param internalErrorCode Internal error code from initialization
   */
  override fun onZoomSDKInitializeResult(errorCode: Int, internalErrorCode: Int) {
    if (errorCode != ZoomError.ZOOM_ERROR_SUCCESS) {
      Log.d("Failed", "Failed to initialize Zoom SDK")
      Log.d(
              "Failed to initialize Zoom SDK. Error: \" + $errorCode + \"",
              "internalErrorCode=\" + $internalErrorCode"
      )
    } else {
      Log.d("Success", "Initialize Zoom SDK successfully.")
      pendingStatus=true
    }
  }

  /**
   * Callback when Zoom authentication identity expires
   */
  override fun onZoomAuthIdentityExpired() {
    Log.d("ZOOM_SDK", "Auth expired")
  }
}
