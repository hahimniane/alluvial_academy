/**
 * The student AI tutor, phone-based.
 *
 * The student's phone does the listening and the speaking; these callables
 * only ever see text. That is what makes it cost nothing per minute: the
 * model is Gemma on Google's free tier (with a paid Flash-Lite behind it),
 * and the one thing that needs guarding is how many students talk at once —
 * the seat rules in utils/ai_tutor_seats.js.
 *
 * All writes to ai_tutor_sessions and ai_tutor_bookings happen here with the
 * Admin SDK; the client can only read its own rows.
 */
const admin = require('firebase-admin');
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {DateTime} = require('luxon');
const seats = require('../utils/ai_tutor_seats');
const tts = require('../services/ai_tutor_tts');
const {createTransporter} = require('../services/email/transporter');
const {brandedEmailHtml} = require('../services/email/branding');

const SETTINGS_DOC = 'settings/ai_tutor';
const SESSIONS = 'ai_tutor_sessions';
const BOOKINGS = 'ai_tutor_bookings';
const geminiUrl = (model) => `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;

/* ----------------------------------------------------------------- auth -- */

// v2 callables put the caller on the request object.
const callerUid = (request) => {
  const uid = request?.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in to use the tutor.');
  return uid;
};

const loadCaller = async (uid) => {
  const snap = await admin.firestore().collection('users').doc(uid).get();
  if (!snap.exists) throw new HttpsError('permission-denied', 'No account found for this sign-in.');
  const data = snap.data() || {};
  const role = String(data.role || data.user_type || data.userType || '').trim().toLowerCase();
  const isAdmin = ['admin', 'super_admin', 'administrator'].includes(role) || data.is_admin === true || data.isAdmin === true;
  if (role !== 'student' && !isAdmin) {
    throw new HttpsError('permission-denied', 'The AI tutor is for students.');
  }
  const name = `${data.first_name || ''} ${data.last_name || ''}`.trim() || data.displayName || 'Student';
  return {uid, role, isAdmin, name, firstName: (data.first_name || name.split(' ')[0] || 'Student').toString(), data, language: String(data.language_preference || 'en')};
};

/** An HttpsError whose message is in the student's language. */
const refuse = (caller, code, text) => new HttpsError(code, seats.localizeProblem(text, caller && caller.language));

/** The student's age band, from their account and their enrollment form. */
const loadAgeProfile = async (caller) => {
  let enrollmentAges = [];
  try {
    const snap = await admin.firestore().collection('enrollments').where('metadata.studentUserId', '==', caller.uid).limit(5).get();
    enrollmentAges = snap.docs.map((d) => d.data()?.student?.age ?? d.data()?.studentAge).filter((a) => a != null && a !== '');
  } catch (e) {
    console.warn('[ai_tutor_voice] enrollment age lookup failed:', e.message);
  }
  return seats.ageProfile({user: caller.data, enrollmentAges});
};

const loadSettings = async () => {
  const snap = await admin.firestore().doc(SETTINGS_DOC).get();
  return seats.normalizeSettings(snap.exists ? snap.data() : null);
};

/* -------------------------------------------------------------- reading -- */

const activeSessionsQuery = (db) =>
  db.collection(SESSIONS).where('status', '==', 'started').where('mode', '==', 'voice_device');

/** Sessions still marked started whose clock has run out are closed first, so seats free up. */
const expireStaleSessions = async (db, now) => {
  const stale = await activeSessionsQuery(db).where('expiresAt', '<=', admin.firestore.Timestamp.fromDate(now)).get();
  const batch = db.batch();
  stale.docs.forEach((d) => batch.update(d.ref, {status: 'expired', endedAt: admin.firestore.FieldValue.serverTimestamp()}));
  if (!stale.empty) await batch.commit();
  return stale.size;
};

const myBookings = async (db, uid) => {
  const snap = await db.collection(BOOKINGS).where('userId', '==', uid).where('status', '==', 'booked').get();
  return snap.docs.map((d) => ({id: d.id, ...d.data()}));
};

const slotBookings = async (db, slotKey) => {
  const snap = await db.collection(BOOKINGS).where('slotKey', '==', slotKey).where('status', '==', 'booked').get();
  return snap.docs.map((d) => ({id: d.id, ...d.data()}));
};

const publicSettings = (s) => ({
  enabled: s.enabled,
  seats: s.seats,
  sessionMinutes: s.sessionMinutes,
  maxBookingsPerDay: s.maxBookingsPerDay,
  windowStart: s.windowStart,
  windowEnd: s.windowEnd,
  timezone: s.timezone,
});

/**
 * Everything the tutor screen needs to draw itself: the settings, the next
 * two days of bookable hours with seats left, the student's own bookings,
 * whether a seat is free right now, and any session already running.
 */
const aiTutorGetAvailability = onCall(async (request) => {
  const uid = callerUid(request);
  const caller = await loadCaller(uid);
  const db = admin.firestore();
  const now = new Date();
  const settings = await loadSettings();
  await expireStaleSessions(db, now);

  const days = Math.min(7, Math.max(1, Number(request.data?.days) || 2));
  const keys = seats.upcomingSlotKeys(now, settings, days);
  const mine = await myBookings(db, uid);
  const counts = {};
  if (keys.length) {
    const from = keys[0], to = keys[keys.length - 1];
    const snap = await db.collection(BOOKINGS).where('status', '==', 'booked').where('slotKey', '>=', from).where('slotKey', '<=', to).get();
    snap.docs.forEach((d) => { const k = d.data().slotKey; counts[k] = (counts[k] || 0) + 1; });
  }
  const slots = keys.map((slotKey) => {
    const start = seats.slotStartFor(slotKey, settings);
    return {
      slotKey,
      startIso: start.toUTC().toISO(),
      endIso: start.plus({hours: 1}).toUTC().toISO(),
      seatsLeft: Math.max(0, settings.seats - (counts[slotKey] || 0)),
      mine: mine.some((b) => b.slotKey === slotKey),
    };
  });

  const activeNow = await activeSessionsQuery(db).get();
  const own = activeNow.docs.find((d) => d.data().userId === uid);
  const nowKey = seats.slotKeyFor(now, settings);
  const held = (await slotBookings(db, nowKey)).map((b) => ({...b, started: b.started === true}));
  const canStartNow = seats.startProblem({
    now, settings, activeCount: activeNow.size, slotBookings: held,
    myBooking: mine.find((b) => b.slotKey === nowKey) || null, activeForMe: Boolean(own),
  }) === null;
  const seatsFreeNow = seats.freeSeatsNow({settings, activeCount: activeNow.size, slotBookings: held, uid});

  return {
    settings: publicSettings(settings),
    studentName: caller.firstName,
    slots,
    myBookings: mine.map((b) => ({id: b.id, slotKey: b.slotKey, startIso: seats.slotStartFor(b.slotKey, settings).toUTC().toISO()})),
    canStartNow,
    seatsFreeNow,
    seatsTotal: settings.seats,
    activeSession: own ? {id: own.id, expiresAt: own.data().expiresAt?.toDate?.().toISOString() || null} : null,
  };
});

/* -------------------------------------------------------------- booking -- */

const aiTutorBookSlot = onCall(async (request) => {
  const uid = callerUid(request);
  const caller = await loadCaller(uid);
  const slotKey = String(request.data?.slotKey || '').trim();
  const db = admin.firestore();
  const settings = await loadSettings();
  const now = new Date();

  return db.runTransaction(async (tx) => {
    const mineSnap = await tx.get(db.collection(BOOKINGS).where('userId', '==', uid).where('status', '==', 'booked'));
    const slotSnap = await tx.get(db.collection(BOOKINGS).where('slotKey', '==', slotKey).where('status', '==', 'booked'));
    const problem = seats.bookingProblem({
      slotKey, now, settings,
      existing: mineSnap.docs.map((d) => d.data()),
      slotCount: slotSnap.size,
    });
    if (problem) throw refuse(caller, 'failed-precondition', problem);
    const start = seats.slotStartFor(slotKey, settings);
    const ref = db.collection(BOOKINGS).doc();
    tx.set(ref, {
      userId: uid,
      userName: caller.name,
      slotKey,
      slotStart: admin.firestore.Timestamp.fromDate(start.toJSDate()),
      slotEnd: admin.firestore.Timestamp.fromDate(start.plus({hours: 1}).toJSDate()),
      status: 'booked',
      started: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return {bookingId: ref.id, slotKey, startIso: start.toUTC().toISO()};
  });
});

const aiTutorCancelBooking = onCall(async (request) => {
  const uid = callerUid(request);
  const bookingId = String(request.data?.bookingId || '').trim();
  const ref = admin.firestore().collection(BOOKINGS).doc(bookingId);
  const snap = await ref.get();
  if (!snap.exists || snap.data().userId !== uid) throw new HttpsError('not-found', 'Booking not found.');
  if (snap.data().status !== 'booked') return {cancelled: false};
  await ref.update({status: 'cancelled', cancelledAt: admin.firestore.FieldValue.serverTimestamp()});
  return {cancelled: true};
});

/* -------------------------------------------------------------- session -- */

const USAGE = 'ai_tutor_usage';

/**
 * Reserves cloud-voice characters against this month's budget. Returns true
 * when the reply may be synthesised; false means the phone reads it itself.
 * Counted before synthesis so ten students at once cannot overshoot together.
 */
const reserveTtsChars = async (db, settings, chars) => {
  if (!chars) return false;
  const month = seats.usageMonthKey();
  const ref = db.collection(USAGE).doc(month);
  let decision = 'pause';
  let used = 0;
  try {
    decision = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      used = snap.exists ? Number(snap.data().ttsChars) || 0 : 0;
      const allowed = seats.ttsBudgetAllows({used, chars, budget: settings.ttsMonthlyCharBudget});
      const what = seats.voiceBudgetDecision({allowed, enabled: settings.enabled, pausedMonth: settings.voiceBudgetPausedMonth, month});
      if (what === 'pause') {
        tx.set(ref, {ttsCharsRefused: admin.firestore.FieldValue.increment(chars), updatedAt: admin.firestore.FieldValue.serverTimestamp()}, {merge: true});
        return what;
      }
      tx.set(ref, {ttsChars: used + chars, ...(what === 'paid' ? {paidChars: admin.firestore.FieldValue.increment(chars)} : {}), budget: settings.ttsMonthlyCharBudget, updatedAt: admin.firestore.FieldValue.serverTimestamp()}, {merge: true});
      return what;
    });
  } catch (e) {
    console.error('[ai_tutor_voice] budget check failed, using the device voice:', e.message);
    return false;
  }
  if (decision === 'pause') {
    await pauseTutorForVoiceBudget(db, settings, {used, budget: settings.ttsMonthlyCharBudget, month}).catch((e) => console.error('[ai_tutor_voice] pause failed:', e.message));
    return false;
  }
  return true;
};

/**
 * The free voice characters are used up: switch the tutor off and tell the
 * admins. Resuming is the owner's call — set `enabled` back to true in
 * settings/ai_tutor; further characters this month are then paid for.
 */
const pauseTutorForVoiceBudget = async (db, settings, {used, budget, month}) => {
  const settingsRef = db.doc(SETTINGS_DOC);
  const first = await db.runTransaction(async (tx) => {
    const snap = await tx.get(settingsRef);
    const data = snap.exists ? snap.data() : {};
    if (data.voiceBudgetPausedMonth === month) return false; // already paused (or resumed) this month
    tx.set(settingsRef, {enabled: false, pausedReason: 'voice_budget', pausedAt: admin.firestore.FieldValue.serverTimestamp(), voiceBudgetPausedMonth: month}, {merge: true});
    return true;
  });
  if (!first) return;
  const title = 'AI tutor paused: free voice budget used up';
  const body = `The tutor used ${used.toLocaleString('en-US')} of its ${budget.toLocaleString('en-US')} free voice characters for ${month} and has paused itself. Students see "The tutor is switched off at the moment." To resume on paid characters (about $30 per million), set enabled to true in settings/ai_tutor.`;
  console.warn('[ai_tutor_voice]', title, body);
  await Promise.all([notifyAdminsPush(db, {title, body, type: 'ai_tutor_paused'}), notifyAdminsEmail(db, {title, body})]);
};

const adminUsers = async (db) => {
  const [byRole, byType] = await Promise.all([
    db.collection('users').where('role', '==', 'admin').get(),
    db.collection('users').where('user_type', '==', 'admin').get(),
  ]);
  const seen = new Map();
  for (const d of [...byRole.docs, ...byType.docs]) seen.set(d.id, d.data() || {});
  return [...seen.values()];
};

const notifyAdminsPush = async (db, {title, body, type}) => {
  try {
    const tokens = new Set();
    for (const data of await adminUsers(db)) {
      for (const entry of Array.isArray(data.fcmTokens) ? data.fcmTokens : []) {
        const value = String(entry?.token || '').trim();
        if (value) tokens.add(value);
      }
      const legacy = String(data.fcmToken || data.fcm_token || '').trim();
      if (legacy) tokens.add(legacy);
    }
    if (!tokens.size) return 0;
    await admin.messaging().sendEachForMulticast({notification: {title, body: body.slice(0, 240)}, data: {type}, tokens: [...tokens]});
    return tokens.size;
  } catch (e) {
    console.error('[ai_tutor_voice] admin push failed:', e.message);
    return 0;
  }
};

const notifyAdminsEmail = async (db, {title, body}) => {
  try {
    const emails = [...new Set((await adminUsers(db)).map((u) => String(u.email || '').trim().toLowerCase()).filter((e) => e.includes('@')))];
    if (!emails.length) return 0;
    const transporter = await createTransporter();
    const html = brandedEmailHtml({
      heading: title,
      bodyHtml: `<p>${body}</p><p>Open <strong>Firestore → settings → ai_tutor</strong> and set <code>enabled</code> to <code>true</code> to resume. Raise <code>ttsMonthlyCharBudget</code> if you want a bigger free-of-surprises limit next month.</p>`,
      footerNote: 'Sent by the AI tutor when its monthly voice budget is reached.',
    });
    await transporter.sendMail({from: '"Alluwal Education Hub" <no-reply@alluwaleducationhub.org>', to: emails.join(', '), subject: title, html});
    return emails.length;
  } catch (e) {
    console.error('[ai_tutor_voice] admin email failed:', e.message);
    return 0;
  }
};

const speakIfWithinBudget = async (db, settings, text, language) => {
  const chars = Math.min(String(text || '').length, tts.MAX_CHARS);
  if (!(await reserveTtsChars(db, settings, chars))) return null;
  return tts.synthesize({text, language, settings, projectId: process.env.GCLOUD_PROJECT});
};

const GREETING = (firstName) => `Assalamu alaikum ${firstName}. I'm Alluwal, your tutor. What are we working on today?`;

const aiTutorStartSession = onCall(async (request) => {
  const uid = callerUid(request);
  const caller = await loadCaller(uid);
  const db = admin.firestore();
  const settings = await loadSettings();
  const now = new Date();
  await expireStaleSessions(db, now);

  const greeting = GREETING(caller.firstName);
  const [started, spoken] = await Promise.all([
    startSessionTx({db, uid, caller, settings, now}),
    speakIfWithinBudget(db, settings, greeting, 'en'),
  ]);
  if (spoken) await db.collection(SESSIONS).doc(started.sessionId).update({ttsChars: admin.firestore.FieldValue.increment(spoken.chars), ttsVoice: spoken.voice}).catch(() => {});
  return {...started, greeting, greetingAudio: spoken ? spoken.audio : null, audioMime: spoken ? spoken.mime : null};
});

const startSessionTx = ({db, uid, caller, settings, now}) => {
  return db.runTransaction(async (tx) => {
    const active = await tx.get(activeSessionsQuery(db));
    const own = active.docs.find((d) => d.data().userId === uid);
    if (own) {
      return {sessionId: own.id, expiresAt: own.data().expiresAt.toDate().toISOString(), resumed: true, studentName: caller.firstName};
    }
    const nowKey = seats.slotKeyFor(now, settings);
    const slotSnap = await tx.get(db.collection(BOOKINGS).where('slotKey', '==', nowKey).where('status', '==', 'booked'));
    const held = slotSnap.docs.map((d) => ({id: d.id, ...d.data()}));
    const myBooking = held.find((b) => b.userId === uid) || null;
    const problem = seats.startProblem({
      now, settings, activeCount: active.size,
      slotBookings: held.filter((b) => b.userId !== uid), myBooking, activeForMe: false,
    });
    if (problem) throw refuse(caller, 'resource-exhausted', problem);

    const expiresAt = seats.sessionExpiry(now, settings, myBooking);
    const ref = db.collection(SESSIONS).doc();
    tx.set(ref, {
      userId: uid,
      userName: caller.name,
      userRole: caller.role,
      mode: 'voice_device',
      roomName: null,
      bookingId: myBooking ? myBooking.id : null,
      slotKey: nowKey,
      status: 'started',
      turns: 0,
      startedAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    });
    if (myBooking) tx.update(db.collection(BOOKINGS).doc(myBooking.id), {started: true, status: 'used', sessionId: ref.id});
    return {sessionId: ref.id, expiresAt: expiresAt.toISOString(), resumed: false, studentName: caller.firstName};
  });
};

const aiTutorEndSession = onCall(async (request) => {
  const uid = callerUid(request);
  const sessionId = String(request.data?.sessionId || '').trim();
  const ref = admin.firestore().collection(SESSIONS).doc(sessionId);
  const snap = await ref.get();
  if (!snap.exists || snap.data().userId !== uid) throw new HttpsError('not-found', 'Session not found.');
  if (snap.data().status === 'started') {
    await ref.update({status: 'ended', endedAt: admin.firestore.FieldValue.serverTimestamp()});
  }
  return {ended: true};
});

/* ----------------------------------------------------------------- turn -- */

const askModel = async ({settings, system, history, apiKey}) => {
  // Gemma models take no system instruction, so it is folded into the first
  // user turn for every model — one request shape, no per-model branching.
  const contents = [{role: 'user', parts: [{text: `${system}\n\n(Conversation begins.)`}]}, {role: 'model', parts: [{text: 'Understood.'}]}];
  for (const m of history) contents.push({role: m.role === 'user' ? 'user' : 'model', parts: [{text: m.text}]});

  let lastError = null;
  for (const model of settings.models) {
    // Gemma 4 and the Gemini Flash models reason before answering; without a
    // thinking level the scratch work eats the output budget and, on Gemma, is
    // returned as the answer. Models that reject the setting get a plain call.
    for (const withThinking of [true, false]) {
      try {
        const generationConfig = {temperature: 0.6, maxOutputTokens: 600};
        if (withThinking) generationConfig.thinkingConfig = {thinkingLevel: 'minimal'};
        const res = await fetch(`${geminiUrl(model)}?key=${apiKey}`, {
          method: 'POST',
          headers: {'Content-Type': 'application/json'},
          body: JSON.stringify({contents, generationConfig}),
        });
        if (!res.ok) {
          lastError = new Error(`${model}: HTTP ${res.status}`);
          if (res.status === 400 && withThinking) continue; // retry without the thinking setting
          // Quota, retired, or overloaded: fall through to the next model.
          if ([400, 404, 429, 503].includes(res.status)) break;
          throw lastError;
        }
        const json = await res.json();
        const text = (json.candidates?.[0]?.content?.parts || [])
          .filter((p) => !p.thought)
          .map((p) => p.text || '').join('').trim();
        if (!text) { lastError = new Error(`${model}: empty reply`); break; }
        return {text, model, usage: json.usageMetadata || null};
      } catch (e) {
        lastError = e;
        break;
      }
    }
  }
  throw lastError || new Error('No model answered');
};

const aiTutorTurn = onCall({secrets: ['GEMINI_API_KEY'], timeoutSeconds: 60}, async (request) => {
  const uid = callerUid(request);
  const caller = await loadCaller(uid);
  const db = admin.firestore();
  const settings = await loadSettings();
  const sessionId = String(request.data?.sessionId || '').trim();
  const ref = db.collection(SESSIONS).doc(sessionId);
  const snap = await ref.get();
  if (!snap.exists || snap.data().userId !== uid) throw new HttpsError('not-found', 'Session not found.');
  const session = snap.data();
  if (session.status !== 'started') throw new HttpsError('failed-precondition', 'This session has ended.');
  if (session.expiresAt.toDate() <= new Date()) {
    await ref.update({status: 'expired', endedAt: admin.firestore.FieldValue.serverTimestamp()});
    throw new HttpsError('deadline-exceeded', 'Your hour is up. Book another one to continue.');
  }

  const history = seats.trimHistory(request.data?.messages, settings);
  const last = history[history.length - 1];
  if (!last || last.role !== 'user') throw new HttpsError('invalid-argument', 'Nothing to answer.');

  if (!settings.enabled) throw refuse(caller, 'failed-precondition', 'The tutor is paused right now. Please come back later.');
  const apiKey = (process.env.GEMINI_API_KEY || '').trim();
  if (!apiKey) throw new HttpsError('failed-precondition', 'The tutor is not configured.');
  const language = seats.languageOf(last.text);
  const system = seats.SYSTEM_PROMPT({studentName: caller.firstName, language, ageProfile: await loadAgeProfile(caller)});

  let reply;
  try {
    reply = await askModel({settings, system, history, apiKey});
  } catch (e) {
    console.error('[ai_tutor_voice] model failure:', e.message);
    throw refuse(caller, 'unavailable', 'The tutor could not answer just now. Please try again.');
  }

  const replyLanguage = seats.languageOf(reply.text);
  const spoken = await speakIfWithinBudget(admin.firestore(), settings, reply.text, replyLanguage);

  await ref.update({
    turns: admin.firestore.FieldValue.increment(1),
    lastTurnAt: admin.firestore.FieldValue.serverTimestamp(),
    lastModel: reply.model,
    ...(spoken ? {ttsChars: admin.firestore.FieldValue.increment(spoken.chars), ttsVoice: spoken.voice} : {}),
    ...(reply.usage ? {promptTokens: admin.firestore.FieldValue.increment(reply.usage.promptTokenCount || 0), replyTokens: admin.firestore.FieldValue.increment(reply.usage.candidatesTokenCount || 0)} : {}),
  });

  return {
    reply: reply.text,
    language: replyLanguage,
    audio: spoken ? spoken.audio : null,
    audioMime: spoken ? spoken.mime : null,
    expiresAt: session.expiresAt.toDate().toISOString(),
  };
});

/* ---------------------------------------------------------------- sweep -- */

/** Closes run-out sessions and releases seats booked but never used. */
const aiTutorSweep = onSchedule({schedule: 'every 10 minutes', timeZone: 'Etc/UTC'}, async () => {
  const db = admin.firestore();
  const now = new Date();
  const expired = await expireStaleSessions(db, now);
  const settings = await loadSettings();
  // A booking whose hour began over ten minutes ago with no session is a no-show.
  const cutoff = DateTime.fromJSDate(now).minus({minutes: 10}).toJSDate();
  const missed = await db.collection(BOOKINGS).where('status', '==', 'booked')
    .where('slotStart', '<=', admin.firestore.Timestamp.fromDate(cutoff)).get();
  const batch = db.batch();
  missed.docs.forEach((d) => batch.update(d.ref, {status: 'no_show'}));
  if (!missed.empty) await batch.commit();
  console.log(`[ai_tutor_voice] sweep: expired=${expired} no_show=${missed.size} seats=${settings.seats}`);
});

module.exports = {
  aiTutorGetAvailability,
  aiTutorBookSlot,
  aiTutorCancelBooking,
  aiTutorStartSession,
  aiTutorEndSession,
  aiTutorTurn,
  aiTutorSweep,
};
