import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'quiz_adaptive_session.dart';

/// Per-student quiz progress: which questions they've seen in each category
/// and the difficulty tier they've reached.
class QuizCategoryProgress {
  const QuizCategoryProgress({
    this.seenQuestionIds = const {},
    this.skillLevel = QuizDifficulty.easy,
  });

  final Set<String> seenQuestionIds;
  final String skillLevel;
}

class QuizProgressService {
  QuizProgressService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String? get _uid => _auth.currentUser?.uid;

  Future<QuizCategoryProgress> loadProgress(String categoryId) async {
    final uid = _uid;
    if (uid == null) return const QuizCategoryProgress();
    try {
      final doc =
          await _firestore.collection('quiz_progress').doc(uid).get();
      final categories = doc.data()?['categories'] as Map<String, dynamic>?;
      final entry = categories?[categoryId] as Map<String, dynamic>?;
      if (entry == null) return const QuizCategoryProgress();
      final seen = (entry['seen_ids'] as List?)?.cast<String>() ?? const [];
      final skill = entry['skill_level'] as String? ?? QuizDifficulty.easy;
      return QuizCategoryProgress(
        seenQuestionIds: seen.toSet(),
        skillLevel: QuizDifficulty.tiers.contains(skill)
            ? skill
            : QuizDifficulty.easy,
      );
    } catch (_) {
      // Offline or rules issue: play without persistence rather than failing.
      return const QuizCategoryProgress();
    }
  }

  Future<void> saveProgress({
    required String categoryId,
    required Set<String> previouslySeenIds,
    required Set<String> newlyAskedIds,
    required String skillLevel,
    required int totalPoolSize,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    var seen = {...previouslySeenIds, ...newlyAskedIds};
    // Once the student has seen the whole pool, restart the rotation so
    // questions become available again instead of repeating immediately.
    if (seen.length >= totalPoolSize) {
      seen = {...newlyAskedIds};
    }
    try {
      await _firestore.collection('quiz_progress').doc(uid).set({
        'categories': {
          categoryId: {
            'seen_ids': seen.toList(),
            'skill_level': skillLevel,
            'updated_at': FieldValue.serverTimestamp(),
          },
        },
      }, SetOptions(merge: true));
    } catch (_) {
      // Progress persistence is best-effort.
    }
  }
}
