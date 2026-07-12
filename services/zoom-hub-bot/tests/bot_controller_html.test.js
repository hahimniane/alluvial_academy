const fs = require('fs');
const path = require('path');

describe('bot_controller.html', () => {
  const htmlPath = path.join(__dirname, '..', 'bot_controller.html');
  const html = fs.readFileSync(htmlPath, 'utf8');
  const inlineScripts = [...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)]
    .map((match) => match[1]);

  test('inline scripts parse', () => {
    expect(inlineScripts.length).toBeGreaterThan(0);
    for (const script of inlineScripts) {
      expect(() => new Function(script)).not.toThrow();
    }
  });

  test('opens breakout rooms with auto-routing options', () => {
    expect(html).toContain('isAutoJoinRoom: true');
    expect(html).toContain('isBackToMainSessionEnabled: false');
    expect(html).toContain('needCountDown: false');
    expect(html).toContain("zoomCall('openBreakoutRooms', { options: desiredRoomOptions })");
  });

  test('reports live room count and in-room occupancy for the backend watcher', () => {
    expect(html).toContain('liveRoomCount');
    expect(html).toContain('inRoomOccupants');
    expect(html).toContain('inRoomParticipantCount');
  });

  test('reports live participants by shift for the admin presence display', () => {
    expect(html).toContain('buildLiveParticipantsByShift');
    expect(html).toContain('liveParticipantsByShift');
    expect(html).toContain("Object.prototype.hasOwnProperty.call(extra || {}, 'liveParticipantsByShift')");
    expect(html).toContain('body.liveParticipantsByShift = extra.liveParticipantsByShift || {}');
    expect(html).toContain("source: 'zoom_hub_bot'");
  });

  test('self-heals an empty breakout room list during the routing loop', () => {
    // A hub whose getBreakoutRooms() reads empty cannot route anyone; the bot
    // must repair it mid-loop, not only at join.
    expect(html).toContain('Self-heal');
    expect(html).toContain('burstReadBreakoutRooms');
    expect(html).toContain('healThrottleMs');
    expect(html).toContain('ensureRoomsOpen()');
  });

  test('only reopens rooms when no participant is inside a room', () => {
    // Closing/reopening must never disrupt a live class; it is gated on in-room
    // occupancy (a waiter in the main session is safe to reopen around).
    expect(html).toContain('function isSafeToReopen');
    expect(html).toContain('inRoomParticipantCount(state) > 0');
    expect(html).toContain('lastKnownInRoomCount');
    expect(html).toContain('roomsCreatedFresh');
  });

  test('escalates to a meeting reset when in-place recovery is exhausted', () => {
    // A corrupted meeting instance cannot be repaired in place; after repeated
    // failed heals the bot asks the backend to end it and reloads to rejoin.
    expect(html).toContain('healFailuresBeforeReset');
    expect(html).toContain('consecutiveHealFailures');
    expect(html).toContain("postState('resetMeeting'");
    expect(html).toContain('resetRequested');
    expect(html).toContain("triggerRejoin('self_heal_exhausted')");
  });

  test('reloads to rejoin on a backend force-rejoin signal, capped against loops', () => {
    // Zombie recovery: backend stamps forceRejoinAt; the bot reloads into a
    // fresh instance, but only when no one is inside a room, and with a cap.
    expect(html).toContain('triggerRejoin = (reason)');
    expect(html).toContain('window.location.reload()');
    expect(html).toContain('assignments.forceRejoinAt');
    expect(html).toContain('forceRejoinAt > pageLoadedAt');
    expect(html).toContain('alluwal_rejoin_count');
  });
});
