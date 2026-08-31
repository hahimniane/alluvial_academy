'use strict';

/**
 * Bayanah live-event rules: question validation, the head-start bonus, and the
 * speed scoring/anti-cheat clamp that decides how many points an answer earns.
 */

const {__test__} = require('../handlers/bayanah');
const {sanitizeQuestion, SPEED_WEIGHT, MAX_NETWORK_LAG_MS, MAX_BONUS_POINTS} = __test__;

// Mirrors the scoring in submitBayanahAnswer so the rules are pinned by tests.
const scoreAnswer = ({
  claimedElapsed, serverElapsed, durationMs, basePoints, isCorrect,
}) => {
  const upperBound = Math.min(durationMs, serverElapsed);
  const lowerBound = Math.max(0, serverElapsed - MAX_NETWORK_LAG_MS);
  const measured = Number.isFinite(claimedElapsed) ? claimedElapsed : serverElapsed;
  const elapsedMs = Math.min(upperBound, Math.max(lowerBound, Math.max(0, measured)));
  const speedFactor = 1 - SPEED_WEIGHT * (elapsedMs / Math.max(1, durationMs));
  return {
    elapsedMs,
    points: isCorrect ? Math.max(1, Math.round(basePoints * speedFactor)) : 0,
  };
};

describe('question validation', () => {
  const valid = {
    question: 'Who was the first Khalifah?',
    options: ['Abu Bakr', 'Umar', 'Uthman', 'Ali'],
    correctIndex: 0,
  };

  test('accepts a well-formed question and applies defaults', () => {
    const q = sanitizeQuestion(valid);
    expect(q.question).toBe('Who was the first Khalifah?');
    expect(q.options).toHaveLength(4);
    expect(q.correct_index).toBe(0);
    expect(q.duration_ms).toBe(20000);
    expect(q.points).toBe(1000);
  });

  test('allows two or three choices', () => {
    expect(sanitizeQuestion({...valid, options: ['Yes', 'No'], correctIndex: 1})
      .options).toHaveLength(2);
  });

  test('rejects a correct index outside the choices', () => {
    expect(() => sanitizeQuestion({...valid, correctIndex: 4})).toThrow();
  });

  test('rejects duplicate choices', () => {
    expect(() => sanitizeQuestion({...valid, options: ['Ali', 'Ali', 'Umar']}))
      .toThrow();
  });

  test('rejects a single choice and an empty question', () => {
    expect(() => sanitizeQuestion({...valid, options: ['Only']})).toThrow();
    expect(() => sanitizeQuestion({...valid, question: 'no'})).toThrow();
  });

  test('clamps an absurd timer into the allowed range', () => {
    expect(sanitizeQuestion({...valid, durationMs: 999999}).duration_ms).toBe(120000);
    expect(sanitizeQuestion({...valid, durationMs: 10}).duration_ms).toBe(5000);
  });
});

describe('speed scoring', () => {
  const base = {durationMs: 20000, basePoints: 1000, isCorrect: true};

  test('an instant answer earns full points', () => {
    expect(scoreAnswer({...base, claimedElapsed: 0, serverElapsed: 30}).points)
      .toBe(1000);
  });

  test('answering at the buzzer still earns half', () => {
    expect(scoreAnswer({...base, claimedElapsed: 20000, serverElapsed: 20000}).points)
      .toBe(500);
  });

  test('halfway through earns three quarters', () => {
    expect(scoreAnswer({...base, claimedElapsed: 10000, serverElapsed: 10100}).points)
      .toBe(750);
  });

  test('a wrong answer earns nothing however fast it was', () => {
    expect(scoreAnswer({...base, isCorrect: false, claimedElapsed: 0, serverElapsed: 20}).points)
      .toBe(0);
  });

  test('faster answers always beat slower ones', () => {
    const fast = scoreAnswer({...base, claimedElapsed: 2000, serverElapsed: 2100}).points;
    const slow = scoreAnswer({...base, claimedElapsed: 15000, serverElapsed: 15100}).points;
    expect(fast).toBeGreaterThan(slow);
  });
});

describe('timing integrity', () => {
  const base = {durationMs: 20000, basePoints: 1000, isCorrect: true};

  test('a network-delayed answer is scored on the student\'s own stopwatch', () => {
    // Student answered in 3s; the call took 2s more to reach us.
    const withLag = scoreAnswer({...base, claimedElapsed: 3000, serverElapsed: 5000});
    const noLag = scoreAnswer({...base, claimedElapsed: 3000, serverElapsed: 3050});
    expect(withLag.points).toBe(noLag.points); // latency costs nothing
  });

  test('a client cannot claim it answered before the question opened', () => {
    // Question has only been open 400ms; client claims 0ms — allowed (within
    // tolerance) — but claiming a negative time is clamped to zero.
    expect(scoreAnswer({...base, claimedElapsed: -5000, serverElapsed: 400}).elapsedMs)
      .toBe(0);
  });

  test('a cheater claiming an impossibly fast answer is clamped to reality', () => {
    // 12s have really passed; client claims 100ms to grab full points.
    const cheat = scoreAnswer({...base, claimedElapsed: 100, serverElapsed: 12000});
    const honest = scoreAnswer({...base, claimedElapsed: 12000, serverElapsed: 12000});
    // Forced back to at least (open time - the latency we forgive).
    expect(cheat.elapsedMs).toBeGreaterThanOrEqual(12000 - MAX_NETWORK_LAG_MS);
    expect(cheat.points).toBeLessThan(1000);
    // The most cheating can buy is the latency allowance, priced in points.
    const maxGain = Math.ceil(base.basePoints * SPEED_WEIGHT * (MAX_NETWORK_LAG_MS / base.durationMs));
    expect(cheat.points - honest.points).toBeLessThanOrEqual(maxGain);
  });

  test('elapsed never exceeds the question duration', () => {
    expect(scoreAnswer({...base, claimedElapsed: 999999, serverElapsed: 21000}).elapsedMs)
      .toBe(20000);
  });

  test('a missing client measurement falls back to the server clock', () => {
    expect(scoreAnswer({...base, claimedElapsed: NaN, serverElapsed: 8000}).elapsedMs)
      .toBe(8000);
  });
});

describe('monthly head start', () => {
  // bonus = answered*10 + accuracy*500, capped
  const bonusFor = (answered, correct) => {
    const accuracy = answered > 0 ? correct / answered : 0;
    return Math.min(MAX_BONUS_POINTS, Math.round(answered * 10 + accuracy * 500));
  };

  test('a student who never played starts at zero', () => {
    expect(bonusFor(0, 0)).toBe(0);
  });

  test('playing all month is worth a real head start', () => {
    expect(bonusFor(60, 48)).toBe(1000); // 600 + 400
  });

  test('accuracy is rewarded at equal volume', () => {
    expect(bonusFor(40, 40)).toBeGreaterThan(bonusFor(40, 20));
  });

  test('the head start is capped so it cannot decide the game alone', () => {
    expect(bonusFor(1000, 1000)).toBe(MAX_BONUS_POINTS);
  });
});

describe('AI drafting', () => {
  const {parseDrafts, buildDraftPrompt} = __test__;
  const wrap = (payload) => ({
    candidates: [{content: {parts: [{text: payload}]}}],
  });
  const good = [{
    question: 'Which Surah is the opening of the Quran?',
    options: ['Al-Fatihah', 'Al-Baqarah', 'Yasin', 'An-Nas'],
    correctAnswer: 0,
    explanation: 'Al-Fatihah opens the Quran.',
  }];

  test('parses a clean JSON array', () => {
    const drafts = parseDrafts(wrap(JSON.stringify(good)));
    expect(drafts).toHaveLength(1);
    expect(drafts[0].correctIndex).toBe(0);
    expect(drafts[0].options).toHaveLength(4);
  });

  test('recovers when the model wraps JSON in prose', () => {
    const messy = `Sure! Here you go:\n${JSON.stringify(good)}\nHope that helps.`;
    expect(parseDrafts(wrap(messy))).toHaveLength(1);
  });

  test('drops malformed drafts instead of saving junk', () => {
    const bad = [
      {question: 'ok', options: ['a', 'b', 'c', 'd'], correctAnswer: 0}, // too short
      {question: 'A fine question here?', options: ['a', 'b'], correctAnswer: 0}, // 2 options
      {question: 'Another fine question?', options: ['a', 'b', 'c', 'd'], correctAnswer: 9},
      {question: 'Duplicate choices?', options: ['a', 'a', 'c', 'd'], correctAnswer: 0},
      good[0],
    ];
    expect(parseDrafts(wrap(JSON.stringify(bad)))).toHaveLength(1);
  });

  test('de-duplicates repeated questions from one response', () => {
    expect(parseDrafts(wrap(JSON.stringify([...good, ...good])))).toHaveLength(1);
  });

  test('returns nothing for unparseable output', () => {
    expect(parseDrafts(wrap('I cannot help with that.'))).toEqual([]);
    expect(parseDrafts(undefined)).toEqual([]);
  });

  test('the prompt carries the audience and forbids repeats', () => {
    const prompt = buildDraftPrompt({
      topic: 'the five pillars', count: 5,
      ageGroup: 'children aged 8-12', difficulty: 'easy',
      avoid: ['What is Salah?'],
    });
    expect(prompt).toContain('the five pillars');
    expect(prompt).toContain('children aged 8-12');
    expect(prompt).toContain('What is Salah?');
    expect(prompt).toMatch(/exactly 5 multiple-choice/);
  });
});

describe('get-ready beat', () => {
  const {PREP_MS, MAX_NETWORK_LAG_MS} = __test__;

  // Server discounts the prep window before judging how long an answer took.
  const serverElapsedFor = (msSincePublish) =>
    Math.max(0, msSincePublish - PREP_MS);

  test('answering the instant the clock starts reads as zero', () => {
    expect(serverElapsedFor(PREP_MS)).toBe(0);
  });

  test('the prep window itself never counts against the student', () => {
    expect(serverElapsedFor(PREP_MS - 500)).toBe(0);
  });

  test('time is measured from the end of the beat', () => {
    expect(serverElapsedFor(PREP_MS + 4000)).toBe(4000);
  });

  test('a fast honest answer still passes the anti-cheat lower bound', () => {
    const serverElapsed = serverElapsedFor(PREP_MS + 900); // 900ms real
    const lowerBound = Math.max(0, serverElapsed - MAX_NETWORK_LAG_MS);
    expect(lowerBound).toBe(0); // nothing forced onto an honest quick answer
  });
});

describe('reveal gating', () => {
  const {PREP_MS} = __test__;
  // Mirrors revealBayanahAnswer's guard.
  const canReveal = ({msSincePublish, durationMs, playerCount, answerCount}) => {
    const elapsed = msSincePublish - PREP_MS;
    const everyoneAnswered = playerCount > 0 && answerCount >= playerCount;
    return elapsed >= durationMs || everyoneAnswered;
  };

  test('blocked while the clock is still running', () => {
    expect(canReveal({msSincePublish: PREP_MS + 5000, durationMs: 20000, playerCount: 10, answerCount: 3}))
      .toBe(false);
  });

  test('allowed once the timer runs out', () => {
    expect(canReveal({msSincePublish: PREP_MS + 20000, durationMs: 20000, playerCount: 10, answerCount: 3}))
      .toBe(true);
  });

  test('allowed early when the whole room has answered', () => {
    expect(canReveal({msSincePublish: PREP_MS + 4000, durationMs: 20000, playerCount: 6, answerCount: 6}))
      .toBe(true);
  });

  test('an empty room cannot trigger the everyone-answered shortcut', () => {
    expect(canReveal({msSincePublish: PREP_MS + 1000, durationMs: 20000, playerCount: 0, answerCount: 0}))
      .toBe(false);
  });

  test('the get-ready beat does not count toward the timer', () => {
    // Published 20s ago, but 1.5s of that was the prep beat.
    expect(canReveal({msSincePublish: 20000, durationMs: 20000, playerCount: 5, answerCount: 1}))
      .toBe(false);
  });
});
