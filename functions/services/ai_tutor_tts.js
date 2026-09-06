/**
 * The tutor's voice: Google Cloud Text-to-Speech.
 *
 * Device voices vary wildly (a Mac browser reads with Apple's flat "compact"
 * voice), so the tutor's words are synthesised once on the server with a
 * natural Chirp 3 HD voice and sent to the phone as MP3. Pricing 2026-09:
 * the first million characters a month are free, then about $30 per million
 * for Chirp 3 HD — an hour of tutoring is roughly six thousand characters.
 */
const {GoogleAuth} = require('google-auth-library');

const auth = new GoogleAuth({scopes: ['https://www.googleapis.com/auth/cloud-platform']});

/** Tried in order per language; the first is the good one, the rest are fallbacks. */
const VOICES = {
  en: [{languageCode: 'en-US', name: 'en-US-Chirp3-HD-Aoede'}, {languageCode: 'en-US', name: 'en-US-Neural2-F'}, {languageCode: 'en-US', name: 'en-US-Wavenet-F'}],
  fr: [{languageCode: 'fr-FR', name: 'fr-FR-Chirp3-HD-Aoede'}, {languageCode: 'fr-FR', name: 'fr-FR-Neural2-F'}, {languageCode: 'fr-FR', name: 'fr-FR-Wavenet-F'}],
  ar: [{languageCode: 'ar-XA', name: 'ar-XA-Chirp3-HD-Aoede'}, {languageCode: 'ar-XA', name: 'ar-XA-Wavenet-A'}],
};

const MAX_CHARS = 1500;

/**
 * Arabic as the voice should see it. A conjunction written on its own
 * ("و الصلاة") is skipped or mumbled by the synthesiser; in Arabic writing it
 * belongs to the next word ("والصلاة"). Diacritics are left exactly as the
 * model wrote them — they are what make short words pronounceable.
 */
const prepareArabic = (text) => String(text || '')
  .replace(/(^|[\s،؛:.!؟"'()«»])([وف])\s+(?=[\u0621-\u064A])/g, '$1$2')
  .replace(/\s{2,}/g, ' ')
  .trim();

const voicesFor = (language, settings) => {
  const custom = settings && settings.voices && settings.voices[language];
  if (Array.isArray(custom) && custom.length) return custom;
  if (custom && typeof custom === 'string') return [{languageCode: (VOICES[language] || VOICES.en)[0].languageCode, name: custom}, ...(VOICES[language] || VOICES.en)];
  return VOICES[language] || VOICES.en;
};

/**
 * MP3 (base64) for `text` in `language`, or null when every voice failed —
 * the phone then falls back to its own voice, so a TTS outage never mutes
 * the tutor.
 */
const synthesize = async ({text, language, settings, projectId}) => {
  const clean = (language === 'ar' ? prepareArabic(text) : String(text || '').trim()).slice(0, MAX_CHARS);
  if (!clean) return null;
  let token;
  try {
    const client = await auth.getClient();
    token = (await client.getAccessToken()).token;
  } catch (e) {
    console.error('[ai_tutor_tts] no access token:', e.message);
    return null;
  }
  let lastError = null;
  for (const voice of voicesFor(language, settings)) {
    try {
      const res = await fetch('https://texttospeech.googleapis.com/v1/text:synthesize', {
        method: 'POST',
        headers: {Authorization: `Bearer ${token}`, 'Content-Type': 'application/json', ...(projectId ? {'x-goog-user-project': projectId} : {})},
        body: JSON.stringify({
          input: {text: clean},
          voice,
          audioConfig: {audioEncoding: 'MP3', speakingRate: language === 'ar' ? 0.95 : 1.0},
        }),
      });
      if (!res.ok) {
        lastError = new Error(`${voice.name}: HTTP ${res.status} ${(await res.text()).slice(0, 200)}`);
        continue;
      }
      const json = await res.json();
      if (!json.audioContent) { lastError = new Error(`${voice.name}: empty audio`); continue; }
      return {audio: json.audioContent, mime: 'audio/mpeg', voice: voice.name, chars: clean.length};
    } catch (e) {
      lastError = e;
    }
  }
  console.error('[ai_tutor_tts] synthesis failed:', lastError && lastError.message);
  return null;
};

module.exports = {synthesize, voicesFor, prepareArabic, VOICES, MAX_CHARS};
