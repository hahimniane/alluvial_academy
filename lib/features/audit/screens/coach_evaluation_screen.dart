import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/teacher_audit_full.dart';
import '../services/teacher_audit_service.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// Windows 11 Fluent Design Colors
class Win11Colors {
  static const Color accent = Color(0xff0078D4);
  static const Color bg = Color(0xffF3F3F3);
  static const Color card = Colors.white;
  static const Color border = Color(0xffE5E5E5);
  static const Color textMain = Color(0xff1A1A1A);
  static const Color textSecondary = Color(0xff616161);
}

/// Side Panel for coach to fill 16-factor evaluation form (Windows 11 Fluent Design)
class CoachEvaluationScreen extends StatefulWidget {
  final TeacherAuditFull audit;
  final VoidCallback onSaved;

  const CoachEvaluationScreen({
    super.key,
    required this.audit,
    required this.onSaved,
  });

  @override
  State<CoachEvaluationScreen> createState() => _CoachEvaluationScreenState();
}

class _CoachEvaluationScreenState extends State<CoachEvaluationScreen> {
  static const _uuid = Uuid();
  late List<AuditFactor> _factors;
  late List<PaymentAdjustmentLine> _coachLines;
  late List<AdvancePayment> _advanceDraft;
  bool _isSubmitting = false;
  final Map<String, TextEditingController> _outcomeControllers = {};
  final Map<String, TextEditingController> _paycutControllers = {};
  final Map<String, TextEditingController> _actionPlanControllers = {};
  Map<String, int> _suggestedScores = {};
  bool _suggestionsLoaded = false;

  @override
  void initState() {
    super.initState();
    // Initialize factors from audit or use defaults
    _factors = widget.audit.auditFactors.isEmpty
        ? TeacherAuditFull.getDefaultAuditFactors()
        : widget.audit.auditFactors.map((f) => AuditFactor.fromMap(f.toMap())).toList();
    _coachLines = List<PaymentAdjustmentLine>.from(
        widget.audit.paymentSummary?.coachAdjustmentLines ?? const []);
    _advanceDraft = List<AdvancePayment>.from(
        widget.audit.paymentSummary?.advancePayments ?? const []);

    // Initialize controllers for text fields
    for (var factor in _factors) {
      _outcomeControllers[factor.id] = TextEditingController(text: factor.outcome);
      _paycutControllers[factor.id] = TextEditingController(text: factor.paycutRecommendation);
      _actionPlanControllers[factor.id] = TextEditingController(text: factor.coachActionPlan);
    }

    // Load form-based suggested scores (only if factors haven't been edited yet)
    final hasDefaultRatings = _factors.every((f) => f.rating == 5);
    if (hasDefaultRatings) {
      _loadSuggestedScores();
    }
  }

  Future<void> _loadSuggestedScores() async {
    try {
      final scores = await TeacherAuditService.getFormSuggestedScores(
        teacherName: widget.audit.teacherName,
        yearMonth: widget.audit.yearMonth,
      );
      if (mounted && scores.isNotEmpty) {
        setState(() {
          _suggestedScores = scores;
          _suggestionsLoaded = true;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    for (var controller in _outcomeControllers.values) {
      controller.dispose();
    }
    for (var controller in _paycutControllers.values) {
      controller.dispose();
    }
    for (var controller in _actionPlanControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submitEvaluation() async {
    setState(() => _isSubmitting = true);
    try {
      // Sync text controllers back to factors
      for (var i = 0; i < _factors.length; i++) {
        final factor = _factors[i];
        _factors[i] = factor.copyWith(
          outcome: _outcomeControllers[factor.id]?.text.trim() ?? '',
          paycutRecommendation: _paycutControllers[factor.id]?.text.trim() ?? '',
          coachActionPlan: _actionPlanControllers[factor.id]?.text.trim() ?? '',
        );
      }

      await TeacherAuditService.updateAuditFactors(
        auditId: widget.audit.id,
        factors: _factors,
        coachPaymentAdjustmentLines: _coachLines,
      );
      await TeacherAuditService.syncAuditAdvancePayments(
        auditId: widget.audit.id,
        advances: _advanceDraft,
      );

      if (mounted) {
        // Show success snackbar FIRST (before onSaved which reloads data)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.auditSubmittedSuccessfully),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        // Call onSaved which handles navigation and data refresh
        // NOTE: onSaved callback already calls Navigator.pop, so we don't call it here
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorE),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final applicable = _factors.where((f) => !f.isNotApplicable).toList();
    final totalScore = applicable.fold(0, (sum, f) => sum + f.rating);
    final maxScore = applicable.isEmpty ? 1 : applicable.length * 5;
    final percentageScore =
        maxScore > 0 ? (totalScore / maxScore) * 100 : 0.0;

    // Handle empty factors case - show loading or error state
    if (_factors.isEmpty) {
      return Material(
        color: Win11Colors.bg,
        child: Container(
          width: 550,
          decoration: const BoxDecoration(
            color: Win11Colors.bg,
            border: Border(left: BorderSide(color: Win11Colors.border, width: 1)),
          ),
          child: Column(
            children: [
              _buildPanelHeader(0, 0, 0),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(AppLocalizations.of(context)!.loadingEvaluationFactors),
                    ],
                  ),
                ),
              ),
              _buildStickyFooter(),
            ],
          ),
        ),
      );
    }

    return Material(
      color: Win11Colors.bg,
      child: SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Container(
          width: 550,
          decoration: const BoxDecoration(
            color: Win11Colors.bg,
            border: Border(left: BorderSide(color: Win11Colors.border, width: 1)),
          ),
          child: Column(
            children: [
              _buildPanelHeader(totalScore, maxScore, percentageScore),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _buildPaymentAdjustmentsCard(),
                    _buildAdvanceCard(),
                    ...List.generate(
                      _factors.length,
                      (index) => _buildFactorCard(_factors[index], index),
                    ),
                  ],
                ),
              ),
              _buildStickyFooter(),
            ],
          ),
        ),
        ),
      ),
    );
  }

  /// Panel Header with teacher info and score
  Widget _buildPanelHeader(int totalScore, int maxScore, double percentageScore) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Win11Colors.card,
        border: Border(bottom: BorderSide(color: Win11Colors.border, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.performanceEvaluation,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                        color: Win11Colors.textMain,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.audit.teacherName,
                      style: GoogleFonts.inter(
                        color: Win11Colors.accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Audit: ${widget.audit.yearMonth}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Win11Colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 20),
                color: Win11Colors.textSecondary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Score display
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getScoreColor(percentageScore).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _getScoreColor(percentageScore).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${AppLocalizations.of(context)!.overallScore}: ',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Win11Colors.textSecondary,
                  ),
                ),
                Text(
                  '$totalScore / $maxScore',
                  style: GoogleFonts.inter(
                    color: _getScoreColor(percentageScore),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${percentageScore.toStringAsFixed(0)}%)',
                  style: GoogleFonts.inter(
                    color: _getScoreColor(percentageScore).withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactorCard(AuditFactor factor, int index) {
    final needsAttention =
        !factor.isNotApplicable && factor.rating < 5;
    final outcomeController = _outcomeControllers[factor.id];
    final paycutController = _paycutControllers[factor.id];
    final actionPlanController = _actionPlanControllers[factor.id];

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Win11Colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: needsAttention ? Colors.orange.withOpacity(0.5) : Win11Colors.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with number and title
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Win11Colors.bg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Win11Colors.textMain,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      factor.title,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Win11Colors.textMain,
                      ),
                    ),
                    if (factor.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        factor.description,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Win11Colors.textSecondary,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilterChip(
              label: Text(AppLocalizations.of(context)!.auditFactorNaShort),
              selected: factor.isNotApplicable,
              onSelected: (v) {
                setState(() {
                  final idx = _factors.indexWhere((f) => f.id == factor.id);
                  if (idx != -1) {
                    _factors[idx] = factor.copyWith(isNotApplicable: v);
                  }
                });
              },
            ),
          ),
          const SizedBox(height: 12),
          // Quick Rating Selector (0-5 horizontal bar)
          _buildFieldLabel('Rating (0 to 5)'),
          const SizedBox(height: 8),
          _buildRatingBar(factor),

          // Show form-based suggestion if available
          if (_suggestedScores.containsKey(factor.id)) ...[
            const SizedBox(height: 8),
            _buildSuggestionChip(factor),
          ],

          const SizedBox(height: 16),
          _buildFieldLabel('OBSERVATIONS'),
          _buildTextField(
            outcomeController!,
            'Explain your rating...',
            maxLines: 3,
          ),

          // Conditional: Show paycut and action plan if rating < 5
          if (needsAttention) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.requiredForRatingsBelow9,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    paycutController!,
                    'Payment impact (e.g., -10%)',
                    isSmall: true,
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    actionPlanController!,
                    'Corrective action plan...',
                    isSmall: true,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static const _ratingLabels = [
    'Critical',
    'Below',
    'Meets',
    'Good',
    'Excellent',
    'Outstanding',
  ];

  /// Suggestion chip from form data
  Widget _buildSuggestionChip(AuditFactor factor) {
    final suggested = _suggestedScores[factor.id]!;
    final isApplied = factor.rating == suggested;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isApplied ? Colors.green.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isApplied ? Colors.green.shade200 : Colors.blue.shade200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isApplied ? Icons.check_circle : Icons.lightbulb_outline,
            size: 14,
            color: isApplied ? Colors.green.shade700 : Colors.blue.shade700,
          ),
          const SizedBox(width: 6),
          Text(
            '${AppLocalizations.of(context)!.coachEvalSuggestedScore}: $suggested/5',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: isApplied ? Colors.green.shade700 : Colors.blue.shade700,
            ),
          ),
          if (!isApplied) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: () {
                setState(() {
                  final idx = _factors.indexWhere((f) => f.id == factor.id);
                  if (idx != -1) {
                    _factors[idx] = factor.copyWith(rating: suggested);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  AppLocalizations.of(context)!.coachEvalApplySuggestion,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade800,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Quick Rating Selector - Horizontal bar 0-5 (Windows 11 style)
  Widget _buildRatingBar(AuditFactor factor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (i) {
        final score = i;
        final isSelected = factor.rating == score;
        return InkWell(
          onTap: factor.isNotApplicable
              ? null
              : () {
                  setState(() {
                    final idx = _factors.indexWhere((f) => f.id == factor.id);
                    if (idx != -1) {
                      _factors[idx] = factor.copyWith(rating: score);
                    }
                  });
                },
          borderRadius: BorderRadius.circular(4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 72,
            height: 50,
            decoration: BoxDecoration(
              color: factor.isNotApplicable
                  ? Win11Colors.bg.withOpacity(0.5)
                  : (isSelected ? Win11Colors.accent : Win11Colors.bg),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isSelected ? Win11Colors.accent : Win11Colors.border,
                width: 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$score',
                  style: GoogleFonts.inter(
                    color: isSelected ? Colors.white : Win11Colors.textMain,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                Text(
                  _ratingLabels[score],
                  style: GoogleFonts.inter(
                    color: isSelected ? Colors.white70 : Win11Colors.textSecondary,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildPaymentAdjustmentsCard() {
    final loc = AppLocalizations.of(context)!;
    final ps = widget.audit.paymentSummary;
    var previewNet = 0.0;
    if (ps != null) {
      final tmp = ps.copyWith(
        coachAdjustmentLines: _coachLines,
        advancePayments: _advanceDraft,
      );
      previewNet = tmp.netAfterAdvances();
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Win11Colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Win11Colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.auditCoachPaymentAdjustmentsTitle,
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 8),
          if (ps != null)
            Text(
              '${loc.auditNetAfterAdjustmentsHint}: \$${previewNet.toStringAsFixed(2)}',
              style: GoogleFonts.inter(
                  fontSize: 12, color: Win11Colors.textSecondary),
            ),
          const SizedBox(height: 12),
          ..._coachLines.map((l) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${l.type} \$${l.amount.toStringAsFixed(2)} — ${l.reason}',
                  style: GoogleFonts.inter(fontSize: 12),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => setState(() => _coachLines.remove(l)),
                ),
              )),
          TextButton.icon(
            onPressed: _isSubmitting ? null : _onAddCoachLine,
            icon: const Icon(Icons.add, size: 18),
            label: Text(loc.auditAddPaymentLine),
          ),
        ],
      ),
    );
  }

  Future<void> _onAddCoachLine() async {
    final loc = AppLocalizations.of(context)!;
    var type = 'penalty';
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setD) => AlertDialog(
          title: Text(loc.auditAddPaymentLine),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: type,
                decoration: InputDecoration(labelText: loc.auditPaymentLineTypeLabel),
                items: [
                  DropdownMenuItem(value: 'penalty', child: Text(loc.auditPaymentLinePenalty)),
                  DropdownMenuItem(value: 'bonus', child: Text(loc.auditPaymentLineBonus)),
                ],
                onChanged: (v) => setD(() => type = v ?? 'penalty'),
              ),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: loc.auditAmountLabel),
              ),
              TextField(
                controller: reasonCtrl,
                decoration: InputDecoration(labelText: loc.auditReasonLabel),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(loc.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(loc.commonOk),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    final amt = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0;
    if (amt <= 0) return;
    setState(() {
      _coachLines.add(PaymentAdjustmentLine(
        id: _uuid.v4(),
        type: type,
        amount: amt,
        reason: reasonCtrl.text.trim().isEmpty ? '—' : reasonCtrl.text.trim(),
        factorId: null,
        createdAt: DateTime.now(),
        createdById: u.uid,
        createdByName: u.displayName ?? u.email ?? u.uid,
      ));
    });
  }

  Widget _buildAdvanceCard() {
    final loc = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Win11Colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Win11Colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.auditAdvanceSectionTitle,
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            loc.auditAdvanceSectionSubtitle,
            style: GoogleFonts.inter(fontSize: 11, color: Win11Colors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _isSubmitting
                ? null
                : () async {
                    final list =
                        await TeacherAuditService.fetchAdvancePaymentSubmissions(
                      userId: widget.audit.oderId,
                      yearMonth: widget.audit.yearMonth,
                    );
                    if (mounted) setState(() => _advanceDraft = list);
                  },
            icon: const Icon(Icons.cloud_download_outlined, size: 18),
            label: Text(loc.auditAdvanceLoadFromForms),
          ),
          ..._advanceDraft.map((a) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '\$${a.amount.toStringAsFixed(2)} · ${a.formResponseId}',
                  style: GoogleFonts.inter(fontSize: 12),
                ),
                subtitle: Text(
                  DateFormat.yMMMd().format(a.submittedAt),
                  style: GoogleFonts.inter(fontSize: 10),
                ),
              )),
        ],
      ),
    );
  }

  /// Sticky Footer with Submit button
  Widget _buildStickyFooter() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Win11Colors.card,
        border: Border(top: BorderSide(color: Win11Colors.border, width: 1)),
      ),
      child: Row(
        children: [
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppLocalizations.of(context)!.commonCancel,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
                color: Win11Colors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submitEvaluation,
            style: ElevatedButton.styleFrom(
              backgroundColor: Win11Colors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    AppLocalizations.of(context)!.submitEvaluation,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Helper: Field Label
  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Win11Colors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// Helper: Text Field (Windows 11 style)
  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    bool isSmall = false,
    int maxLines = 3,
  }) {
    return TextField(
      controller: controller,
      maxLines: isSmall ? 1 : maxLines,
      style: GoogleFonts.inter(
        fontSize: 13,
        color: Win11Colors.textMain,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
          fontSize: 13,
          color: Win11Colors.textSecondary,
        ),
        filled: true,
        fillColor: Win11Colors.bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Win11Colors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Win11Colors.accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Color _getRatingColor(int rating) {
    if (rating >= 4) return Colors.green.shade700;
    if (rating >= 3) return Colors.orange.shade700;
    return Colors.red.shade700;
  }

  Color _getScoreColor(double percentage) {
    if (percentage >= 90) return Colors.green.shade700;
    if (percentage >= 70) return Colors.orange.shade700;
    return Colors.red.shade700;
  }
}
