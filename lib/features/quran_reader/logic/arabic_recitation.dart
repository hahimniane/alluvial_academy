/// Arabic recitation matching — Dart port of the web app's
/// `apps/web/src/lib/arabicRecitation.ts` (keep the two in sync).
///
/// Normalizes Arabic to a bare comparable skeleton (no tashkeel, unified
/// letter forms, dagger-alef treated as a real alef), then aligns recited
/// words against expected words with an order-preserving LCS and a small
/// edit-distance tolerance.
library;

final RegExp _diacritics = RegExp(r'[ؐ-ًؚ-ٰٟ'
    r'ۖ-ۜ۟-۪ۤۧۨ-ۭـ]');

/// Reduce Arabic to a bare skeleton for comparison.
String normalizeArabic(String text) {
  var t = text.replaceAll('ٰ', 'ا'); // dagger alef is a real alef
  t = t.replaceAll(_diacritics, '');
  t = t
      .replaceAll(RegExp('[آأإٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي')
      .replaceAll('ء', '')
      .replaceAll('ة', 'ه');
  t = t.replaceAll(RegExp(r'[^ء-ي\s]'), '');
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}

List<String> tokenize(String text) {
  final n = normalizeArabic(text);
  return n.isEmpty ? <String>[] : n.split(' ').where((w) => w.isNotEmpty).toList();
}

int _levenshtein(String a, String b) {
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  var curr = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    curr[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      curr[j] = [prev[j] + 1, curr[j - 1] + 1, prev[j - 1] + cost]
          .reduce((x, y) => x < y ? x : y);
    }
    final tmp = prev;
    prev = curr;
    curr = tmp;
  }
  return prev[b.length];
}

/// Close enough to count as the same word (minor ASR noise / letter swaps).
bool similarWords(String a, String b) {
  if (a == b) return true;
  final shorter = a.length < b.length ? a.length : b.length;
  if (shorter <= 3) return false;
  return _levenshtein(a, b) <= 1;
}

class RecitationResult {
  final List<bool> correct;
  final int correctCount;
  final int total;
  RecitationResult(this.correct, this.correctCount, this.total);
  double get accuracy => total == 0 ? 0 : correctCount / total;
}

/// Order-preserving LCS: which expected words were recited?
RecitationResult checkRecitation(List<String> expectedTokens, String spokenText) {
  final spoken = tokenize(spokenText);
  final n = expectedTokens.length;
  final m = spoken.length;
  final correct = List<bool>.filled(n, false);
  if (n == 0) return RecitationResult(correct, 0, 0);
  final dp = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      dp[i][j] = similarWords(expectedTokens[i], spoken[j])
          ? dp[i + 1][j + 1] + 1
          : (dp[i + 1][j] > dp[i][j + 1] ? dp[i + 1][j] : dp[i][j + 1]);
    }
  }
  var i = 0, j = 0;
  while (i < n && j < m) {
    if (similarWords(expectedTokens[i], spoken[j])) {
      correct[i] = true;
      i++;
      j++;
    } else if (dp[i + 1][j] >= dp[i][j + 1]) {
      i++;
    } else {
      j++;
    }
  }
  final count = correct.where((c) => c).length;
  return RecitationResult(correct, count, n);
}

/// For each expected word, the index of the spoken word it matched (or null).
/// Used to map transcript word timestamps back onto ayah words.
List<int?> alignSpokenToExpected(List<String> expected, List<String> spoken) {
  final n = expected.length, m = spoken.length;
  final pair = List<int?>.filled(n, null);
  if (n == 0 || m == 0) return pair;
  final dp = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      dp[i][j] = expected[i].isNotEmpty && similarWords(expected[i], spoken[j])
          ? dp[i + 1][j + 1] + 1
          : (dp[i + 1][j] > dp[i][j + 1] ? dp[i + 1][j] : dp[i][j + 1]);
    }
  }
  var i = 0, j = 0;
  while (i < n && j < m) {
    if (expected[i].isNotEmpty && similarWords(expected[i], spoken[j])) {
      pair[i] = j;
      i++;
      j++;
    } else if (dp[i + 1][j] >= dp[i][j + 1]) {
      i++;
    } else {
      j++;
    }
  }
  return pair;
}

enum AyahStatus { pending, current, done, missed }

enum FollowEvent { ok, slip, none }

/// Ayah-level streaming matcher for the memorization follow-along:
/// reciting/repeating the current ayah or advancing in order is fine; skipping
/// or jumping out of order is a slip. Mirrors the web AyahFollowMatcher.
class AyahFollowMatcher {
  final List<List<String>> ayahs;
  late final List<List<bool>> wordDone;
  late final List<AyahStatus> ayahStatus;
  int currentAyah = 0;
  int posInAyah = 0;
  int slips = 0;
  final List<String> _recent = [];

  static const _withinLookahead = 2;
  static const _confirm = 2;

  AyahFollowMatcher(this.ayahs) {
    wordDone = ayahs.map((a) => List<bool>.filled(a.length, false)).toList();
    ayahStatus = List<AyahStatus>.generate(
        ayahs.length, (i) => i == 0 ? AyahStatus.current : AyahStatus.pending);
  }

  bool get done =>
      currentAyah >= ayahs.length - 1 &&
      posInAyah >= (ayahs.isEmpty ? 0 : ayahs.last.length);

  int _startMatchLen(int ai, List<String> seq) {
    final ayah = ayahs[ai];
    var k = 0;
    while (k < seq.length && k < ayah.length && similarWords(ayah[k], seq[k])) {
      k++;
    }
    return k;
  }

  void _enter(int ai, int matched, AyahStatus status) {
    if (ayahStatus[currentAyah] == AyahStatus.current) {
      ayahStatus[currentAyah] = wordDone[currentAyah].every((d) => d)
          ? AyahStatus.done
          : AyahStatus.pending;
    }
    currentAyah = ai;
    ayahStatus[ai] = status;
    for (var i = 0; i < ayahs[ai].length; i++) {
      wordDone[ai][i] = i < matched;
    }
    posInAyah = matched;
    _recent.clear();
  }

  FollowEvent push(String spoken) {
    final cur = currentAyah;
    final ayah = ayahs[cur];

    for (var k = 0; k <= _withinLookahead && posInAyah + k < ayah.length; k++) {
      if (similarWords(ayah[posInAyah + k], spoken)) {
        wordDone[cur][posInAyah + k] = true;
        posInAyah += k + 1;
        _recent.clear();
        return FollowEvent.ok;
      }
    }

    if (ayah.isNotEmpty && posInAyah > 0 && similarWords(ayah[0], spoken)) {
      for (var i = 0; i < ayah.length; i++) {
        wordDone[cur][i] = i == 0;
      }
      posInAyah = 1;
      _recent.clear();
      return FollowEvent.ok;
    }

    if (cur + 1 < ayahs.length &&
        ayahs[cur + 1].isNotEmpty &&
        similarWords(ayahs[cur + 1][0], spoken)) {
      _enter(cur + 1, 1, AyahStatus.current);
      return FollowEvent.ok;
    }

    _recent.add(spoken);
    if (_recent.length > 3) _recent.removeAt(0);
    var bestJ = -1, bestLen = 0;
    for (var j = 0; j < ayahs.length; j++) {
      if (j == cur) continue;
      final len = _startMatchLen(j, _recent);
      if (len >= _confirm && len > bestLen) {
        bestLen = len;
        bestJ = j;
      }
    }
    if (bestJ >= 0) {
      if (bestJ == cur + 1) {
        _enter(bestJ, bestLen, AyahStatus.current);
        return FollowEvent.ok;
      }
      if (bestJ > cur + 1) {
        for (var m = cur + 1; m < bestJ; m++) {
          if (ayahStatus[m] == AyahStatus.pending) {
            ayahStatus[m] = AyahStatus.missed;
          }
        }
      }
      _enter(bestJ, bestLen, AyahStatus.current);
      slips++;
      return FollowEvent.slip;
    }
    return FollowEvent.none;
  }
}
