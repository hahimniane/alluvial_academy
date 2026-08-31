"""Expected-vs-heard phoneme comparison for Quran recitation.

Expected side: each (imlaei, diacritized) word goes through the vendored MSA
phonetiser. Heard side: the IqraEval CTC phoneme recognizer's greedy output.
Both are normalized into comparable tokens (gemination carried as a `:` marker),
aligned globally, and each word is classified:

  ok      — matched
  ending  — right word, wrong final short vowel (case ending), e.g. -a for -u
  length  — right word, a vowel recited long that should be short or vice versa
            (madd errors like "raabi" for "rabbi")
  sound   — a consonant clearly off (substituted, or a strong letter dropped)
  missed  — most of the word's phonemes absent

Tolerances (deliberate): hamza softening, emphatic/plain vowel coloring, and
sun-letter assimilation are normalized away. Gemination differences never flag
on their own (the recognizer under-reports doubling even for expert reciters);
they only inform alignment. The final word's ending and final-vowel length are
exempt (waqf).
"""

from __future__ import annotations

import contextlib
import io
import re
from dataclasses import dataclass, field

from phonetiser.phonetise_Arabic import phonetise

SHORT = {"a", "i", "u"}
LONG = {"aa", "ii", "uu"}
VOWELS = SHORT | LONG
SUN = {"t", "th", "d", "dh", "r", "z", "s", "sh", "S", "D", "T", "Z", "l", "n", "*"}
STRONG = {"E", "H", "S", "D", "T", "Z", "q", "g"}  # salient letters whose omission flags
_VOWEL_FOLD = {"A": "a", "AA": "aa", "I": "i", "II": "ii", "U": "u", "UU": "uu"}

HARAKAH = {"a": "fatha", "u": "damma", "i": "kasra", "aa": "fatha", "uu": "damma", "ii": "kasra"}


def base(tok: str) -> str:
    return tok[:-1] if tok.endswith(":") else tok


def is_vowel(tok: str) -> bool:
    return base(tok) in VOWELS


def _fold(tok: str) -> str:
    tok = re.sub(r"\d", "", tok)
    return _VOWEL_FOLD.get(tok, tok)


# ---------------------------------------------------------------------------
# Expected side (G2P)
# ---------------------------------------------------------------------------

def _expected_tokens(word: str) -> list[str]:
    """Raw phonetiser output for one word → normalized tokens with `:` geminates.

    The phonetiser encodes shadda indirectly: a doubled-digit vowel (`i0i0`),
    doubled long-vowel tokens (`aa aa`), or doubled consonants (`l l`). All are
    converted to a geminate marker on the consonant.
    """
    cleaned = word.replace("ٰ", "ا")  # dagger alef is a real long-alef
    with contextlib.redirect_stdout(io.StringIO()):
        result = phonetise(cleaned)
    raw = result[1][0].split() if result[1] else []
    raw = [t for t in raw if t and t != "sil"]

    out: list[str] = []
    for tok in raw:
        m = re.fullmatch(r"(?P<v>[aiuAIU])0(?P=v)0?", tok)  # exact shadda artifact: i0i0
        if m:
            if out and not is_vowel(out[-1]) and not out[-1].endswith(":"):
                out[-1] += ":"
            out.append(_fold(m.group("v")))
            continue
        folded = _fold(tok)
        if not folded or folded == "|":
            continue
        # Some phonetiser variants emit shadda as a doubled single token (`bb`,
        # `DD`) rather than two tokens or doubled-digit vowels — fold to marker.
        if len(folded) == 2 and folded[0] == folded[1] and folded not in LONG:
            folded = f"{folded[0]}:"
        if out and folded == out[-1]:
            if is_vowel(folded):
                # doubled vowel tokens = shadda on the consonant before them
                for k in range(len(out) - 1, -1, -1):
                    if not is_vowel(out[k]):
                        if not out[k].endswith(":"):
                            out[k] += ":"
                        break
                continue
            # doubled consonant = geminate
            out[-1] += ":"
            continue
        out.append(folded)

    # Definite article: `(<) (a) l + sun letter` assimilates — drop the lam and
    # geminate the sun letter (recited "ar-raHman", G2P says "l r ...").
    i = 0
    if i < len(out) and out[i] == "<":
        i += 1
    if i < len(out) and out[i] in ("a", "aa"):
        i += 1
    if i + 1 < len(out) and out[i] == "l" and base(out[i + 1]) in SUN:
        nxt = out[i + 1]
        out = out[:i] + [nxt if nxt.endswith(":") else f"{nxt}:"] + out[i + 2:]

    return out


def word_to_phonemes(word: str) -> list[str]:
    return _expected_tokens(word)


# ---------------------------------------------------------------------------
# Heard side (CTC output)
# ---------------------------------------------------------------------------

def normalize_heard(tokens: list[str]) -> list[str]:
    out: list[str] = []
    for tok in tokens:
        if not tok or tok in ("sil", "|"):
            continue
        folded = _fold(tok)
        if not folded:
            continue
        # dict geminates like `bb` `rr` `SS` → marker form
        if len(folded) == 2 and folded[0] == folded[1] and folded not in LONG:
            folded = f"{folded[0]}:"
        out.append(folded)
    return out


# ---------------------------------------------------------------------------
# Alignment + classification
# ---------------------------------------------------------------------------

def _minor_pair(a: str, b: str) -> bool:
    """Never-flag substitutions (phonologically systematic / model noise)."""
    if a == b or base(a) == base(b):
        return True
    if {base(a), base(b)} <= {"<", ">", "'", "h", "hh"}:
        return True
    return False


@dataclass
class WordResult:
    word: str
    status: str = "ok"  # ok | ending | length | sound | missed
    expected_ending: str | None = None
    heard_ending: str | None = None
    expected_phonemes: list[str] = field(default_factory=list)
    heard_phonemes: list[str] = field(default_factory=list)


def align_and_classify(words: list[str], heard_raw: list[str]) -> list[WordResult]:
    expected_per_word = [word_to_phonemes(w) for w in words]
    # Hamzat-wasl elision for non-initial words starting with bare alef.
    for wi in range(1, len(words)):
        if words[wi].startswith("ا"):
            phs = expected_per_word[wi]
            if phs and phs[0] == "<":
                phs.pop(0)
            if phs and phs[0] in VOWELS:
                phs.pop(0)

    flat: list[str] = []
    owner: list[int] = []
    for wi, phs in enumerate(expected_per_word):
        for p in phs:
            flat.append(p)
            owner.append(wi)

    heard = normalize_heard(heard_raw)
    n, m = len(flat), len(heard)

    def _sub(a: str, b: str) -> float:
        if a == b:
            return 1.0
        if base(a) == base(b):
            return 0.6  # length/gemination difference — align tightly
        av, bv = is_vowel(a), is_vowel(b)
        if av and bv and base(a)[0] == base(b)[0]:
            return 0.5  # same vowel family, different length (a↔aa)
        if av and bv:
            return 0.2  # different vowel quality — the ending signal
        if _minor_pair(a, b):
            return 0.4
        if av != bv:
            return -1.2
        return -0.6

    GAP_E, GAP_H = -1.0, -0.25
    score = [[0.0] * (m + 1) for _ in range(n + 1)]
    for i in range(1, n + 1):
        score[i][0] = score[i - 1][0] + GAP_E
    for j in range(1, m + 1):
        score[0][j] = 0.0  # free leading heard tokens (basmala, isti'adha)
    for i in range(1, n + 1):
        for j in range(1, m + 1):
            s = _sub(flat[i - 1], heard[j - 1])
            score[i][j] = max(score[i - 1][j - 1] + s, score[i - 1][j] + GAP_E, score[i][j - 1] + GAP_H)

    pair: list[int | None] = [None] * n
    i, j = n, m
    while i > 0 and j > 0:
        s = _sub(flat[i - 1], heard[j - 1])
        if abs(score[i][j] - (score[i - 1][j - 1] + s)) < 1e-9:
            pair[i - 1] = j - 1
            i, j = i - 1, j - 1
        elif abs(score[i][j] - (score[i - 1][j] + GAP_E)) < 1e-9:
            i -= 1
        else:
            j -= 1

    results: list[WordResult] = []
    pos = 0
    last_wi = len(words) - 1
    for wi, phs in enumerate(expected_per_word):
        k = len(phs)
        idxs = list(range(pos, pos + k))
        pos += k
        res = WordResult(word=words[wi], expected_phonemes=phs,
                         heard_phonemes=[heard[pair[x]] for x in idxs if pair[x] is not None])
        if k == 0:
            results.append(res)
            continue

        matched = sum(
            1 for x in idxs
            if pair[x] is not None and (base(flat[x]) == base(heard[pair[x]]) or _minor_pair(flat[x], heard[pair[x]]))
        )
        if matched <= k * 0.4:
            res.status = "missed"
            results.append(res)
            continue

        vowel_idxs = [x for x in idxs if is_vowel(flat[x])]
        bad_sub = [
            x for x in idxs
            if pair[x] is not None and not is_vowel(flat[x])
            and base(heard[pair[x]]) != base(flat[x]) and not _minor_pair(flat[x], heard[pair[x]])
        ]
        strong_dropped = [
            x for x in idxs
            if pair[x] is None and base(flat[x]) in STRONG and matched >= k * 0.5
        ]

        # 1) Sound: ≥2 substituted consonants, or a dropped strong letter. A
        #    single substitution is NOT flagged: tested against real student
        #    mics, the recognizer's own consonant confusions (q/T, g/E, r/d) at
        #    that rate produce more false alarms than true catches.
        if len(bad_sub) >= 2 or strong_dropped:
            res.status = "sound"

        # 2) Harakah quality: ANY matched vowel whose family (a/i/u) differs —
        #    word-final AND mid-word (an'umta, daalluun). The final word's last
        #    vowel is waqf-exempt. Skipped when the word's consonants are messy
        #    (≥2 subs → it's already "sound"/garbled; vowel quality from garbled
        #    audio is noise).
        if res.status == "ok" and len(bad_sub) <= 1:
            for x in vowel_idxs:
                if wi == last_wi and vowel_idxs and x == vowel_idxs[-1]:
                    continue
                if pair[x] is None:
                    continue
                exp_v, heard_v = base(flat[x]), base(heard[pair[x]])
                if heard_v in VOWELS and heard_v[0] != exp_v[0]:
                    res.status = "ending"
                    res.expected_ending = HARAKAH.get(exp_v)
                    res.heard_ending = HARAKAH.get(heard_v)
                    break

        # 3) Length (madd) — DISABLED for now. Token-level length comparison is
        #    unreliable with this stack: the G2P's length conventions disagree
        #    with recited audio in places (e.g. الرَّحِيمِ encoded with a long
        #    vowel that is recited short), and the recognizer under-reports
        #    gemination even for expert reciters — testing showed false "length"
        #    flags on perfectly recited ayahs. Real madd detection needs CTC
        #    frame DURATIONS (phoneme-length ratios), a future service upgrade.

        results.append(res)
    return results
