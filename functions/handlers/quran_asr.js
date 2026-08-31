'use strict';

/**
 * transcribeRecitation — auth-checked bridge to the private Quran ASR Cloud Run
 * service (Quran-tuned faster-whisper). The student's browser records a short
 * recitation clip and calls this; we forward it to the private service using
 * the function's own identity token (so the Cloud Run service stays private and
 * only signed-in users can reach it), and return the transcript + word timings
 * for the app to align against the expected ayah.
 */

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { GoogleAuth } = require('google-auth-library');
const FormData = require('form-data');

// Private Cloud Run service (project alluwal-academy, us-central1). Invoked with
// an ID token minted for this audience; the function's runtime SA holds
// roles/run.invoker on the service.
const ASR_URL = 'https://quran-asr-554077757249.us-central1.run.app';
const MAX_AUDIO_BYTES = 9 * 1024 * 1024; // callable payload ceiling headroom

const auth = new GoogleAuth();

const transcribeRecitation = onCall(
  { region: 'us-central1', memory: '256MiB', timeoutSeconds: 120, cors: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in to check your recitation.');
    }
    const { audioBase64, filename } = request.data || {};
    if (typeof audioBase64 !== 'string' || audioBase64.length === 0) {
      throw new HttpsError('invalid-argument', 'audioBase64 is required.');
    }
    const buffer = Buffer.from(audioBase64, 'base64');
    if (buffer.length === 0) {
      throw new HttpsError('invalid-argument', 'Audio was empty.');
    }
    if (buffer.length > MAX_AUDIO_BYTES) {
      throw new HttpsError('invalid-argument', 'Recitation clip is too large.');
    }

    const form = new FormData();
    form.append('file', buffer, {
      filename: typeof filename === 'string' && filename ? filename : 'recitation.webm',
      contentType: 'application/octet-stream',
    });

    let client;
    try {
      client = await auth.getIdTokenClient(ASR_URL);
    } catch (err) {
      console.error('transcribeRecitation: failed to get ID token client', err);
      throw new HttpsError('internal', 'Could not authenticate to the transcription service.');
    }

    try {
      const response = await client.request({
        url: `${ASR_URL}/transcribe`,
        method: 'POST',
        headers: form.getHeaders(),
        data: form.getBuffer(),
        maxContentLength: Infinity,
        maxBodyLength: Infinity,
      });
      return response.data; // { text, words: [{word,start,end}], duration }
    } catch (err) {
      const status = err && err.response && err.response.status;
      console.error('transcribeRecitation: ASR request failed', status, err && err.message);
      throw new HttpsError('internal', `Transcription failed${status ? ` (${status})` : ''}.`);
    }
  },
);

module.exports = { transcribeRecitation };
