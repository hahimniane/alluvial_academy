const https = require('https');
const functions = require('firebase-functions');
const {CloudTasksClient} = require('@google-cloud/tasks');

const PROJECT_ID =
  process.env.GCP_PROJECT ||
  process.env.GCLOUD_PROJECT ||
  process.env.GOOGLE_CLOUD_PROJECT ||
  process.env.PROJECT_ID;
const TASKS_LOCATION = process.env.TASKS_LOCATION || 'northamerica-northeast1';
const FUNCTION_REGION = process.env.FUNCTION_REGION || 'us-central1';
const SHIFT_TASK_QUEUE = process.env.SHIFT_TASK_QUEUE || 'shift-lifecycle-queue';
let cachedProjectNumber =
  process.env.GCP_PROJECT_NUMBER ||
  process.env.GOOGLE_CLOUD_PROJECT_NUMBER ||
  process.env.PROJECT_NUMBER ||
  null;
let cachedTasksServiceAccount = null;
const TASKS_SERVICE_ACCOUNT_EMAIL =
  process.env.TASKS_SERVICE_ACCOUNT_EMAIL || process.env.CLOUD_TASKS_SERVICE_ACCOUNT_EMAIL || null;
const PREFER_APPSPOT_TASKS_SA =
  String(process.env.TASKS_SERVICE_ACCOUNT_PREFERENCE || '').trim().toLowerCase() === 'appspot';

const tasksClient = new CloudTasksClient();

const fetchMetadata = (path) =>
  new Promise((resolve, reject) => {
    const options = {
      host: 'metadata.google.internal',
      path,
      headers: {'Metadata-Flavor': 'Google'},
      timeout: 2000,
    };

    const req = https.request(options, (res) => {
      if (res.statusCode !== 200) {
        reject(new Error(`Metadata request failed (${res.statusCode}) for ${path}`));
        return;
      }

      let data = '';
      res.on('data', (chunk) => {
        data += chunk;
      });
      res.on('end', () => resolve(data.trim()));
    });

    req.on('error', reject);
    req.end();
  });

const getProjectNumber = async () => {
  if (cachedProjectNumber) {
    return cachedProjectNumber;
  }
  try {
    const number = await fetchMetadata('/computeMetadata/v1/project/numeric-project-id');
    cachedProjectNumber = number;
    return number;
  } catch (error) {
    console.warn('Unable to fetch project number from metadata server:', error.message);
    return null;
  }
};

const getTasksServiceAccount = async () => {
  if (cachedTasksServiceAccount) {
    return cachedTasksServiceAccount;
  }

  const explicit = String(TASKS_SERVICE_ACCOUNT_EMAIL || '').trim();
  if (explicit) {
    console.log(`[DEBUG] Using configured Cloud Tasks service account: ${explicit}`);
    cachedTasksServiceAccount = explicit;
    return explicit;
  }

  if (!PREFER_APPSPOT_TASKS_SA) {
    // Prefer project number from environment; otherwise attempt metadata server (Cloud Run / Functions).
    const projectNumber = cachedProjectNumber || (await getProjectNumber());
    if (projectNumber) {
      const computed = `${projectNumber}-compute@developer.gserviceaccount.com`;
      console.log(`[DEBUG] Using computed Cloud Tasks service account: ${computed}`);
      cachedTasksServiceAccount = computed;
      return computed;
    }
  }

  // Fallback: App Engine default service account (requires App Engine enabled).
  if (PROJECT_ID) {
    const appspot = `${PROJECT_ID}@appspot.gserviceaccount.com`;
    console.log(`[WARN] Using App Engine service account for Cloud Tasks: ${appspot}`);
    cachedTasksServiceAccount = appspot;
    return appspot;
  }

  if (PREFER_APPSPOT_TASKS_SA) {
    // Last-resort fallback if project ID is missing but project number is available.
    const projectNumber = cachedProjectNumber || (await getProjectNumber());
    if (projectNumber) {
      const computed = `${projectNumber}-compute@developer.gserviceaccount.com`;
      console.log(`[WARN] Falling back to computed Cloud Tasks service account: ${computed}`);
      cachedTasksServiceAccount = computed;
      return computed;
    }
  }

  throw new Error('Unable to determine a service account email for Cloud Tasks OIDC token');
};

const queuePath = () => tasksClient.queuePath(PROJECT_ID, TASKS_LOCATION, SHIFT_TASK_QUEUE);

const taskName = (shiftId, phase, suffix) => {
  const base = `shift-${shiftId}-${phase}`;
  const safeSuffix = suffix
    ? String(suffix)
        .trim()
        .replace(/[^a-zA-Z0-9-_]/g, '_')
    : null;
  const taskId = safeSuffix ? `${base}-${safeSuffix}` : base;
  return tasksClient.taskPath(PROJECT_ID, TASKS_LOCATION, SHIFT_TASK_QUEUE, taskId);
};

const buildFunctionUrl = (functionName) => {
  const url = `https://${FUNCTION_REGION}-${PROJECT_ID}.cloudfunctions.net/${functionName}`;
  console.log(`Building function URL for ${functionName}: ${url}`);
  return url;
};

const encodeTaskBody = (payload) => Buffer.from(JSON.stringify(payload)).toString('base64');

const toScheduleTime = (date) => ({
  seconds: Math.floor(date.getTime() / 1000),
  nanos: (date.getMilliseconds() % 1000) * 1e6,
});

const ensureFutureDate = (date) => {
  if (date.getTime() <= Date.now()) {
    return new Date(Date.now() + 2000);
  }
  return date;
};

const deleteTaskIfExists = async (name) => {
  try {
    await tasksClient.deleteTask({name});
    console.log(`Cloud Tasks: Deleted existing task ${name}`);
  } catch (error) {
    if (error.code === 5) {
      return;
    }
    throw error;
  }
};

const ensureTasksConfig = async () => {
  if (!PROJECT_ID) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Unable to determine project ID for Cloud Tasks scheduling. ' +
        'Set the GCP_PROJECT environment variable or deploy on Firebase.'
    );
  }

  console.log(
    `Cloud Tasks Config: PROJECT_ID=${PROJECT_ID}, TASKS_LOCATION=${TASKS_LOCATION}, ` +
      `FUNCTION_REGION=${FUNCTION_REGION}, QUEUE=${SHIFT_TASK_QUEUE}, ` +
      `Using default service account authentication`
  );

  const queue = queuePath();
  try {
    await tasksClient.getQueue({name: queue});
    console.log(`Queue verified: ${queue}`);
  } catch (error) {
    if (error.code === 5) {
      console.error(`Queue not found or no permission: ${queue}`);
      throw new functions.https.HttpsError(
        'failed-precondition',
        `Cloud Tasks queue not found or permission denied. ` +
          `Queue: ${SHIFT_TASK_QUEUE} in ${TASKS_LOCATION}. ` +
          `Please ensure the queue exists and the calling service account has the 'Cloud Tasks Enqueuer' role. ` +
          `Error: ${error.message}`
      );
    }
    throw error;
  }

  return null;
};

module.exports = {
  tasksClient,
  ensureTasksConfig,
  queuePath,
  taskName,
  buildFunctionUrl,
  encodeTaskBody,
  toScheduleTime,
  ensureFutureDate,
  deleteTaskIfExists,
  getTasksServiceAccount,
  getProjectNumber,
  FUNCTION_REGION,
  PROJECT_ID,
};
