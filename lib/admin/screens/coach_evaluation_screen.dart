import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/teacher_audit_full.dart';
import '../../core/services/teacher_audit_service.dart';

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
  late List<AuditFactor> _factors;
  bool _isSubmitting = false;
  final Map<String, TextEditingController> _outcomeControllers = {};
  final Map<String, TextEditingController> _paycutControllers = {};
  final Map<String, TextEditingController> _actionPlanControllers = {};

  @override
  void initState() {
    super.initState();
    // Initialize factors from audit or use defaults
    _factors = widget.audit.auditFactors.isEmpty
        ? TeacherAuditFull.getDefaultAuditFactors()
        : widget.audit.auditFactors.map((f) => AuditFactor.fromMap(f.toMap())).toList();

    // Initialize controllers for text fields
    for (var factor in _factors) {
      _outcomeControllers[factor.id] = TextEditingController(text: factor.outcome);
      _paycutControllers[factor.id] = TextEditingController(text: factor.paycutRecommendation);
      _actionPlanControllers[factor.id] = TextEditingController(text: factor.coachActionPlan);
    }
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
      );

      if (mounted) {
        // Show success snackbar FIRST (before onSaved which reloads data)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Audit submitted successfully!'),
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
            content: Text('Error: $e'),
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
    final totalScore = _factors.fold(0, (sum, f) => sum + f.rating);
    final maxScore = _factors.length * 9;
    final percentageScore = maxScore > 0 ? (totalScore / maxScore) * 100 : 0.0;

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
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading evaluation factors...'),
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
        child: Container(
          width: 550, // Fixed width for Side Panel
          decoration: const BoxDecoration(
            color: Win11Colors.bg,
            border: Border(left: BorderSide(color: Win11Colors.border, width: 1)),
          ),
          child: Column(
            children: [
              _buildPanelHeader(totalScore, maxScore, percentageScore),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: _factors.length,
                  itemBuilder: (context, index) => _buildFactorCard(_factors[index], index),
                ),
              ),
              _buildStickyFooter(),
            ],
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
                      'Performance Evaluation',
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
                  'Score: ',
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
    final needsAttention = factor.rating < 9;
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
          const SizedBox(height: 16),
          
          // Quick Rating Selector (1-9 horizontal bar)
          _buildFieldLabel('Rating (1 to 9)'),
          const SizedBox(height: 8),
          _buildRatingBar(factor),

          const SizedBox(height: 16),
          _buildFieldLabel('OBSERVATIONS'),
          _buildTextField(
            outcomeController!,
            'Explain your rating...',
            maxLines: 3,
          ),

          // Conditional: Show paycut and action plan if rating < 9
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
                    'Required: Rating below 9',
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

  /// Quick Rating Selector - Horizontal bar 1-9 (Windows 11 style)
  Widget _buildRatingBar(AuditFactor factor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(9, (i) {
        final score = i + 1;
        final isSelected = factor.rating == score;
        return InkWell(
          onTap: () {
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
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isSelected ? Win11Colors.accent : Win11Colors.bg,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isSelected ? Win11Colors.accent : Win11Colors.border,
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                '$score',
                style: GoogleFonts.inter(
                  color: isSelected ? Colors.white : Win11Colors.textMain,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        );
      }),
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
              'Cancel',
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
                    'Submit Evaluation',
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
    if (rating >= 8) return Colors.green.shade700;
    if (rating >= 5) return Colors.orange.shade700;
    return Colors.red.shade700;
  }

  Color _getScoreColor(double percentage) {
    if (percentage >= 90) return Colors.green.shade700;
    if (percentage >= 70) return Colors.orange.shade700;
    return Colors.red.shade700;
  }
}
