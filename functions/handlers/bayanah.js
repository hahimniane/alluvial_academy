'use strict';

/**
 * Bayanah live event — a host-run, Kahoot-style game for the day of the Bayanah.
 *
 * Everyone watches ONE small document (`bayanah_events/{eventId}`), so when the
 * host advances, every screen flips at the same moment. The correct answer is
 * never in that document until the question closes, so it can't be read ahead.
 *
 * TIMING (the part that has to be exact): each device starts its own stopwatch
 * the instant a question appears and reports how long the student took. That
 * measurement is local, so a slow network never costs a student points. The
 * server independently checks the claim is physically possible — you cannot
 * report an answer faster than the question has actually been open — and clamps
 * it. Answers are idempotent per student per question.
 *
 * Students who played the monthly quiz get bonus points as a head start, taken
 * from their existing `quiz_competitions/{monthKey}/students/{uid}` record.
 */

const {onCall, HttpsError} = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const {DateTime} = require('luxon');
const {callGemini} = require('./quiz_generation');

const TIME_ZONE = 'America/New_York';
const EVENTS = 'bayanah_events';

// Scoring
const DEFAULT_BASE_POINTS = 1000;
const SPEED_WEIGHT = 0.5; // answering instantly = full points, at the buzzer = half
const DEFAULT_DURATION_MS = 20000;
const MIN_DURATION_MS = 5000;
const MAX_DURATION_MS = 120000;
// The most network delay we'll forgive between the student tapping and the
// call reaching us. It bounds how much a faked "instant" answer could gain:
// at most SPEED_WEIGHT * (MAX_NETWORK_LAG_MS / duration) of the question's
// points, and it's also the worst a genuinely laggy student can be penalised.
const MAX_NETWORK_LAG_MS = 3000;
// Late answers still land (network hiccup) but score nothing beyond the window.
const LATE_GRACE_MS = 2500;
/**
 * "Get ready" beat between publishing a question and the clock starting.
 *
 * Every device waits this long locally after the question arrives, which gives
 * an image time to decode before anyone can answer — otherwise a student whose
 * picture is still loading would lose points for a slow connection. Because the
 * wait is measured on each device, no clock synchronisation is involved; the
 * server just subtracts it when checking how long an answer really took.
 */
const PREP_MS = 1500;

// Monthly head start
const BONUS_PER_QUESTION = 10;
const BONUS_ACCURACY_BONUS = 500; // scaled by accuracy
const MAX_BONUS_POINTS = 2000;

const roleValue = (data = {}) => String(
  data.user_type || data.userType || data.role || '',
).trim().toLowerCase();

const isAdminUser = (data = {}) => {
  const role = roleValue(data);
  return role === 'admin' || role === 'super_admin' ||
    data.is_admin === true || data.isAdmin === true;
};

const isStudentUser = (data = {}) => roleValue(data) === 'student';

const monthKeyForDate = (date = new Date()) => DateTime
  .fromJSDate(date, {zone: 'utc'})
  .setZone(TIME_ZONE)
  .toFormat('yyyy-MM');

const requireUser = async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in required');
  const snap = await admin.firestore().collection('users').doc(uid).get();
  return {uid, data: snap.data() || {}};
};

const requireAdmin = async (request) => {
  const user = await requireUser(request);
  if (!isAdminUser(user.data)) {
    throw new HttpsError('permission-denied', 'Admin access required');
  }
  return user;
};

const displayNameFor = (data = {}, uid = '') => {
  const first = String(data.first_name || data.firstName || '').trim();
  const last = String(data.last_name || data.lastName || '').trim();
  const full = `${first} ${last}`.trim();
  const name = full || String(data.display_name || data.displayName || '').trim();
  return name || `Student ${uid.slice(0, 4)}`;
};

const clampInt = (value, min, max, fallback) => {
  const n = Number(value);
  if (!Number.isFinite(n)) return fallback;
  return Math.max(min, Math.min(max, Math.round(n)));
};

const sanitizeQuestion = (data = {}) => {
  const question = String(data.question || '').trim();
  if (question.length < 3 || question.length > 400) {
    throw new HttpsError('invalid-argument', 'Question must be 3–400 characters');
  }
  const options = Array.isArray(data.options)
    ? data.options.map((o) => String(o || '').trim()).filter((o) => o.length > 0)
    : [];
  if (options.length < 2 || options.length > 4) {
    throw new HttpsError('invalid-argument', 'Give between 2 and 4 answer choices');
  }
  if (new Set(options).size !== options.length) {
    throw new HttpsError('invalid-argument', 'Answer choices must be different');
  }
  const correctIndex = Number(data.correctIndex);
  if (!Number.isInteger(correctIndex) || correctIndex < 0 || correctIndex >= options.length) {
    throw new HttpsError('invalid-argument', 'Pick which choice is correct');
  }
  const imageUrl = String(data.imageUrl || '').trim();
  if (imageUrl && !/^https:\/\//i.test(imageUrl)) {
    throw new HttpsError('invalid-argument', 'Image must be an https URL');
  }
  return {
    question,
    options,
    correct_index: correctIndex,
    duration_ms: clampInt(data.durationMs, MIN_DURATION_MS, MAX_DURATION_MS, DEFAULT_DURATION_MS),
    points: clampInt(data.points, 100, 5000, DEFAULT_BASE_POINTS),
    explanation: String(data.explanation || '').trim().slice(0, 500) || null,
    image_url: imageUrl || null,
  };
};

/** Head start earned by playing the monthly quiz before Bayanah day. */
const bonusPointsFor = async (uid, monthKey) => {
  try {
    const snap = await admin.firestore()
      .collection('quiz_competitions').doc(monthKey)
      .collection('students').doc(uid)
      .get();
    if (!snap.exists) return {points: 0, answered: 0, correct: 0};
    const d = snap.data() || {};
    const answered = Number(d.unique_answered_count || 0);
    const correct = Number(d.correct_answer_count || 0);
    const accuracy = answered > 0 ? correct / answered : 0;
    const points = Math.min(
      MAX_BONUS_POINTS,
      Math.round(answered * BONUS_PER_QUESTION + accuracy * BONUS_ACCURACY_BONUS),
    );
    return {points, answered, correct};
  } catch (err) {
    console.warn('bayanah: bonus lookup failed', err && err.message);
    return {points: 0, answered: 0, correct: 0};
  }
};

const eventRef = (eventId) => {
  const id = String(eventId || '').trim();
  if (!id) throw new HttpsError('invalid-argument', 'eventId is required');
  return admin.firestore().collection(EVENTS).doc(id);
};

const requireHost = async (request) => {
  const user = await requireUser(request);
  const ref = eventRef(request.data?.eventId);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError('not-found', 'Event not found');
  const event = snap.data() || {};
  if (!isAdminUser(user.data) && event.host_uid !== user.uid) {
    throw new HttpsError('permission-denied', 'Only the host can run this event');
  }
  return {...user, ref, event};
};

// ───────────────────────────── Admin: authoring ─────────────────────────────

const createBayanahEvent = onCall({region: 'us-central1', cors: true}, async (request) => {
  const {uid} = await requireAdmin(request);
  const title = String(request.data?.title || '').trim() || 'Bayanah Competition';
  const eventDate = String(request.data?.eventDate || '').trim(); // YYYY-MM-DD
  const monthKey = /^\d{4}-\d{2}-\d{2}$/.test(eventDate)
    ? eventDate.slice(0, 7)
    : monthKeyForDate();
  const joinCode = String(Math.floor(100000 + Math.random() * 900000));
  const ref = admin.firestore().collection(EVENTS).doc();
  await ref.set({
    title,
    event_date: eventDate || null,
    month_key: monthKey,
    join_code: joinCode,
    status: 'draft',
    host_uid: uid,
    created_by: uid,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
    current_index: -1,
    current_question: null,
    question_started_at: null,
    reveal: null,
    player_count: 0,
    question_count: 0,
    bonus_enabled: request.data?.bonusEnabled !== false,
  });
  return {eventId: ref.id, joinCode};
});

const saveBayanahQuestion = onCall({region: 'us-central1', cors: true}, async (request) => {
  await requireAdmin(request);
  const ref = eventRef(request.data?.eventId);
  const clean = sanitizeQuestion(request.data);
  const questionId = String(request.data?.questionId || '').trim();
  const questionsRef = ref.collection('questions');

  if (questionId) {
    await questionsRef.doc(questionId).set({
      ...clean,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    return {questionId};
  }
  const existing = await questionsRef.count().get();
  const order = existing.data().count;
  const doc = questionsRef.doc();
  await doc.set({
    ...clean,
    order,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  });
  await ref.set({question_count: order + 1}, {merge: true});
  return {questionId: doc.id, order};
});

const deleteBayanahQuestion = onCall({region: 'us-central1', cors: true}, async (request) => {
  await requireAdmin(request);
  const ref = eventRef(request.data?.eventId);
  const questionId = String(request.data?.questionId || '').trim();
  if (!questionId) throw new HttpsError('invalid-argument', 'questionId is required');
  await ref.collection('questions').doc(questionId).delete();
  const remaining = await ref.collection('questions').count().get();
  await ref.set({question_count: remaining.data().count}, {merge: true});
  return {ok: true};
});

// ───────────────────────────── Admin: AI drafting ─────────────────────────────

const buildDraftPrompt = ({topic, count, ageGroup, difficulty, avoid}) => `
You are writing questions for a live Kahoot-style Islamic knowledge game called
Bayanah, played by students in a madrasah.

Write exactly ${count} multiple-choice questions about: ${topic}

Audience: ${ageGroup}
Difficulty: ${difficulty}

Rules:
- Each question must have exactly 4 answer choices, with exactly one correct.
- Keep every question under 120 characters so it is readable on a phone in a
  few seconds, and keep each choice under 40 characters.
- Questions must be factually correct and uncontroversial across mainstream
  Sunni teaching. Avoid sectarian disputes, fiqh disagreements, and anything
  where scholars differ.
- Vary the questions; do not ask the same fact twice.
- Write in clear, simple English suitable for the audience.
- Add a one-sentence explanation of the correct answer.
${avoid && avoid.length ? `- Do NOT repeat any of these existing questions:\n${avoid.slice(0, 40).map((q) => `  • ${q}`).join('\n')}` : ''}

Return ONLY a JSON array, no prose, in exactly this shape:
[
  {
    "question": "…",
    "options": ["…", "…", "…", "…"],
    "correctAnswer": 0,
    "explanation": "…"
  }
]
`.trim();

const parseDrafts = (body) => {
  const text = body?.candidates?.[0]?.content?.parts?.[0]?.text || '';
  let parsed;
  try {
    parsed = JSON.parse(text);
  } catch (_) {
    const match = text.match(/\[[\s\S]*\]/);
    if (!match) return [];
    try {
      parsed = JSON.parse(match[0]);
    } catch (__) {
      return [];
    }
  }
  if (!Array.isArray(parsed)) return [];
  const seen = new Set();
  const drafts = [];
  for (const raw of parsed) {
    const question = String(raw?.question || '').trim();
    const options = Array.isArray(raw?.options)
      ? raw.options.map((o) => String(o || '').trim()).filter(Boolean)
      : [];
    const correctIndex = Number(raw?.correctAnswer);
    if (question.length < 5 || question.length > 300) continue;
    if (options.length !== 4 || new Set(options).size !== 4) continue;
    if (!Number.isInteger(correctIndex) || correctIndex < 0 || correctIndex > 3) continue;
    const key = question.toLowerCase().replace(/[^a-z0-9 ]/g, '').trim();
    if (seen.has(key)) continue;
    seen.add(key);
    drafts.push({
      question,
      options,
      correctIndex,
      explanation: String(raw?.explanation || '').trim().slice(0, 300),
    });
  }
  return drafts;
};

/**
 * Draft questions with AI. Nothing is saved — the admin picks which drafts to
 * keep and those are written through the normal save path, so no question ever
 * reaches students without a human approving it.
 */
const draftBayanahQuestions = onCall({
  region: 'us-central1',
  cors: true,
  timeoutSeconds: 120,
  secrets: ['GEMINI_API_KEY'],
}, async (request) => {
  await requireAdmin(request);
  const topic = String(request.data?.topic || '').trim();
  if (topic.length < 3) {
    throw new HttpsError('invalid-argument', 'Describe what the questions should be about');
  }
  const count = clampInt(request.data?.count, 1, 15, 8);
  const ageGroup = String(request.data?.ageGroup || 'children aged 8-12').trim();
  const difficulty = String(request.data?.difficulty || 'easy').trim();

  // Avoid repeating questions already in this event.
  let avoid = [];
  const eventId = String(request.data?.eventId || '').trim();
  if (eventId) {
    const existing = await admin.firestore().collection(EVENTS).doc(eventId)
      .collection('questions').limit(60).get();
    avoid = existing.docs.map((d) => String(d.data().question || ''));
  }

  const apiKey = (process.env.GEMINI_API_KEY || '').trim();
  if (!apiKey) {
    throw new HttpsError('failed-precondition', 'AI drafting is not configured');
  }

  let result;
  try {
    result = await callGemini({
      apiKey,
      prompt: buildDraftPrompt({topic, count, ageGroup, difficulty, avoid}),
    });
  } catch (err) {
    console.error('draftBayanahQuestions: Gemini failed', err && err.message);
    throw new HttpsError('unavailable', 'The AI could not draft questions right now. Try again.');
  }

  const drafts = parseDrafts(result.body);
  if (drafts.length === 0) {
    throw new HttpsError('unavailable', 'The AI returned nothing usable. Try rewording the topic.');
  }
  return {drafts, model: result.model};
});

/** Save several approved drafts at once, preserving the order shown. */
const saveBayanahQuestionsBatch = onCall({region: 'us-central1', cors: true}, async (request) => {
  await requireAdmin(request);
  const ref = eventRef(request.data?.eventId);
  const items = Array.isArray(request.data?.questions) ? request.data.questions : [];
  if (items.length === 0 || items.length > 25) {
    throw new HttpsError('invalid-argument', 'Pick between 1 and 25 questions');
  }
  const cleaned = items.map(sanitizeQuestion);

  const existing = await ref.collection('questions').count().get();
  let order = existing.data().count;
  const batch = admin.firestore().batch();
  for (const q of cleaned) {
    batch.set(ref.collection('questions').doc(), {
      ...q,
      order,
      source: 'ai',
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    order += 1;
  }
  batch.set(ref, {question_count: order}, {merge: true});
  await batch.commit();
  return {saved: cleaned.length, total: order};
});

// ───────────────────────────── Host: running the game ─────────────────────────────

const setBayanahStatus = onCall({region: 'us-central1', cors: true}, async (request) => {
  const {ref} = await requireHost(request);
  const status = String(request.data?.status || '').trim();
  if (!['draft', 'lobby', 'live', 'ended'].includes(status)) {
    throw new HttpsError('invalid-argument', 'Unknown status');
  }
  const patch = {status, updated_at: admin.firestore.FieldValue.serverTimestamp()};
  if (status === 'lobby') {
    patch.current_index = -1;
    patch.current_question = null;
    patch.question_started_at = null;
    patch.reveal = null;
  }
  if (status === 'ended') {
    // Clear the live question too, so every player's screen leaves the game
    // the instant the host ends it rather than sitting on a dead question.
    patch.current_question = null;
    patch.question_started_at = null;
    patch.reveal = null;
    patch.ended_at = admin.firestore.FieldValue.serverTimestamp();
  }
  await ref.set(patch, {merge: true});
  return {status};
});

/**
 * Advance to a question. Publishes the text + choices (never the answer) and
 * stamps the server time that becomes the reference point for scoring.
 */
const nextBayanahQuestion = onCall({region: 'us-central1', cors: true}, async (request) => {
  const {ref, event} = await requireHost(request);
  const requested = Number(request.data?.index);
  const nextIndex = Number.isInteger(requested)
    ? requested
    : Number(event.current_index ?? -1) + 1;

  const snap = await ref.collection('questions').orderBy('order').get();
  const questions = snap.docs;
  if (nextIndex < 0 || nextIndex >= questions.length) {
    await ref.set({
      status: 'ended',
      current_question: null,
      question_started_at: null,
      reveal: null,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    return {finished: true};
  }

  const doc = questions[nextIndex];
  const q = doc.data();
  await ref.set({
    status: 'live',
    current_index: nextIndex,
    current_question: {
      question_id: doc.id,
      question: q.question,
      options: q.options,
      duration_ms: q.duration_ms,
      points: q.points,
      index: nextIndex,
      total: questions.length,
      image_url: q.image_url || null,
      prep_ms: PREP_MS,
    },
    question_started_at: admin.firestore.FieldValue.serverTimestamp(),
    reveal: null,
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});
  return {index: nextIndex, total: questions.length};
});

/** Close the open question and reveal the answer + how the room answered. */
const revealBayanahAnswer = onCall({region: 'us-central1', cors: true}, async (request) => {
  const {ref, event} = await requireHost(request);
  const current = event.current_question;
  if (!current) throw new HttpsError('failed-precondition', 'No question is open');

  const qSnap = await ref.collection('questions').doc(current.question_id).get();
  const correctIndex = Number(qSnap.data()?.correct_index ?? -1);

  const answers = await ref.collection('answers')
    .where('question_id', '==', current.question_id).get();

  // Never reveal while students can still answer — seeing the answer early
  // would end the question for everyone still thinking. The two legitimate
  // ways out are the timer running out or the whole room having answered.
  const startedAt = event.question_started_at;
  if (startedAt) {
    const durationMs = Number(current.duration_ms || DEFAULT_DURATION_MS);
    const prepMs = Number(current.prep_ms ?? PREP_MS);
    const elapsed = (Date.now() - startedAt.toDate().getTime()) - prepMs;
    const playerCount = Number(event.player_count || 0);
    const everyoneAnswered = playerCount > 0 && answers.size >= playerCount;
    if (elapsed < durationMs && !everyoneAnswered) {
      const secondsLeft = Math.ceil((durationMs - elapsed) / 1000);
      throw new HttpsError(
        'failed-precondition',
        `Still ${secondsLeft}s on the clock — wait for the timer or for everyone to answer.`,
      );
    }
  }
  const counts = new Array((current.options || []).length).fill(0);
  answers.forEach((a) => {
    const i = Number(a.data().selected_index);
    if (Number.isInteger(i) && i >= 0 && i < counts.length) counts[i] += 1;
  });

  await ref.set({
    reveal: {
      question_id: current.question_id,
      correct_index: correctIndex,
      counts,
      explanation: qSnap.data()?.explanation || null,
      answered_count: answers.size,
    },
    question_started_at: null, // closes the window for late scoring
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});
  return {correctIndex, counts, answered: answers.size};
});

// ───────────────────────────── Students: play ─────────────────────────────

const joinBayanah = onCall({region: 'us-central1', cors: true}, async (request) => {
  const {uid, data: userData} = await requireUser(request);
  if (!isStudentUser(userData) && !isAdminUser(userData)) {
    throw new HttpsError('permission-denied', 'Students only');
  }
  const code = String(request.data?.joinCode || '').trim();
  const eventId = String(request.data?.eventId || '').trim();

  let ref;
  if (eventId) {
    ref = eventRef(eventId);
  } else {
    if (!/^\d{6}$/.test(code)) {
      throw new HttpsError('invalid-argument', 'Enter the 6-digit game code');
    }
    const found = await admin.firestore().collection(EVENTS)
      .where('join_code', '==', code)
      .where('status', 'in', ['lobby', 'live'])
      .limit(1).get();
    if (found.empty) throw new HttpsError('not-found', 'No open game with that code');
    ref = found.docs[0].ref;
  }

  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError('not-found', 'Game not found');
  const event = snap.data() || {};
  if (event.status === 'ended') {
    throw new HttpsError('failed-precondition', 'This game has finished');
  }

  const playerRef = ref.collection('players').doc(uid);
  const existing = await playerRef.get();
  if (existing.exists) {
    return {eventId: ref.id, rejoined: true, bonusPoints: existing.data().bonus_points || 0};
  }

  const bonus = event.bonus_enabled === false
    ? {points: 0, answered: 0, correct: 0}
    : await bonusPointsFor(uid, String(event.month_key || monthKeyForDate()));

  await playerRef.set({
    uid,
    display_name: displayNameFor(userData, uid),
    joined_at: admin.firestore.FieldValue.serverTimestamp(),
    bonus_points: bonus.points,
    month_answered_count: bonus.answered,
    month_correct_count: bonus.correct,
    total_points: bonus.points, // head start
    correct_count: 0,
    answered_count: 0,
    streak: 0,
  });
  await ref.set({
    player_count: admin.firestore.FieldValue.increment(1),
  }, {merge: true});

  return {eventId: ref.id, rejoined: false, bonusPoints: bonus.points};
});

/**
 * Score one answer.
 *
 * `elapsedMs` is measured on the student's device from the moment the question
 * appeared — network latency therefore costs them nothing. We verify the claim
 * against our own clock so it can't be faked, then award speed-weighted points.
 */
const submitBayanahAnswer = onCall({region: 'us-central1', cors: true}, async (request) => {
  const {uid} = await requireUser(request);
  const ref = eventRef(request.data?.eventId);
  const selectedIndex = Number(request.data?.selectedIndex);
  const claimedElapsed = Number(request.data?.elapsedMs);
  if (!Number.isInteger(selectedIndex) || selectedIndex < 0) {
    throw new HttpsError('invalid-argument', 'selectedIndex is required');
  }

  const db = admin.firestore();
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError('not-found', 'Game not found');
  const event = snap.data() || {};
  const current = event.current_question;
  const startedAt = event.question_started_at;
  if (!current || !startedAt) {
    throw new HttpsError('failed-precondition', 'No question is open');
  }
  const questionId = current.question_id;
  if (request.data?.questionId && request.data.questionId !== questionId) {
    throw new HttpsError('failed-precondition', 'That question already closed');
  }
  if (selectedIndex >= (current.options || []).length) {
    throw new HttpsError('invalid-argument', 'Unknown choice');
  }

  const durationMs = Number(current.duration_ms || DEFAULT_DURATION_MS);
  // Devices hold the question for the "get ready" beat before their clock
  // starts, so discount it here or every answer would look later than it was.
  const prepMs = Number(current.prep_ms ?? PREP_MS);
  const serverElapsed = Math.max(
    0,
    (Date.now() - startedAt.toDate().getTime()) - prepMs,
  );
  if (serverElapsed > durationMs + LATE_GRACE_MS) {
    throw new HttpsError('deadline-exceeded', 'Time is up for this question');
  }
  // Trust the device's stopwatch — that's what makes latency free for the
  // student — but bound it by what the clock says is possible. You can't have
  // taken longer than the question has been open (upper), and you can't have
  // answered meaningfully sooner than it reached us either (lower), which is
  // what stops a tampered client claiming an instant answer.
  const upperBound = Math.min(durationMs, serverElapsed);
  const lowerBound = Math.max(0, serverElapsed - MAX_NETWORK_LAG_MS);
  const measured = Number.isFinite(claimedElapsed) ? claimedElapsed : serverElapsed;
  const elapsedMs = Math.min(upperBound, Math.max(lowerBound, Math.max(0, measured)));

  const qSnap = await ref.collection('questions').doc(questionId).get();
  if (!qSnap.exists) throw new HttpsError('not-found', 'Question not found');
  const correctIndex = Number(qSnap.data().correct_index);
  const basePoints = Number(current.points || DEFAULT_BASE_POINTS);
  const isCorrect = selectedIndex === correctIndex;
  const speedFactor = 1 - SPEED_WEIGHT * (elapsedMs / Math.max(1, durationMs));
  const points = isCorrect ? Math.max(1, Math.round(basePoints * speedFactor)) : 0;

  const answerRef = ref.collection('answers').doc(`${questionId}_${uid}`);
  const playerRef = ref.collection('players').doc(uid);

  const result = await db.runTransaction(async (tx) => {
    const [answerSnap, playerSnap] = await Promise.all([
      tx.get(answerRef), tx.get(playerRef),
    ]);
    if (answerSnap.exists) {
      const prev = answerSnap.data();
      return {counted: false, isCorrect: prev.is_correct, points: prev.points};
    }
    if (!playerSnap.exists) {
      throw new HttpsError('failed-precondition', 'Join the game first');
    }
    const player = playerSnap.data() || {};
    const streak = isCorrect ? Number(player.streak || 0) + 1 : 0;

    tx.set(answerRef, {
      question_id: questionId,
      uid,
      selected_index: selectedIndex,
      correct_index: correctIndex,
      is_correct: isCorrect,
      elapsed_ms: elapsedMs,
      server_elapsed_ms: serverElapsed,
      points,
      answered_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.set(playerRef, {
      total_points: admin.firestore.FieldValue.increment(points),
      correct_count: admin.firestore.FieldValue.increment(isCorrect ? 1 : 0),
      answered_count: admin.firestore.FieldValue.increment(1),
      streak,
      last_answer_at: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    return {counted: true, isCorrect, points};
  });

  // The answer stays hidden until the host reveals it.
  return {...result, elapsedMs};
});

module.exports = {
  createBayanahEvent,
  draftBayanahQuestions,
  saveBayanahQuestionsBatch,
  saveBayanahQuestion,
  deleteBayanahQuestion,
  setBayanahStatus,
  nextBayanahQuestion,
  revealBayanahAnswer,
  joinBayanah,
  submitBayanahAnswer,
  __test__: {
    sanitizeQuestion,
    bonusPointsFor,
    isAdminUser,
    isStudentUser,
    SPEED_WEIGHT,
    MAX_NETWORK_LAG_MS,
    PREP_MS,
    parseDrafts,
    buildDraftPrompt,
    MAX_BONUS_POINTS,
  },
};
