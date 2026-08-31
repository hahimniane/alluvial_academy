/**
 * Arabic recitation matching.
 *
 * Compares what a student recited (a speech-to-text transcript) against the
 * expected ayah words, and marks each expected word correct or not. The Quran
 * text carries full tashkeel and several letter forms that a transcript won't,
 * so both sides are normalized to a bare comparable skeleton first. Matching is
 * order-preserving (LCS) with a small edit-distance tolerance, so minor ASR
 * noise and letter swaps don't read as mistakes.
 *
 * This is transcription-source agnostic: v0 feeds it the browser SpeechRecognition
 * transcript; a Quran-tuned backend can feed it a better transcript unchanged.
 */

// Tashkeel (harakat), superscript alef, Quranic annotation marks, and tatweel.
const DIACRITICS = /[ؐ-ًؚ-ٰٟۖ-ۭ۠-۪ۤ-ۭـ]/g;

/** Reduce Arabic to a bare skeleton for comparison (no tashkeel, unified forms). */
export function normalizeArabic(text: string): string {
  return text
    .replace(/ٰ/g, "ا") // dagger alef (صِرَٰطَ، ٱلرَّحْمَٰنِ) is a real alef, not tashkeel
    .replace(DIACRITICS, "")
    .replace(/[آأإٱ]/g, "ا") // آأإٱ → ا
    .replace(/ى/g, "ي") // ى → ي
    .replace(/ؤ/g, "و") // ؤ → و
    .replace(/ئ/g, "ي") // ئ → ي
    .replace(/ء/g, "") // ء drop
    .replace(/ة/g, "ه") // ة → ه
    .replace(/[^ء-ي\s]/g, "") // keep Arabic letters + whitespace
    .replace(/\s+/g, " ")
    .trim();
}

export function tokenize(text: string): string[] {
  const normalized = normalizeArabic(text);
  return normalized ? normalized.split(" ").filter(Boolean) : [];
}

function levenshtein(a: string, b: string): number {
  const m = a.length;
  const n = b.length;
  if (!m) return n;
  if (!n) return m;
  let prev = Array.from({ length: n + 1 }, (_, i) => i);
  let curr = new Array(n + 1).fill(0);
  for (let i = 1; i <= m; i += 1) {
    curr[0] = i;
    for (let j = 1; j <= n; j += 1) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      curr[j] = Math.min(prev[j] + 1, curr[j - 1] + 1, prev[j - 1] + cost);
    }
    [prev, curr] = [curr, prev];
  }
  return prev[n];
}

/** Close enough to count as the same word (handles minor ASR / letter swaps). */
function similar(a: string, b: string): boolean {
  if (a === b) return true;
  const shorter = Math.min(a.length, b.length);
  if (shorter <= 3) return false;
  return levenshtein(a, b) <= 1;
}

/**
 * Order-preserving LCS pairing: for each expected word (skeleton), the index of
 * the spoken word it matched, or null. Used to map transcript word TIMESTAMPS
 * back onto ayah words (e.g. "play just this word of my recording").
 */
export function alignSpokenToExpected(expected: string[], spoken: string[]): (number | null)[] {
  const n = expected.length;
  const m = spoken.length;
  const pair: (number | null)[] = new Array(n).fill(null);
  if (!n || !m) return pair;
  const dp: number[][] = Array.from({ length: n + 1 }, () => new Array(m + 1).fill(0));
  for (let i = n - 1; i >= 0; i -= 1) {
    for (let j = m - 1; j >= 0; j -= 1) {
      dp[i][j] = expected[i] !== "" && similar(expected[i], spoken[j]) ? dp[i + 1][j + 1] + 1 : Math.max(dp[i + 1][j], dp[i][j + 1]);
    }
  }
  let i = 0;
  let j = 0;
  while (i < n && j < m) {
    if (expected[i] !== "" && similar(expected[i], spoken[j])) {
      pair[i] = j;
      i += 1;
      j += 1;
    } else if (dp[i + 1][j] >= dp[i][j + 1]) {
      i += 1;
    } else {
      j += 1;
    }
  }
  return pair;
}

export type RecitationResult = {
  /** One flag per expected word: was it recited (in order)? */
  correct: boolean[];
  correctCount: number;
  total: number;
  accuracy: number; // 0..1
};

/**
 * Align spoken tokens to expected tokens (order-preserving) and flag each
 * expected word as recited or not. LCS over `similar` equality.
 */
export function checkRecitation(expectedTokens: string[], spokenText: string): RecitationResult {
  const spoken = tokenize(spokenText);
  const n = expectedTokens.length;
  const m = spoken.length;
  const correct = new Array(n).fill(false);
  if (n === 0) return { correct, correctCount: 0, total: 0, accuracy: 0 };

  // LCS length table.
  const dp: number[][] = Array.from({ length: n + 1 }, () => new Array(m + 1).fill(0));
  for (let i = n - 1; i >= 0; i -= 1) {
    for (let j = m - 1; j >= 0; j -= 1) {
      dp[i][j] = similar(expectedTokens[i], spoken[j])
        ? dp[i + 1][j + 1] + 1
        : Math.max(dp[i + 1][j], dp[i][j + 1]);
    }
  }
  // Backtrack, marking matched expected words.
  let i = 0;
  let j = 0;
  while (i < n && j < m) {
    if (similar(expectedTokens[i], spoken[j])) {
      correct[i] = true;
      i += 1;
      j += 1;
    } else if (dp[i + 1][j] >= dp[i][j + 1]) {
      i += 1;
    } else {
      j += 1;
    }
  }
  const correctCount = correct.filter(Boolean).length;
  return { correct, correctCount, total: n, accuracy: correctCount / n };
}

// Core Arabic short vowels / tanwin / sukun → a coarse ending category.
const FINAL_VOWEL: Record<string, string> = {
  "َ": "a", // fatha
  "ً": "a", // fathatan
  "ُ": "u", // damma
  "ٌ": "u", // dammatan
  "ِ": "i", // kasra
  "ٍ": "i", // kasratan
  "ْ": "0", // sukun
};

/** The word's final short-vowel category (a/u/i/0), or "" if none is marked. */
function finalVowel(word: string): string {
  for (let k = word.length - 1; k >= 0; k -= 1) {
    const v = FINAL_VOWEL[word[k]];
    if (v) return v;
  }
  return "";
}

export type WordCheckStatus = "correct" | "ending" | "wrong";
export type WordCheck = { status: WordCheckStatus; expected: string; heard?: string };

/**
 * Diacritic-aware per-word check (EXPERIMENT).
 *
 * Aligns the transcript to the expected words by consonant skeleton (so we know
 * which word is which), then — for a matched word — compares the final short
 * vowel (case ending). Same word, different ending (اللَّهُ vs اللَّهَ) → "ending".
 * Wrong/missing word → "wrong". The last word of the passage is exempted from the
 * ending check because reciters stop on it (waqf → sukun) regardless of iʿrāb.
 *
 * Whether this actually FLAGS a mis-said ending depends on the model faithfully
 * transcribing what was said vs. auto-correcting to the canonical text — which is
 * exactly what this experiment measures.
 */
export function checkRecitationDetailed(expectedWords: string[], spokenText: string): WordCheck[] {
  const expSkel = expectedWords.map(normalizeArabic);
  const spokenRaw = spokenText.trim() ? spokenText.trim().split(/\s+/) : [];
  const spoken = spokenRaw.map((raw) => ({ raw, skel: normalizeArabic(raw) })).filter((s) => s.skel !== "");
  const spokenSkel = spoken.map((s) => s.skel);

  const n = expSkel.length;
  const m = spokenSkel.length;
  const dp: number[][] = Array.from({ length: n + 1 }, () => new Array(m + 1).fill(0));
  for (let i = n - 1; i >= 0; i -= 1) {
    for (let j = m - 1; j >= 0; j -= 1) {
      dp[i][j] = expSkel[i] !== "" && similar(expSkel[i], spokenSkel[j]) ? dp[i + 1][j + 1] + 1 : Math.max(dp[i + 1][j], dp[i][j + 1]);
    }
  }
  const pair = new Array<number>(n).fill(-1);
  let i = 0;
  let j = 0;
  while (i < n && j < m) {
    if (expSkel[i] !== "" && similar(expSkel[i], spokenSkel[j])) {
      pair[i] = j;
      i += 1;
      j += 1;
    } else if (dp[i + 1][j] >= dp[i][j + 1]) {
      i += 1;
    } else {
      j += 1;
    }
  }

  let lastReal = -1;
  for (let k = 0; k < n; k += 1) if (expSkel[k] !== "") lastReal = k;

  return expectedWords.map((w, idx) => {
    if (expSkel[idx] === "") return { status: "correct", expected: w };
    const s = pair[idx];
    if (s < 0) return { status: "wrong", expected: w };
    if (idx === lastReal) return { status: "correct", expected: w }; // waqf — skip ending check
    const heard = spoken[s].raw;
    const ev = finalVowel(w);
    const hv = finalVowel(heard);
    if (ev === "" || hv === "" || ev === hv) return { status: "correct", expected: w };
    return { status: "ending", expected: w, heard };
  });
}

export type AyahStatus = "pending" | "current" | "done" | "missed";
export type FollowEvent = "ok" | "slip" | "none";

/**
 * Ayah-level streaming matcher for hands-free memorization.
 *
 * Tracks which ayah the reciter is on and enforces the memorization rules the
 * app cares about — at the ayah level, not the word level:
 *
 *   - Reciting the current ayah, or REPEATING it from the top → fine (memorizers
 *     repeat an ayah many times).
 *   - Advancing to the very next ayah in order → fine.
 *   - Skipping an ayah (1 → 3) or jumping out of order / backwards → "slip"
 *     (the caller beeps). Skipped-over ayahs are marked "missed".
 *
 * Word matching within an ayah is only used to know where the reciter is and to
 * light up progress; a wrong ayah is what triggers the alert. A jump is only
 * acted on once ≥2 of the new ayah's opening words match, so a single noisy ASR
 * token never causes a false slip.
 */
export class AyahFollowMatcher {
  readonly ayahs: string[][];
  readonly wordDone: boolean[][];
  readonly ayahStatus: AyahStatus[];
  currentAyah = 0;
  posInAyah = 0;
  slips = 0;
  private recent: string[] = [];

  private static readonly WITHIN_LOOKAHEAD = 2; // tolerate a skipped/garbled word inside an ayah
  private static readonly CONFIRM = 2; // opening words needed to confirm a jump to another ayah

  constructor(ayahs: string[][]) {
    this.ayahs = ayahs;
    this.wordDone = ayahs.map((a) => a.map(() => false));
    this.ayahStatus = ayahs.map((_, i) => (i === 0 ? "current" : "pending"));
  }

  get done(): boolean {
    return this.currentAyah >= this.ayahs.length - 1 && this.posInAyah >= (this.ayahs[this.ayahs.length - 1]?.length ?? 0);
  }

  /** Deep copy — used to preview interim (unstable) speech without committing it. */
  clone(): AyahFollowMatcher {
    const c = new AyahFollowMatcher(this.ayahs);
    c.currentAyah = this.currentAyah;
    c.posInAyah = this.posInAyah;
    c.slips = this.slips;
    c.recent = [...this.recent];
    for (let i = 0; i < this.ayahStatus.length; i += 1) c.ayahStatus[i] = this.ayahStatus[i];
    for (let i = 0; i < this.wordDone.length; i += 1) {
      for (let j = 0; j < this.wordDone[i].length; j += 1) c.wordDone[i][j] = this.wordDone[i][j];
    }
    return c;
  }

  private startMatchLen(ai: number, seq: string[]): number {
    const ayah = this.ayahs[ai] ?? [];
    let k = 0;
    while (k < seq.length && k < ayah.length && similar(ayah[k], seq[k])) k += 1;
    return k;
  }

  private enter(ai: number, matched: number, status: AyahStatus): void {
    if (this.ayahStatus[this.currentAyah] === "current") {
      this.ayahStatus[this.currentAyah] = this.wordDone[this.currentAyah].every(Boolean) ? "done" : "pending";
    }
    this.currentAyah = ai;
    this.ayahStatus[ai] = status;
    for (let i = 0; i < this.ayahs[ai].length; i += 1) this.wordDone[ai][i] = i < matched;
    this.posInAyah = matched;
    this.recent = [];
  }

  /** Feed one stable spoken token. Returns "slip" when the caller should beep. */
  push(spoken: string): FollowEvent {
    const cur = this.currentAyah;
    const ayah = this.ayahs[cur] ?? [];

    // 1) Continue the current ayah (small lookahead absorbs a skipped/garbled word).
    for (let k = 0; k <= AyahFollowMatcher.WITHIN_LOOKAHEAD && this.posInAyah + k < ayah.length; k += 1) {
      if (similar(ayah[this.posInAyah + k], spoken)) {
        this.wordDone[cur][this.posInAyah + k] = true;
        this.posInAyah += k + 1;
        this.recent = [];
        return "ok";
      }
    }

    // 2) Repeat the current ayah from the top (allowed — no beep).
    if (ayah.length > 0 && this.posInAyah > 0 && similar(ayah[0], spoken)) {
      for (let i = 0; i < ayah.length; i += 1) this.wordDone[cur][i] = i === 0;
      this.posInAyah = 1;
      this.recent = [];
      return "ok";
    }

    // 3) Start of the next ayah, in order (allowed — no beep).
    const next = this.ayahs[cur + 1];
    if (next && next.length > 0 && similar(next[0], spoken)) {
      this.enter(cur + 1, 1, "current");
      return "ok";
    }

    // 4) Otherwise buffer and see if the reciter has moved to some other ayah.
    this.recent.push(spoken);
    if (this.recent.length > 3) this.recent.shift();
    let bestJ = -1;
    let bestLen = 0;
    for (let j = 0; j < this.ayahs.length; j += 1) {
      if (j === cur) continue;
      const len = this.startMatchLen(j, this.recent);
      if (len >= AyahFollowMatcher.CONFIRM && len > bestLen) {
        bestLen = len;
        bestJ = j;
      }
    }
    if (bestJ >= 0) {
      if (bestJ === cur + 1) {
        this.enter(bestJ, bestLen, "current");
        return "ok";
      }
      // Skip ahead or jump back — a memorization slip.
      if (bestJ > cur + 1) {
        for (let m = cur + 1; m < bestJ; m += 1) if (this.ayahStatus[m] === "pending") this.ayahStatus[m] = "missed";
      }
      this.enter(bestJ, bestLen, "current");
      this.slips += 1;
      return "slip";
    }
    return "none";
  }
}
