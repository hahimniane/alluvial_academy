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
    expect(html).toContain('setStatus(formatZoomError(joinErrorText, error))');
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
