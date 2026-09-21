const fs = require('fs');
const path = require('path');

/**
 * The order of two calls in `runOnce`, which is not a detail.
 *
 * A lane is one Zoom host account and a Zoom host can run only one meeting. So
 * a handover has to let go of the old hub before it claims the new one. Done
 * the other way round, Zoom refuses the join with errorCode 3000 ("Already has
 * other meetings in progress"), the bot retries every 31 seconds, and each
 * retry that eventually succeeds re-opens the breakout rooms — throwing the
 * class that is sitting in them back out, teacher and student together.
 *
 * `bot.js` is a script with no exports, so this reads the source. Crude, but it
 * pins the one thing that must not be reordered, and it fails if it is.
 */
describe('handing a lane over between hubs', () => {
  const source = fs.readFileSync(path.join(__dirname, '..', 'bot.js'), 'utf8');
  const runOnce = source.slice(
    source.indexOf('async function runOnce()'),
    source.indexOf('async function main()'),
  );

  test('runOnce is where the handover happens', () => {
    expect(runOnce).toContain('closeExpiredSessions(activeIds)');
    expect(runOnce).toContain('await startHub(directive)');
  });

  test('the old hub is released before the new one is joined', () => {
    const closeAt = runOnce.indexOf('await closeExpiredSessions(activeIds)');
    const startAt = runOnce.indexOf('await startHub(directive)');
    expect(closeAt).toBeGreaterThan(-1);
    expect(startAt).toBeGreaterThan(-1);
    expect(closeAt).toBeLessThan(startAt);
  });

  test('the reason is written down where it would be reordered', () => {
    expect(runOnce).toContain('Already has other meetings in progress');
  });
});
