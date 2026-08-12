import 'package:cloud_functions/cloud_functions.dart';

class QuizReviewQueue {
  const QuizReviewQueue({
    required this.questions,
    required this.recentReviews,
    required this.canManageReviewers,
    required this.reviewerTeacherIds,
  });

  final List<Map<String, dynamic>> questions;
  final List<Map<String, dynamic>> recentReviews;
  final bool canManageReviewers;
  final List<String> reviewerTeacherIds;

  factory QuizReviewQueue.fromMap(Map<String, dynamic> data) {
    List<Map<String, dynamic>> mapsFor(String key) =>
        (data[key] as List? ?? const [])
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList();
    return QuizReviewQueue(
      questions: mapsFor('questions'),
      recentReviews: mapsFor('recentReviews'),
      canManageReviewers: data['canManageReviewers'] == true,
      reviewerTeacherIds: (data['reviewerTeacherIds'] as List? ?? const [])
          .map((uid) => uid.toString())
          .toList(),
    );
  }
}

class QuizReviewService {
  QuizReviewService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<QuizReviewQueue> loadQueue() async {
    final result = await _functions.httpsCallable('getQuizReviewQueue').call();
    return QuizReviewQueue.fromMap(
      Map<String, dynamic>.from(result.data as Map),
    );
  }

  Future<void> reviewQuestion({
    required String questionId,
    required String status,
    String? rejectionReason,
  }) =>
      _functions.httpsCallable('reviewQuizQuestion').call({
        'questionId': questionId,
        'status': status,
        if (rejectionReason != null) 'rejectionReason': rejectionReason,
      });

  Future<void> setReviewers(List<String> reviewerTeacherIds) => _functions
      .httpsCallable('setQuizReviewers')
      .call({'reviewerTeacherIds': reviewerTeacherIds});

  Future<void> sendReviewBatch() =>
      _functions.httpsCallable('sendQuizReviewBatchNow').call();

  Future<void> sendStudentApprovalBatch() =>
      _functions.httpsCallable('sendQuizStudentApprovalBatchNow').call();
}
