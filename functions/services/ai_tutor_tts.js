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

const AR = /[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]/;
const LAT = /[A-Za-z\u00C0-\u024F]/;

/**
 * A reply split into runs of one script each. "Surah Al-Asr says: وَالْعَصْرِ …
 * which means…" becomes [latin, arabic, latin], so every run can be read by a
 * voice that knows its language. Punctuation and spaces stick to the run
 * before them.
 */
const segment = (text) => {
  const runs = [];
  let current = null;
  for (const ch of String(text || '')) {
    const kind = AR.test(ch) ? 'ar' : LAT.test(ch) ? 'lat' : null;
    if (!current) { current = {kind: kind || 'lat', text: ch}; continue; }
    if (kind === null || kind === current.kind) { current.text += ch; continue; }
    runs.push(current);
    current = {kind, text: ch};
  }
  if (current) runs.push(current);
  return runs.map((r) => ({...r, text: r.text.trim()})).filter((r) => LAT.test(r.text) || AR.test(r.text));
};

const wavHeader = (dataLength, sampleRate) => {
  const h = Buffer.alloc(44);
  h.write('RIFF', 0); h.writeUInt32LE(36 + dataLength, 4); h.write('WAVE', 8);
  h.write('fmt ', 12); h.writeUInt32LE(16, 16); h.writeUInt16LE(1, 20); h.writeUInt16LE(1, 22);
  h.writeUInt32LE(sampleRate, 24); h.writeUInt32LE(sampleRate * 2, 28); h.writeUInt16LE(2, 32); h.writeUInt16LE(16, 34);
  h.write('data', 36); h.writeUInt32LE(dataLength, 40);
  return h;
};

const _request = async ({text, voice, token, projectId, audioConfig}) => {
  const res = await fetch('https://texttospeech.googleapis.com/v1/text:synthesize', {
    method: 'POST',
    headers: {Authorization: `Bearer ${token}`, 'Content-Type': 'application/json', ...(projectId ? {'x-goog-user-project': projectId} : {})},
    body: JSON.stringify({input: {text}, voice, audioConfig}),
  });
  if (!res.ok) throw new Error(`${voice.name}: HTTP ${res.status} ${(await res.text()).slice(0, 200)}`);
  const json = await res.json();
  if (!json.audioContent) throw new Error(`${voice.name}: empty audio`);
  return json.audioContent;
};

const _withVoices = async (language, settings, fn) => {
  let lastError = null;
  for (const voice of voicesFor(language, settings)) {
    try { return await fn(voice); } catch (e) { lastError = e; }
  }
  throw lastError || new Error('no voice');
};

const SAMPLE_RATE = 24000;

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
  const runs = segment(clean);
  const mixed = runs.some((r) => r.kind === 'ar') && runs.some((r) => r.kind === 'lat');
  try {
    if (!mixed) {
      const lang = runs.length && runs[0].kind === 'ar' ? 'ar' : language;
      const spoken = lang === 'ar' ? prepareArabic(clean) : clean;
      return await _withVoices(lang, settings, async (voice) => ({
        audio: await _request({text: spoken, voice, token, projectId, audioConfig: {audioEncoding: 'MP3', speakingRate: lang === 'ar' ? 0.95 : 1.0}}),
        mime: 'audio/mpeg', voice: voice.name, chars: clean.length,
      }));
    }
    // Mixed scripts: one voice per run, stitched as PCM with a short pause.
    const base = language === 'ar' ? 'en' : language;
    const pause = Buffer.alloc(SAMPLE_RATE * 2 * 0.25);
    const parts = [];
    const voices = new Set();
    for (const run of runs) {
      const lang = run.kind === 'ar' ? 'ar' : base;
      const spoken = lang === 'ar' ? prepareArabic(run.text) : run.text;
      const wav = await _withVoices(lang, settings, async (voice) => {
        voices.add(voice.name);
        return Buffer.from(await _request({text: spoken, voice, token, projectId, audioConfig: {audioEncoding: 'LINEAR16', sampleRateHertz: SAMPLE_RATE, speakingRate: lang === 'ar' ? 0.9 : 1.0}}), 'base64');
      });
      parts.push(wav.subarray(44), pause);
    }
    const pcm = Buffer.concat(parts);
    return {audio: Buffer.concat([wavHeader(pcm.length, SAMPLE_RATE), pcm]).toString('base64'), mime: 'audio/wav', voice: [...voices].join('+'), chars: clean.length};
  } catch (e) {
    console.error('[ai_tutor_tts] synthesis failed:', e.message);
    return null;
  }
};

module.exports = {synthesize, voicesFor, prepareArabic, segment, VOICES, MAX_CHARS};
