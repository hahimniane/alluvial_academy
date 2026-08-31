'use strict';

/**
 * checkPronunciation — auth-checked bridge to the private Quran phoneme-check
 * Cloud Run service (IqraEval CTC phoneme model + MSA phonetiser). The student
 * records an ayah; we forward audio + the ayah's diacritized words and return
 * per-word verdicts (ok | ending | sound | missed) with harakah-level detail.
 * Same invocation pattern as transcribeRecitation (quran_asr.js).
 */

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { GoogleAuth } = require('google-auth-library');
const admin = require('firebase-admin');

const PHONEME_URL = 'https://quran-phoneme-554077757249.us-central1.run.app';
const MAX_AUDIO_BYTES = 9 * 1024 * 1024;

const auth = new GoogleAuth();

/**
 * Beta debug capture: store the recording + the checker's verdict so we can
 * replay real student audio through the pipeline offline and tune detection.
 * Fire-and-forget — never blocks or fails the check itself.
 */
async function saveDebugCapture(uid, buffer, extension, words, result) {
  try {
    const bucket = admin.storage().bucket();
    const stamp = new Date().toISOString().replace(/[:.]/g, '-');
    const base = `recitation_debug/${uid}/${stamp}`;
    await bucket.file(`${base}.${extension}`).save(buffer, {
      contentType: 'application/octet-stream',
      resumable: false,
    });
    await bucket.file(`${base}.json`).save(
      JSON.stringify({ uid, words, result, saved_at: new Date().toISOString() }, null, 2),
      { contentType: 'application/json', resumable: false },
    );
  } catch (err) {
    console.warn('checkPronunciation: debug capture failed (non-fatal)', err && err.message);
  }
}

const checkPronunciation = onCall(
  { region: 'us-central1', memory: '256MiB', timeoutSeconds: 180, cors: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in to check your recitation.');
    }
    const { audioBase64, filename, words, warm } = request.data || {};

    // Warm-up ping: wakes the (scale-to-zero) Cloud Run service so the first
    // real check of a session doesn't hit a cold instance.
    if (warm === true) {
      try {
        const warmClient = await auth.getIdTokenClient(PHONEME_URL);
        await warmClient.request({ url: `${PHONEME_URL}/`, method: 'GET', timeout: 120000 });
        return { warm: true };
      } catch (err) {
        console.warn('checkPronunciation: warmup failed (non-fatal)', err && err.message);
        return { warm: false };
      }
    }
    if (typeof audioBase64 !== 'string' || audioBase64.length === 0) {
      throw new HttpsError('invalid-argument', 'audioBase64 is required.');
    }
    if (!Array.isArray(words) || words.length === 0 || words.length > 120 ||
        !words.every((w) => typeof w === 'string' && w.length > 0 && w.length < 60)) {
      throw new HttpsError('invalid-argument', 'words must be a non-empty array of ayah words.');
    }
    if (Buffer.byteLength(audioBase64, 'utf8') > MAX_AUDIO_BYTES * 1.4) {
      throw new HttpsError('invalid-argument', 'Recitation clip is too large.');
    }

    let client;
    try {
      client = await auth.getIdTokenClient(PHONEME_URL);
    } catch (err) {
      console.error('checkPronunciation: failed to get ID token client', err);
      throw new HttpsError('internal', 'Could not authenticate to the pronunciation service.');
    }

    try {
      const doRequest = () =>
        client.request({
          url: `${PHONEME_URL}/check`,
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          data: {
            audio_base64: audioBase64,
            filename: typeof filename === 'string' && filename ? filename : 'recitation.webm',
            words,
          },
          maxContentLength: Infinity,
          maxBodyLength: Infinity,
          timeout: 165000,
        });
      let response;
      try {
        response = await doRequest();
      } catch (firstErr) {
        // Cold start / burst can 503; one retry after a short wait almost
        // always lands on the now-warm instance.
        const status = firstErr && firstErr.response && firstErr.response.status;
        if (status && status >= 500) {
          await new Promise((resolve) => setTimeout(resolve, 4000));
          response = await doRequest();
        } else {
          throw firstErr;
        }
      }
      const result = response.data; // { heard_phonemes, words: [{word,status,expected_ending,heard_ending,...}] }
      console.log(
        'checkPronunciation result',
        JSON.stringify({
          uid: request.auth.uid,
          heard: result && result.heard_phonemes,
          verdicts: result && Array.isArray(result.words) ? result.words.map((w) => `${w.word}:${w.status}`) : null,
        }),
      );
      const ext = /\.(mp4|m4a)$/i.test(String(filename || '')) ? 'mp4' : /\.ogg$/i.test(String(filename || '')) ? 'ogg' : 'webm';
      const buffer = Buffer.from(audioBase64, 'base64');
      await saveDebugCapture(request.auth.uid, buffer, ext, words, result);
      return result;
    } catch (err) {
      const status = err && err.response && err.response.status;
      console.error('checkPronunciation: phoneme request failed', status, err && err.message);
      throw new HttpsError('internal', `Pronunciation check failed${status ? ` (${status})` : ''}.`);
    }
  },
);

module.exports = { checkPronunciation };
