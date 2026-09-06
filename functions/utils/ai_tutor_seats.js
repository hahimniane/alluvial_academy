/**
 * The rules behind the student AI tutor's seats and bookings.
 *
 * The tutor costs nothing per minute — the student's phone listens and speaks,
 * and the model is on Google's free tier — so the only thing that needs
 * limiting is how many students talk at once, which is what keeps the free
 * quota and the experience intact. Everything here is pure so it can be
 * tested without Firestore; the callables in handlers/ai_tutor_voice.js do the
 * reading and writing.
 */
const {DateTime} = require('luxon');

const DEFAULT_SETTINGS = Object.freeze({
  enabled: true,
  seats: 10,
  sessionMinutes: 60,
  maxBookingsPerDay: 2,
  windowStart: '15:00',
  windowEnd: '23:00',
  timezone: 'America/New_York',
  /** Tried in order; the free Gemma models first, a paid Flash-Lite last. */
  models: ['gemma-4-26b-a4b-it', 'gemma-4-31b-it', 'gemini-3.1-flash-lite', 'gemini-flash-lite-latest'],
  /** Longest a single conversation is kept when sent to the model. */
  maxHistoryMessages: 16,
});

const _int = (value, fallback) => {
  const n = Number(value);
  return Number.isFinite(n) && n > 0 ? Math.floor(n) : fallback;
};

const _hhmm = (value, fallback) =>
  typeof value === 'string' && /^([01]\d|2[0-3]):[0-5]\d$/.test(value) ? value : fallback;

/** Settings as stored, with every field defaulted so callers never guard. */
const normalizeSettings = (raw) => {
  const data = raw && typeof raw === 'object' ? raw : {};
  const zone = typeof data.timezone === 'string' && DateTime.now().setZone(data.timezone).isValid
    ? data.timezone
    : DEFAULT_SETTINGS.timezone;
  return {
    enabled: data.enabled !== false,
    seats: _int(data.seats, DEFAULT_SETTINGS.seats),
    sessionMinutes: _int(data.sessionMinutes, DEFAULT_SETTINGS.sessionMinutes),
    maxBookingsPerDay: _int(data.maxBookingsPerDay, DEFAULT_SETTINGS.maxBookingsPerDay),
    windowStart: _hhmm(data.windowStart, DEFAULT_SETTINGS.windowStart),
    windowEnd: _hhmm(data.windowEnd, DEFAULT_SETTINGS.windowEnd),
    timezone: zone,
    models: Array.isArray(data.models) && data.models.length ? data.models.map(String) : DEFAULT_SETTINGS.models,
    maxHistoryMessages: _int(data.maxHistoryMessages, DEFAULT_SETTINGS.maxHistoryMessages),
    /** Optional per-language Cloud TTS voice overrides, e.g. {en: 'en-US-Chirp3-HD-Kore'}. */
    voices: data.voices && typeof data.voices === 'object' ? data.voices : {},
  };
};

/** "2026-09-08T15" in the tutor's timezone — one key per bookable hour. */
const slotKeyFor = (date, settings) =>
  DateTime.fromJSDate(date, {zone: settings.timezone}).startOf('hour').toFormat("yyyy-LL-dd'T'HH");

const slotStartFor = (slotKey, settings) => {
  const dt = DateTime.fromFormat(slotKey, "yyyy-LL-dd'T'HH", {zone: settings.timezone});
  return dt.isValid ? dt : null;
};

/** Whether an hour slot falls inside the daily window. */
const slotInWindow = (slotKey, settings) => {
  const start = slotStartFor(slotKey, settings);
  if (!start) return false;
  const [sh, sm] = settings.windowStart.split(':').map(Number);
  const [eh, em] = settings.windowEnd.split(':').map(Number);
  const startMinutes = sh * 60 + sm;
  const endMinutes = eh * 60 + em;
  const slotMinutes = start.hour * 60 + start.minute;
  // The last bookable hour must fit entirely before the window closes.
  return slotMinutes >= startMinutes && slotMinutes + 60 <= endMinutes;
};

/**
 * Every bookable hour from now until `days` ahead, in the tutor's timezone.
 * Hours already begun are left out — a walk-in takes those.
 */
const upcomingSlotKeys = (now, settings, days = 2) => {
  const keys = [];
  const start = DateTime.fromJSDate(now, {zone: settings.timezone}).startOf('hour').plus({hours: 1});
  const end = start.plus({days});
  for (let cursor = start; cursor < end; cursor = cursor.plus({hours: 1})) {
    const key = cursor.toFormat("yyyy-LL-dd'T'HH");
    if (slotInWindow(key, settings)) keys.push(key);
  }
  return keys;
};

/**
 * Why a booking may not be made, or null when it may.
 * `existing` are the student's own bookings (status 'booked') and
 * `slotCount` is how many seats in that slot are already booked by anyone.
 */
const bookingProblem = ({slotKey, now, settings, existing, slotCount}) => {
  if (!settings.enabled) return 'The tutor is switched off at the moment.';
  const start = slotStartFor(slotKey, settings);
  if (!start) return 'That is not a valid time.';
  if (start.toJSDate() <= now) return 'That hour has already started. Start now if a seat is free.';
  if (!slotInWindow(slotKey, settings)) {
    return `The tutor is available ${settings.windowStart}–${settings.windowEnd} (${settings.timezone}).`;
  }
  if (existing.some((b) => b.slotKey === slotKey)) return 'You already have this hour.';
  const day = slotKey.slice(0, 10);
  const sameDay = existing.filter((b) => b.slotKey.slice(0, 10) === day).length;
  if (sameDay >= settings.maxBookingsPerDay) {
    return `You can book up to ${settings.maxBookingsPerDay} hours a day.`;
  }
  if (slotCount >= settings.seats) return 'That hour is full. Try another one.';
  return null;
};

/**
 * Whether a student may start talking right now.
 *
 * A booked seat is always honoured. A walk-in gets a seat only if one is free
 * after the seats promised to others for this hour are held back — so a
 * student who booked never arrives to find their seat taken.
 */
const startProblem = ({now, settings, activeCount, slotBookings, myBooking, activeForMe}) => {
  if (!settings.enabled) return 'The tutor is switched off at the moment.';
  if (activeForMe) return null; // resuming their own live session is always fine
  const key = slotKeyFor(now, settings);
  if (myBooking && myBooking.slotKey === key) {
    return activeCount < settings.seats ? null : 'All seats are busy right now. Try again in a moment.';
  }
  if (!slotInWindow(key, settings)) {
    return `The tutor is available ${settings.windowStart}–${settings.windowEnd} (${settings.timezone}).`;
  }
  const heldForOthers = slotBookings.filter((b) => !b.started).length;
  const free = settings.seats - activeCount - heldForOthers;
  return free > 0 ? null : 'All seats are taken this hour. Book a later hour.';
};

/** When a session that starts now must end. */
const sessionExpiry = (now, settings, myBooking) => {
  const byLength = new Date(now.getTime() + settings.sessionMinutes * 60000);
  if (myBooking) {
    const slotEnd = slotStartFor(myBooking.slotKey, settings).plus({hours: 1}).toJSDate();
    return slotEnd < byLength ? slotEnd : byLength;
  }
  return byLength;
};

/** The conversation as the model should see it: recent, alternating, trimmed. */
const trimHistory = (messages, settings) => {
  const clean = (Array.isArray(messages) ? messages : [])
    .filter((m) => m && (m.role === 'user' || m.role === 'assistant') && typeof m.text === 'string')
    .map((m) => ({role: m.role, text: m.text.trim().slice(0, 2000)}))
    .filter((m) => m.text);
  return clean.slice(-settings.maxHistoryMessages);
};

/** Which voice the phone should use for a reply. */
const FRENCH_MARKERS = /\b(le|la|les|est|vous|nous|pour|avec|dans|une|des|moi|toi|qui|que|quoi|comment|pourquoi|explique|expliquer|dis|parle|raconte|deux|trois|c'est|qu'est|est-ce|je|tu|il|elle|mon|ma|mes|ton|ta|tes|ne|pas|sur|sous|chez|merci|bonjour|salut|prière|priere|jeûne|jeune|aujourd'hui)\b/gi;
const ENGLISH_MARKERS = /\b(the|is|are|what|who|why|how|please|tell|explain|about|and|you|your|me|my|do|does|did|can|was|were|in|of|to|this|that)\b/gi;

const languageOf = (text) => {
  const t = String(text || '');
  // Arabic wins only when it carries the message; an English answer that
  // quotes a verse stays English for the microphone and the base voice.
  const arabicLetters = (t.match(/[\u0621-\u064A]/g) || []).length;
  const latinLetters = (t.match(/[A-Za-z\u00C0-\u024F]/g) || []).length;
  if (arabicLetters > latinLetters) return 'ar';
  const fr = (t.match(FRENCH_MARKERS) || []).length + (/[éèêàçùœ]/.test(t) ? 1 : 0);
  const en = (t.match(ENGLISH_MARKERS) || []).length;
  return fr > en ? 'fr' : 'en';
};


const _dateFrom = (value) => {
  if (!value) return null;
  if (typeof value.toDate === 'function') return DateTime.fromJSDate(value.toDate());
  if (value instanceof Date) return DateTime.fromJSDate(value);
  const dt = DateTime.fromISO(String(value));
  return dt.isValid ? dt : null;
};

/**
 * How old the student is, from whatever the account and enrollment recorded.
 * Most accounts carry only is_adult_student; the enrollment form usually has
 * the child's age. When nothing is known the tutor assumes a young child —
 * the safe side for what it will and will not discuss.
 */
const ageProfile = ({user = {}, enrollmentAges = [], now = new Date()} = {}) => {
  const today = DateTime.fromJSDate(now);
  const finish = (age) => ({
    age,
    band: age == null ? 'unknown' : age >= 18 ? 'adult' : age >= 13 ? 'teen' : 'child',
  });
  const dob = _dateFrom(user.date_of_birth || user.dateOfBirth || user.birth_date || user.birthDate || user.dob);
  if (dob && dob < today) return finish(Math.floor(today.diff(dob, 'years').years));
  const recorded = Number(user.age ?? user.student_age ?? user.studentAge);
  if (Number.isFinite(recorded) && recorded > 0 && recorded < 120) return finish(Math.floor(recorded));
  const year = Number(user.quiz_competition_birth_year || user.quizCompetitionBirthYear);
  if (Number.isFinite(year) && year > 1900 && year <= today.year) {
    const month = Number(user.quiz_competition_birth_month || user.quizCompetitionBirthMonth) || 7;
    return finish(Math.max(0, Math.floor(today.diff(DateTime.fromObject({year, month, day: 1}), 'years').years)));
  }
  const fromEnrollment = enrollmentAges.map(Number).filter((a) => Number.isFinite(a) && a > 0 && a < 120);
  if (fromEnrollment.length) return finish(Math.floor(Math.max(...fromEnrollment)));
  if (user.is_adult_student === true || user.isAdultStudent === true) return {age: null, band: 'adult'};
  return {age: null, band: 'unknown'};
};

/** Seats a walk-in could take this minute (never below zero). */
const freeSeatsNow = ({settings, activeCount, slotBookings, uid}) => {
  const heldForOthers = slotBookings.filter((b) => !b.started && b.userId !== uid).length;
  return Math.max(0, settings.seats - activeCount - heldForOthers);
};

const _ageLine = (profile) => {
  const p = profile || {band: 'unknown', age: null};
  if (p.band === 'adult') return p.age ? `The student is an adult, ${p.age} years old.` : 'The student is an adult.';
  if (p.band === 'teen') return `The student is ${p.age} years old — a teenager.`;
  if (p.band === 'child') return `The student is ${p.age} years old — a child.`;
  return "The student's age is not recorded; treat them as a young child under 13.";
};

const _ageRules = (profile) => {
  const band = (profile || {}).band;
  if (band === 'adult') {
    return 'Explain at an adult level. Keep to learning topics; decline anything not suitable for a school setting.';
  }
  if (band === 'teen') {
    return 'Explain at a teenager\'s level. Do not discuss marriage and intimacy, graphic violence or punishments, politics, or adult-only rulings; if asked, say kindly that it is a question for their parent or teacher and return to the lesson.';
  }
  return 'Explain the way you would to a young child: simple words, one idea at a time, short sentences. Do not discuss marriage and intimacy, death in graphic detail, violence, punishments, politics, or anything meant for older students; if asked, say kindly that it is a question for their parent or teacher and return to the lesson.';
};

const SYSTEM_PROMPT = ({studentName, language, ageProfile: profile}) => [
  `You are Alluwal, the AI tutor of Alluwal Education Hub, an online school teaching Qur'an and Islamic studies, Arabic and African languages including Adlam, and school subjects.`,
  `You are talking with a student named ${studentName || 'a student'}, by voice: your words are read aloud on their phone.`,
  _ageLine(profile),
  _ageRules(profile),
  "Islamic questions are welcome and expected: the Qur'an and its meanings, prayer, wudu, fasting, zakat, hajj, the Prophets' stories, good character, du'as and daily sunnahs. Answer them warmly and simply, and when scholars differ or a ruling depends on the situation, say so and suggest asking their teacher or parent.",
  'Speak the way a warm, patient teacher speaks. Keep answers short — two to four sentences — unless the student asks for more, and end with a small question that checks they understood.',
  `Always answer in the language of the student's most recent message, even when earlier turns were in another language. Their most recent message is in ${language === 'ar' ? 'Arabic' : language === 'fr' ? 'French' : 'English'}: reply entirely in ${language === 'ar' ? 'Arabic' : language === 'fr' ? 'French' : 'English'}.`,
  'Never invent Qur\'an verses or hadith; if unsure of an exact wording, say so and describe the meaning instead.',
  'This is a child-safe space: no violence, romance, politics or anything unsuitable for a young student. If asked, gently steer back to learning.',
  'Do not do graded work for the student; guide them to the answer instead.',
  'Do not use markdown, lists or emoji — it is spoken aloud.',
  "When you recite Qur'an, a du'a or any Arabic phrase, write it in Arabic script — never in Latin transliteration — and then give its meaning in the student's language.",
  'When you write Arabic, write it fully vowelled with tashkeel (fatha, damma, kasra, sukun, shadda) on every word, and attach و and ف to the word that follows them, so the voice reads every word correctly.',
].join(' ');

module.exports = {
  DEFAULT_SETTINGS,
  normalizeSettings,
  slotKeyFor,
  slotStartFor,
  slotInWindow,
  upcomingSlotKeys,
  bookingProblem,
  startProblem,
  sessionExpiry,
  trimHistory,
  languageOf,
  ageProfile,
  freeSeatsNow,
  SYSTEM_PROMPT,
};
