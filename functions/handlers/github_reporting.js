const admin = require('firebase-admin');
const crypto = require('crypto');
const {onSchedule} = require('firebase-functions/v2/scheduler');

const GITHUB_ACTIVITY_COLLECTION = 'github_activity_events';
const AUTOMATION_RUNS_COLLECTION = 'automation_runs';

const DEFAULT_TEMPLATE_ID = 'cto_weekly_engineering_report';
const DEFAULT_REPORTER_NAME = 'Hassimiou Niane';
const DEFAULT_REPORTER_EMAIL = 'hassimiou.niane@maine.edu';
const DEFAULT_AUTHOR_EMAILS = [
  'hassimiou.niane@maine.edu',
  'hassimiou@hotmail.com',
];
const DEFAULT_AUTHOR_USERNAMES = [
  'hahimniane',
  'hashimniane',
];

function normalizeString(value) {
  return String(value || '').trim();
}

function normalizeLower(value) {
  return normalizeString(value).toLowerCase();
}

function normalizeListEnv(value, fallback = []) {
  const raw = normalizeString(value);
  if (!raw) return [...fallback];
  return raw
    .split(',')
    .map((item) => normalizeLower(item))
    .filter(Boolean);
}

function unique(values) {
  return [...new Set(values.filter(Boolean))];
}

function naturalJoin(values) {
  const items = unique(values);
  if (items.length === 0) return '';
  if (items.length === 1) return items[0];
  if (items.length === 2) return `${items[0]} and ${items[1]}`;
  return `${items.slice(0, -1).join(', ')}, and ${items[items.length - 1]}`;
}

function toDate(value) {
  if (!value) return null;
  if (value instanceof Date) return value;
  if (typeof value?.toDate === 'function') return value.toDate();
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function parseJsonBody(body) {
  if (!body) return {};
  if (typeof body === 'string') {
    try {
      return JSON.parse(body);
    } catch (_) {
      return {};
    }
  }
  return body;
}

function compareSecrets(expected, provided) {
  if (!expected) return true;
  const left = Buffer.from(expected);
  const right = Buffer.from(provided || '');
  if (left.length !== right.length) return false;
  return crypto.timingSafeEqual(left, right);
}

function normalizeBranch(ref) {
  const value = normalizeString(ref);
  if (value.startsWith('refs/heads/')) {
    return value.slice('refs/heads/'.length);
  }
  return value;
}

function humanizeToken(value) {
  const normalized = normalizeString(value)
    .replace(/[_-]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  if (!normalized) return '';
  return normalized.replace(/\b\w/g, (char) => char.toUpperCase());
}

function describeChangedPath(filePath) {
  const normalized = normalizeString(filePath).replace(/\\/g, '/');
  if (!normalized) return '';

  const parts = normalized.split('/').filter(Boolean);
  if (parts[0] === 'lib' && parts[1] === 'features' && parts[2]) {
    const feature = normalizeLower(parts[2]);
    if (feature === 'parent') return 'parent and billing experience';
    if (feature === 'dashboard') return 'dashboard updates';
    if (feature === 'chat') return 'chat features';
    if (feature === 'livekit') return 'LiveKit improvements';
    if (feature === 'settings') return 'settings and configuration';
    return `${humanizeToken(feature)} feature work`;
  }

  if (parts[0] === 'functions' && parts[1] === 'handlers' && parts[2]) {
    const handlerName = parts[2].replace(/\.js$/, '');
    if (handlerName === 'payments') return 'payments backend';
    if (handlerName === 'invoice_access') return 'invoice access control';
    return `${humanizeToken(handlerName)} backend`;
  }

  if (parts[0] === 'functions' && parts[1] === 'services' && parts[2]) {
    const serviceName = parts[2].replace(/\.js$/, '');
    return `${humanizeToken(serviceName)} service`;
  }

  if (parts[0] === 'functions' && parts[1] === 'dev-scripts') {
    return 'backend maintenance scripts';
  }

  if (parts[0] === 'scripts') return 'project scripts';
  if (parts[0] === 'web') return 'web app assets';
  if (parts[0] === 'android') return 'Android app setup';
  if (parts[0] === 'ios') return 'iOS app setup';

  return humanizeToken(parts[0]);
}

function extractFocusAreas(filePaths) {
  const counts = new Map();
  for (const filePath of filePaths || []) {
    const area = describeChangedPath(filePath);
    if (!area) continue;
    counts.set(area, (counts.get(area) || 0) + 1);
  }

  return [...counts.entries()]
    .sort((a, b) => {
      if (b[1] !== a[1]) return b[1] - a[1];
      return a[0].localeCompare(b[0]);
    })
    .map(([label]) => label);
}

function sanitizeCommitMessage(message) {
  return normalizeString(message).split(/\r?\n/, 1)[0].replace(/\s+/g, ' ');
}

function isUsefulCommitMessage(message) {
  const normalized = normalizeLower(message);
  if (!normalized) return false;
  if (normalized.startsWith('merge pull request')) return false;
  if (normalized.startsWith('merge branch')) return false;
  return true;
}

function getConfig() {
  return {
    sharedSecret: normalizeString(process.env.GITHUB_REPORT_SHARED_SECRET),
    templateId:
      normalizeString(process.env.CTO_REPORT_TEMPLATE_ID) || DEFAULT_TEMPLATE_ID,
    reporterName:
      normalizeString(process.env.CTO_REPORT_USER_NAME) || DEFAULT_REPORTER_NAME,
    reporterEmail:
      normalizeString(process.env.CTO_REPORT_USER_EMAIL) || DEFAULT_REPORTER_EMAIL,
    reporterUserId: normalizeString(process.env.CTO_REPORT_USER_ID),
    authorEmails: normalizeListEnv(
      process.env.CTO_REPORT_GITHUB_AUTHOR_EMAILS,
      DEFAULT_AUTHOR_EMAILS,
    ),
    authorUsernames: normalizeListEnv(
      process.env.CTO_REPORT_GITHUB_AUTHOR_USERNAMES,
      DEFAULT_AUTHOR_USERNAMES,
    ),
    repositoryAllowlist: normalizeListEnv(
      process.env.CTO_REPORT_GITHUB_REPOSITORIES,
      [],
    ),
  };
}

function matchesAllowedAuthor(commit, payload, config) {
  const authorEmail = normalizeLower(commit?.author?.email);
  const authorName = normalizeLower(commit?.author?.name);
  const senderLogin = normalizeLower(payload?.sender?.login);
  const pusherEmail = normalizeLower(payload?.pusher?.email);
  const pusherName = normalizeLower(payload?.pusher?.name);

  if (config.authorEmails.includes(authorEmail)) return true;
  if (config.authorEmails.includes(pusherEmail) && !authorEmail) return true;
  if (config.authorUsernames.includes(senderLogin) && !authorEmail) return true;
  if (config.authorUsernames.includes(authorName) && !authorEmail) return true;
  if (config.authorUsernames.includes(pusherName) && !authorEmail) return true;
  return false;
}

function sanitizeCommit(commit) {
  const message = sanitizeCommitMessage(commit?.message);
  const files = unique([
    ...(Array.isArray(commit?.added) ? commit.added : []),
    ...(Array.isArray(commit?.modified) ? commit.modified : []),
    ...(Array.isArray(commit?.removed) ? commit.removed : []),
  ]);

  return {
    id: normalizeString(commit?.id),
    message,
    url: normalizeString(commit?.url),
    timestamp: toDate(commit?.timestamp)?.toISOString() || null,
    authorName: normalizeString(commit?.author?.name),
    authorEmail: normalizeLower(commit?.author?.email),
    files,
  };
}

function buildEventDocId(payload) {
  const after = normalizeString(payload?.after);
  if (after) return after;
  const seed = JSON.stringify({
    repo: payload?.repository?.full_name,
    ref: payload?.ref,
    head: payload?.head_commit?.id,
    pushedAt: payload?.head_commit?.timestamp || new Date().toISOString(),
  });
  return crypto.createHash('sha1').update(seed).digest('hex');
}

function sanitizePushPayload(payload, config = getConfig()) {
  const parsed = payload || {};
  const repositoryFullName = normalizeString(parsed?.repository?.full_name);
  const repositoryName = normalizeString(parsed?.repository?.name);
  const branch = normalizeBranch(parsed?.ref);

  if (
    config.repositoryAllowlist.length > 0 &&
    !config.repositoryAllowlist.includes(normalizeLower(repositoryFullName))
  ) {
    return {skip: true, reason: 'repository_not_allowed'};
  }

  const relevantCommits = (Array.isArray(parsed?.commits) ? parsed.commits : [])
    .filter((commit) => matchesAllowedAuthor(commit, parsed, config))
    .map(sanitizeCommit)
    .filter((commit) => commit.id);

  if (relevantCommits.length === 0) {
    return {skip: true, reason: 'no_matching_commits'};
  }

  const changedFiles = unique(relevantCommits.flatMap((commit) => commit.files));
  const focusAreas = extractFocusAreas(changedFiles);

  const pushedAt =
    [...relevantCommits]
      .map((commit) => toDate(commit.timestamp))
      .filter(Boolean)
      .sort((a, b) => b.getTime() - a.getTime())[0] ||
    toDate(parsed?.head_commit?.timestamp) ||
    new Date();

  return {
    skip: false,
    docId: buildEventDocId(parsed),
    event: {
      source: 'github_push',
      repositoryFullName,
      repositoryName,
      branch,
      ref: normalizeString(parsed?.ref),
      before: normalizeString(parsed?.before),
      after: normalizeString(parsed?.after),
      compareUrl: normalizeString(parsed?.compare),
      senderLogin: normalizeString(parsed?.sender?.login),
      pusherName: normalizeString(parsed?.pusher?.name),
      pusherEmail: normalizeLower(parsed?.pusher?.email),
      pushedAt: admin.firestore.Timestamp.fromDate(pushedAt),
      commitIds: relevantCommits.map((commit) => commit.id),
      commits: relevantCommits,
      changedFiles,
      focusAreas,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  };
}

function startOfUtcDay(date) {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
}

function addUtcDays(date, days) {
  return new Date(date.getTime() + days * 24 * 60 * 60 * 1000);
}

function getPreviousWeeklyPeriod(referenceDate = new Date()) {
  const ref = startOfUtcDay(referenceDate);
  const weekday = ref.getUTCDay();
  const distanceToMonday = (weekday + 6) % 7;
  const currentWeekStart = addUtcDays(ref, -distanceToMonday);
  const periodEnd = currentWeekStart;
  const periodStart = addUtcDays(periodEnd, -7);
  return {periodStart, periodEnd};
}

function formatDateKey(date) {
  return date.toISOString().slice(0, 10);
}

function buildRunDocId({templateId, periodStart}) {
  return `${templateId}_${formatDateKey(periodStart)}`;
}

function splitName(fullName) {
  const parts = normalizeString(fullName).split(/\s+/).filter(Boolean);
  if (parts.length === 0) return {firstName: '', lastName: ''};
  if (parts.length === 1) return {firstName: parts[0], lastName: ''};
  return {
    firstName: parts[0],
    lastName: parts.slice(1).join(' '),
  };
}

function buildWeeklyWorkSummary(commits) {
  const changedFiles = unique(commits.flatMap((commit) => commit.files || []));
  const focusAreas = extractFocusAreas(changedFiles).slice(0, 6);
  const usefulMessages = unique(
    commits
      .map((commit) => sanitizeCommitMessage(commit.message))
      .filter(isUsefulCommitMessage),
  ).slice(0, 6);

  const lines = [];
  if (focusAreas.length > 0) {
    lines.push(`Worked mainly on ${naturalJoin(focusAreas)}.`);
  } else {
    lines.push('Worked mainly on software updates reflected in GitHub pushes.');
  }

  if (usefulMessages.length > 0) {
    lines.push('');
    lines.push('Recent focus:');
    for (const message of usefulMessages) {
      lines.push(`- ${message}`);
    }
  }

  return lines.join('\n').trim();
}

function buildFormSubmission({
  templateId,
  formName,
  reporter,
  periodStart,
  periodEnd,
  workSummary,
  eventDocIds,
  commitIds,
}) {
  const {firstName, lastName} = splitName(reporter.name);
  const reportingDate = addUtcDays(periodEnd, -1);
  const yearMonth = reportingDate.toISOString().slice(0, 7);

  return {
    formId: templateId,
    templateId,
    formName,
    formTitle: formName,
    formType: 'weekly',
    frequency: 'weekly',
    userId: reporter.uid,
    submittedBy: reporter.uid,
    teacherId: reporter.uid,
    teacher_id: reporter.uid,
    userEmail: reporter.email,
    firstName,
    lastName,
    userFirstName: firstName,
    userLastName: lastName,
    responses: {
      reporter_name: reporter.name,
      work_summary: workSummary,
      follow_up: '',
    },
    status: 'completed',
    submittedAt: admin.firestore.FieldValue.serverTimestamp(),
    lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    yearMonth,
    automationSource: 'github_weekly_cto_report',
    reportingPeriodStart: periodStart.toISOString(),
    reportingPeriodEnd: periodEnd.toISOString(),
    githubEventIds: eventDocIds,
    githubCommitIds: commitIds,
  };
}

async function resolveReporter(db, config) {
  if (config.reporterUserId) {
    const byIdDoc = await db.collection('users').doc(config.reporterUserId).get();
    if (!byIdDoc.exists) {
      throw new Error(`Reporter user not found by ID: ${config.reporterUserId}`);
    }
    const data = byIdDoc.data() || {};
    return {
      uid: byIdDoc.id,
      email:
        normalizeString(data['e-mail']) ||
        normalizeString(data.email) ||
        config.reporterEmail,
      name:
        normalizeString(`${data.first_name || ''} ${data.last_name || ''}`) ||
        config.reporterName,
    };
  }

  let snap = await db.collection('users')
    .where('e-mail', '==', config.reporterEmail)
    .limit(1)
    .get();

  if (snap.empty) {
    snap = await db.collection('users')
      .where('email', '==', config.reporterEmail)
      .limit(1)
      .get();
  }

  if (snap.empty) {
    throw new Error(`Reporter user not found by email: ${config.reporterEmail}`);
  }

  const doc = snap.docs[0];
  const data = doc.data() || {};
  return {
    uid: doc.id,
    email:
      normalizeString(data['e-mail']) ||
      normalizeString(data.email) ||
      config.reporterEmail,
    name:
      normalizeString(`${data.first_name || ''} ${data.last_name || ''}`) ||
      config.reporterName,
  };
}

async function resolveTemplate(db, templateId) {
  const doc = await db.collection('form_templates').doc(templateId).get();
  if (!doc.exists) {
    throw new Error(`Template not found: ${templateId}`);
  }
  const data = doc.data() || {};
  if (data.isActive === false) {
    throw new Error(`Template is inactive: ${templateId}`);
  }
  return {
    id: doc.id,
    name: normalizeString(data.name) || 'CTO Weekly Engineering Report',
  };
}

function collectCommitsFromEvents(events) {
  const uniqueCommits = new Map();
  const eventIds = [];

  for (const event of events) {
    if (event?.id) eventIds.push(event.id);
    for (const commit of Array.isArray(event?.commits) ? event.commits : []) {
      const commitId = normalizeString(commit?.id);
      if (!commitId || uniqueCommits.has(commitId)) continue;
      uniqueCommits.set(commitId, {
        ...commit,
        files: Array.isArray(commit?.files) ? commit.files : [],
        message: sanitizeCommitMessage(commit?.message),
        timestamp: commit?.timestamp || null,
      });
    }
  }

  return {
    commits: [...uniqueCommits.values()].sort((a, b) => {
      const left = toDate(a.timestamp)?.getTime() || 0;
      const right = toDate(b.timestamp)?.getTime() || 0;
      return right - left;
    }),
    eventIds: unique(eventIds),
  };
}

async function generateWeeklyCtoReportForDate({
  db = admin.firestore(),
  referenceDate = new Date(),
  force = false,
  config = getConfig(),
}) {
  const period = getPreviousWeeklyPeriod(referenceDate);
  const runDocId = buildRunDocId({
    templateId: config.templateId,
    periodStart: period.periodStart,
  });
  const runRef = db.collection(AUTOMATION_RUNS_COLLECTION).doc(runDocId);
  const existingRun = await runRef.get();

  if (!force && existingRun.exists) {
    const existingData = existingRun.data() || {};
    if (existingData.status === 'submitted') {
      return {
        ok: true,
        skipped: true,
        reason: 'already_submitted',
        runDocId,
        formResponseId: existingData.formResponseId || null,
      };
    }
  }

  const [reporter, template] = await Promise.all([
    resolveReporter(db, config),
    resolveTemplate(db, config.templateId),
  ]);

  const eventsSnap = await db.collection(GITHUB_ACTIVITY_COLLECTION)
    .where('pushedAt', '>=', admin.firestore.Timestamp.fromDate(period.periodStart))
    .where('pushedAt', '<', admin.firestore.Timestamp.fromDate(period.periodEnd))
    .get();

  const events = eventsSnap.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
  }));
  const {commits, eventIds} = collectCommitsFromEvents(events);

  if (commits.length === 0) {
    await runRef.set({
      status: 'no_activity',
      templateId: template.id,
      reporterUserId: reporter.uid,
      reportingPeriodStart: period.periodStart.toISOString(),
      reportingPeriodEnd: period.periodEnd.toISOString(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});

    return {
      ok: true,
      skipped: true,
      reason: 'no_activity',
      runDocId,
    };
  }

  const workSummary = buildWeeklyWorkSummary(commits);
  const submission = buildFormSubmission({
    templateId: template.id,
    formName: template.name,
    reporter,
    periodStart: period.periodStart,
    periodEnd: period.periodEnd,
    workSummary,
    eventDocIds: eventIds,
    commitIds: commits.map((commit) => commit.id),
  });

  const formRef = await db.collection('form_responses').add(submission);

  await runRef.set({
    status: 'submitted',
    templateId: template.id,
    formResponseId: formRef.id,
    reporterUserId: reporter.uid,
    reportingPeriodStart: period.periodStart.toISOString(),
    reportingPeriodEnd: period.periodEnd.toISOString(),
    githubEventIds: eventIds,
    githubCommitIds: commits.map((commit) => commit.id),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});

  return {
    ok: true,
    skipped: false,
    runDocId,
    formResponseId: formRef.id,
    reportingPeriodStart: period.periodStart.toISOString(),
    reportingPeriodEnd: period.periodEnd.toISOString(),
  };
}

async function ingestGitHubActivity(req, res) {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, X-GitHub-Event, X-GitHub-Report-Secret');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({error: 'Method Not Allowed'});
    return;
  }

  const config = getConfig();
  const providedSecret = req.get('X-GitHub-Report-Secret');
  if (!compareSecrets(config.sharedSecret, providedSecret)) {
    res.status(401).json({error: 'Unauthorized'});
    return;
  }

  const eventType = normalizeLower(req.get('X-GitHub-Event'));
  if (eventType && eventType !== 'push') {
    res.status(202).json({ok: true, skipped: true, reason: 'unsupported_event'});
    return;
  }

  const payload = parseJsonBody(req.body);
  const result = sanitizePushPayload(payload, config);
  if (result.skip) {
    res.status(202).json({ok: true, skipped: true, reason: result.reason});
    return;
  }

  try {
    await admin.firestore()
      .collection(GITHUB_ACTIVITY_COLLECTION)
      .doc(result.docId)
      .set(result.event, {merge: true});

    res.status(200).json({
      ok: true,
      skipped: false,
      eventId: result.docId,
      repository: result.event.repositoryFullName,
      branch: result.event.branch,
    });
  } catch (error) {
    console.error('[github_reporting] ingest failed', error);
    res.status(500).json({error: error.message || 'Failed to ingest activity'});
  }
}

async function runCtoWeeklyReportHttp(req, res) {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, X-GitHub-Report-Secret');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({error: 'Method Not Allowed'});
    return;
  }

  const config = getConfig();
  const providedSecret = req.get('X-GitHub-Report-Secret');
  if (!compareSecrets(config.sharedSecret, providedSecret)) {
    res.status(401).json({error: 'Unauthorized'});
    return;
  }

  const body = parseJsonBody(req.body);
  const referenceDate = toDate(body.referenceDate) || new Date();
  const force = body.force === true;

  try {
    const result = await generateWeeklyCtoReportForDate({
      referenceDate,
      force,
      config,
    });
    res.status(200).json(result);
  } catch (error) {
    console.error('[github_reporting] manual run failed', error);
    res.status(500).json({error: error.message || 'Failed to generate report'});
  }
}

const generateWeeklyCtoReport = onSchedule({
  schedule: '0 12 * * MON',
  timeZone: 'America/New_York',
  memory: '256MiB',
  region: 'us-central1',
}, async () => {
  try {
    const result = await generateWeeklyCtoReportForDate({});
    console.log('[github_reporting] weekly run result', result);
  } catch (error) {
    console.error('[github_reporting] scheduled run failed', error);
    throw error;
  }
});

module.exports = {
  ingestGitHubActivity,
  runCtoWeeklyReportHttp,
  generateWeeklyCtoReport,
  __test__: {
    sanitizePushPayload,
    buildWeeklyWorkSummary,
    buildFormSubmission,
    extractFocusAreas,
    describeChangedPath,
    getPreviousWeeklyPeriod,
    buildRunDocId,
    collectCommitsFromEvents,
  },
};
