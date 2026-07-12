import Flutter
import UIKit
import MobileRTC
import ReplayKit

public class FlutterZoomMeetingWrapperPlugin: NSObject, FlutterPlugin, MobileRTCAuthDelegate, MobileRTCMeetingServiceDelegate {

  // App Group shared by the Runner app and the ScreenShare broadcast upload
  // extension. This exact string must also be the App Group capability on both
  // Xcode targets and the `appGroup` in the extension's SampleHandler.
  static let screenShareAppGroupId = "group.com.example.alluwalacademyadmin.screenshare"

  // Bundle identifier of the Broadcast Upload Extension target. Setting this on
  // the SDK init context enables the in-meeting "Screen" (direct screen share)
  // option wired to our extension.
  static let screenShareExtensionBundleId = "com.example.alluwalacademyadmin.ScreenShare"

  private var authResult: FlutterResult?
  private var joinResult: FlutterResult?
  // The app's own (Flutter) window, captured before Zoom presents its meeting UI
  // window, so we can restore it when the meeting ends instead of leaving the
  // user on Zoom's torn-down black window.
  private weak var hostWindow: UIWindow?
  // Retained so we can notify Flutter (onMeetingEnded) when the meeting ends.
  private var channel: FlutterMethodChannel?
  private var meetingEndNotified = false
  private var cleanupGeneration = 0
  private var sdkCleanedUpAfterMeeting = false
  private var shouldAutoJoinBreakoutRoom = false
  private var expectedBreakoutRoomName: String?
  private var breakoutAttendee: MobileRTCBOAttendee?
  private var breakoutDataHelper: MobileRTCBOData?
  private var pendingBreakoutRoomID: String?
  private var pendingBreakoutRoomName: String?
  private var breakoutAutoJoinGeneration = 0
  private var meetingIsDisconnecting = false
  private var breakoutTransferInProgress = false
  private var breakoutTransferEndedCheckGeneration = 0
  private var lastMeetingState: MobileRTCMeetingState = .idle
  private var lastMeetingEndReasonRaw: UInt?
  private var userTappedMeetingEnd = false
  private var nativeLeaveInProgress = false

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_zoom_meeting_wrapper", binaryMessenger: registrar.messenger())
    let instance = FlutterZoomMeetingWrapperPlugin()
    instance.channel = channel
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initZoom":
      guard let args = call.arguments as? [String: Any],
            let jwt = args["jwt"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "Missing JWT token", details: nil))
        return
      }
      initializeZoom(jwt: jwt, result: result)

    case "joinMeeting":
      guard let args = call.arguments as? [String: Any],
            let meetingId = args["meetingId"] as? String,
            let password = args["meetingPassword"] as? String,
            let displayName = args["displayName"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "Missing meeting parameters", details: nil))
        return
      }
      let routingDisplayName = (args["routingDisplayName"] as? String)?
        .trimmingCharacters(in: .whitespacesAndNewlines)
      let joinDisplayName = routingDisplayName?.isEmpty == false ? routingDisplayName! : displayName
      let breakoutRoomName = (args["breakoutRoomName"] as? String)?
        .trimmingCharacters(in: .whitespacesAndNewlines)
      startJoinMeeting(
        meetingId: meetingId,
        password: password,
        displayName: joinDisplayName,
        customerKey: args["customerKey"] as? String,
        autoJoinBreakoutRoom: args["autoJoinBreakoutRoom"] as? Bool ?? false,
        breakoutRoomName: breakoutRoomName?.isEmpty == false ? breakoutRoomName : nil,
        result: result)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Zoom SDK

  // Find the directory that contains MobileRTCResources.bundle using FileManager so the
  // result is a plain filesystem path identical to what Zoom docs show (Bundle.main.bundlePath).
  // CocoaPods places the bundle in the main app bundle (static integration) or inside the
  // plugin framework (use_frameworks!), so we check both.
  private func mobileRTCResourcesBundlePath() -> String? {

    if let path = Bundle.main.path(
        forResource: "MobileRTCResources",
        ofType: "bundle"
    ) {
        return path
    }

    if let path = Bundle(for: MobileRTC.self).path(
        forResource: "MobileRTCResources",
        ofType: "bundle"
    ) {
        return path
    }

    if let path = Bundle(for: FlutterZoomMeetingWrapperPlugin.self).path(
        forResource: "MobileRTCResources",
        ofType: "bundle"
    ) {
        return path
    }

    return nil
  }

  private func initializeZoom(jwt: String, result: @escaping FlutterResult) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }

      let sdk = MobileRTC.shared()

      // SDK already authorized — no need to re-initialize
      if sdk.isRTCAuthorized() {
        result(true)
        return
      }

      guard let resPath = self.mobileRTCResourcesBundlePath() else {
        result(FlutterError(code: "INIT_ERROR", message: "MobileRTCResources.bundle not found in app bundle. Ensure it is listed in the podspec resources and pod install was run.", details: nil))
        return
      }

      let context = MobileRTCSDKInitContext()
      context.domain = "zoom.us"
      context.enableLog = true
      let frameworkBundle = Bundle(for: MobileRTC.self)
      context.bundleResPath = frameworkBundle.bundlePath
      // Required for iOS device screen sharing via the Broadcast Upload
      // Extension. Must match the App Group added to both the Runner target and
      // the ScreenShare extension target, and the `appGroup` set in the
      // extension's SampleHandler. See docs/zoom-native-mobile-sdk-runbook.md.
      context.appGroupId = FlutterZoomMeetingWrapperPlugin.screenShareAppGroupId
      context.replaykitBundleIdentifier =
        FlutterZoomMeetingWrapperPlugin.screenShareExtensionBundleId

      let initResult = sdk.initialize(context)

      guard initResult else {
        result(FlutterError(code: "INIT_ERROR", message: "MobileRTC.initialize() returned false", details: nil))
        return
      }

      guard let authService = sdk.getAuthService() else {
        result(FlutterError(code: "INIT_ERROR", message: "Could not get MobileRTC auth service", details: nil))
        return
      }

      self.authResult = result
      authService.delegate = self
      authService.jwtToken = jwt
      authService.sdkAuth()
    }
  }

  private func startJoinMeeting(
    meetingId: String,
    password: String,
    displayName: String,
    customerKey: String?,
    autoJoinBreakoutRoom: Bool,
    breakoutRoomName: String?,
    result: @escaping FlutterResult
  ) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }

      guard MobileRTC.shared().isRTCAuthorized() else {
        result(FlutterError(code: "SDK_ERROR", message: "Zoom SDK is not initialized. Call initZoom first.", details: nil))
        return
      }

      guard let meetingService = MobileRTC.shared().getMeetingService() else {
        result(FlutterError(code: "SDK_ERROR", message: "Could not get MobileRTC meeting service", details: nil))
        return
      }

      guard let scene = UIApplication.shared.connectedScenes
        .first(where: { $0.activationState == .foregroundActive }) else {
        result(FlutterError(code: "SDK_ERROR", message: "No active foreground scene found", details: nil))
        return
      }

      // Remember the app's current key window so we can bring it back when the
      // meeting ends (Zoom presents its UI in a separate window).
      self.hostWindow = (scene as? UIWindowScene)?.windows.first(where: { $0.isKeyWindow })

      MobileRTC.shared().setMobileRTCPresentationScene(scene)
      meetingService.delegate = self
      self.joinResult = result
      self.meetingEndNotified = false
      self.cleanupGeneration += 1
      self.sdkCleanedUpAfterMeeting = false
      self.meetingIsDisconnecting = false
      self.configureShareParticipantVisibility()
      self.configureBreakoutAutoJoin(
        enabled: autoJoinBreakoutRoom,
        expectedRoomName: breakoutRoomName)

      let params = MobileRTCMeetingJoinParam()
      params.meetingNumber = meetingId
      params.password = password
      params.userName = displayName
      if let customerKey = customerKey?.trimmingCharacters(in: .whitespacesAndNewlines),
         !customerKey.isEmpty {
        params.customerKey = customerKey
      }

      let joinError = meetingService.joinMeeting(with: params)
      if joinError != .success {
        self.joinResult = nil
        self.cancelBreakoutAutoJoin()
        result(FlutterError(
          code: "JOIN_ERROR",
          message: "joinMeeting returned error code: \(joinError.rawValue)",
          details: nil))
      }
      // On .success the result is delivered via onMeetingStateChange delegate
    }
  }

  private func configureShareParticipantVisibility() {
    guard let settings = MobileRTC.shared().getMeetingSettings() else { return }
    settings.meetingVideoHidden = false
    settings.meetingParticipantHidden = false
    settings.meetingShareHidden = false
    settings.meetingMoreHidden = false
    settings.topBarHidden = false
    settings.bottomBarHidden = false
    settings.thumbnailInShare = true
    settings.setHideNoVideoUsersEnabled(false)
    settings.enableHideSelfView(false)
  }

  // MARK: - MobileRTCAuthDelegate

  public func onMobileRTCAuthReturn(_ returnValue: MobileRTCAuthError) {
    guard let result = authResult else { return }
    authResult = nil

    DispatchQueue.main.async {
      if returnValue == .success {
        result(true)
      } else {
        result(FlutterError(code: "AUTH_ERROR", message: "Zoom auth failed with error: \(returnValue.rawValue)", details: nil))
      }
    }
  }

  public func onMobileRTCAuthExpired() {
    authResult = nil
  }

  // MARK: - MobileRTCMeetingServiceDelegate

  public func onMeetingStateChange(_ state: MobileRTCMeetingState) {
    let meetingService = MobileRTC.shared().getMeetingService()
    lastMeetingState = state
    if state == .joinBO {
      breakoutTransferInProgress = true
      meetingIsDisconnecting = false
    }
    if state == .leaveBO {
      breakoutTransferInProgress = false
    }

    NSLog("Alluwal Zoom: meeting state raw=%lu boStatus=%lu isBOStarted=%@ isInBO=%@ boUserStatus=%@ disconnecting=%@ boTransfer=%@ pendingBO=%@",
          UInt(state.rawValue),
          UInt(meetingService?.getBOStatus().rawValue ?? 0),
          meetingService?.isBOMeetingStarted() == true ? "true" : "false",
          meetingService?.isInBOMeeting() == true ? "true" : "false",
          currentBreakoutUserStatusDescription(meetingService),
          meetingIsDisconnecting ? "true" : "false",
          breakoutTransferInProgress ? "true" : "false",
          pendingBreakoutRoomName ?? "(unknown)")

    // When the meeting ends, bring the app's own window back to the front so the
    // user returns to the app instead of a black Zoom window, and tell Flutter so
    // it can pop the meeting screen. Runs regardless of whether a join callback is
    // still pending.
    if state == .disconnecting && !breakoutTransferInProgress {
      meetingIsDisconnecting = true
    }
    if (state == .ended || state == .idle) &&
        shouldDeferMeetingEndCleanupForBreakoutTransfer(meetingService, state: state) {
      scheduleBreakoutTransferEndedCheck()
      return
    }
    if state == .ended || (state == .idle && meetingIsDisconnecting) {
      scheduleMeetingEndCleanup()
    }

    guard let result = joinResult else { return }

    switch state {
    case .inMeeting:
      meetingIsDisconnecting = false
      if meetingService?.isInBOMeeting() == true {
        breakoutTransferInProgress = false
        breakoutTransferEndedCheckGeneration += 1
      }
      joinResult = nil
      scheduleBreakoutAutoJoin(reason: "inMeeting")
      DispatchQueue.main.async { result(true) }
    case .failed, .ended, .disconnecting:
      if breakoutTransferInProgress &&
          shouldDeferMeetingEndCleanupForBreakoutTransfer(meetingService, state: state) {
        scheduleBreakoutTransferEndedCheck()
        return
      }
      joinResult = nil
      DispatchQueue.main.async {
        result(FlutterError(code: "JOIN_ERROR", message: "Meeting ended or failed. State: \(state.rawValue)", details: nil))
      }
    default:
      break
    }
  }

  public func onMeetingError(_ error: MobileRTCMeetError, message: String?) {
    NSLog("Alluwal Zoom: meeting error raw=%lu message=%@",
          UInt(error.rawValue),
          message ?? "")
    guard let result = joinResult else { return }
    if error != .success {
      joinResult = nil
      DispatchQueue.main.async {
        result(FlutterError(
          code: "JOIN_ERROR",
          message: "Meeting error \(error.rawValue): \(message ?? "")",
          details: nil))
      }
    }
  }

  public func onHasAttendeeRightsNotification(_ attendee: MobileRTCBOAttendee) {
    NSLog("Alluwal Zoom: breakout attendee rights received room=%@",
          attendee.getBOName() ?? "(unknown)")
    breakoutAttendee = attendee
    scheduleBreakoutAutoJoin(reason: "attendeeRights")
  }

  public func onLostAttendeeRightsNotification() {
    NSLog("Alluwal Zoom: breakout attendee rights lost")
    breakoutAttendee = nil
  }

  public func onHasDataHelperRightsNotification(_ dataHelper: MobileRTCBOData) {
    NSLog("Alluwal Zoom: breakout data helper rights received currentBO=%@ selfStatus=%@",
          dataHelper.getCurrentBOName() ?? "(unknown)",
          currentBreakoutUserStatusDescription(MobileRTC.shared().getMeetingService()))
    breakoutDataHelper = dataHelper
    scheduleBreakoutAutoJoin(reason: "dataHelperRights")
  }

  public func onLostDataHelperRightsNotification() {
    NSLog("Alluwal Zoom: breakout data helper rights lost")
    breakoutDataHelper = nil
  }

  public func onBOStatusChanged(_ status: MobileRTCBOStatus) {
    NSLog("Alluwal Zoom: BO status changed raw=%lu", UInt(status.rawValue))
    if status.rawValue == 2 {
      scheduleBreakoutAutoJoin(reason: "boStarted")
    }
  }

  public func onBOSwitchRequestReceived(_ newBOName: String?, newBOID: String?) {
    NSLog("Alluwal Zoom: BO switch request room=%@ id=%@",
          newBOName ?? "(unknown)",
          newBOID ?? "(unknown)")
    if matchesExpectedBreakoutRoom(newBOName) {
      pendingBreakoutRoomID = normalizedBreakoutRoomName(newBOID)
      pendingBreakoutRoomName = normalizedBreakoutRoomName(newBOName)
      tryJoinAssignedBreakoutRoom(reason: "boSwitchRequestImmediate")
      scheduleBreakoutAutoJoin(reason: "boSwitchRequest")
    } else {
      NSLog("Alluwal Zoom: ignoring breakout switch to unexpected room %@", newBOName ?? "(unknown)")
    }
  }

  public func onBOInfoUpdated(_ boId: String?) {
    NSLog("Alluwal Zoom: BO info updated id=%@", boId ?? "(unknown)")
    scheduleBreakoutAutoJoin(reason: "boInfoUpdated")
  }

  public func onBOListInfoUpdated() {
    NSLog("Alluwal Zoom: BO list info updated")
    scheduleBreakoutAutoJoin(reason: "boListInfoUpdated")
  }

  public func onMeetingEndedReason(_ reason: MobileRTCMeetingEndReason) {
    lastMeetingEndReasonRaw = UInt(reason.rawValue)
    NSLog("Alluwal Zoom: meeting ended reason raw=%lu boTransfer=%@ disconnecting=%@",
          UInt(reason.rawValue),
          breakoutTransferInProgress ? "true" : "false",
          meetingIsDisconnecting ? "true" : "false")
  }

  public func onClickedEndButton(_ parentVC: UIViewController, end endButton: UIButton) -> Bool {
    if nativeLeaveInProgress {
      return true
    }
    userTappedMeetingEnd = true
    nativeLeaveInProgress = true
    breakoutTransferInProgress = false
    breakoutTransferEndedCheckGeneration += 1
    cancelBreakoutAutoJoin()
    meetingIsDisconnecting = true

    NSLog("Alluwal Zoom: native leave requested from Zoom end button")
    DispatchQueue.main.async {
      guard let meetingService = MobileRTC.shared().getMeetingService() else {
        self.scheduleMeetingEndCleanup()
        return
      }
      meetingService.leaveMeeting(with: LeaveMeetingCmd(rawValue: 0)!)
    }
    return true
  }

  private func configureBreakoutAutoJoin(enabled: Bool, expectedRoomName: String?) {
    shouldAutoJoinBreakoutRoom = enabled
    expectedBreakoutRoomName = normalizedBreakoutRoomName(expectedRoomName)
    breakoutAttendee = nil
    breakoutDataHelper = nil
    pendingBreakoutRoomID = nil
    pendingBreakoutRoomName = nil
    breakoutAutoJoinGeneration += 1
    breakoutTransferInProgress = false
    breakoutTransferEndedCheckGeneration += 1
    lastMeetingEndReasonRaw = nil
    userTappedMeetingEnd = false
    nativeLeaveInProgress = false
  }

  private func cancelBreakoutAutoJoin() {
    shouldAutoJoinBreakoutRoom = false
    expectedBreakoutRoomName = nil
    breakoutAttendee = nil
    breakoutDataHelper = nil
    pendingBreakoutRoomID = nil
    pendingBreakoutRoomName = nil
    breakoutAutoJoinGeneration += 1
  }

  private func scheduleBreakoutAutoJoin(reason: String) {
    guard shouldAutoJoinBreakoutRoom else { return }
    breakoutAutoJoinGeneration += 1
    let generation = breakoutAutoJoinGeneration
    let delays: [TimeInterval] = [0, 0.25, 0.75, 1.5, 2.5, 4.0, 6.0, 9.0, 13.0, 18.0, 25.0, 35.0, 45.0]
    for delay in delays {
      DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
        guard let self = self, self.breakoutAutoJoinGeneration == generation else { return }
        self.tryJoinAssignedBreakoutRoom(reason: reason)
      }
    }
  }

  private func tryJoinAssignedBreakoutRoom(reason: String) {
    guard shouldAutoJoinBreakoutRoom else { return }
    guard let meetingService = MobileRTC.shared().getMeetingService() else {
      logBreakoutAutoJoinSkipped(reason: reason, detail: "missingMeetingService")
      return
    }
    guard meetingService.isBOMeetingEnabled() else {
      logBreakoutAutoJoinSkipped(reason: reason, detail: "boDisabled")
      return
    }
    guard !meetingService.isInBOMeeting() else {
      breakoutTransferInProgress = false
      breakoutTransferEndedCheckGeneration += 1
      logBreakoutAutoJoinSkipped(reason: reason, detail: "alreadyInBO")
      return
    }

    if lastMeetingState == .joinBO || lastMeetingState == .reconnecting {
      breakoutTransferInProgress = true
      logBreakoutAutoJoinSkipped(reason: reason, detail: "transferAlreadyInProgress")
      return
    }

    let boStatus = meetingService.getBOStatus()
    guard boStatus.rawValue == 2 || meetingService.isBOMeetingStarted() else {
      logBreakoutAutoJoinSkipped(reason: reason, detail: "boNotStarted")
      return
    }

    if let pendingBreakoutRoomID = pendingBreakoutRoomID,
       matchesExpectedBreakoutRoom(pendingBreakoutRoomName),
       let assistant = meetingService.getAssistantHelper() {
      let joined = assistant.joinBO(pendingBreakoutRoomID)
      if joined {
        breakoutTransferInProgress = true
      }
      NSLog("Alluwal Zoom: assistant joinBO result=%@ reason=%@ room=%@ id=%@",
            joined ? "true" : "false",
            reason,
            pendingBreakoutRoomName ?? "(unknown)",
            pendingBreakoutRoomID)
      if joined { return }
    }

    let attendee = breakoutAttendee ?? meetingService.getAttedeeHelper()
    guard let attendee = attendee else {
      logBreakoutAutoJoinSkipped(reason: reason, detail: "missingAttendeeHelper")
      return
    }
    breakoutAttendee = attendee

    let reportedRoomName = firstNonEmpty(
      meetingService.getJoiningBOName(),
      attendee.getBOName())
    guard matchesExpectedBreakoutRoom(reportedRoomName) else {
      NSLog("Alluwal Zoom: assigned breakout room mismatch; expected %@ got %@",
            expectedBreakoutRoomName ?? "(any)",
            reportedRoomName ?? "(unknown)")
      return
    }

    let joined = attendee.joinBO()
    if joined {
      breakoutTransferInProgress = true
    }
    NSLog("Alluwal Zoom: attendee joinBO result=%@ reason=%@ room=%@",
          joined ? "true" : "false",
          reason,
          reportedRoomName ?? "(unknown)")
  }

  private func logBreakoutAutoJoinSkipped(reason: String, detail: String) {
    let meetingService = MobileRTC.shared().getMeetingService()
    NSLog("Alluwal Zoom: attendee joinBO skipped detail=%@ reason=%@ state=%lu boStatus=%lu isBOStarted=%@ isInBO=%@ boUserStatus=%@",
          detail,
          reason,
          UInt(lastMeetingState.rawValue),
          UInt(meetingService?.getBOStatus().rawValue ?? 0),
          meetingService?.isBOMeetingStarted() == true ? "true" : "false",
          meetingService?.isInBOMeeting() == true ? "true" : "false",
          currentBreakoutUserStatusDescription(meetingService))
  }

  private func shouldDeferMeetingEndCleanupForBreakoutTransfer(
    _ meetingService: MobileRTCMeetingService?,
    state: MobileRTCMeetingState
  ) -> Bool {
    guard shouldAutoJoinBreakoutRoom else { return false }
    guard breakoutTransferInProgress else { return false }
    guard !userTappedMeetingEnd else { return false }
    guard lastMeetingEndReasonRaw != 1 &&
            lastMeetingEndReasonRaw != 2 &&
            lastMeetingEndReasonRaw != 3 &&
            lastMeetingEndReasonRaw != 4 &&
            lastMeetingEndReasonRaw != 5 &&
            lastMeetingEndReasonRaw != 6 else {
      return false
    }

    NSLog("Alluwal Zoom: deferring meeting cleanup during breakout transfer state=%lu boStatus=%lu isBOStarted=%@ isInBO=%@ endReason=%@",
          UInt(state.rawValue),
          UInt(meetingService?.getBOStatus().rawValue ?? 0),
          meetingService?.isBOMeetingStarted() == true ? "true" : "false",
          meetingService?.isInBOMeeting() == true ? "true" : "false",
          lastMeetingEndReasonRaw.map(String.init) ?? "(none)")
    return true
  }

  private func scheduleBreakoutTransferEndedCheck() {
    breakoutTransferEndedCheckGeneration += 1
    let generation = breakoutTransferEndedCheckGeneration
    let delays: [TimeInterval] = [1.0, 3.0, 6.0, 10.0, 16.0, 24.0, 36.0, 50.0, 65.0]
    for (index, delay) in delays.enumerated() {
      DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
        guard let self = self,
              self.breakoutTransferEndedCheckGeneration == generation else {
          return
        }
        self.checkDeferredBreakoutTransferEnd(isFinalCheck: index == delays.count - 1)
      }
    }
  }

  private func checkDeferredBreakoutTransferEnd(isFinalCheck: Bool) {
    guard breakoutTransferInProgress else { return }
    guard let meetingService = MobileRTC.shared().getMeetingService() else {
      if isFinalCheck {
        scheduleMeetingEndCleanup()
      }
      return
    }

    if meetingService.isInBOMeeting() {
      NSLog("Alluwal Zoom: breakout transfer completed after deferred ended state")
      breakoutTransferInProgress = false
      breakoutTransferEndedCheckGeneration += 1
      return
    }

    if meetingService.getMeetingState() == .inMeeting {
      NSLog("Alluwal Zoom: still in main meeting after deferred breakout ended state; retrying BO join")
      breakoutTransferInProgress = false
      scheduleBreakoutAutoJoin(reason: "deferredTransferStillInMeeting")
      return
    }

    if isFinalCheck {
      NSLog("Alluwal Zoom: breakout transfer did not recover; cleaning up ended meeting")
      scheduleMeetingEndCleanup()
    } else {
      NSLog("Alluwal Zoom: waiting for breakout transfer recovery after deferred ended state")
    }
  }

  private func currentBreakoutUserStatusDescription(
    _ meetingService: MobileRTCMeetingService?
  ) -> String {
    guard let dataHelper = breakoutDataHelper ?? meetingService?.getDataHelper() else {
      return "(unknown)"
    }
    if let status = currentBreakoutUserStatus(dataHelper) {
      return String(UInt(status.rawValue))
    }
    return "(unknown)"
  }

  private func currentBreakoutUserStatus(
    _ dataHelper: MobileRTCBOData
  ) -> MobileRTCBOUserStatus? {
    if let unassignedUsers = dataHelper.getUnassignedUserList() {
      for case let userID as String in unassignedUsers {
        if dataHelper.isBOUserMyself(userID) {
          return MobileRTCBOUserStatus(rawValue: 1)
        }
      }
    }

    guard let boIDs = dataHelper.getBOMeetingIDList() else {
      return nil
    }
    for case let boID as String in boIDs {
      guard let meeting = dataHelper.getBOMeeting(byID: boID),
            let users = meeting.getUserList() else {
        continue
      }
      for userID in users where dataHelper.isBOUserMyself(userID) {
        return meeting.getBOUserStatus(withUserID: userID)
      }
    }
    return nil
  }

  private func firstNonEmpty(_ values: String?...) -> String? {
    for value in values {
      if let normalized = normalizedBreakoutRoomName(value) {
        return normalized
      }
    }
    return nil
  }

  private func matchesExpectedBreakoutRoom(_ roomName: String?) -> Bool {
    guard let expected = expectedBreakoutRoomName else { return true }
    guard let actual = normalizedBreakoutRoomName(roomName) else { return true }
    return expected.caseInsensitiveCompare(actual) == .orderedSame
  }

  private func normalizedBreakoutRoomName(_ roomName: String?) -> String? {
    guard let trimmed = roomName?.trimmingCharacters(in: .whitespacesAndNewlines),
          !trimmed.isEmpty else {
      return nil
    }
    return trimmed
  }

  private func scheduleMeetingEndCleanup() {
    cancelBreakoutAutoJoin()
    meetingIsDisconnecting = false
    cleanupGeneration += 1
    let generation = cleanupGeneration
    let delays: [TimeInterval] = [0, 0.15, 0.35, 0.75, 1.5, 2.5, 4.0, 6.0]
    for delay in delays {
      DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
        guard let self = self, self.cleanupGeneration == generation else { return }
        self.restoreAppWindowAfterMeetingEnd()
      }
    }
  }

  private func restoreAppWindowAfterMeetingEnd() {
    cleanupZoomSdkIfNeeded()

    let appWindow = hostWindow ?? UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }

    for scene in UIApplication.shared.connectedScenes {
      guard let windowScene = scene as? UIWindowScene else { continue }
      for window in windowScene.windows {
        if window === appWindow { continue }
        if isSystemWindow(window) { continue }
        window.rootViewController?.dismiss(animated: false)
        window.isHidden = true
        window.alpha = 0
      }
    }

    appWindow?.rootViewController?.dismiss(animated: false)
    if let appView = appWindow?.rootViewController?.view {
      removeResidualZoomViews(from: appView)
    }
    if let appWindow = appWindow {
      removeResidualZoomViews(from: appWindow)
    }
    appWindow?.alpha = 1
    appWindow?.isHidden = false
    appWindow?.makeKeyAndVisible()

    if !meetingEndNotified {
      meetingEndNotified = true
      channel?.invokeMethod("onMeetingEnded", arguments: nil)
    }
  }

  private func cleanupZoomSdkIfNeeded() {
    guard !sdkCleanedUpAfterMeeting else { return }
    sdkCleanedUpAfterMeeting = true
    let sdk = MobileRTC.shared()
    if sdk.isRTCAuthorized() {
      sdk.cleanup()
    }
  }

  private func removeResidualZoomViews(from root: UIView) {
    for subview in root.subviews {
      if subview === root.window?.rootViewController?.view {
        removeResidualZoomViews(from: subview)
        continue
      }
      if isResidualZoomView(subview) {
        subview.removeFromSuperview()
        continue
      }
      removeResidualZoomViews(from: subview)
    }
  }

  private func isResidualZoomView(_ view: UIView) -> Bool {
    let className = NSStringFromClass(type(of: view))
    if className.contains("MobileRTC") ||
      className.contains("Zoom") ||
      className.contains("ZM") ||
      className.contains("ZP") ||
      className.contains("MBProgressHUD") {
      return true
    }

    let accessibility = view.accessibilityLabel ?? ""
    if accessibility.localizedCaseInsensitiveContains("waiting") {
      return true
    }

    if let label = view as? UILabel,
       label.text?.localizedCaseInsensitiveContains("waiting") == true {
      return true
    }

    if let button = view as? UIButton,
       button.title(for: .normal)?.localizedCaseInsensitiveContains("waiting") == true {
      return true
    }

    return false
  }

  private func isSystemWindow(_ window: UIWindow) -> Bool {
    let className = String(describing: type(of: window))
    return className.contains("TextEffects") ||
      className.contains("Keyboard") ||
      className.contains("StatusBar")
  }

  // Called by Zoom's default meeting UI when the user taps "Screen" in the share
  // menu. Implementing this selector is what makes the SDK surface the screen
  // share option; here we present the system broadcast picker targeting our
  // Broadcast Upload Extension so the whole device screen is shared.
  public func onClickShareScreen(_ parentVC: UIViewController) {
    let picker = RPSystemBroadcastPickerView(
      frame: CGRect(x: 0, y: 0, width: 60, height: 60))
    picker.preferredExtension =
      FlutterZoomMeetingWrapperPlugin.screenShareExtensionBundleId
    picker.showsMicrophoneButton = false
    parentVC.view.addSubview(picker)
    for subview in picker.subviews {
      if let button = subview as? UIButton {
        button.sendActions(for: .touchUpInside)
      }
    }
  }
}
