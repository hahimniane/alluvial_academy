import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';
import '../models/quiz_category.dart';
import '../services/quiz_review_service.dart';
import 'admin_quiz_competition_screen.dart';

/// Admin screen to approve or reject AI-generated quiz questions.
/// Only approved questions ever reach students.
class AdminQuizReviewScreen extends StatefulWidget {
  const AdminQuizReviewScreen({super.key});

  @override
  State<AdminQuizReviewScreen> createState() => _AdminQuizReviewScreenState();
}

class _AdminQuizReviewScreenState extends State<AdminQuizReviewScreen> {
  bool _generating = false;
  bool _sendingBatch = false;
  final QuizReviewService _reviewService = QuizReviewService();
  late Future<QuizReviewQueue> _queueFuture;

  @override
  void initState() {
    super.initState();
    _queueFuture = _reviewService.loadQueue();
  }

  void _reloadQueue() {
    setState(() => _queueFuture = _reviewService.loadQueue());
  }

  Future<void> _setStatus(
    String questionId,
    String status, {
    String? rejectionReason,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await _reviewService.reviewQuestion(
        questionId: questionId,
        status: status,
        rejectionReason: rejectionReason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(status == 'approved'
            ? l10n.quizReviewApprovedSnack
            : l10n.quizReviewRejectedSnack),
      ));
      _reloadQueue();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.quizReviewActionFailed(e.toString()))),
      );
    }
  }

  Future<void> _rejectQuestion(String questionId) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    var showRequiredError = false;
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.quizReviewRejectionReasonTitle),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: l10n.quizReviewRejectionReasonLabel,
              hintText: l10n.quizReviewRejectionReasonHint,
              errorText: showRequiredError
                  ? l10n.quizReviewRejectionReasonRequired
                  : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.quizCompetitionCancel),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) {
                  setDialogState(() => showRequiredError = true);
                  return;
                }
                Navigator.pop(dialogContext, value);
              },
              child: Text(l10n.quizReviewConfirmRejection),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (reason == null) return;
    await _setStatus(questionId, 'rejected', rejectionReason: reason);
  }

  Future<void> _sendStudentBatch() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _sendingBatch = true);
    try {
      await _reviewService.sendStudentApprovalBatch();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.quizReviewStudentBatchSent)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.quizReviewActionFailed(error.toString()))),
      );
    } finally {
      if (mounted) setState(() => _sendingBatch = false);
    }
  }

  Future<void> _manageReviewers(List<String> currentIds) async {
    final l10n = AppLocalizations.of(context)!;
    final teachers = await FirebaseFirestore.instance
        .collection('users')
        .where('user_type', isEqualTo: 'teacher')
        .get();
    if (!mounted) return;
    final selected = currentIds.toSet();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.quizReviewManageReviewers),
          content: SizedBox(
            width: 420,
            child: ListView(
              shrinkWrap: true,
              children: teachers.docs
                  .where((teacher) => teacher.data()['is_active'] != false)
                  .map((teacher) {
                final data = teacher.data();
                final name = [data['first_name'], data['last_name']]
                    .whereType<String>()
                    .where((part) => part.trim().isNotEmpty)
                    .join(' ');
                return CheckboxListTile(
                  value: selected.contains(teacher.id),
                  title: Text(name.isEmpty ? teacher.id : name),
                  subtitle:
                      data['email'] is String ? Text(data['email']) : null,
                  onChanged: (value) => setDialogState(() {
                    if (value == true) {
                      selected.add(teacher.id);
                    } else {
                      selected.remove(teacher.id);
                    }
                  }),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.quizCompetitionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.quizReviewSaveReviewers),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      await _reviewService.setReviewers(selected.toList());
      await _reviewService.sendReviewBatch();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.quizReviewReviewersSaved)),
      );
      _reloadQueue();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.quizReviewActionFailed(error.toString()))),
      );
    }
  }

  Future<void> _generateNow() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _generating = true);
    try {
      await FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('generateQuizQuestionsNow')
          .call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.quizReviewGenerateStarted)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.quizReviewActionFailed(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: ScrollNotificationObserver(
        child: SelectionArea(
          child: FutureBuilder<QuizReviewQueue>(
            future: _queueFuture,
            builder: (context, snapshot) {
          final questions = (snapshot.data?.questions ?? []).toList()
            ..sort((a, b) {
              final aTime = a['created_at'];
              final bTime = b['created_at'];
              if (aTime is Timestamp && bTime is Timestamp) {
                return bTime.compareTo(aTime);
              }
              return 0;
            });

              return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(
                l10n,
                questions.length,
                snapshot.data?.canManageReviewers ?? false,
                snapshot.data?.reviewerTeacherIds ?? const [],
              ),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Expanded(
                    child: Center(child: CircularProgressIndicator()))
              else if (snapshot.hasError)
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l10n.quizReviewAccessRequired,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(color: Colors.grey[600]),
                      ),
                    ),
                  ),
                )
              else if (questions.isEmpty)
                Expanded(
                  child: _buildEmptyState(
                    l10n,
                    snapshot.data?.recentReviews ?? const [],
                  ),
                )
              else
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    children: [
                      ...questions.map(
                        (question) => _buildQuestionCard(l10n, question),
                      ),
                      if ((snapshot.data?.recentReviews ?? []).isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          l10n.quizReviewRecentDecisions,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...snapshot.data!.recentReviews
                            .map((review) => ListTile(
                                  dense: true,
                                  title:
                                      Text(review['question'] as String? ?? ''),
                                  subtitle: Text(l10n.quizReviewDecisionBy(
                                    review['status'] as String? ?? '',
                                    review['reviewerName'] as String? ?? '',
                                    review['reviewerRole'] as String? ?? '',
                                  )),
                                )),
                      ],
                    ],
                  ),
                ),
            ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    AppLocalizations l10n,
    int pendingCount,
    bool canManageReviewers,
    List<String> reviewerTeacherIds,
  ) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.quizReviewTitle,
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.quizReviewPendingCount(pendingCount),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          if (canManageReviewers) ...[
            ElevatedButton.icon(
              onPressed: _generating ? null : _generateNow,
              icon: _generating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text(l10n.quizReviewGenerate),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
            const SizedBox(width: 12),
          ],
          if (canManageReviewers)
            OutlinedButton.icon(
              onPressed: _sendingBatch ? null : _sendStudentBatch,
              icon: _sendingBatch
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.notifications_active_outlined, size: 18),
              label: Text(l10n.quizReviewSendStudentBatch),
            ),
          if (canManageReviewers) const SizedBox(width: 12),
          if (canManageReviewers)
            OutlinedButton.icon(
              onPressed: () => _manageReviewers(reviewerTeacherIds),
              icon: const Icon(Icons.people_outline, size: 18),
              label: Text(l10n.quizReviewManageReviewers),
            ),
          if (canManageReviewers) const SizedBox(width: 12),
          if (canManageReviewers)
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const AdminQuizCompetitionScreen(),
                ),
              ),
              icon: const Icon(Icons.emoji_events_rounded, size: 18),
              label: Text(l10n.quizCompetitionAdminTitle),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    AppLocalizations l10n,
    List<Map<String, dynamic>> recentReviews,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fact_check_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            l10n.quizReviewEmpty,
            style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600]),
          ),
          if (recentReviews.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              l10n.quizReviewRecentDecisions,
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...recentReviews.map((review) => Text(
                  l10n.quizReviewDecisionBy(
                    review['status'] as String? ?? '',
                    review['reviewerName'] as String? ?? '',
                    review['reviewerRole'] as String? ?? '',
                  ),
                  style: GoogleFonts.inter(fontSize: 12),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestionCard(AppLocalizations l10n, Map<String, dynamic> data) {
    final question = data['question'] as String? ?? '';
    final options = (data['options'] as List?)?.cast<String>() ?? const [];
    final correctIndex = data['correctAnswer'] as int? ?? 0;
    final explanation = data['explanation'] as String? ?? '';
    final difficulty = data['difficulty'] as String? ?? 'easy';
    final categoryId = data['category'] as String? ?? '';
    final category = QuizCategory.defaultCategories
        .where((c) => c.id == categoryId)
        .toList();
    final categoryName = category.isNotEmpty ? category.first.name : categoryId;
    final categoryColor =
        category.isNotEmpty ? category.first.color : Colors.blueGrey;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _chip(categoryName, categoryColor),
              const SizedBox(width: 8),
              _chip(difficulty, _difficultyColor(difficulty)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            question,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(options.length, (index) {
            final isCorrect = index == correctIndex;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    isCorrect
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked,
                    size: 18,
                    color:
                        isCorrect ? const Color(0xFF10B981) : Colors.grey[400],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      options[index],
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight:
                            isCorrect ? FontWeight.w600 : FontWeight.w400,
                        color: isCorrect
                            ? const Color(0xFF065F46)
                            : const Color(0xFF374151),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (explanation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              explanation,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: Colors.grey[600],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => _rejectQuestion(data['id'] as String? ?? ''),
                icon: const Icon(Icons.close_rounded, size: 18),
                label: Text(l10n.quizReviewReject),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFEF4444)),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () =>
                    _setStatus(data['id'] as String? ?? '', 'approved'),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text(l10n.quizReviewApprove),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Color _difficultyColor(String difficulty) {
    switch (difficulty) {
      case 'hard':
        return const Color(0xFFEF4444);
      case 'medium':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF10B981);
    }
  }
}
