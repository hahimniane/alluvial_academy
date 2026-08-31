/// Bayanah live event — client wrapper over the `bayanah*` callables and the
/// realtime document every player watches.
///
/// The event document is deliberately tiny: one small doc holds the current
/// question, so a host clicking "Next" flips every screen at the same moment
/// without anyone polling.
library;

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

class BayanahQuestion {
  final String id;
  final int order;
  final String question;
  final List<String> options;
  final int correctIndex;
  final int durationMs;
  final int points;
  final String? explanation;
  final String? imageUrl;

  const BayanahQuestion({
    required this.id,
    required this.order,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.durationMs,
    required this.points,
    this.explanation,
    this.imageUrl,
  });

  factory BayanahQuestion.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return BayanahQuestion(
      id: doc.id,
      order: (d['order'] as num?)?.toInt() ?? 0,
      question: '${d['question'] ?? ''}',
      options: ((d['options'] as List?) ?? []).map((o) => '$o').toList(),
      correctIndex: (d['correct_index'] as num?)?.toInt() ?? 0,
      durationMs: (d['duration_ms'] as num?)?.toInt() ?? 20000,
      points: (d['points'] as num?)?.toInt() ?? 1000,
      explanation: d['explanation'] as String?,
      imageUrl: d['image_url'] as String?,
    );
  }
}

/// The live question as players see it — never carries the correct answer.
class BayanahLiveQuestion {
  final String questionId;
  final String question;
  final List<String> options;
  final int durationMs;
  final int points;
  final int index;
  final int total;
  final String? imageUrl;
  final int prepMs;

  const BayanahLiveQuestion({
    required this.questionId,
    required this.question,
    required this.options,
    required this.durationMs,
    required this.points,
    required this.index,
    required this.total,
    this.imageUrl,
    this.prepMs = 1500,
  });

  static BayanahLiveQuestion? fromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    return BayanahLiveQuestion(
      questionId: '${m['question_id'] ?? ''}',
      question: '${m['question'] ?? ''}',
      options: ((m['options'] as List?) ?? []).map((o) => '$o').toList(),
      durationMs: (m['duration_ms'] as num?)?.toInt() ?? 20000,
      points: (m['points'] as num?)?.toInt() ?? 1000,
      index: (m['index'] as num?)?.toInt() ?? 0,
      total: (m['total'] as num?)?.toInt() ?? 0,
      imageUrl: m['image_url'] as String?,
      prepMs: (m['prep_ms'] as num?)?.toInt() ?? 1500,
    );
  }
}

class BayanahReveal {
  final String questionId;
  final int correctIndex;
  final List<int> counts;
  final String? explanation;
  const BayanahReveal(this.questionId, this.correctIndex, this.counts, this.explanation);

  static BayanahReveal? fromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    return BayanahReveal(
      '${m['question_id'] ?? ''}',
      (m['correct_index'] as num?)?.toInt() ?? -1,
      ((m['counts'] as List?) ?? []).map((c) => (c as num).toInt()).toList(),
      m['explanation'] as String?,
    );
  }
}

class BayanahEvent {
  final String id;
  final String title;
  final String status; // draft | lobby | live | ended
  final String joinCode;
  final String? eventDate;
  final int playerCount;
  final int questionCount;
  final int currentIndex;
  final BayanahLiveQuestion? currentQuestion;
  final DateTime? questionStartedAt;
  final BayanahReveal? reveal;

  const BayanahEvent({
    required this.id,
    required this.title,
    required this.status,
    required this.joinCode,
    required this.eventDate,
    required this.playerCount,
    required this.questionCount,
    required this.currentIndex,
    required this.currentQuestion,
    required this.questionStartedAt,
    required this.reveal,
  });

  factory BayanahEvent.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return BayanahEvent(
      id: doc.id,
      title: '${d['title'] ?? 'Bayanah'}',
      status: '${d['status'] ?? 'draft'}',
      joinCode: '${d['join_code'] ?? ''}',
      eventDate: d['event_date'] as String?,
      playerCount: (d['player_count'] as num?)?.toInt() ?? 0,
      questionCount: (d['question_count'] as num?)?.toInt() ?? 0,
      currentIndex: (d['current_index'] as num?)?.toInt() ?? -1,
      currentQuestion: BayanahLiveQuestion.fromMap(
          (d['current_question'] as Map?)?.cast<String, dynamic>()),
      questionStartedAt: (d['question_started_at'] as Timestamp?)?.toDate(),
      reveal: BayanahReveal.fromMap(
          (d['reveal'] as Map?)?.cast<String, dynamic>()),
    );
  }
}

class BayanahPlayer {
  final String uid;
  final String displayName;
  final int totalPoints;
  final int bonusPoints;
  final int correctCount;
  final int answeredCount;
  final int streak;

  const BayanahPlayer({
    required this.uid,
    required this.displayName,
    required this.totalPoints,
    required this.bonusPoints,
    required this.correctCount,
    required this.answeredCount,
    required this.streak,
  });

  factory BayanahPlayer.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return BayanahPlayer(
      uid: doc.id,
      displayName: '${d['display_name'] ?? 'Student'}',
      totalPoints: (d['total_points'] as num?)?.toInt() ?? 0,
      bonusPoints: (d['bonus_points'] as num?)?.toInt() ?? 0,
      correctCount: (d['correct_count'] as num?)?.toInt() ?? 0,
      answeredCount: (d['answered_count'] as num?)?.toInt() ?? 0,
      streak: (d['streak'] as num?)?.toInt() ?? 0,
    );
  }
}

class BayanahService {
  final FirebaseFirestore _db;
  final FirebaseFunctions _fns;

  BayanahService({FirebaseFirestore? db, FirebaseFunctions? functions})
      : _db = db ?? FirebaseFirestore.instance,
        _fns = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  CollectionReference<Map<String, dynamic>> get _events =>
      _db.collection('bayanah_events');

  // ── Realtime streams (what makes every screen flip together) ──
  Stream<BayanahEvent> watchEvent(String eventId) =>
      _events.doc(eventId).snapshots().map(BayanahEvent.fromDoc);

  Stream<List<BayanahEvent>> watchEvents() => _events
      .orderBy('created_at', descending: true)
      .limit(25)
      .snapshots()
      .map((s) => s.docs.map(BayanahEvent.fromDoc).toList());

  Stream<List<BayanahQuestion>> watchQuestions(String eventId) => _events
      .doc(eventId)
      .collection('questions')
      .orderBy('order')
      .snapshots()
      .map((s) => s.docs.map(BayanahQuestion.fromDoc).toList());

  /// Leaderboard. Under ~50 players this is cheap to rank on the device.
  Stream<List<BayanahPlayer>> watchLeaderboard(String eventId) => _events
      .doc(eventId)
      .collection('players')
      .orderBy('total_points', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => s.docs.map(BayanahPlayer.fromDoc).toList());

  // ── Admin ──
  Future<String> createEvent({required String title, String? eventDate}) async {
    final res = await _fns.httpsCallable('createBayanahEvent').call<dynamic>({
      'title': title,
      if (eventDate != null) 'eventDate': eventDate,
    });
    return '${(res.data as Map)['eventId']}';
  }

  Future<void> saveQuestion({
    required String eventId,
    String? questionId,
    required String question,
    required List<String> options,
    required int correctIndex,
    required int durationMs,
    int points = 1000,
    String? explanation,
    String? imageUrl,
  }) async {
    await _fns.httpsCallable('saveBayanahQuestion').call<dynamic>({
      'eventId': eventId,
      if (questionId != null) 'questionId': questionId,
      'question': question,
      'options': options,
      'correctIndex': correctIndex,
      'durationMs': durationMs,
      'points': points,
      if (explanation != null && explanation.isNotEmpty) 'explanation': explanation,
      if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
    });
  }

  Future<void> deleteQuestion(String eventId, String questionId) =>
      _fns.httpsCallable('deleteBayanahQuestion').call<dynamic>({
        'eventId': eventId,
        'questionId': questionId,
      });


  /// Ask the AI for draft questions. Nothing is saved until the admin picks.
  Future<List<Map<String, dynamic>>> draftQuestions({
    String? eventId,
    required String topic,
    int count = 8,
    String ageGroup = 'children aged 8-12',
    String difficulty = 'easy',
  }) async {
    final res = await _fns.httpsCallable('draftBayanahQuestions').call<dynamic>({
      if (eventId != null) 'eventId': eventId,
      'topic': topic,
      'count': count,
      'ageGroup': ageGroup,
      'difficulty': difficulty,
    });
    final drafts = ((res.data as Map)['drafts'] as List?) ?? [];
    return drafts.map((d) => Map<String, dynamic>.from(d as Map)).toList();
  }

  /// Save several approved drafts in one go.
  Future<int> saveQuestionsBatch({
    required String eventId,
    required List<Map<String, dynamic>> questions,
  }) async {
    final res = await _fns.httpsCallable('saveBayanahQuestionsBatch').call<dynamic>({
      'eventId': eventId,
      'questions': questions,
    });
    return ((res.data as Map)['saved'] as num?)?.toInt() ?? 0;
  }

  /// Upload a question picture and return its permanent https URL.
  ///
  /// Uses raw bytes rather than a File so this works identically on the web
  /// admin console and on mobile.
  Future<String> uploadQuestionImage({
    required Uint8List bytes,
    required String fileName,
    String contentType = 'image/jpeg',
  }) async {
    final safe = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final ref = FirebaseStorage.instance
        .ref('bayanah_images/${DateTime.now().millisecondsSinceEpoch}_$safe');
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }

  // ── Host ──
  Future<void> setStatus(String eventId, String status) =>
      _fns.httpsCallable('setBayanahStatus').call<dynamic>({
        'eventId': eventId,
        'status': status,
      });

  Future<bool> nextQuestion(String eventId, {int? index}) async {
    final res = await _fns.httpsCallable('nextBayanahQuestion').call<dynamic>({
      'eventId': eventId,
      if (index != null) 'index': index,
    });
    return ((res.data as Map)['finished'] as bool?) ?? false;
  }

  Future<void> reveal(String eventId) =>
      _fns.httpsCallable('revealBayanahAnswer').call<dynamic>({'eventId': eventId});

  // ── Student ──
  Future<Map<String, dynamic>> join({String? joinCode, String? eventId}) async {
    final res = await _fns.httpsCallable('joinBayanah').call<dynamic>({
      if (joinCode != null) 'joinCode': joinCode,
      if (eventId != null) 'eventId': eventId,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// [elapsedMs] must be measured on THIS device from the moment the question
  /// appeared — that is what keeps network lag from costing the student points.
  Future<Map<String, dynamic>> submitAnswer({
    required String eventId,
    required String questionId,
    required int selectedIndex,
    required int elapsedMs,
  }) async {
    final res = await _fns.httpsCallable('submitBayanahAnswer').call<dynamic>({
      'eventId': eventId,
      'questionId': questionId,
      'selectedIndex': selectedIndex,
      'elapsedMs': elapsedMs,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// The open game a student can join without typing a code.
  Future<BayanahEvent?> findOpenEvent() async {
    final snap = await _events
        .where('status', whereIn: ['lobby', 'live'])
        .orderBy('created_at', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return BayanahEvent.fromDoc(snap.docs.first);
  }
}
