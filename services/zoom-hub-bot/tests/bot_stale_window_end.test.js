const fs = require('fs');
const path = require('path');

/**
 * A hub's window end is not fixed: a rolling segment grows as later classes
 * merge into it. The bot judges "expired" by the window end it remembers, so
 * a page that keeps the end it joined with leaves the hub a minute after that
 * stale end and rejoins on the next poll — and the rejoin re-opens the rooms,
 * throwing every class in progress back to the main room (Oct 11 and Oct 14
 * 2026, 7:16 PM and 8:16 PM, one minute after each superseded window end).
 *
 * `bot.js` is a script with no exports, so this reads the source, like the
 * handover test does.
 */
describe('a running hub keeps its window end current', () => {
  const source = fs.readFileSync(path.join(__dirname, '..', 'bot.js'), 'utf8');
  const startHub = source.slice(
    source.indexOf('async function startHub(directive)'),
    source.indexOf('async function leaveSession'),
  );

  test('an already-running hub refreshes windowEnd from the directive instead of being ignored', () => {
    expect(startHub).not.toContain('if (sessions.has(directive.hubDocId)) return;');
    const refresh = startHub.indexOf('running.windowEnd = new Date(directive.windowEnd).getTime()');
    const firstReturn = startHub.indexOf('return;');
    expect(refresh).toBeGreaterThan(-1);
    expect(refresh).toBeLessThan(firstReturn);
  });

  test('expiry is still judged by session.windowEnd, so the refresh is what prevents the leave', () => {
    expect(source).toContain('const expired = session.windowEnd && session.windowEnd + 60000 < now;');
  });
});
