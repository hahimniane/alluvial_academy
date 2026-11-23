const fs = require('fs');
const path = require('path');

/**
 * bot.js has no exports, so like the handover test this reads the source and
 * pins the wiring that makes a dead Zoom connection cost seconds, not minutes.
 */
describe('fast recovery wiring in bot.js', () => {
  const source = fs.readFileSync(path.join(__dirname, '..', 'bot.js'), 'utf8');
  const html = fs.readFileSync(path.join(__dirname, '..', 'bot_controller.html'), 'utf8');

  test('the page verdict recycles the page at once', () => {
    expect(source).toContain('text.includes(sdkHealth.DEAD_MARKER)');
    expect(source).toMatch(/DEAD_MARKER\)[\s\S]{0,400}recycleSession\(directive\.hubDocId, why\)/);
  });

  test('a recycle holds only the short minimum and passes the 150s cap to the page', () => {
    const recycle = source.slice(source.indexOf('async function recycleSession'), source.indexOf('async function retryJoinSoon'));
    expect(recycle).toContain('liveness.blockRejoin(rejoinBlockedUntil, hubDocId, recycledAt, ghostHostMinMs)');
    expect(recycle).toContain('oldHostDeadlineByHub.set(hubDocId, recycledAt + ghostHostClearMs)');
    expect(source).toContain("params.set('oldHostDeadline'");
    expect(html).toContain("oldHostDeadline: Number(params.get('oldHostDeadline'))");
  });

  test('the page keeps rooms shut until the old host session is gone, before opening them', () => {
    const join = html.slice(html.indexOf('success: async () => {'), html.indexOf('error: async (error) => {'));
    expect(join.indexOf('await waitForOldHostSession()')).toBeGreaterThan(-1);
    expect(join.indexOf('await waitForOldHostSession()')).toBeLessThan(join.indexOf('await ensureRoomsOpen()'));
  });

  test('a refused join is retried without throwing, and never opens rooms', () => {
    expect(html).toContain("const JOIN_REFUSED_MARKER = 'Zoom join refused:'");
    expect(source).toContain("const JOIN_REFUSED_MARKER = 'Zoom join refused:'");
    const joinError = html.slice(html.indexOf("setStatus('Zoom join failed')"), html.indexOf("setStatus('Zoom init failed')"));
    expect(joinError).not.toContain('throw error');
    expect(joinError).not.toContain('ensureRoomsOpen');
  });

  test('a page error after the join goes through the recycle path; before it, a quick retry', () => {
    const handler = source.slice(source.indexOf("page.on('pageerror'"), source.indexOf("page.on('close'"));
    expect(handler).toContain('if (session.joined)');
    expect(handler).toContain('recycleSession(directive.hubDocId');
    expect(handler).toContain('retryJoinSoon(directive.hubDocId');
  });

  test('the main loop wakes for a held hub instead of sleeping a full poll', () => {
    expect(source).toContain('await sleep(liveness.nextPollDelay(rejoinBlockedUntil, Date.now(), pollMs))');
  });

  test('backend calls have deadlines on both sides', () => {
    expect(source).toContain('signal: AbortSignal.timeout(fetchTimeoutMs)');
    expect(html).toContain('controller.abort()');
  });

  test('every Zoom call has a deadline and reports to the health tracker', () => {
    const zoomCall = html.slice(html.indexOf('function zoomCall(method, args, timeoutMs)'), html.indexOf('function noteZoomOutcome'));
    expect(zoomCall).toContain('setTimeout(');
    expect(zoomCall).toContain("settle('timeout'");
    expect(zoomCall).toContain('noteZoomOutcome(method, outcome');
    expect(html).toContain('<script src="sdk_health.js"></script>');
    expect(source).toContain("'sdk_health.js'");
  });

  test('the routing loop stops acting once the connection is declared dead', () => {
    expect(html).toContain('while (!leaving && !connectionDead)');
  });
});
