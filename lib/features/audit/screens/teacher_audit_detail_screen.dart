import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/teacher_audit_full.dart';
import '../../../core/services/teacher_audit_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// Teacher's detailed audit view with ability to dispute/edit
class TeacherAuditDetailScreen extends StatefulWidget {
  final String? yearMonth; // If null, defaults to current month

  const TeacherAuditDetailScreen({super.key, this.yearMonth});

  @override
  State<TeacherAuditDetailScreen> createState() => _TeacherAuditDetailScreenState();
}

class _TeacherAuditDetailScreenState extends State<TeacherAuditDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  TeacherAuditFull? _audit;
  bool _isLoading = true;
  String _selectedYearMonth = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _selectedYearMonth = widget.yearMonth ?? DateFormat('yyyy-MM').format(DateTime.now());
    _loadAudit();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAudit() async {
    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Try to get existing audit first
      var audit = await TeacherAuditService.getMyAudit(
        yearMonth: _selectedYearMonth,
      );

      // IMPORTANT: Teachers can only see their audit when it's completed (finalized)
      // They should NOT see audits that are still pending, in review, or coachSubmitted
      if (audit != null && audit.status != AuditStatus.completed) {
        // Audit exists but is not finalized yet - don't show it to teacher
        setState(() {
          _audit = null; // Don't show incomplete audits
          _isLoading = false;
        });
        return;
      }

      // If no audit exists or it's not completed, don't compute one
      // Teachers should only see finalized audits
      if (audit == null) {
        setState(() {
          _audit = null;
          _isLoading = false;
        });
        return;
      }

      // Verify that the audit belongs to the current user (security check)
      if (audit.oderId != user.uid) {
        // Security: Teacher trying to access another teacher's audit
        setState(() {
          _audit = null;
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _audit = audit;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _selectMonth() async {
    final now = DateTime.now();
    final months = List.generate(12, (i) {
      final date = DateTime(now.year, now.month - i);
      return DateFormat('yyyy-MM').format(date);
    });

    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(AppLocalizations.of(context)!.formSelectMonth),
        children: months.map((m) {
          final date = DateTime.parse('$m-01');
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, m),
            child: Text(
              DateFormat('MMMM yyyy').format(date),
              style: TextStyle(
                fontWeight: m == _selectedYearMonth ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );

    if (selected != null && selected != _selectedYearMonth) {
      setState(() => _selectedYearMonth = selected);
      _loadAudit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.myMonthlyReport,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton.icon(
            onPressed: _selectMonth,
            icon: const Icon(Icons.calendar_month),
            label: Text(
              DateFormat('MMM yyyy').format(DateTime.parse('$_selectedYearMonth-01')),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAudit,
            tooltip: AppLocalizations.of(context)!.commonRefresh,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(text: AppLocalizations.of(context)!.overview, icon: Icon(Icons.dashboard)),
            Tab(text: AppLocalizations.of(context)!.dashboardClasses, icon: Icon(Icons.school)),
            Tab(text: AppLocalizations.of(context)!.navForms, icon: Icon(Icons.assignment)),
            Tab(text: AppLocalizations.of(context)!.payment, icon: Icon(Icons.payments)),
            Tab(text: AppLocalizations.of(context)!.dispute, icon: Icon(Icons.edit_note)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _audit == null
              ? _buildNoAudit()
              : _audit!.status != AuditStatus.completed
                  ? _buildAuditNotFinalized()
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _OverviewTab(audit: _audit!),
                        _ClassesTab(audit: _audit!),
                        _FormsTab(audit: _audit!),
                        _PaymentTab(audit: _audit!),
                        _DisputeTab(audit: _audit!, onSubmit: _loadAudit),
                      ],
                    ),
    );
  }

  Widget _buildNoAudit() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assessment_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No audit data for ${DateFormat('MMMM yyyy').format(DateTime.parse('$_selectedYearMonth-01'))}',
            style: GoogleFonts.inter(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.yourAuditReportWillBeAvailable,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditNotFinalized() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hourglass_empty, size: 64, color: Colors.orange.shade400),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.auditUnderReview,
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          Text(
            'Your audit for ${DateFormat('MMMM yyyy').format(DateTime.parse('$_selectedYearMonth-01'))} is currently being reviewed.\n\nYou will be able to view it once it has been finalized.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

/// Overview tab showing summary
class _OverviewTab extends StatelessWidget {
  final TeacherAuditFull audit;

  const _OverviewTab({required this.audit});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall score card
          _buildScoreCard(context),
          const SizedBox(height: 24),

          // Hours by Subject section
          if (audit.hoursTaughtBySubject.isNotEmpty) ...[
            Text(
              AppLocalizations.of(context)!.hoursBySubject,
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _buildHoursBySubject(),
            const SizedBox(height: 24),
          ],

          // Metrics grid
          _buildMetricsGrid(context),
          const SizedBox(height: 24),

          // Detailed metrics sections
          _buildDetailedMetrics(context),
          const SizedBox(height: 24),

          // Issues section
          if (audit.issues.isNotEmpty) ...[
            Text(
              AppLocalizations.of(context)!.issuesFlags,
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ...audit.issues.map((issue) => _buildIssueCard(issue)),
          ],
        ],
      ),
    );
  }

  Widget _buildScoreCard(BuildContext context) {
    Color tierColor;
    IconData tierIcon;

    switch (audit.performanceTier) {
      case 'excellent':
        tierColor = Colors.green;
        tierIcon = Icons.emoji_events;
        break;
      case 'good':
        tierColor = Colors.blue;
        tierIcon = Icons.thumb_up;
        break;
      case 'needsImprovement':
        tierColor = Colors.orange;
        tierIcon = Icons.trending_up;
        break;
      default:
        tierColor = Colors.red;
        tierIcon = Icons.warning;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tierColor.withOpacity(0.1), tierColor.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tierColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tierColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(tierIcon, size: 48, color: tierColor),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.overallScore,
                  style: GoogleFonts.inter(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${audit.overallScore.toStringAsFixed(1)}%',
                  style: GoogleFonts.inter(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: tierColor,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: tierColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    audit.performanceTier.toUpperCase(),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHoursBySubject() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: audit.hoursTaughtBySubject.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    entry.key,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '${entry.value.toStringAsFixed(1)}h',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDetailedMetrics(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Schedule section
        Text(
          AppLocalizations.of(context)!.shiftSchedule,
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildDetailRow(context, 'Scheduled', '${audit.totalClassesScheduled}'),
                _buildDetailRow(context, 'Completed', '${audit.totalClassesCompleted}'),
                _buildDetailRow(context, 'Missed', '${audit.totalClassesMissed}'),
                const Divider(height: 24),
                _buildDetailRow(
                  context,
                  'Completion Rate',
                  '${audit.completionRate.toStringAsFixed(1)}%',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Punctuality section
        Text(
          AppLocalizations.of(context)!.punctuality,
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildDetailRow(context, 'Total Clock-Ins', '${audit.totalClockIns}'),
                _buildDetailRow(context, 'On-Time', '${audit.onTimeClockIns}'),
                _buildDetailRow(context, 'Late', '${audit.lateClockIns}'),
                const Divider(height: 24),
                _buildDetailRow(
                  context,
                  'Punctuality Rate',
                  '${audit.punctualityRate.toStringAsFixed(1)}%',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Form Compliance section
        Text(
          AppLocalizations.of(context)!.formCompliance,
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildDetailRow(context, 'Required', '${audit.readinessFormsRequired}'),
                _buildDetailRow(context, 'Submitted', '${audit.readinessFormsSubmitted}'),
                const Divider(height: 24),
                _buildDetailRow(
                  context,
                  'Compliance Rate',
                  '${audit.formComplianceRate.toStringAsFixed(1)}%',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _localizeDetailLabel(String label, AppLocalizations l10n) {
    switch (label) {
      case 'Scheduled':
        return l10n.auditScheduled;
      case 'Completed':
        return l10n.auditCompleted;
      case 'Missed':
        return l10n.auditMissed;
      case 'Completion Rate':
        return l10n.auditCompletionRate;
      case 'Total Clock-Ins':
        return l10n.auditTotalClockIns;
      case 'On-Time':
        return l10n.auditOnTime;
      case 'Late':
        return l10n.auditLate;
      case 'Punctuality Rate':
        return l10n.auditPunctualityRate;
      case 'Required':
        return l10n.auditRequired;
      case 'Submitted':
        return l10n.auditSubmitted;
      case 'Compliance Rate':
        return l10n.auditComplianceRate;
      default:
        return label;
    }
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _localizeDetailLabel(label, l10n),
            style: GoogleFonts.inter(color: Colors.grey.shade600),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.3,
      children: [
        _MetricCard(
          title: AppLocalizations.of(context)!.classesCompleted,
          value: '${audit.totalClassesCompleted}/${audit.totalClassesScheduled}',
          subtitle: AppLocalizations.of(context)!
              .auditCompletionPercent(audit.completionRate.toStringAsFixed(0)),
          icon: Icons.school,
          color: Colors.green,
        ),
        _MetricCard(
          title: AppLocalizations.of(context)!.hoursTaught,
          value: '${audit.totalHoursTaught.toStringAsFixed(1)}h',
          subtitle: AppLocalizations.of(context)!
              .auditSubjectsCount(audit.hoursTaughtBySubject.length),
          icon: Icons.schedule,
          color: Colors.blue,
        ),
        _MetricCard(
          title: AppLocalizations.of(context)!.punctuality,
          value: '${audit.punctualityRate.toStringAsFixed(0)}%',
          subtitle: AppLocalizations.of(context)!
              .auditOnTimeClockIns(audit.onTimeClockIns, audit.totalClockIns),
          icon: Icons.timer,
          color: audit.punctualityRate >= 80 ? Colors.green : Colors.orange,
        ),
        _MetricCard(
          title: AppLocalizations.of(context)!.navForms,
          value: '${audit.readinessFormsSubmitted}/${audit.readinessFormsRequired}',
          subtitle: AppLocalizations.of(context)!
              .auditCompliancePercent(audit.formComplianceRate.toStringAsFixed(0)),
          icon: Icons.assignment,
          color: audit.formComplianceRate >= 80 ? Colors.green : Colors.orange,
        ),
      ],
    );
  }

  Widget _buildIssueCard(AuditIssue issue) {
    Color severityColor;
    switch (issue.severity) {
      case 'high':
        severityColor = Colors.red;
        break;
      case 'medium':
        severityColor = Colors.orange;
        break;
      default:
        severityColor = Colors.yellow.shade700;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: severityColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: severityColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            issue.severity == 'high' ? Icons.error : Icons.warning,
            color: severityColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  issue.type.replaceAll('_', ' ').toUpperCase(),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: severityColor,
                  ),
                ),
                Text(
                  issue.description,
                  style: GoogleFonts.inter(),
                ),
              ],
            ),
          ),
          if (issue.penaltyAmount != null && issue.penaltyAmount! > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '-\$${issue.penaltyAmount!.toStringAsFixed(2)}',
                style: GoogleFonts.inter(
                  color: Colors.red.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Metric card widget
class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Classes tab showing detailed shift info
class _ClassesTab extends StatelessWidget {
  final TeacherAuditFull audit;

  const _ClassesTab({required this.audit});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('teaching_shifts')
          .where('teacher_id', isEqualTo: audit.oderId)
          .orderBy('shift_start', descending: true)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              AppLocalizations.of(context)!.noClassesFound,
              style: GoogleFonts.inter(color: Colors.grey),
            ),
          );
        }

        // Filter by month
        final parts = audit.yearMonth.split('-');
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final startDate = DateTime(year, month, 1);
        final endDate = DateTime(year, month + 1, 0);

        final shifts = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final shiftStart = (data['shift_start'] as Timestamp).toDate();
          return shiftStart.isAfter(startDate.subtract(const Duration(days: 1))) &&
              shiftStart.isBefore(endDate.add(const Duration(days: 1)));
        }).toList();
        
        // Sort shifts by start date (oldest first) for chronological order
        shifts.sort((a, b) {
          final aStart = (a.data() as Map<String, dynamic>)['shift_start'] as Timestamp;
          final bStart = (b.data() as Map<String, dynamic>)['shift_start'] as Timestamp;
          return aStart.toDate().compareTo(bStart.toDate());
        });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: shifts.length,
          itemBuilder: (context, index) {
            final data = shifts[index].data() as Map<String, dynamic>;
            return _ShiftCard(
              shiftId: shifts[index].id,
              data: data,
            );
          },
        );
      },
    );
  }
}

class _ShiftCard extends StatefulWidget {
  final String shiftId;
  final Map<String, dynamic> data;

  const _ShiftCard({required this.shiftId, required this.data});

  @override
  State<_ShiftCard> createState() => _ShiftCardState();
}

class _ShiftCardState extends State<_ShiftCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final shiftStart = (widget.data['shift_start'] as Timestamp).toDate();
    final shiftEnd = (widget.data['shift_end'] as Timestamp).toDate();
    final status = widget.data['status'] as String? ?? 'scheduled';
    final subject = widget.data['subject_display_name'] as String? ??
        widget.data['subject'] as String? ??
        AppLocalizations.of(context)!.commonUnknown;
    final studentNames = (widget.data['student_names'] as List<dynamic>?)?.cast<String>() ?? [];

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'fullyCompleted':
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'missed':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case 'cancelled':
        statusColor = Colors.grey;
        statusIcon = Icons.block;
        break;
      default:
        statusColor = Colors.blue;
        statusIcon = Icons.schedule;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withOpacity(0.3)),
      ),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(statusIcon, color: statusColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          DateFormat('EEE, MMM d • h:mm a').format(shiftStart),
                          style: GoogleFonts.inter(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      status.replaceAll('Completed', '').replaceAll('fully', 'Completed'),
                      style: GoogleFonts.inter(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
                  ),
                ],
              ),
              if (_expanded) ...[
                const Divider(height: 24),
                _buildDetailRow('Duration', '${shiftEnd.difference(shiftStart).inMinutes} minutes'),
                if (studentNames.isNotEmpty)
                  _buildDetailRow('Students', studentNames.join(', ')),
                _buildDetailRow('Time', '${DateFormat('h:mm a').format(shiftStart)} - ${DateFormat('h:mm a').format(shiftEnd)}'),
                const SizedBox(height: 8),
                // Check for form submission
                FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('form_responses')
                      .where('shiftId', isEqualTo: widget.shiftId)
                      .limit(1)
                      .get(),
                  builder: (context, snapshot) {
                    final hasForm = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
                    return Row(
                      children: [
                        Icon(
                          hasForm ? Icons.assignment_turned_in : Icons.assignment_late,
                          color: hasForm ? Colors.green : Colors.orange,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          hasForm ? 'Form submitted' : 'Form pending',
                          style: GoogleFonts.inter(
                            color: hasForm ? Colors.green : Colors.orange,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Payment tab showing payment breakdown
class _PaymentTab extends StatelessWidget {
  final TeacherAuditFull audit;

  const _PaymentTab({required this.audit});

  @override
  Widget build(BuildContext context) {
    final payment = audit.paymentSummary;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total payment card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade100, Colors.green.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.account_balance_wallet, size: 48, color: Colors.green.shade700),
                SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.totalPayment,
                        style: GoogleFonts.inter(color: Colors.grey.shade600),
                      ),
                      Text(
                        '\$${payment?.totalNetPayment.toStringAsFixed(2) ?? '0.00'}',
                        style: GoogleFonts.inter(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                      if (payment?.adminAdjustment != null && payment!.adminAdjustment != 0)
                        Text(
                          'Includes adjustment: ${payment.adminAdjustment >= 0 ? '+' : ''}\$${payment.adminAdjustment.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                            color: payment.adminAdjustment >= 0 ? Colors.green : Colors.red,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Breakdown by subject
          Text(
            AppLocalizations.of(context)!.paymentBySubject,
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          if (payment != null && payment.paymentsBySubject.isNotEmpty)
            ...payment.paymentsBySubject.entries.map((entry) => _buildSubjectPayment(entry.value))
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(AppLocalizations.of(context)!.noPaymentDataAvailable),
            ),
          const SizedBox(height: 24),

          // Summary breakdown
          Text(
            AppLocalizations.of(context)!.summary,
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          _buildSummaryRow('Gross Payment', '\$${payment?.totalGrossPayment.toStringAsFixed(2) ?? '0.00'}'),
          _buildSummaryRow('Penalties', '-\$${payment?.totalPenalties.toStringAsFixed(2) ?? '0.00'}', isNegative: true),
          _buildSummaryRow('Bonuses', '+\$${payment?.totalBonuses.toStringAsFixed(2) ?? '0.00'}', isPositive: true),
          if (payment?.adminAdjustment != null && payment!.adminAdjustment != 0)
            _buildSummaryRow(
              'Admin Adjustment',
              '${payment.adminAdjustment >= 0 ? '+' : ''}\$${payment.adminAdjustment.toStringAsFixed(2)}',
              isPositive: payment.adminAdjustment > 0,
              isNegative: payment.adminAdjustment < 0,
            ),
          const Divider(height: 24),
          _buildSummaryRow('Net Payment', '\$${payment?.totalNetPayment.toStringAsFixed(2) ?? '0.00'}', isBold: true),
        ],
      ),
    );
  }

  Widget _buildSubjectPayment(SubjectPayment payment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                payment.subjectName,
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              Text(
                '\$${payment.netAmount.toStringAsFixed(2)}',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildPillInfo('${payment.hoursTaught.toStringAsFixed(1)}h', Colors.blue),
              const SizedBox(width: 8),
              _buildPillInfo('\$${payment.hourlyRate.toStringAsFixed(2)}/hr', Colors.grey),
              const SizedBox(width: 8),
              if (payment.penalties > 0)
                _buildPillInfo('-\$${payment.penalties.toStringAsFixed(2)}', Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPillInfo(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isPositive = false, bool isNegative = false, bool isBold = false}) {
    Color valueColor = Colors.black;
    if (isPositive) valueColor = Colors.green;
    if (isNegative) valueColor = Colors.red;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: valueColor,
              fontSize: isBold ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// Forms tab showing readiness forms with clickable details
class _FormsTab extends StatelessWidget {
  final TeacherAuditFull audit;

  const _FormsTab({required this.audit});

  @override
  Widget build(BuildContext context) {
    if (audit.detailedForms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.noFormsSubmittedForThisPeriod,
              style: GoogleFonts.inter(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    // Sort forms by date (oldest first) for chronological order
    final sortedForms = [...audit.detailedForms]..sort((a, b) {
      final aTime = (a['submittedAt'] as Timestamp?)?.toDate() ?? 
                   (a['shiftEnd'] as Timestamp?)?.toDate() ?? 
                   DateTime(1970);
      final bTime = (b['submittedAt'] as Timestamp?)?.toDate() ?? 
                   (b['shiftEnd'] as Timestamp?)?.toDate() ?? 
                   DateTime(1970);
      return aTime.compareTo(bTime);
    });
    
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: sortedForms.length,
      itemBuilder: (context, index) {
        final form = sortedForms[index];
        return _FormCard(form: form, index: index + 1);
      },
    );
  }
}

class _FormCard extends StatefulWidget {
  final Map<String, dynamic> form;
  final int index;

  const _FormCard({required this.form, required this.index});

  @override
  State<_FormCard> createState() => _FormCardState();
}

class _FormCardState extends State<_FormCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final submittedAt = _parseTimestamp(widget.form['submittedAt']);
    final shiftEnd = _parseTimestamp(widget.form['shiftEnd']);
    final shiftTitle = widget.form['shiftTitle'] ?? 'Not linked';
    final delayHours = (widget.form['delayHours'] as num?)?.toDouble() ?? 0.0;
    final responses = widget.form['responses'] as Map<String, dynamic>? ?? {};

    // Determine delay status
    Color statusColor;
    IconData statusIcon;
    String statusText;
    if (delayHours <= 24) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'On-Time';
    } else if (delayHours <= 48) {
      statusColor = Colors.orange;
      statusIcon = Icons.warning;
      statusText = 'Late';
    } else {
      statusColor = Colors.red;
      statusIcon = Icons.error;
      statusText = 'Very Late';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${widget.index}',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              color: statusColor,
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
                              shiftTitle,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(statusIcon, size: 16, color: statusColor),
                                const SizedBox(width: 4),
                                Text(
                                  statusText,
                                  style: GoogleFonts.inter(
                                    color: statusColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (delayHours > 0) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '+${delayHours.toStringAsFixed(1)}h',
                                    style: GoogleFonts.inter(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.grey.shade600,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        'Submitted: ${_formatDate(submittedAt)}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  if (shiftEnd != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.event_available, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          'Class ended: ${_formatDate(shiftEnd)}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.formResponses2,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (responses.isEmpty)
                    Text(
                      AppLocalizations.of(context)!.noResponseDataAvailable,
                      style: GoogleFonts.inter(
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else
                    ...responses.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatFieldName(entry.key),
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatFieldValue(entry.value),
                              style: GoogleFonts.inter(fontSize: 14),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    if (value is Map && value.containsKey('_seconds')) {
      return DateTime.fromMillisecondsSinceEpoch(value['_seconds'] * 1000);
    }
    return null;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('MMM d, h:mm a').format(date);
  }

  String _formatFieldName(String key) {
    // Convert field IDs to readable names
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _formatFieldValue(dynamic value) {
    if (value == null) return 'N/A';
    if (value is String) return value;
    if (value is bool) return value ? 'Yes' : 'No';
    if (value is num) return value.toString();
    if (value is Map) {
      // Handle complex objects (like image uploads)
      if (value.containsKey('downloadURL')) {
        return '📎 File attached';
      }
      return value.toString();
    }
    if (value is List) {
      return value.join(', ');
    }
    return value.toString();
  }
}

/// Dispute tab for teacher corrections
class _DisputeTab extends StatefulWidget {
  final TeacherAuditFull audit;
  final VoidCallback onSubmit;

  const _DisputeTab({
    required this.audit,
    required this.onSubmit,
  });

  @override
  State<_DisputeTab> createState() => _DisputeTabState();
}

class _DisputeTabState extends State<_DisputeTab> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedField;
  final _reasonController = TextEditingController();
  final _suggestedValueController = TextEditingController();
  bool _isSubmitting = false;

  final List<Map<String, String>> _disputeFields = [
    {'id': 'totalClassesCompleted', 'label': 'Classes Completed'},
    {'id': 'totalClassesMissed', 'label': 'Classes Missed'},
    {'id': 'totalHoursTaught', 'label': 'Hours Taught'},
    {'id': 'onTimeClockIns', 'label': 'On-Time Clock-Ins'},
    {'id': 'lateClockIns', 'label': 'Late Clock-Ins'},
    {'id': 'readinessFormsSubmitted', 'label': 'Forms Submitted'},
    {'id': 'paymentAmount', 'label': 'Payment Amount'},
    {'id': 'other', 'label': 'Other'},
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    _suggestedValueController.dispose();
    super.dispose();
  }

  Future<void> _submitDispute() async {
    if (!_formKey.currentState!.validate() || _selectedField == null) return;

    setState(() => _isSubmitting = true);

    try {
      await TeacherAuditService.submitDispute(
        auditId: widget.audit.id,
        field: _selectedField!,
        reason: _reasonController.text.trim(),
        suggestedValue: _suggestedValueController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.disputeSubmittedSuccessfully),
            backgroundColor: Colors.green,
          ),
        );
        widget.onSubmit();
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
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if there's an existing dispute
    final existingDispute = widget.audit.reviewChain?.teacherDispute;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.ifYouBelieveThereSAn,
                    style: GoogleFonts.inter(color: Colors.blue.shade800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Existing dispute status
          if (existingDispute != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getDisputeStatusColor(existingDispute.status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _getDisputeStatusColor(existingDispute.status)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _getDisputeStatusIcon(existingDispute.status),
                        color: _getDisputeStatusColor(existingDispute.status),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context)!.existingDispute,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: _getDisputeStatusColor(existingDispute.status),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getDisputeStatusColor(existingDispute.status),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          existingDispute.status.toUpperCase(),
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(AppLocalizations.of(context)!
                      .auditDisputeField(existingDispute.field)),
                  const SizedBox(height: 4),
                  Text(AppLocalizations.of(context)!
                      .auditDisputeReason(existingDispute.reason)),
                  if (existingDispute.adminResponse.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      AppLocalizations.of(context)!.adminResponse,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    Text(existingDispute.adminResponse),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // New dispute form
          if (existingDispute == null || existingDispute.status == 'rejected') ...[
            Text(
              AppLocalizations.of(context)!.submitNewDispute,
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedField,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.fieldToDispute,
                      border: OutlineInputBorder(),
                    ),
                    items: _disputeFields.map((field) {
                      return DropdownMenuItem(
                        value: field['id'],
                        child: Text(field['label']!),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedField = value),
                    validator: (value) => value == null ? 'Please select a field' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _reasonController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.reasonForDispute,
                      hintText: AppLocalizations.of(context)!.pleaseExplainWhyYouBelieveThis,
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please provide a reason';
                      }
                      if (value.trim().length < 20) {
                        return 'Please provide more detail (at least 20 characters)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _suggestedValueController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.suggestedCorrectValueOptional,
                      hintText: AppLocalizations.of(context)!.whatShouldTheCorrectValueBe,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submitDispute,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      label: Text(_isSubmitting ? 'Submitting...' : 'Submit Dispute'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xff0386FF),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getDisputeStatusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  IconData _getDisputeStatusIcon(String status) {
    switch (status) {
      case 'accepted':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.pending;
    }
  }
}
