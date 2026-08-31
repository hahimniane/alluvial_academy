/**
 * Which model the responder asks, and how it gets its key.
 *
 * The platform already pays for Gemini (quiz_generation.js, bayanah.js), and
 * that key already lives in Secret Manager, so the responder reuses it rather
 * than asking anyone to open a second AI account. Anthropic is supported and
 * preferred when a key is present, but nothing here requires it.
 *
 * Key resolution, in order:
 *   1. ANTHROPIC_API_KEY  (env)
 *   2. GEMINI_API_KEY     (env)
 *   3. GEMINI_API_KEY     (Secret Manager, via the service account we already
 *      authenticate with) — so the key never has to be copied anywhere.
 */

import { GoogleAuth } from 'google-auth-library';

// Gemini retires model ids and free-tier quotas move, so fall through a
// preference list instead of pinning one — the same lesson quiz_generation.js
// already learned the hard way.
const GEMINI_MODELS = [
  'gemini-3.5-flash',
  'gemini-flash-latest',
  'gemini-3.1-flash-lite',
];

const SECRET_PROJECT = process.env.GOOGLE_CLOUD_PROJECT || 'alluwal-academy';

async function readGeminiKeyFromSecretManager() {
  const auth = new GoogleAuth({
    scopes: ['https://www.googleapis.com/auth/cloud-platform'],
    ...(process.env.FIREBASE_SERVICE_ACCOUNT
      ? { credentials: JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT) }
      : {}),
  });
  const client = await auth.getClient();
  const { token } = await client.getAccessToken();
  const url = `https://secretmanager.googleapis.com/v1/projects/${SECRET_PROJECT}` +
    '/secrets/GEMINI_API_KEY/versions/latest:access';
  const response = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
  if (!response.ok) {
    throw new Error(
      `Could not read GEMINI_API_KEY from Secret Manager (${response.status}). ` +
      'Grant the service account roles/secretmanager.secretAccessor, or set ' +
      'GEMINI_API_KEY / ANTHROPIC_API_KEY directly.',
    );
  }
  const body = await response.json();
  return Buffer.from(body.payload.data, 'base64').toString('utf8').trim();
}

/** @returns {Promise<{provider: 'anthropic'|'gemini', apiKey: string}>} */
export async function resolveModelCredentials() {
  const anthropic = (process.env.ANTHROPIC_API_KEY || '').trim();
  if (anthropic) return { provider: 'anthropic', apiKey: anthropic };
  const gemini = (process.env.GEMINI_API_KEY || '').trim();
  if (gemini) return { provider: 'gemini', apiKey: gemini };
  return { provider: 'gemini', apiKey: await readGeminiKeyFromSecretManager() };
}

function extractJson(text) {
  const match = String(text || '').match(/\{[\s\S]*\}/);
  if (!match) throw new Error(`Model did not return JSON: ${String(text).slice(0, 300)}`);
  return JSON.parse(match[0]);
}

async function askAnthropic({ apiKey, system, user, model }) {
  const response = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify({
      model: model || 'claude-opus-5',
      max_tokens: 1024,
      system,
      messages: [{ role: 'user', content: user }],
    }),
  });
  if (!response.ok) {
    throw new Error(`Anthropic ${response.status}: ${(await response.text()).slice(0, 300)}`);
  }
  const payload = await response.json();
  const text = (payload.content || [])
    .filter((block) => block.type === 'text')
    .map((block) => block.text)
    .join('\n');
  return { verdict: extractJson(text), model: payload.model || model };
}

async function askGemini({ apiKey, system, user, model }) {
  const candidates = model ? [model, ...GEMINI_MODELS] : GEMINI_MODELS;
  let lastError = null;
  for (const candidate of candidates) {
    const url = 'https://generativelanguage.googleapis.com/v1beta/models/' +
      `${candidate}:generateContent`;
    const response = await fetch(url, {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'x-goog-api-key': apiKey },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: system }] },
        contents: [{ role: 'user', parts: [{ text: user }] }],
        generationConfig: { temperature: 0, responseMimeType: 'application/json' },
      }),
    });
    if (response.ok) {
      const body = await response.json();
      const text = (body.candidates?.[0]?.content?.parts || [])
        .map((part) => part.text || '')
        .join('\n');
      return { verdict: extractJson(text), model: candidate };
    }
    lastError = new Error(
      `Gemini ${candidate} error ${response.status}: ${(await response.text()).slice(0, 200)}`,
    );
    console.warn(`[oncall] ${lastError.message}; trying next model`);
  }
  throw lastError || new Error('No Gemini model responded.');
}

/** Ask whichever model is available for a JSON verdict. */
export async function askModel({ system, user }) {
  const { provider, apiKey } = await resolveModelCredentials();
  const override = (process.env.ONCALL_MODEL || '').trim() || null;
  const ask = provider === 'anthropic' ? askAnthropic : askGemini;
  const result = await ask({ apiKey, system, user, model: override });
  return { ...result, provider };
}
