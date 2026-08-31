/**
 * AI quiz question generation pipeline.
 *
 * A weekly scheduled job asks Gemini (free-tier API key) for new kid-friendly
 * Islamic quiz questions per category and writes them to the `quiz_questions`
 * collection with status 'pending'. Nothing reaches students until an admin
 * approves it (status 'approved') in the review screen.
 */
const admin = require('firebase-admin');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onCall, HttpsError } = require('firebase-functions/v2/https');

const QUIZ_QUESTIONS_COLLECTION = 'quiz_questions';
const bundledQuestionTexts = require('../data/quiz_question_texts.json');
// Tried in order. Older Gemini models get retired (404) or free-tier
// zeroed (429) for new API keys, and the newest can 503 under load,
// so we fall through a preference list instead of pinning one model.
const GEMINI_MODELS = [
  'gemini-3.5-flash',
  'gemini-flash-latest',
  'gemini-3.1-flash-lite',
];
const geminiUrl = (model) =>
  `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;
const QUESTIONS_PER_CATEGORY_PER_RUN = 10;
const MAX_PENDING_PER_CATEGORY = 30;
const MAX_EXISTING_IN_PROMPT = 120;
const VALID_DIFFICULTIES = new Set(['easy', 'medium', 'hard']);
const QUESTION_STOP_WORDS = new Set([
  'the', 'a', 'an', 'is', 'are', 'of', 'to', 'in', 'for', 'and', 'on',
  'with', 'what', 'which', 'how', 'many', 'does', 'do', 'was', 'were',
  'that', 'this', 'it', 'from', 'as', 'at', 'by', 'be',
]);

const CATEGORIES = [
  { id: 'five_pillars', topic: 'The five pillars of Islam: Shahada, Salah (prayer, rakats, wudu, adhan), Zakat, Sawm/Ramadan, Hajj and Umrah' },
  { id: 'prophets', topic: 'Stories and facts about the Prophets of Allah mentioned in the Quran, from Adam to Muhammad (peace be upon them)' },
  { id: 'quran_basics', topic: 'Structure and facts about the Quran: surahs, juz, famous verses, revelation, tajweed, respect for the mushaf' },
  { id: 'daily_duas', topic: 'Everyday duas and Islamic phrases: what to say before/after daily actions, meanings of common phrases like Alhamdulillah' },
  { id: 'islamic_history', topic: 'Key events of early Islamic history: Hijrah, battles, caliphs, Islamic calendar, important places' },
  { id: 'arabic_basics', topic: 'Arabic alphabet, harakat, common Arabic words (family, numbers, colors, everyday objects)' },
  { id: 'seerah', topic: 'The life of Prophet Muhammad (peace be upon him) from birth to death: family, revelation, character, key moments' },
  { id: 'sahaba', topic: 'The companions of the Prophet: the four caliphs, famous companions, their titles and contributions' },
  { id: 'islamic_manners', topic: 'Islamic manners and character (adab/akhlaq): greetings, eating, honesty, kindness to parents/neighbors/animals' },
];

function buildPrompt({ topic, existingQuestions, count }) {
  return [
    'You are writing multiple-choice quiz questions for Muslim children aged 6-14 at an online Islamic academy.',
    `Topic: ${topic}`,
    '',
    'Requirements:',
    `- Write exactly ${count} NEW questions not present in the existing list below.`,
    '- Mix difficulties: roughly one third "easy" (ages 6-9), one third "medium" (ages 9-12), one third "hard" (ages 12-14).',
    '- Each question has exactly 4 answer options and exactly one correct answer.',
    '- Vary the position of the correct answer across questions.',
    '- Add a short, warm, one-sentence explanation for the correct answer.',
    '- Content must be mainstream, non-sectarian Sunni basics appropriate for children. No rulings/fatwas, no controversial or scary content.',
    '- Facts must be well-established and verifiable. If unsure about a fact, do not use it.',
    '- Use respectful phrases: "peace be upon him" for Prophets.',
    '',
    'Existing questions (do NOT duplicate or rephrase these):',
    ...existingQuestions.map((q) => `- ${q}`),
    '',
    'Respond with ONLY a JSON array, no other text. Each element:',
    '{"difficulty":"easy|medium|hard","question":"...","options":["...","...","...","..."],"correctAnswer":0,"explanation":"..."}',
  ].join('\n');
}

function parseGeminiQuestions(responseBody) {
  const text = responseBody?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) return [];
  let parsed;
  try {
    parsed = JSON.parse(text);
  } catch (_) {
    // Some models wrap JSON in markdown fences despite instructions.
    const match = String(text).match(/\[[\s\S]*\]/);
    if (!match) return [];
    try {
      parsed = JSON.parse(match[0]);
    } catch (_) {
      return [];
    }
  }
  return Array.isArray(parsed) ? parsed : [];
}

function validateGeneratedQuestion(raw) {
  if (!raw || typeof raw !== 'object') return null;
  const question = String(raw.question || '').trim();
  const explanation = String(raw.explanation || '').trim();
  const difficulty = String(raw.difficulty || '').trim().toLowerCase();
  const options = Array.isArray(raw.options)
    ? raw.options.map((o) => String(o || '').trim())
    : [];
  const correctAnswer = Number(raw.correctAnswer);

  if (!question || question.length < 10 || question.length > 300) return null;
  if (!VALID_DIFFICULTIES.has(difficulty)) return null;
  if (options.length !== 4 || options.some((o) => !o)) return null;
  if (new Set(options.map((o) => o.toLowerCase())).size !== 4) return null;
  if (!Number.isInteger(correctAnswer) || correctAnswer < 0 || correctAnswer > 3) {
    return null;
  }
  if (!explanation) return null;

  return { question, explanation, difficulty, options, correctAnswer };
}

function normalizeQuestionText(text) {
  return String(text || '')
    .toLowerCase()
    .replace(/[^a-z0-9؀-ۿ ]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

function questionTokens(text) {
  return new Set(normalizeQuestionText(text)
    .split(' ')
    .filter((word) => word.length > 2 && !QUESTION_STOP_WORDS.has(word)));
}

function isNearDuplicateQuestion(candidateText, existingText) {
  const candidateTokens = questionTokens(candidateText);
  const existingTokens = questionTokens(existingText);
  if (candidateTokens.size < 3 || existingTokens.size < 3) return false;
  let shared = 0;
  for (const token of candidateTokens) {
    if (existingTokens.has(token)) shared++;
  }
  return shared / Math.min(candidateTokens.size, existingTokens.size) >= 0.9;
}

function filterNewQuestions(candidates, existingTexts) {
  const seen = new Set(existingTexts.map(normalizeQuestionText));
  const comparisonTexts = [...existingTexts];
  const fresh = [];
  for (const candidate of candidates) {
    const key = normalizeQuestionText(candidate.question);
    if (!key || seen.has(key) ||
        comparisonTexts.some((existing) =>
          isNearDuplicateQuestion(candidate.question, existing))) continue;
    seen.add(key);
    comparisonTexts.push(candidate.question);
    fresh.push(candidate);
  }
  return fresh;
}

async function callGemini({ apiKey, prompt, fetchImpl = fetch }) {
  let lastError;
  for (const model of GEMINI_MODELS) {
    const response = await fetchImpl(geminiUrl(model), {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: {
          temperature: 0.9,
          responseMimeType: 'application/json',
        },
      }),
    });
    if (response.ok) {
      return { body: await response.json(), model };
    }
    const errorBody = await response.text().catch(() => '');
    lastError = new Error(
      `Gemini ${model} error ${response.status}: ${errorBody.slice(0, 300)}`,
    );
    console.warn(`[quiz_generation] ${lastError.message}; trying next model`);
  }
  throw lastError;
}

async function generateForCategory({ db, apiKey, category, fetchImpl }) {
  const snapshot = await db
    .collection(QUIZ_QUESTIONS_COLLECTION)
    .where('category', '==', category.id)
    .get();

  let pendingCount = 0;
  const generatedTexts = [];
  snapshot.forEach((doc) => {
    const data = doc.data() || {};
    if (data.status === 'pending') pendingCount++;
    // Rejected questions stay in the dedupe list so the model
    // doesn't regenerate something an admin already turned down.
    if (data.question) {
      generatedTexts.push(String(data.question));
    }
  });

  const bundledTexts = Array.isArray(bundledQuestionTexts[category.id])
    ? bundledQuestionTexts[category.id]
    : [];
  const existingTexts = [...bundledTexts, ...generatedTexts];
  if (pendingCount >= MAX_PENDING_PER_CATEGORY) {
    console.log(`[quiz_generation] ${category.id}: ${pendingCount} pending, skipping`);
    return { category: category.id, created: 0, skipped: true };
  }

  const prompt = buildPrompt({
    topic: category.topic,
    existingQuestions: [
      ...bundledTexts,
      ...generatedTexts.slice(-Math.max(0, MAX_EXISTING_IN_PROMPT - bundledTexts.length)),
    ],
    count: QUESTIONS_PER_CATEGORY_PER_RUN,
  });

  const { body, model } = await callGemini({ apiKey, prompt, fetchImpl });
  const candidates = parseGeminiQuestions(body)
    .map(validateGeneratedQuestion)
    .filter(Boolean);
  const fresh = filterNewQuestions(candidates, existingTexts);

  const batch = db.batch();
  const createdIds = [];
  for (const question of fresh) {
    const ref = db.collection(QUIZ_QUESTIONS_COLLECTION).doc();
    createdIds.push(ref.id);
    batch.set(ref, {
      ...question,
      id: ref.id,
      category: category.id,
      status: 'pending',
      source: 'ai',
      model,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
  if (createdIds.length > 0) await batch.commit();

  console.log(
    `[quiz_generation] ${category.id}: ${candidates.length} generated, ` +
    `${fresh.length} new, ${createdIds.length} saved as pending`,
  );
  return { category: category.id, created: createdIds.length, skipped: false };
}

async function runGeneration({ fetchImpl } = {}) {
  const apiKey = (process.env.GEMINI_API_KEY || '').trim();
  if (!apiKey) {
    throw new Error('GEMINI_API_KEY is not configured');
  }
  const db = admin.firestore();
  const results = [];
  for (const category of CATEGORIES) {
    try {
      results.push(await generateForCategory({ db, apiKey, category, fetchImpl }));
    } catch (error) {
      console.error(`[quiz_generation] ${category.id} failed`, error);
      results.push({ category: category.id, created: 0, error: error.message });
    }
  }
  return results;
}

const generateQuizQuestionsWeekly = onSchedule({
  schedule: '0 3 * * MON',
  timeZone: 'America/New_York',
  memory: '256MiB',
  region: 'us-central1',
  secrets: ['GEMINI_API_KEY'],
}, async () => {
  const results = await runGeneration();
  console.log('[quiz_generation] weekly run complete', JSON.stringify(results));
});

const isAdminUser = (data = {}) => {
  const role = String(data.role || data.user_type || data.userType || '')
    .trim()
    .toLowerCase();
  return role === 'admin' || role === 'super_admin' ||
    data.is_admin === true || data.isAdmin === true;
};

/** Manual trigger so admins can top up the pending pool without waiting a week. */
const generateQuizQuestionsNow = onCall({
  memory: '256MiB',
  region: 'us-central1',
  secrets: ['GEMINI_API_KEY'],
  timeoutSeconds: 300,
}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in required');
  }
  const requesterDoc = await admin.firestore().collection('users').doc(uid).get();
  if (!requesterDoc.exists || !isAdminUser(requesterDoc.data() || {})) {
    throw new HttpsError('permission-denied', 'Admin access required');
  }
  const results = await runGeneration();
  return { results };
});

module.exports = {
  generateQuizQuestionsWeekly,
  generateQuizQuestionsNow,
  callGemini,
  GEMINI_MODELS,
  __test__: {
    buildPrompt,
    parseGeminiQuestions,
    validateGeneratedQuestion,
    normalizeQuestionText,
    isNearDuplicateQuestion,
    filterNewQuestions,
    generateForCategory,
    runGeneration,
    CATEGORIES,
  },
};
