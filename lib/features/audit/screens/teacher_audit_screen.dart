import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/teacher_audit_full.dart';
import '../models/teacher_audit_metrics.dart';
import '../services/teacher_audit_service.dart';
import '../../settings/services/pilot_flag_service.dart';
import '../../../core/utils/export_helpers.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';
import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import 'package:alluwalacademyadmin/core/utils/shift_session_aggregator.dart';

/// Teacher's personal audit dashboard
/// Shows their performance metrics, details by class, and improvement areas
class TeacherAuditScreen extends StatefulWidget {
  const TeacherAuditScreen({super.key});

  @override
  State<TeacherAuditScreen> createState() => _TeacherAuditScreenState();
}

class _TeacherAuditScreenState extends State<TeacherAuditScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String _selectedMonth = '';
  TeacherAuditFull? _audit;
  List<String> _availableMonths = [];
  bool _isLoading = true;
  bool _isPilot = false;
  String? _errorMessage;

  // Detailed data from Firestore
  List<Map<String, dynamic>> _detailedShifts = [];
  List<Map<String, dynamic>> _detailedTimesheets = [];
  List<Map<String, dynamic>> _detailedForms = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshAuditDoc() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !mounted) return;
    try {
      await TeacherAuditService.computeAuditForTeacher(
        userId: user.uid,
        yearMonth: _selectedMonth,
      );
      await _loadMetrics();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('${AppLocalizations.of(context)!.commonError}: $e')),
        );
      }
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Not logged in';
            _isLoading = false;
          });
        }
        return;
      }

      // Check if pilot
      _isPilot = await PilotFlagService.isCurrentUserPilot();

      _availableMonths =
          await TeacherAuditService.getAvailableYearMonthsForTeacher(user.uid);

      // Default to current month or first available
      final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
      if (_availableMonths.contains(currentMonth)) {
        _selectedMonth = currentMonth;
      } else if (_availableMonths.isNotEmpty) {
        _selectedMonth = _availableMonths.first;
      } else {
        _selectedMonth = currentMonth;
      }

      await _loadMetrics();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading data: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMetrics() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !mounted) return;

    setState(() => _isLoading = true);

    try {
      _audit = await TeacherAuditService.getMyAudit(yearMonth: _selectedMonth);
      if (_audit != null) {
        _detailedShifts =
            List<Map<String, dynamic>>.from(_audit!.detailedShifts);
        _detailedTimesheets =
            List<Map<String, dynamic>>.from(_audit!.detailedTimesheets);
        _detailedForms = List<Map<String, dynamic>>.from(_audit!.detailedForms);
      } else {
        _detailedShifts = [];
        _detailedTimesheets = [];
        _detailedForms = [];
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading metrics: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.myPerformanceAudit,
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xff111827),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: AppLocalizations.of(context)!.commonRefresh,
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _refreshAuditDoc,
          ),
          if (_isPilot)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xff8B5CF6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.science, size: 16, color: Color(0xff8B5CF6)),
                  const SizedBox(width: 4),
                  Text(
                    AppLocalizations.of(context)!.pilot,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff8B5CF6),
                    ),
                  ),
                ],
              ),
            ),
          // Month picker
          if (_availableMonths.isNotEmpty)
            DropdownButton<String>(
              value: _availableMonths.contains(_selectedMonth)
                  ? _selectedMonth
                  : null,
              underline: const SizedBox(),
              icon: const Icon(Icons.calendar_month),
              items: _availableMonths.map((m) {
                final date = DateTime.parse('$m-01');
                return DropdownMenuItem(
                  value: m,
                  child: Text(DateFormat('MMM yyyy').format(date)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedMonth = value);
                  _loadMetrics();
                }
              },
            ),
          const SizedBox(width: 16),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xff0386FF),
          unselectedLabelColor: const Color(0xff6B7280),
          indicatorColor: const Color(0xff0386FF),
          tabs: [
            Tab(
                icon: Icon(Icons.dashboard),
                text: AppLocalizations.of(context)!.overview),
            Tab(
                icon: Icon(Icons.calendar_today),
                text: AppLocalizations.of(context)!.dashboardClasses),
            Tab(
                icon: Icon(Icons.access_time),
                text: AppLocalizations.of(context)!.clockIns),
            Tab(
                icon: Icon(Icons.description),
                text: AppLocalizations.of(context)!.navForms),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorState()
              : _audit == null
                  ? _buildNoDataState()
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOverviewTab(),
                        _buildClassesTab(),
                        _buildClockInsTab(),
                        _buildFormsTab(),
                      ],
                    ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'An error occurred',
            style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: Text(AppLocalizations.of(context)!.commonRetry),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.noAuditDataForSelectedmonth,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.yourPerformanceDataWillAppearHere,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // OVERVIEW TAB
  // ════════════════════════════════════════════════════════════════
  Widget _buildOverviewTab() {
    final a = _audit!;
    final tier = PerformanceTierExtension.fromString(a.performanceTier);
    final tierColor = _getTierColor(tier);
    final netPay = a.paymentSummary?.totalNetPayment;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [tierColor, tierColor.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: tierColor.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  tier.emoji,
                  style: const TextStyle(fontSize: 48),
                ),
                const SizedBox(height: 8),
                Text(
                  '${a.overallScore.toStringAsFixed(1)}%',
                  style: GoogleFonts.inter(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  tier.displayName.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.9),
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMMM yyyy')
                      .format(DateTime.parse('${a.yearMonth}-01')),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            AppLocalizations.of(context)!.scoreBreakdown,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _buildScoreRow('📅 Completion', a.completionRate, 0.40),
          _buildScoreRow('⏰ Punctuality', a.punctualityRate, 0.35),
          _buildScoreRow('📝 Form Compliance', a.formComplianceRate, 0.25),
          const SizedBox(height: 24),
          Text(
            AppLocalizations.of(context)!.quickStats,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatCard(
                  'Classes',
                  '${a.totalClassesCompleted}/${a.totalClassesScheduled}',
                  Icons.school,
                  const Color(0xff0386FF)),
              const SizedBox(width: 12),
              _buildStatCard(
                  'On-Time',
                  '${a.onTimeClockIns}/${a.totalClockIns}',
                  Icons.access_time,
                  const Color(0xff10B981)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatCard('Worked h', a.totalWorkedHours.toStringAsFixed(2),
                  Icons.timer, const Color(0xff10B981)),
              const SizedBox(width: 12),
              _buildStatCard(
                  'Forms',
                  '${a.readinessFormsSubmitted}/${a.readinessFormsRequired}',
                  Icons.description,
                  const Color(0xff8B5CF6)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatCard(
                  'Issues',
                  '${a.issues.length}',
                  Icons.flag,
                  a.issues.isEmpty
                      ? const Color(0xff10B981)
                      : const Color(0xffEF4444)),
              const SizedBox(width: 12),
              _buildStatCard('Late', '${a.lateClockIns}', Icons.schedule,
                  const Color(0xffF59E0B)),
            ],
          ),
          if (netPay != null) ...[
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.auditMessagePaymentSummary,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.of(context)!.auditMessageFinalAmount,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '\$${netPay.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (a.issues.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.issuesToAddress,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ...a.issues.map(_buildAuditIssueCard),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _exportTeachingData,
              icon: const Icon(Icons.download_for_offline_outlined),
              label: const Text("Download My Teaching Data (CSV)"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0E72ED),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Exports your shifts, timesheets, and pay for the current range.",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditIssueCard(AuditIssue issue) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.flag_outlined, size: 20, color: Color(0xFFF59E0B)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  issue.description,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                ),
                if (issue.date != null)
                  Text(
                    DateFormat('MMM d, h:mm a').format(issue.date!),
                    style: GoogleFonts.inter(
                        fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Exports the teacher's data for the current selected month
  Future<void> _exportTeachingData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final startOfMonth = DateTime.parse('${_selectedMonth}-01');
      final endOfMonth =
          DateTime(startOfMonth.year, startOfMonth.month + 1, 0, 23, 59, 59);

      // Fetch shifts, timesheets, and forms for the selected month
      final shiftQuery = await FirebaseFirestore.instance
          .collection('teaching_shifts')
          .where('teacher_id', isEqualTo: user.uid)
          .where('shift_start',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('shift_start',
              isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .get();

      final timesheetQuery = await FirebaseFirestore.instance
          .collection('timesheet_entries')
          .where('teacher_id', isEqualTo: user.uid)
          .get();

      final formQuery = await FirebaseFirestore.instance
          .collection('form_responses')
          .where('userId', isEqualTo: user.uid)
          .get();

      final shifts = shiftQuery.docs.map((doc) => doc.data()).toList();
      final timesheets = timesheetQuery.docs.map((doc) => doc.data()).toList();
      final forms = formQuery.docs.map((doc) => doc.data()).toList();

      // Group by shift ID
      final timesheetsByShift = <String, List<Map<String, dynamic>>>{};
      for (final ts in timesheets) {
        final sid = ts['shift_id'] ?? ts['shiftId'];
        if (sid != null) {
          for (final key
              in ShiftSessionAggregator.getShiftIdIndexKeys(sid.toString())) {
            timesheetsByShift.putIfAbsent(key, () => []).add(ts);
          }
        }
      }

      final formsByShift = <String, List<Map<String, dynamic>>>{};
      for (final form in forms) {
        final sid = form['shiftId'];
        if (sid != null) {
          for (final key
              in ShiftSessionAggregator.getShiftIdIndexKeys(sid.toString())) {
            formsByShift.putIfAbsent(key, () => []).add(form);
          }
        }
      }

      // Prepare CSV Data
      final List<String> headers = [
        'Date',
        'Shift Name',
        'Status',
        'Scheduled Hours',
        'Worked Hours',
        'Pay',
        'Has Form'
      ];

      final List<List<dynamic>> rows = [];

      for (final shift in shifts) {
        final shiftId = shift['id'] ?? shift['shift_id'] ?? '';
        final shiftStart = (shift['shift_start'] as Timestamp?)?.toDate();

        final shiftTimesheets = timesheetsByShift[shiftId] ?? [];
        final shiftForms = formsByShift[shiftId] ?? [];

        final result = ShiftSessionAggregator.computeSession(
            shift, shiftTimesheets, shiftForms);

        if (result.hasPunchedTimesheets || result.hasForm) {
          rows.add([
            shiftStart != null
                ? DateFormat('yyyy-MM-dd').format(shiftStart)
                : '',
            shift['title'] ?? shift['subject'] ?? 'Teaching Session',
            shift['status'] ?? 'scheduled',
            ShiftSessionAggregator.getScheduledHours(shift).toStringAsFixed(2),
            result.workedHours.toStringAsFixed(2),
            result.realPay.toStringAsFixed(2),
            result.hasForm ? 'Yes' : 'No',
          ]);
        }
      }

      if (mounted) {
        ExportHelpers.showExportDialog(
          context,
          headers,
          rows,
          'Alluwal_Teaching_Data_${_selectedMonth}',
        );
      }
    } catch (e) {
      AppLogger.error('Error exporting data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Export failed: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildScoreRow(String label, double score, double weight) {
    final contribution = score * weight;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              Text(
                '${score.toStringAsFixed(1)}%',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  color: _getScoreColor(score),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(_getScoreColor(score)),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Weight: ${(weight * 100).toInt()}% → Contribution: ${contribution.toStringAsFixed(1)} pts',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style:
                      GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                ),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // CLASSES TAB
  // ════════════════════════════════════════════════════════════════
  Widget _buildClassesTab() {
    if (_detailedShifts.isEmpty) {
      return _buildEmptyTabState(
          'No class data available', Icons.school_outlined);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _detailedShifts.length,
      itemBuilder: (context, index) {
        final shift = _detailedShifts[index];
        return _buildShiftCard(shift, index + 1);
      },
    );
  }

  Widget _buildShiftCard(Map<String, dynamic> shift, int index) {
    final status = shift['status'] ?? 'unknown';
    final statusInfo = _getStatusInfo(status);
    final startDate = _parseDate(shift['start']);
    final duration = shift['duration'] ?? 'N/A';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusInfo.color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: ExpansionTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: statusInfo.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(statusInfo.emoji, style: const TextStyle(fontSize: 20)),
          ),
        ),
        title: Text(
          shift['name'] ?? shift['title'] ?? 'Unnamed Class',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              startDate != null
                  ? DateFormat('EEE, MMM d, h:mm a').format(startDate)
                  : AppLocalizations.of(context)!.commonUnknownDate,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
            ),
            if (shift['fromShiftTrade'] == true) ...[
              const SizedBox(height: 4),
              Text(
                AppLocalizations.of(context)!.teacherAuditShiftFromTradeNotice,
                style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusInfo.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            status.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: statusInfo.color,
            ),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Shift ID', shift['id'] ?? 'N/A'),
                _buildDetailRow('Duration', duration),
                _buildDetailRow('Status', '$status ${statusInfo.emoji}'),
                if (startDate != null)
                  _buildDetailRow('Start',
                      DateFormat('MMM d, yyyy h:mm a').format(startDate)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // CLOCK-INS TAB
  // ════════════════════════════════════════════════════════════════

  List<_ShiftClockGroup> _groupedClockIns() {
    final byKey = <String, List<Map<String, dynamic>>>{};
    for (final ts in _detailedTimesheets) {
      final sid = ts['shift_id'] as String? ?? ts['shiftId'] as String?;
      final key = sid == null || sid.isEmpty
          ? '__orphan__${ts['id'] ?? 'noid'}'
          : ShiftSessionAggregator.canonicalShiftIdForGrouping(sid);
      byKey.putIfAbsent(key, () => []).add(ts);
    }
    final groups = byKey.entries
        .map((e) => _ShiftClockGroup(groupKey: e.key, segments: e.value))
        .toList();
    DateTime? minClock(_ShiftClockGroup g) {
      DateTime? m;
      for (final t in g.segments) {
        final d =
            _parseDate(t['clockIn']) ?? _parseDate(t['clock_in_timestamp']);
        if (d == null) continue;
        if (m == null || d.isBefore(m)) m = d;
      }
      return m;
    }

    groups.sort((a, b) => (minClock(a) ?? DateTime(1970))
        .compareTo(minClock(b) ?? DateTime(1970)));
    return groups;
  }

  Map<String, dynamic>? _detailedShiftMatching(String? rawShiftId) {
    if (rawShiftId == null || rawShiftId.isEmpty) return null;
    final keys = ShiftSessionAggregator.getShiftIdIndexKeys(rawShiftId).toSet();
    final canon =
        ShiftSessionAggregator.canonicalShiftIdForGrouping(rawShiftId);
    for (final s in _detailedShifts) {
      final id = s['id'] as String?;
      if (id == null) continue;
      if (keys.contains(id) ||
          ShiftSessionAggregator.canonicalShiftIdForGrouping(id) == canon) {
        return Map<String, dynamic>.from(s);
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _formsForShiftRaw(String? rawShiftId) {
    if (rawShiftId == null || rawShiftId.isEmpty) return [];
    final keys = ShiftSessionAggregator.getShiftIdIndexKeys(rawShiftId).toSet();
    final canon =
        ShiftSessionAggregator.canonicalShiftIdForGrouping(rawShiftId);
    return _detailedForms
        .where((f) {
          final fid = f['shiftId'] as String?;
          if (fid == null || fid.isEmpty) return false;
          if (keys.contains(fid)) return true;
          return ShiftSessionAggregator.canonicalShiftIdForGrouping(fid) ==
              canon;
        })
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Map<String, dynamic> _shiftMapForAggregator(
    Map<String, dynamic>? detailed,
    _ShiftClockGroup group,
  ) {
    if (detailed != null) return Map<String, dynamic>.from(detailed);
    final sorted = List<Map<String, dynamic>>.from(group.segments);
    sorted.sort((a, b) {
      final da =
          _parseDate(a['clockIn']) ?? _parseDate(a['clock_in_timestamp']);
      final db =
          _parseDate(b['clockIn']) ?? _parseDate(b['clock_in_timestamp']);
      return (da ?? DateTime(1970)).compareTo(db ?? DateTime(1970));
    });
    final first = sorted.first;
    final rawId = first['shift_id'] as String? ?? first['shiftId'] as String?;
    final id = group.isOrphanBucket
        ? (first['id'] as String? ?? 'unknown')
        : (rawId ?? group.groupKey);
    return {
      'id': id,
      'start': first['shiftStart'],
      'shift_start': first['shiftStart'],
      'end': null,
      'shift_end': null,
      'hourly_rate': 0.0,
      'hourlyRate': 0.0,
    };
  }

  (Color, String) _punctualityStyle(double deltaMinutes) {
    if (deltaMinutes <= 0) {
      return (
        const Color(0xff10B981),
        '${deltaMinutes.abs().toInt()} min early',
      );
    }
    if (deltaMinutes <= 5) {
      return (const Color(0xffF59E0B), 'On time');
    }
    return (const Color(0xffEF4444), '${deltaMinutes.toInt()} min late');
  }

  Widget _buildClockInsTab() {
    if (_detailedTimesheets.isEmpty) {
      return _buildEmptyTabState(
          'No clock-in data available', Icons.access_time);
    }

    final groups = _groupedClockIns();
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        return _buildShiftClockSessionCard(groups[index]);
      },
    );
  }

  List<Widget> _buildSegmentClockDetailRows(Map<String, dynamic> timesheet) {
    final shiftStart = _parseDate(timesheet['shiftStart']);
    final clockIn = _parseDate(timesheet['clockIn']) ??
        _parseDate(timesheet['clock_in_timestamp']);
    final clockOut = _parseDate(timesheet['clockOut']) ??
        _parseDate(timesheet['clock_out_timestamp']);
    final delta = (timesheet['deltaMinutes'] as num?)?.toDouble() ?? 0.0;
    final (_, deltaText) = _punctualityStyle(delta);
    return [
      _buildDetailRow(
        'Shift Start',
        shiftStart != null ? DateFormat('h:mm a').format(shiftStart) : 'N/A',
      ),
      _buildDetailRow(
        'Clock-In',
        clockIn != null ? DateFormat('h:mm a').format(clockIn) : 'N/A',
      ),
      _buildDetailRow(
        'Clock-Out',
        clockOut != null ? DateFormat('h:mm a').format(clockOut) : 'N/A',
      ),
      _buildDetailRow('Delta', deltaText),
    ];
  }

  Widget _buildShiftClockSessionCard(_ShiftClockGroup group) {
    final loc = AppLocalizations.of(context)!;
    final sorted = List<Map<String, dynamic>>.from(group.segments);
    sorted.sort((a, b) {
      final da =
          _parseDate(a['clockIn']) ?? _parseDate(a['clock_in_timestamp']);
      final db =
          _parseDate(b['clockIn']) ?? _parseDate(b['clock_in_timestamp']);
      return (da ?? DateTime(1970)).compareTo(db ?? DateTime(1970));
    });
    final first = sorted.first;
    final rawShiftId =
        first['shift_id'] as String? ?? first['shiftId'] as String?;
    final detailedShift =
        group.isOrphanBucket ? null : _detailedShiftMatching(rawShiftId);
    final shiftAgg = _shiftMapForAggregator(detailedShift, group);
    final tsCopies = sorted.map((e) => Map<String, dynamic>.from(e)).toList();
    final forms = _formsForShiftRaw(rawShiftId);
    final session =
        ShiftSessionAggregator.computeSession(shiftAgg, tsCopies, forms);

    final titleText =
        (detailedShift != null ? (detailedShift['title'] as String?) : null) ??
            first['shiftTitle'] as String?;
    final displayTitle = (titleText != null && titleText.isNotEmpty)
        ? titleText
        : loc.commonUnknownShift;

    final firstClock =
        _parseDate(first['clockIn']) ?? _parseDate(first['clock_in_timestamp']);
    final delta = (first['deltaMinutes'] as num?)?.toDouble() ?? 0.0;
    final (deltaColor, deltaText) = _punctualityStyle(delta);
    final shiftStatus = detailedShift?['status'] as String? ?? '';
    final statusUi =
        _getStatusInfo(shiftStatus.isNotEmpty ? shiftStatus : 'unknown');

    final subtitle = (firstClock != null)
        ? (sorted.length > 1
            ? '${DateFormat('h:mm a').format(firstClock)} · ${loc.auditClockSegmentCount(sorted.length)}'
            : 'Clocked in: ${DateFormat('h:mm a').format(firstClock)}')
        : 'No clock-in data';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: ExpansionTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: deltaColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(statusUi.emoji, style: const TextStyle(fontSize: 20)),
          ),
        ),
        title: Text(
          displayTitle,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: deltaColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            deltaText,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: deltaColor,
            ),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow(
                  loc.auditHoursWorked,
                  '${session.workedHours.toStringAsFixed(2)} h',
                ),
                _buildDetailRow(
                  loc.auditClockSessionPay,
                  '\$${session.realPay.toStringAsFixed(2)}',
                ),
                const Divider(),
                if (sorted.length > 1) ...[
                  Text(
                    loc.auditClockSegmentsHeader,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                ],
                for (var i = 0; i < sorted.length; i++) ...[
                  if (sorted.length > 1) ...[
                    Text(
                      '${i + 1}.',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  ..._buildSegmentClockDetailRows(sorted[i]),
                  if (i < sorted.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // FORMS TAB
  // ════════════════════════════════════════════════════════════════
  Widget _buildFormsTab() {
    if (_detailedForms.isEmpty) {
      return _buildEmptyTabState(
          'No form submissions', Icons.description_outlined);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _detailedForms.length,
      itemBuilder: (context, index) {
        final form = _detailedForms[index];
        return _buildFormCard(form, index + 1);
      },
    );
  }

  Widget _buildFormCard(Map<String, dynamic> form, int index) {
    final submittedAt = _parseDate(form['submittedAt']);
    final shiftEnd = _parseDate(form['shiftEnd']);
    final delayHours = (form['delayHours'] ?? 0).toDouble();
    final responses = form['responses'] as Map<String, dynamic>? ?? {};

    Color delayColor;
    String delayText;
    if (delayHours <= 24) {
      delayColor = const Color(0xff10B981);
      delayText = 'On time';
    } else if (delayHours <= 48) {
      delayColor = const Color(0xffF59E0B);
      delayText = '+${delayHours.toInt()}h';
    } else {
      delayColor = const Color(0xffEF4444);
      delayText = '+${delayHours.toInt()}h late';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: ExpansionTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xff8B5CF6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(index.toString(), style: TextStyle(fontSize: 20)),
          ),
        ),
        title: Text(
          form['shiftTitle'] ??
              AppLocalizations.of(context)!.commonUnknownClass,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          submittedAt != null
              ? 'Submitted: ${DateFormat('MMM d, h:mm a').format(submittedAt)}'
              : 'No submission date',
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: delayColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            delayText,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: delayColor,
            ),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Form ID', form['id'] ?? 'N/A'),
                _buildDetailRow('Shift ID', form['shiftId'] ?? 'Not linked'),
                if (submittedAt != null)
                  _buildDetailRow('Submitted',
                      DateFormat('MMM d, h:mm a').format(submittedAt)),
                if (shiftEnd != null)
                  _buildDetailRow('Shift End',
                      DateFormat('MMM d, h:mm a').format(shiftEnd)),
                const Divider(),
                Text(
                  'Responses (${responses.length} fields)',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...responses.entries.take(10).map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• ${e.key}: ${_formatValue(e.value)}',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: Colors.grey[700]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )),
                if (responses.length > 10)
                  Text(
                    '... and ${responses.length - 10} more',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: Colors.grey[500]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // HELPER METHODS
  // ════════════════════════════════════════════════════════════════
  Widget _buildEmptyTabState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style:
                  GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Color _getTierColor(PerformanceTier tier) {
    switch (tier) {
      case PerformanceTier.excellent:
        return const Color(0xff10B981);
      case PerformanceTier.good:
        return const Color(0xff0386FF);
      case PerformanceTier.needsImprovement:
        return const Color(0xffF59E0B);
      case PerformanceTier.critical:
        return const Color(0xffEF4444);
    }
  }

  Color _getScoreColor(double score) {
    if (score >= 90) return const Color(0xff10B981);
    if (score >= 75) return const Color(0xff0386FF);
    if (score >= 60) return const Color(0xffF59E0B);
    return const Color(0xffEF4444);
  }

  ({String emoji, Color color}) _getStatusInfo(String status) {
    switch (status) {
      case 'completed':
      case 'fullyCompleted':
        return (emoji: '✅', color: const Color(0xff10B981));
      case 'partiallyCompleted':
        return (emoji: '⚠️', color: const Color(0xffF59E0B));
      case 'missed':
        return (emoji: '❌', color: const Color(0xffEF4444));
      case 'cancelled':
        return (emoji: '🚫', color: const Color(0xff6B7280));
      case 'active':
        return (emoji: '▶️', color: const Color(0xff0386FF));
      case 'scheduled':
        return (emoji: '📅', color: const Color(0xff8B5CF6));
      default:
        return (emoji: '❓', color: Colors.grey);
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    if (value is Map && value['_seconds'] != null) {
      return DateTime.fromMillisecondsSinceEpoch(value['_seconds'] * 1000);
    }
    return null;
  }

  String _formatValue(dynamic value) {
    if (value == null) return 'N/A';
    if (value is List) return value.join(', ');
    if (value is String && value.length > 50)
      return '${value.substring(0, 50)}...';
    return value.toString();
  }
}

class _ShiftClockGroup {
  final String groupKey;
  final List<Map<String, dynamic>> segments;

  const _ShiftClockGroup({
    required this.groupKey,
    required this.segments,
  });

  bool get isOrphanBucket => groupKey.startsWith('__orphan__');
}
