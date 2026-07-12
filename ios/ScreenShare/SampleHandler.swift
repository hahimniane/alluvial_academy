import ReplayKit
// MobileRTCScreenShareService comes from the Objective-C header exposed via
// ScreenShare-Bridging-Header.h (the framework has no Swift module map).

// Broadcast Upload Extension entry point. iOS captures the device screen in this
// separate process and delivers frames here; we forward them to Zoom's
// MobileRTCScreenShareService, which ships them to the meeting via the shared
// App Group. The `appGroup` below MUST match:
//   - the App Group capability on BOTH the Runner and ScreenShare targets, and
//   - FlutterZoomMeetingWrapperPlugin.screenShareAppGroupId in the main app.
class SampleHandler: RPBroadcastSampleHandler, MobileRTCScreenShareServiceDelegate {

  private let shareService = MobileRTCScreenShareService()

  override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
    shareService.delegate = self
    shareService.appGroup = "group.com.example.alluwalacademyadmin.screenshare"
    shareService.broadcastStarted(withSetupInfo: setupInfo)
  }

  override func broadcastPaused() {
    shareService.broadcastPaused()
  }

  override func broadcastResumed() {
    shareService.broadcastResumed()
  }

  override func broadcastFinished() {
    shareService.broadcastFinished()
  }

  override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer,
                                    with sampleBufferType: RPSampleBufferType) {
    shareService.processSampleBuffer(sampleBuffer, with: sampleBufferType)
  }

  // MobileRTCScreenShareServiceDelegate. Swift imports this selector without
  // splitting "WithError", so the name is the full selector with an unlabeled
  // parameter (verified against the SDK with swiftc -typecheck).
  func mobileRTCScreenShareServiceFinishBroadcastWithError(_ error: Error!) {
    self.finishBroadcastWithError(error)
  }
}
