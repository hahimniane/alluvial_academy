const fs = require('fs');
const path = require('path');

describe('zoom_meeting.html', () => {
  const htmlPath = path.join(__dirname, '..', '..', 'web', 'zoom_meeting.html');
  const html = fs.readFileSync(htmlPath, 'utf8');
  const inlineScripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)]
    .map((match) => match[1]);
  const meetingScript = inlineScripts[inlineScripts.length - 1];

  test('inline meeting script parses', () => {
    expect(inlineScripts.length).toBeGreaterThan(0);
    expect(() => new Function(meetingScript)).not.toThrow();
  });

  test('participant page has no role-1 fallback or host credentials', () => {
    expect(html).not.toContain("params.get('participantSignature')");
    expect(html).not.toContain("params.get('participantFallback')");
    expect(html).not.toContain("params.get('zak')");
    expect(html).not.toContain("params.get('autoOpenBreakoutRooms')");
    expect(html).not.toContain('reloadAsParticipantFallback');
    expect(html).not.toContain('fallbackParams.set');
    expect(html).not.toContain('hostJoinDowngraded');
  });

  test('hub breakout management UI is suppressed for classroom users', () => {
    expect(html).toContain('startBreakoutManagementGuard');
    expect(html).toContain('suppressBreakoutManagementUi');
    expect(html).toContain('blockBreakoutManagementEvent');
    expect(html).toContain('classroomControlSelector');
    expect(html).toContain('[role="menuitem"]');
    expect(html).toContain('[class*="menu-item"]');
    expect(html).toContain('Close All Rooms');
    expect(html).toContain('Leave (?:Breakout )?Room');
    expect(html).toContain('hiddenFromClassroom');
  });

  test('native Zoom leave/end controls are suppressed behind the app leave button', () => {
    expect(html).toContain('isZoomNativeLeaveControl');
    expect(html).toContain('isOwnClassroomControl');
    expect(html).toContain('classroomControlTarget');
    expect(html).toContain('hideControlsUnderLeaveButton');
    expect(html).toContain('rectsOverlap');
    expect(html).toContain('alluwal-classroom-hidden');
    expect(html).toContain('[class*="leave-meeting" i]');
    expect(html).toContain('[class*="footer" i] [aria-label*="Leave" i]');
    expect(html).not.toContain('[class*="footer" i] [class*="leave" i]');
    expect(html).not.toContain('[class*="footer" i] [class*="end" i]');
    expect(html).toContain('#leaveMeetingButton::before');
    expect(html).toContain('top: calc(18px + env(safe-area-inset-top, 0px))');
    expect(html).not.toContain('bottom: calc(18px + env(safe-area-inset-bottom, 0px))');
    expect(html).toContain('End Meeting for All');
    expect(html).toContain('visibility\', \'hidden');
  });

  test('Zoom camera and audio controls are not hidden by classroom guards', () => {
    expect(html).toContain('isZoomMediaControl');
    expect(html).toContain('mediaControlPattern');
    expect(html).toContain('video|camera|cam|audio|microphone|mic|mute|unmute|start video|stop video|start camera|stop camera|enable video|disable video|turn on camera|turn off camera|join audio|share audio');
    expect(html).toContain('if (isZoomMediaControl(element)) return false');
    expect(html).toContain('if (isZoomMediaControl(control)) continue');
  });

  test('Zoom More and whiteboard controls remain available', () => {
    expect(html).toContain('isZoomAllowedUtilityControl');
    expect(html).toContain('utilityControlPattern');
    expect(html).toContain('more|whiteboards?|whiteboard');
    expect(html).toContain('if (isZoomAllowedUtilityControl(control)) continue');
    expect(html).not.toContain('rectsOverlap(shieldRect, rect)');
  });

  test('Zoom Share Screen controls remain available when the SDK renders them', () => {
    expect(html).toContain('screenShare: true');
    expect(html).toContain('sharingMode: \'both\'');
    expect(html).toContain('showPureSharingContent: false');
    expect(html).toContain('disablePictureInPicture: false');
    expect(html).toContain('@media (max-width: 640px), (pointer: coarse)');
    expect(html).toContain('overflow-x: auto !important');
    expect(html).toContain('-webkit-overflow-scrolling: touch');
    expect(html).toContain('#zmmtg-root button[aria-label*="Share" i]');
    expect(html).toContain('screenShareControlPattern');
    expect(html).toContain('share screen|screen share|share content|share');
    expect(html).toContain('!screenShareControlPattern.test(testText)');
    expect(html).toContain('if (isZoomAllowedUtilityControl(control)) continue');
  });

  test('screen share does not force-refocus the Zoom tab', () => {
    expect(html).toContain('installScreenShareFocusGuard');
    expect(html).toContain('navigator.mediaDevices');
    expect(html).toContain('mediaDevices.getDisplayMedia');
    expect(html).toContain('__alluwalFocusGuardInstalled');
    expect(html).toContain('window.CaptureController');
    expect(html).toContain("controller.setFocusBehavior('no-focus-change')");
    expect(html).not.toContain('window.focus();');
    expect(html).not.toContain('focusClassroomAfterScreenSharePrompt');
  });

  test('picture-in-picture uses a page-owned video that survives Zoom re-renders', () => {
    expect(html).toContain('installAutomaticPictureInPicture');
    expect(html).toContain('__alluwalAutomaticPictureInPictureInstalled');
    // PiP must target an element this page owns and never detaches — PiP on a
    // Zoom-owned <video> closes the PiP window the moment the SDK re-renders it.
    expect(html).toContain('alluwalPipVideo');
    expect(html).toContain('alluwalPipCanvas');
    expect(html).toContain('pipCanvas.captureStream(15)');
    expect(html).toContain('pipVideo.autoPictureInPicture = true');
    expect(html).toContain('pipVideo.requestPictureInPicture()');
    expect(html).not.toContain('video.requestPictureInPicture()');
    // Zoom-owned videos are PiP-DISABLED so Chrome auto-PiP can only pick our
    // element, and our mediaSession handler is re-asserted so the SDK cannot
    // replace it after load.
    expect(html).toContain('suppressZoomOwnedPictureInPicture');
    expect(html).toContain('video.disablePictureInPicture = true');
    expect(html).toContain('registerEnterPictureInPictureHandler');
    expect(html).toContain("pipVideo.addEventListener('leavepictureinpicture'");
    // Source is hot-swapped (video srcObject preferred, canvas capture fallback)
    // without closing the PiP window.
    expect(html).toContain('feedPipVideo');
    expect(html).toContain('bestZoomVideoStream');
    expect(html).toContain('bestZoomDrawableElement');
    expect(html).toContain('drawPipCanvasFrame');
    expect(html).toContain('mediaFrameQuality');
    expect(html).toContain('frameSampleCanvas');
    expect(html).toContain('blankAvatarLike');
    expect(html).toContain('cameraLikeScore');
    expect(html).toContain('nonDarkRatio');
    expect(html).toContain('captureStream');
    expect(html).toContain('isActiveScreenShareStream');
    expect(html).toContain('participantCandidateScore');
    expect(html).toContain('sharedContentContextPattern');
    expect(html).toContain('participantVideoContextPattern');
    expect(html).toContain('areaRatio > 0.35');
    expect(html).toContain('candidate.score > 0');
    expect(html).toContain('window.__alluwalPipDebug');
    expect(html).toContain('pipVideo');
    expect(html).toContain('pipCanvas');
    expect(html).toContain('try { feedPipVideo(); } catch (_) {}');
    expect(html).toContain('try { requestZoomPictureInPicture(); } catch (_) {}');
    expect(html).toContain("navigator.mediaSession.setActionHandler('enterpictureinpicture'");
    expect(html).toContain('requestZoomPictureInPicture');
    expect(html).toContain("document.addEventListener('visibilitychange'");
    // Only the active sharer's hidden-tab path auto-attempts PiP.
    expect(html).toContain('isScreenSharing');
    expect(html).toContain('trackScreenShareStream');
    // Deterministic gesture path: auto-PiP eligibility is Chrome's call and can
    // simply never fire for screen-share-only sessions, so a button shown while
    // sharing opens the floating view with a guaranteed user gesture — and the
    // page must NOT auto-exit PiP when the tab becomes visible again.
    expect(html).toContain('alluwalPipButton');
    expect(html).toContain('Keep participants visible');
    expect(html).toContain('updatePipButton');
    expect(html).not.toContain('document.exitPictureInPicture()');
  });

  test('mobile share screen fix stays inside the web meeting page', () => {
    expect(html).not.toContain('id="openNativeZoomButton"');
    expect(html).not.toContain("params.get('openNativeZoomForShareText')");
    expect(html).not.toContain('const shouldShowNativeZoomShareFallback');
    expect(html).not.toContain('location.assign(joinUrl)');
    expect(html).not.toContain('zoomOpenInZoomAppForScreenShare');
  });

  test('hub classroom stays hidden until private breakout room is confirmed', () => {
    expect(html).toContain('alluwal-private-routing-pending');
    expect(html).toContain('body.alluwal-private-routing-pending #zmmtg-root');
    expect(html).toContain('opacity: 0 !important');
    expect(html).toContain('const markPrivateRoomReady');
    expect(html).toContain('getCurrentBreakoutRoom');
    expect(html).toContain('getUserStatus');
    expect(html).toContain('userStatusInRoom');
    expect(html).toContain("params.get('routingStillConnectingText')");
    expect(html).toContain("params.get('routingHelpText')");
    expect(html).not.toContain('hideAfterMs: meetingJoinConfirmed ? joinedRoutingStatusMs : 0');
  });

  test('private routing guard auto-confirms Zoom no-audio-video prompt', () => {
    expect(html).toContain('autoConfirmNoAudioVideoPrompt');
    expect(html).toContain('privateRoutingPending');
    expect(html).toContain("Are you sure you don't want audio or video");
    expect(html).toContain('Continue without audio or video');
    expect(html).toContain('button.click()');
    expect(html).toContain('autoConfirmNoAudioVideoPrompt();');
    expect(html).toContain('pointer-events: none !important');
    expect(html).not.toContain('body.alluwal-private-routing-pending #zmmtg-root {\n      opacity: 0 !important;\n      pointer-events: auto !important;');
  });

  test('closing or navigating away silently asks Zoom to leave the meeting', () => {
    expect(html).toContain('requestZoomLeave');
    expect(html).toContain('leaveZoomSilently');
    expect(html).toContain('zoomLeaveRequested');
    expect(html).toContain('clearZoomSession();');
    expect(html).toContain('ZoomMtg.leaveMeeting');
    expect(html).toContain("window.addEventListener('pagehide', leaveZoomSilently");
    expect(html).toContain("window.addEventListener('beforeunload', leaveZoomSilently");
    expect(html).not.toContain("window.addEventListener('visibilitychange', leaveZoomSilently");
  });

  test('breakout room checks understand Zoom customer key field variants', () => {
    expect(html).toContain('participantCustomerKey');
    expect(html).toContain('participant.customerKey');
    expect(html).toContain('participant.customer_key');
    expect(html).toContain('participant.customerKeyValue');
    expect(html).toContain('participant.customer_key_value');
    expect(html).toContain('participant.customUserId');
    expect(html).toContain('participant.custom_user_id');
  });

  test('participant page does not expose hub assignments or host breakout APIs', () => {
    expect(html).not.toContain("params.get('assignmentToken')");
    expect(html).not.toContain('refreshHubAssignments');
    expect(html).not.toContain('zoomHubAssignments');
    expect(html).not.toContain('room.visitorIds');
    expect(html).not.toContain('room.visitor_ids');
    expect(html).not.toContain('getBreakoutRooms');
    expect(html).not.toContain('createBreakoutRoom');
    expect(html).not.toContain('openBreakoutRooms');
    expect(html).not.toContain('assignUserToBreakoutRoom');
    expect(html).not.toContain('moveUserToBreakoutRoom');
    expect(html).not.toContain('moveAssignedParticipants');
    expect(html).not.toContain('onBreakoutRoomChange');
    expect(html).toContain('onRoomStatusChange');
  });

  test('Zoom join failures include Zoom reason details instead of only generic text', () => {
    expect(html).toContain('formatZoomError');
    expect(html).toContain('Zoom join failed');
    expect(html).toContain('error && error.reason');
    expect(html).toContain('error && error.errorMessage');
    expect(html).toContain('Code ${error.errorCode}');
    // Init errors still surface the formatted Zoom reason.
    expect(html).toContain('setStatus(formatZoomError(initErrorText, error))');
  });

  test('shows a class-ending countdown before participants are removed at the time limit', () => {
    expect(html).toContain('classEndsAt');
    expect(html).toContain('startClassCountdown');
    expect(html).toContain('COUNTDOWN_WARN_MS');
    expect(html).toContain('classEndingSoonText');
    expect(html).toContain('classEndedText');
    // Countdown starts once the participant is actually in the meeting.
    expect(html).toContain('startClassCountdown();');
  });

  test('Zoom join failures auto-retry with backoff instead of hard-failing the class', () => {
    // A hub can be briefly unavailable (block-boundary handoff or meeting reset)
    // — the class must keep the connecting layer and reconnect on its own.
    expect(html).toContain('scheduleJoinRetry');
    expect(html).toContain('retryStatusForElapsed');
    expect(html).toContain('joinAttempts');
    // The join-failure path retries rather than showing a terminal join error.
    expect(html).toContain('Transient hub unavailability');
  });

  test('Zoom active-browser concurrency errors ask older classroom tabs to leave before retrying', () => {
    expect(html).toContain('isConcurrentHostMeetingError');
    expect(html).toContain("code === '3000'");
    expect(html).toContain('already has other meetings in progress');
    expect(html).toContain('attemptedActiveMeetingRecovery');
    expect(html).toContain('announceZoomSession');
    expect(html).toContain('retrying after closing older classroom tabs');
  });

  test('Zoom join attempts time out instead of leaving the classroom stuck connecting', () => {
    expect(html).toContain('joinAttemptTimeoutMs');
    expect(html).toContain('joinTimeoutError');
    expect(html).toContain('JOIN_TIMEOUT');
    expect(html).toContain('Zoom join timed out');
    expect(html).toContain('finishJoinAttempt(() => handleJoinFailure(joinTimeoutError(), true))');
    expect(html).toContain('success: () => finishJoinAttempt(onJoinSuccess)');
    expect(html).toContain('error: (error) => finishJoinAttempt(() => handleJoinFailure(error))');
  });

  test('new classroom tabs ask older Zoom web tabs to leave before retrying Code 3000', () => {
    expect(html).toContain('alluwal_zoom_meeting_session');
    expect(html).toContain('alluwal-zoom-meeting-session');
    expect(html).toContain('BroadcastChannel');
    expect(html).toContain('handleCompetingZoomSession');
    expect(html).toContain('announceZoomSession');
    expect(html).toContain('attemptedActiveMeetingRecovery');
    expect(html).toContain('retrying after closing older classroom tabs');
    expect(html).toContain('setTimeout(() => {');
    expect(html).toContain('}, 1600)');
  });

  test('controlled leave meeting button is kept separate from Zoom leave room', () => {
    expect(html).toContain('leaveMeetingButton');
    expect(html).toContain('leaveMeetingText');
    expect(html).toContain('ZoomMtg.leaveMeeting');
    expect(html).toContain('Leave (?:Breakout )?Room');
    const breakoutControlLine = html
      .split('\n')
      .find((line) => line.includes('Breakout\\s*Rooms?|Close All Rooms'));
    expect(breakoutControlLine).toContain('Leave (?:Breakout )?Room');
    expect(breakoutControlLine).not.toContain('Leave Meeting');
  });

  test('breakout room matching uses exact name or clicked shift key, not fuzzy prefix matching', () => {
    expect(html).toContain("params.get('breakoutRoomKey')");
    expect(html).toContain('normalizeRoomName');
    expect(html).toContain('normalizedShortKeyPrefix');
    expect(html).not.toContain('target.startsWith(display)');
    expect(html).not.toContain('display.startsWith(target)');
  });

  test('breakout dialog matcher uses whitespace regex, not a literal backslash', () => {
    expect(html).toContain('Breakout Rooms\\s*(-|–)\\s*In Progress');
    expect(html).not.toContain('Breakout Rooms\\\\s*(-|–)\\\\s*In Progress');
  });
});
