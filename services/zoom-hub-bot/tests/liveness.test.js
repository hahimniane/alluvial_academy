const {
  DEFAULT_PAGE_SILENCE_MS,
  DEFAULT_GHOST_HOST_CLEAR_MS,
  positiveNumber,
  isPageSilent,
  routingHealth,
  pageResponds,
  blockRejoin,
  isRejoinBlocked,
} = require('../liveness');

describe('isPageSilent', () => {
  const now = 1_000_000_000;

  test('a page logging at its normal ~17s cadence is not silent', () => {
    expect(isPageSilent(now - 17_000, now)).toBe(false);
    expect(isPageSilent(now - 60_000, now)).toBe(false);
  });

  test('a page quiet for longer than the threshold is silent', () => {
    expect(isPageSilent(now - DEFAULT_PAGE_SILENCE_MS - 1, now)).toBe(true);
    // Tonight's zombie: silent from 18:24:45 until a person restarted it at 19:06.
    expect(isPageSilent(now - 41 * 60 * 1000, now)).toBe(true);
  });

  test('exactly at the threshold is not yet silent', () => {
    expect(isPageSilent(now - DEFAULT_PAGE_SILENCE_MS, now)).toBe(false);
  });

  test('an unknown last-activity time never counts as silent', () => {
    expect(isPageSilent(undefined, now)).toBe(false);
    expect(isPageSilent(null, now)).toBe(false);
    expect(isPageSilent(Number.NaN, now)).toBe(false);
  });
});

describe('pageResponds', () => {
  test('a responsive page answers', async () => {
    await expect(pageResponds(async () => 42, 500)).resolves.toBe(true);
  });

  test('a frozen page that never settles is reported as not responding', async () => {
    await expect(pageResponds(() => new Promise(() => {}), 50)).resolves.toBe(false);
  });

  test('a probe that throws is reported as not responding', async () => {
    await expect(pageResponds(async () => { throw new Error('Target closed'); }, 500)).resolves.toBe(false);
    await expect(pageResponds(() => { throw new Error('sync throw'); }, 500)).resolves.toBe(false);
  });
});

describe('rejoin hold after recycling a page', () => {
  test('the hub is held back for the ghost-host window, then released', () => {
    const blocked = new Map();
    const t0 = 5_000_000;
    blockRejoin(blocked, 'hub_a', t0);

    expect(isRejoinBlocked(blocked, 'hub_a', t0 + 1)).toBe(true);
    expect(isRejoinBlocked(blocked, 'hub_a', t0 + DEFAULT_GHOST_HOST_CLEAR_MS - 1)).toBe(true);
    expect(isRejoinBlocked(blocked, 'hub_a', t0 + DEFAULT_GHOST_HOST_CLEAR_MS)).toBe(false);
    expect(blocked.has('hub_a')).toBe(false);
  });

  test('holding one hub does not hold another', () => {
    const blocked = new Map();
    blockRejoin(blocked, 'hub_a', 0);
    expect(isRejoinBlocked(blocked, 'hub_b', 1)).toBe(false);
  });
});

describe('positiveNumber', () => {
  test('uses a valid override and falls back otherwise', () => {
    expect(positiveNumber('240000', 1)).toBe(240000);
    expect(positiveNumber('', 7)).toBe(7);
    expect(positiveNumber('0', 7)).toBe(7);
    expect(positiveNumber('-5', 7)).toBe(7);
    expect(positiveNumber('abc', 7)).toBe(7);
  });
});

describe('routingHealth', () => {
  const MINUTE = 60 * 1000;

  test('a page that has never routed is judged on its output, not on routing', () => {
    // Still joining and building its rooms: it has no routing to show yet, and
    // tearing it down for that would kill every hub during startup.
    const joining = { lastPageActivityAt: 1000, lastRoutingAt: null };
    expect(routingHealth(joining, 1000 + 10 * 1000, 3 * MINUTE)).toEqual({
      established: false, silent: false, silentForMs: 10 * 1000,
    });
    expect(routingHealth(joining, 1000 + 4 * MINUTE, 3 * MINUTE).silent).toBe(true);
  });

  test('a routing page is healthy', () => {
    const healthy = { lastPageActivityAt: 5000, lastRoutingAt: 5000 };
    const health = routingHealth(healthy, 5000 + 20 * 1000, 3 * MINUTE);
    expect(health.established).toBe(true);
    expect(health.silent).toBe(false);
  });

  test('a page still logging but no longer routing is caught', () => {
    // 2026-09-11 lane 1: the routing loop died at 22:27 while the SDK went on
    // printing errors until 23:00. Watching output alone called that healthy,
    // and the lane served nobody for two and a half hours.
    const now = 100 * MINUTE;
    const stillTalking = {
      lastRoutingAt: now - 30 * MINUTE,
      lastPageActivityAt: now - 5 * 1000,
    };
    const health = routingHealth(stillTalking, now, 3 * MINUTE);
    expect(health.established).toBe(true);
    expect(health.silent).toBe(true);
    expect(Math.round(health.silentForMs / MINUTE)).toBe(30);
    // The guard that matters: watching output alone still calls this healthy.
    expect(isPageSilent(stillTalking.lastPageActivityAt, now, 3 * MINUTE)).toBe(false);
  });

  test('a session with no timestamps at all is never torn down', () => {
    expect(routingHealth({}, 1000, 3 * MINUTE)).toEqual({
      established: false, silent: false, silentForMs: 0,
    });
  });
});
