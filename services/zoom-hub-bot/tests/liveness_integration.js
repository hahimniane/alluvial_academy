'use strict';

/**
 * Liveness checked against a real Chromium page, not a fake one.
 *
 * `tests/liveness.test.js` drives liveness.js with stubs, so it proves the
 * arithmetic but not the thing that actually took lanes down: a renderer whose
 * main thread has stopped while the page object stays open. This drives the
 * browser the bot drives, wedges it the way the frozen Zoom SDK wedges it, and
 * checks the real code notices.
 *
 * It launches a browser and takes ~25s, so it is deliberately outside `npm test`:
 *
 *     node tests/liveness_integration.js
 *
 * Run it on the VPS after deploying bot.js, where the installed Chromium is the
 * one that will actually host classes.
 */

const path = require('path');
const { chromium } = require('playwright');
const liveness = require(path.join(__dirname, '..', 'liveness'));

const results = [];
function check(name, passed, detail) {
  results.push({ name, passed });
  console.log(`${passed ? 'PASS' : 'FAIL'}  ${name}${detail ? ` — ${detail}` : ''}`);
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

/** A page shaped like a hub session: it chatters on the console, and node listens. */
async function newHubLikePage(browser) {
  const context = await browser.newContext({ viewport: { width: 640, height: 480 } });
  const page = await context.newPage();
  const session = { context, page, lastPageActivityAt: Date.now() };
  page.on('console', () => {
    session.lastPageActivityAt = Date.now();
  });
  await page.goto('about:blank');
  // The controller logs a routing snapshot every ~17s; 400ms keeps this short.
  await page.evaluate(() => {
    window.__beat = setInterval(() => console.log('routing snapshot'), 400);
  });
  return session;
}

(async () => {
  const browser = await chromium.launch({
    headless: true,
    args: ['--disable-background-timer-throttling', '--disable-dev-shm-usage'],
  });

  // A working page keeps stamping activity and answers at once.
  const healthy = await newHubLikePage(browser);
  await sleep(1500);
  check(
    'healthy page keeps stamping lastPageActivityAt',
    Date.now() - healthy.lastPageActivityAt < 1000,
  );
  check(
    'healthy page is not judged silent',
    liveness.isPageSilent(healthy.lastPageActivityAt, Date.now(), 1000) === false,
  );
  const healthyStart = Date.now();
  check(
    'healthy page answers the probe',
    (await liveness.pageResponds(() => healthy.page.evaluate(() => Date.now()), 5000)) === true,
    `answered in ${Date.now() - healthyStart}ms`,
  );

  // A page that has merely gone quiet must be kept: silence alone is not a fault.
  const quiet = await newHubLikePage(browser);
  await quiet.page.evaluate(() => clearInterval(window.__beat));
  await sleep(1500);
  check(
    'quiet page is judged silent',
    liveness.isPageSilent(quiet.lastPageActivityAt, Date.now(), 1000) === true,
  );
  check(
    'quiet but living page answers the probe, so it is kept',
    (await liveness.pageResponds(() => quiet.page.evaluate(() => Date.now()), 5000)) === true,
  );

  // The production failure: the renderer's main thread never comes back.
  const hung = await newHubLikePage(browser);
  hung.page
    .evaluate(() => {
      setTimeout(() => {
        for (;;) {
          /* main thread wedged, as it is when the Zoom SDK dies */
        }
      }, 0);
    })
    .catch(() => {});
  await sleep(2500);

  check(
    'hung page stops producing console output',
    liveness.isPageSilent(hung.lastPageActivityAt, Date.now(), 1000) === true,
    `silent ${Date.now() - hung.lastPageActivityAt}ms`,
  );

  // Why the probe has to be raced: on its own it never comes back at all.
  let bareEvaluateSettled = false;
  hung.page
    .evaluate(() => Date.now())
    .then(
      () => {
        bareEvaluateSettled = true;
      },
      () => {
        bareEvaluateSettled = true;
      },
    );
  await sleep(6000);
  check(
    'a bare page.evaluate() never settles on a hung renderer',
    bareEvaluateSettled === false,
    'this is why pageResponds races it against a timer',
  );

  const probeStart = Date.now();
  const hungResponds = await liveness.pageResponds(
    () => hung.page.evaluate(() => Date.now()),
    5000,
  );
  const probeMs = Date.now() - probeStart;
  check('hung page does not answer the probe', hungResponds === false);
  check(
    'the probe gives up on schedule instead of hanging with the page',
    probeMs >= 4800 && probeMs < 7000,
    `${probeMs}ms against a 5000ms budget`,
  );

  // Recycling has to work on a page that answers nothing.
  await Promise.race([hung.context.close(), sleep(15000)]).catch(() => {});
  check('context.close() tears down a hung page', hung.page.isClosed() === true);

  // The rejoin hold, so a recycled hub does not put two hosts in one meeting.
  const blocked = new Map();
  const t0 = Date.now();
  liveness.blockRejoin(blocked, 'hub_test', t0, 150000);
  check('rejoin is blocked right after a recycle', liveness.isRejoinBlocked(blocked, 'hub_test', t0) === true);
  check(
    'rejoin still blocked at 149s, while the ghost host lingers',
    liveness.isRejoinBlocked(blocked, 'hub_test', t0 + 149000) === true,
  );
  check('rejoin allowed at 151s', liveness.isRejoinBlocked(blocked, 'hub_test', t0 + 151000) === false);
  check('an unrelated hub is never blocked', liveness.isRejoinBlocked(blocked, 'other_hub', t0) === false);

  // A dead renderer does not close the page, so bot.js listens for the crash.
  const crashy = await newHubLikePage(browser);
  let crashFired = false;
  crashy.page.on('crash', () => {
    crashFired = true;
  });
  crashy.page.goto('chrome://crash').catch(() => {});
  await sleep(4000);
  check("renderer crash fires page.on('crash')", crashFired === true);
  await Promise.race([crashy.context.close(), sleep(5000)]).catch(() => {});

  // Defaults are the runbook's numbers (docs/zoom-hub-bot-plan.md §20).
  check('silence threshold defaults to 3 min', liveness.DEFAULT_PAGE_SILENCE_MS === 180000);
  check('ghost host hold defaults to 150s', liveness.DEFAULT_GHOST_HOST_CLEAR_MS === 150000);

  await healthy.context.close().catch(() => {});
  await quiet.context.close().catch(() => {});
  await browser.close();

  const failed = results.filter((result) => !result.passed);
  console.log(`\n${results.length - failed.length}/${results.length} checks passed`);
  for (const failure of failed) console.log(`  failed: ${failure.name}`);
  process.exit(failed.length ? 1 : 0);
})().catch((error) => {
  console.error('harness error:', error);
  process.exit(2);
});
