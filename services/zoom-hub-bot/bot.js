const path = require('path');
const { pathToFileURL } = require('url');
const { chromium } = require('playwright');

const lane = Number(process.env.ZOOM_HUB_LANE || process.argv[2] || 0);
const functionBaseUrl = String(process.env.ZOOM_HUB_FUNCTION_BASE_URL || '').replace(/\/+$/, '');
const botKey = String(process.env.ZOOM_HUB_BOT_KEY || '');
const pollMs = Number(process.env.ZOOM_HUB_BOT_POLL_MS || 30000);
const headless = String(process.env.ZOOM_HUB_BOT_HEADLESS || 'true') !== 'false';

if (!Number.isInteger(lane) || lane < 1) {
  throw new Error('Set ZOOM_HUB_LANE or pass lane number 1/2 as the first argument.');
}
if (!functionBaseUrl) {
  throw new Error('Set ZOOM_HUB_FUNCTION_BASE_URL, for example https://us-central1-alluwal-academy.cloudfunctions.net.');
}
if (!botKey) {
  throw new Error('Set ZOOM_HUB_BOT_KEY.');
}

let browser;
const sessions = new Map();

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function serializeError(error) {
  if (!error) return '';
  if (typeof error === 'string') return error;
  if (error instanceof Error) {
    return JSON.stringify({
      name: error.name,
      message: error.message,
      stack: error.stack,
    });
  }
  try {
    return JSON.stringify(error);
  } catch (_) {
    return String(error);
  }
}

async function fetchJson(pathname, options = {}) {
  const response = await fetch(`${functionBaseUrl}${pathname}`, {
    ...options,
    headers: {
      'x-bot-key': botKey,
      ...(options.body ? { 'content-type': 'application/json' } : {}),
      ...(options.headers || {}),
    },
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok || body.success === false) {
    throw new Error(body.error || `Request failed with HTTP ${response.status}`);
  }
  return body;
}

function controllerUrl(directive) {
  const url = new URL(pathToFileURL(path.join(__dirname, 'bot_controller.html')).href);
  const params = url.searchParams;
  params.set('functionBaseUrl', functionBaseUrl);
  params.set('botKey', botKey);
  params.set('lane', String(lane));
  params.set('hubDocId', directive.hubDocId);
  params.set('sdkKey', directive.sdkKey);
  params.set('signature', directive.signatureRole1);
  params.set('meetingNumber', directive.meetingNumber);
  params.set('password', directive.password || '');
  params.set('zak', directive.zak);
  params.set('hostAccount', directive.hostAccount || '');
  params.set('rooms', JSON.stringify(directive.rooms || []));
  params.set('boIdByRoomName', JSON.stringify(directive.boIdByRoomName || {}));
  params.set('windowEnd', directive.windowEnd || '');
  return url.href;
}

async function ensureBrowser() {
  if (browser && browser.isConnected()) return browser;
  browser = await chromium.launch({
    headless,
    args: [
      '--autoplay-policy=no-user-gesture-required',
      '--disable-background-timer-throttling',
      '--disable-dev-shm-usage',
      '--use-fake-ui-for-media-stream',
      '--use-fake-device-for-media-stream',
      '--window-size=640,480',
    ],
  });
  return browser;
}

async function startHub(directive) {
  if (sessions.has(directive.hubDocId)) return;
  const activeBrowser = await ensureBrowser();
  const context = await activeBrowser.newContext({
    viewport: { width: 640, height: 480 },
    permissions: ['camera', 'microphone'],
  });
  const page = await context.newPage();
  page.on('console', (message) => {
    const text = message.text();
    console.log(`[lane ${lane}] [${directive.hubDocId}] ${message.type()}: ${text}`);
  });
  page.on('pageerror', async (error) => {
    console.error(`[lane ${lane}] [${directive.hubDocId}] page error: ${serializeError(error)}`);
    sessions.delete(directive.hubDocId);
    try {
      await context.close();
    } catch (_) {}
  });
  page.on('close', () => {
    sessions.delete(directive.hubDocId);
  });

  sessions.set(directive.hubDocId, {
    context,
    page,
    windowEnd: directive.windowEnd ? new Date(directive.windowEnd).getTime() : null,
  });

  await page.goto(controllerUrl(directive), { waitUntil: 'domcontentloaded', timeout: 60000 });
  console.log(`[lane ${lane}] started hub ${directive.hubDocId}`);
}

async function leaveSession(session) {
  if (!session || !session.page) return;
  try {
    await session.page.evaluate(() => new Promise((resolve) => {
      const zoom = window.ZoomMtg;
      if (!zoom || typeof zoom.leaveMeeting !== 'function') {
        resolve();
        return;
      }
      try {
        zoom.leaveMeeting({
          success: resolve,
          error: resolve,
        });
      } catch (_) {
        resolve();
      }
    }));
  } catch (_) {}
}

async function closeExpiredSessions(activeIds) {
  const now = Date.now();
  for (const [hubDocId, session] of sessions.entries()) {
    const expired = session.windowEnd && session.windowEnd + 60000 < now;
    const inactive = !activeIds.has(hubDocId);
    if (!expired && !inactive) continue;
    await leaveSession(session);
    try {
      await session.context.close();
    } catch (error) {
      console.warn(
        `[lane ${lane}] failed to close ${expired ? 'expired' : 'inactive'} hub ${hubDocId}:`,
        error.message || error,
      );
    }
    sessions.delete(hubDocId);
  }
}

async function shutdown() {
  for (const session of sessions.values()) {
    await leaveSession(session);
    try {
      await session.context.close();
    } catch (_) {}
  }
  sessions.clear();
  if (browser) await browser.close().catch(() => {});
}

async function runOnce() {
  const body = await fetchJson(`/zoomHubBotDirectives?lane=${encodeURIComponent(String(lane))}`);
  const directives = Array.isArray(body.directives) ? body.directives : [];
  const activeIds = new Set(directives.map((directive) => directive.hubDocId).filter(Boolean));

  for (const directive of directives) {
    if (!directive.hubDocId || !directive.meetingNumber || !directive.sdkKey || !directive.signatureRole1) {
      continue;
    }
    await startHub(directive);
  }

  await closeExpiredSessions(activeIds);
}

async function main() {
  process.on('SIGTERM', async () => {
    await shutdown();
    process.exit(0);
  });
  process.on('SIGINT', async () => {
    await shutdown();
    process.exit(0);
  });

  while (true) {
    try {
      await runOnce();
    } catch (error) {
      console.error(`[lane ${lane}] loop failed:`, error.message || error);
    }
    await sleep(pollMs);
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
