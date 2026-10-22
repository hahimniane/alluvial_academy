/**
 * Secrets for the finance bank and WhatsApp features.
 *
 * `defineSecret` / `secrets: [...]` make a deploy fail while the named secret
 * does not exist, and Alluwal has not opened the Plaid or WhatsApp accounts
 * yet. So these functions are deployed WITHOUT binding the secrets. Each value
 * is read when it is needed, from two places, in this order:
 *
 *  1. `process.env.NAME` — set by a function secret binding or a
 *     `functions/.env.<project>` file, if the owner chooses either.
 *  2. Google Secret Manager, by name, with the function's own service account
 *     (`firebase functions:secrets:set NAME` creates the secret there; the
 *     service account needs the Secret Manager Secret Accessor role, see
 *     docs/finance/BANK_AND_WHATSAPP_SETUP.md).
 *
 * A secret that is not set resolves to '' and the feature reports "not
 * connected" and does nothing: no error, no write.
 */

const NAMES = [
  'PLAID_CLIENT_ID',
  'PLAID_SECRET',
  'PLAID_ENV',
  'PLAID_WEBHOOK_URL',
  'WHATSAPP_TOKEN',
  'WHATSAPP_PHONE_NUMBER_ID',
  'WHATSAPP_VERIFY_TOKEN',
  'WHATSAPP_APP_SECRET',
  'GEMINI_API_KEY',
];

const CACHE_MS = 5 * 60 * 1000;
const cache = new Map(); // name -> {value, at}

let _authClient = null;

const projectId = () =>
  process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || (() => {
    try {
      return JSON.parse(process.env.FIREBASE_CONFIG || '{}').projectId || '';
    } catch (e) {
      return '';
    }
  })();

const fromSecretManager = async (name) => {
  const project = projectId();
  if (!project) return '';
  try {
    if (!_authClient) {
      const {GoogleAuth} = require('google-auth-library');
      _authClient = new GoogleAuth({scopes: ['https://www.googleapis.com/auth/cloud-platform']});
    }
    const client = await _authClient.getClient();
    const res = await client.request({
      url: `https://secretmanager.googleapis.com/v1/projects/${project}/secrets/${name}/versions/latest:access`,
    });
    const data = res && res.data && res.data.payload && res.data.payload.data;
    return data ? Buffer.from(data, 'base64').toString('utf8').trim() : '';
  } catch (e) {
    // 404 (not created yet) and 403 (not granted yet) both mean "not set".
    return '';
  }
};

/** One secret's value, or '' when it is not set. */
const getSecret = async (name) => {
  const fromEnv = String(process.env[name] || '').trim();
  if (fromEnv) return fromEnv;
  const hit = cache.get(name);
  if (hit && Date.now() - hit.at < CACHE_MS) return hit.value;
  const value = await fromSecretManager(name);
  cache.set(name, {value, at: Date.now()});
  return value;
};

const getSecrets = async (names) => {
  const out = {};
  await Promise.all(names.map(async (n) => {
    out[n] = await getSecret(n);
  }));
  return out;
};

const clearSecretCache = () => cache.clear();

const PLAID_HOSTS = {
  sandbox: 'https://sandbox.plaid.com',
  development: 'https://development.plaid.com',
  production: 'https://production.plaid.com',
};

/** Plaid credentials, or null when Plaid is not configured. */
const plaidCredentials = async (getter = getSecret) => {
  const [clientId, secret, env] = await Promise.all([
    getter('PLAID_CLIENT_ID'),
    getter('PLAID_SECRET'),
    getter('PLAID_ENV'),
  ]);
  if (!clientId || !secret) return null;
  const environment = PLAID_HOSTS[String(env || 'production').toLowerCase()] ? String(env || 'production').toLowerCase() : 'production';
  return {clientId, secret, env: environment, host: PLAID_HOSTS[environment]};
};

/** WhatsApp Cloud API credentials, or null when it is not configured. */
const whatsappCredentials = async (getter = getSecret) => {
  const [token, phoneNumberId, verifyToken, appSecret] = await Promise.all([
    getter('WHATSAPP_TOKEN'),
    getter('WHATSAPP_PHONE_NUMBER_ID'),
    getter('WHATSAPP_VERIFY_TOKEN'),
    getter('WHATSAPP_APP_SECRET'),
  ]);
  if (!token || !phoneNumberId || !verifyToken || !appSecret) return null;
  return {token, phoneNumberId, verifyToken, appSecret};
};

module.exports = {
  NAMES,
  getSecret,
  getSecrets,
  clearSecretCache,
  plaidCredentials,
  whatsappCredentials,
  PLAID_HOSTS,
};
