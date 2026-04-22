import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/models/teacher_audit_metrics.dart';
import '../../../core/services/audit_metrics_service.dart';
import '../../../core/services/teacher_metrics_service.dart';
import '../../../core/services/pilot_flag_service.dart';
import '../../shift_management/screens/available_shifts_screen.dart';
import '../../../utility_functions/export_helpers.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';
import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

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
  TeacherAuditMetrics? _metrics;
  TeacherBasicMetrics? _liveMetrics;
  bool _isLiveMonth = false;
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

  Future<QuerySnapshot<Map<String, dynamic>>> _fetchMetricsMonths({
    required String collection,
    required String userId,
  }) {
    return FirebaseFirestore.instance
        .collection(collection)
        .where('userId', isEqualTo: userId)
        .orderBy('yearMonth', descending: true)
        .get();
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

      // Get available months
      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        final collection = _isPilot ? 'pilot_audit_metrics' : 'audit_metrics';
        snapshot =
            await _fetchMetricsMonths(collection: collection, userId: user.uid);
        if (_isPilot && snapshot.docs.isEmpty) {
          final fallback = await _fetchMetricsMonths(
            collection: 'audit_metrics',
            userId: user.uid,
          );
          if (fallback.docs.isNotEmpty) {
            _isPilot = false;
            snapshot = fallback;
          }
        }
      } on FirebaseException catch (e) {
        if (_isPilot && e.code == 'permission-denied') {
          _isPilot = false;
          snapshot = await _fetchMetricsMonths(
            collection: 'audit_metrics',
            userId: user.uid,
          );
        } else {
          rethrow;
        }
      }

      _availableMonths = snapshot.docs
          .map((doc) => doc.data()['yearMonth'] as String?)
          .where((m) => m != null)
          .cast<String>()
          .toSet()
          .toList();

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
      final currentMonth = TeacherMetricsService.getYearMonth(DateTime.now());
      _isLiveMonth = _selectedMonth == currentMonth;

      if (_isLiveMonth) {
        // Load live metrics for current month
        final now = DateTime.now();
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

        _liveMetrics = await TeacherMetricsService.aggregate(
          teacherId: user.uid,
          start: startOfMonth,
          end: endOfMonth,
        );
        _metrics = null;
      } else {
        // Load frozen metrics for past months
        _metrics = await AuditMetricsService.getMetrics(
          oderId: user.uid,
          yearMonth: _selectedMonth,
          pilotOnly: _isPilot,
        );
        _liveMetrics = null;
      }

      // Load detailed data if available in the metrics doc (only for past months)
      if (_metrics != null) {
        final collection = _isPilot ? 'pilot_audit_metrics' : 'audit_metrics';
        final doc = await FirebaseFirestore.instance
            .collection(collection)
            .doc(_metrics!.id)
            .get();

        if (doc.exists) {
          final data = doc.data()!;
          _detailedShifts = List<Map<String, dynamic>>.from(
              data['detailedShifts'] ?? []);
          _detailedTimesheets = List<Map<String, dynamic>>.from(
              data['detailedTimesheets'] ?? []);
          _detailedForms = List<Map<String, dynamic>>.from(
              data['detailedForms'] ?? []);
        }
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
            Tab(icon: Icon(Icons.dashboard), text: AppLocalizations.of(context)!.overview),
            Tab(icon: Icon(Icons.calendar_today), text: AppLocalizations.of(context)!.dashboardClasses),
            Tab(icon: Icon(Icons.access_time), text: AppLocalizations.of(context)!.clockIns),
            Tab(icon: Icon(Icons.description), text: AppLocalizations.of(context)!.navForms),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorState()
              : (_metrics == null && _liveMetrics == null)
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
    if (_isLiveMonth && _liveMetrics != null) {
      return _buildLiveOverviewTab();
    }

    final m = _metrics!;
    final tierColor = _getTierColor(m.performanceTier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall Score Card
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
                  m.performanceTier.emoji,
                  style: const TextStyle(fontSize: 48),
                ),
                const SizedBox(height: 8),
                Text(
                  '${m.overallScore.toStringAsFixed(1)}%',
                  style: GoogleFonts.inter(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  m.performanceTier.displayName.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.9),
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMMM yyyy').format(DateTime.parse('${m.yearMonth}-01')),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Score Breakdown
          Text(
            AppLocalizations.of(context)!.scoreBreakdown,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _buildScoreRow('📅 Completion', m.completionRate, 0.30),
          _buildScoreRow('⏰ Punctuality', m.punctualityRate, 0.20),
          _buildScoreRow('📝 Form Compliance', m.formComplianceRate, 0.15),
          _buildScoreRow('📚 Student Outcomes', 
              (m.avgQuizScore + m.assignmentCompletionRate + m.attendanceRate) / 3, 0.35),

          const SizedBox(height: 24),

          // Quick Stats Grid
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
              _buildStatCard('Classes', '${m.completedClasses}/${m.scheduledClasses}', Icons.school, const Color(0xff0386FF)),
              const SizedBox(width: 12),
              _buildStatCard('On-Time', '${m.onTimeClockIns}/${m.totalClockIns}', Icons.access_time, const Color(0xff10B981)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatCard('Forms', '${m.formsSubmitted}/${m.formsRequired}', Icons.description, const Color(0xff8B5CF6)),
              const SizedBox(width: 12),
              _buildStatCard('Issues', '${m.flags.length}', Icons.flag, 
                  m.flags.isEmpty ? const Color(0xff10B981) : const Color(0xffEF4444)),
            ],
          ),

          // Flags Section
          if (m.flags.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.issuesToAddress,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ...m.flags.map((flag) => _buildFlagCard(flag)),
          ],

          const SizedBox(height: 32),
          
          // Export Button
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  /// Builds the overview tab for the current month using live metrics
  Widget _buildLiveOverviewTab() {
    final m = _liveMetrics!;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Live Status Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0E72ED).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF0E72ED).withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt, color: Color(0xFF0E72ED)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Live Performance (Current Month)",
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E3A5F),
                        ),
                      ),
                      Text(
                        "Showing real-time metrics. Month-end audit will freeze these values.",
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF1E3A5F).withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Basic Metrics Grid
          Text(
            "Monthly Summary",
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildStatCard('Classes', '${m.completedClasses}/${m.scheduledClasses}', Icons.school, const Color(0xff0386FF)),
              _buildStatCard('Hours', m.hoursWorked.toStringAsFixed(1), Icons.timer, const Color(0xff10B981)),
              _buildStatCard('Forms', '${m.formsSubmitted}/${m.formsRequired}', Icons.description, const Color(0xff8B5CF6)),
              _buildStatCard('Late', '${m.lateClockIns}', Icons.access_time, const Color(0xffF59E0B)),
            ],
          ),
          const SizedBox(height: 24),

          // Earnings Section
          Text(
            "Earnings (Provisional)",
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
            child: Column(
              children: [
                _buildPayRow("Paid", m.payPaid, const Color(0xFF059669)),
                const Divider(height: 24),
                _buildPayRow("Approved", m.payApproved, const Color(0xFF0E72ED)),
                const Divider(height: 24),
                _buildPayRow("Pending", m.payPending, const Color(0xFFF59E0B)),
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Total",
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      "\$${(m.payPaid + m.payApproved + m.payPending).toStringAsFixed(2)}",
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          if (m.payPending > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "You have entries awaiting re-approval after edits. Your final total may change.",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF9A3412),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),
          
          // Export Button
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  /// Exports the teacher's data for the current selected month
  Future<void> _exportTeachingData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final startOfMonth = DateTime.parse('${_selectedMonth}-01');
      final endOfMonth = DateTime(startOfMonth.year, startOfMonth.month + 1, 0, 23, 59, 59);

      // Fetch timesheets for the selected month (clock-in time window)
      final timesheetQuery = await FirebaseFirestore.instance
          .collection('timesheet_entries')
          .where('teacher_id', isEqualTo: user.uid)
          .get();

      final timesheets = timesheetQuery.docs
          .where((doc) {
            final data = doc.data();
            final clockIn = (data['clock_in_time'] ?? data['clock_in_timestamp']) as Timestamp?;
            if (clockIn == null) return false;
            final date = clockIn.toDate();
            return date.isAfter(startOfMonth.subtract(const Duration(seconds: 1))) && 
                   date.isBefore(endOfMonth.add(const Duration(seconds: 1)));
          })
          .map((doc) => doc.data())
          .toList();

      // Prepare CSV Data
      final List<String> headers = [
        'Date',
        'Shift Name',
        'Status',
        'Clock In',
        'Clock Out',
        'Duration',
        'Pay',
        'Notes'
      ];

      final List<List<dynamic>> rows = [];
      
      for (final ts in timesheets) {
        final clockIn = (ts['clock_in_time'] ?? ts['clock_in_timestamp'] as Timestamp?)?.toDate();
        final clockOut = (ts['clock_out_time'] ?? ts['clock_out_timestamp'] as Timestamp?)?.toDate();
        
        rows.add([
          clockIn != null ? DateFormat('yyyy-MM-dd').format(clockIn) : '',
          ts['shift_title'] ?? 'Teaching Session',
          ts['status'] ?? 'pending',
          clockIn != null ? DateFormat('HH:mm:ss').format(clockIn) : '',
          clockOut != null ? DateFormat('HH:mm:ss').format(clockOut) : '',
          ts['total_hours'] ?? '',
          ts['payment_amount'] ?? ts['total_pay'] ?? 0.0,
          ts['employee_notes'] ?? '',
        ]);
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
          SnackBar(content: Text("Export failed: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildPayRow(String label, double amount, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        Text(
          "\$${amount.toStringAsFixed(2)}",
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B),
          ),
        ),
      ],
    );
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
              Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
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

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
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
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
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

  Widget _buildFlagCard(AuditFlagDetail flag) {
    IconData icon;
    Color color;
    switch (flag.type) {
      case AuditFlag.missedClass:
        icon = Icons.cancel;
        color = const Color(0xffEF4444);
        break;
      case AuditFlag.lateClockIn:
        icon = Icons.access_time;
        color = const Color(0xffF59E0B);
        break;
      case AuditFlag.missingForm:
        icon = Icons.description_outlined;
        color = const Color(0xff8B5CF6);
        break;
      default:
        icon = Icons.flag;
        color = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  flag.description,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                ),
                if (flag.date != null)
                  Text(
                    DateFormat('MMM d, h:mm a').format(flag.date!),
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // CLASSES TAB
  // ════════════════════════════════════════════════════════════════
  Widget _buildClassesTab() {
    if (_detailedShifts.isEmpty) {
      return _buildEmptyTabState('No class data available', Icons.school_outlined);
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
          shift['name'] ?? 'Unnamed Class',
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
                  _buildDetailRow('Start', DateFormat('MMM d, yyyy h:mm a').format(startDate)),
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
  Widget _buildClockInsTab() {
    if (_detailedTimesheets.isEmpty) {
      return _buildEmptyTabState('No clock-in data available', Icons.access_time);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _detailedTimesheets.length,
      itemBuilder: (context, index) {
        final timesheet = _detailedTimesheets[index];
        return _buildTimesheetCard(timesheet, index + 1);
      },
    );
  }

  Widget _buildTimesheetCard(Map<String, dynamic> timesheet, int index) {
    final delta = (timesheet['deltaMinutes'] ?? 0).toDouble();
    final status = timesheet['status'] ?? '❓';
    final shiftStart = _parseDate(timesheet['shiftStart']);
    final clockIn = _parseDate(timesheet['clockIn']);
    final clockOut = _parseDate(timesheet['clockOut']);

    Color deltaColor;
    String deltaText;
    if (delta <= 0) {
      deltaColor = const Color(0xff10B981);
      deltaText = '${delta.abs().toInt()} min early';
    } else if (delta <= 5) {
      deltaColor = const Color(0xffF59E0B);
      deltaText = 'On time';
    } else {
      deltaColor = const Color(0xffEF4444);
      deltaText = '${delta.toInt()} min late';
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
            color: deltaColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(status, style: const TextStyle(fontSize: 20)),
          ),
        ),
        title: Text(
          timesheet['shiftTitle'] ?? AppLocalizations.of(context)!.commonUnknownShift,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          clockIn != null
              ? 'Clocked in: ${DateFormat('h:mm a').format(clockIn)}'
              : 'No clock-in data',
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
                _buildDetailRow('Shift Start', shiftStart != null
                    ? DateFormat('h:mm a').format(shiftStart)
                    : 'N/A'),
                _buildDetailRow('Clock-In', clockIn != null
                    ? DateFormat('h:mm a').format(clockIn)
                    : 'N/A'),
                _buildDetailRow('Clock-Out', clockOut != null
                    ? DateFormat('h:mm a').format(clockOut)
                    : 'N/A'),
                _buildDetailRow('Delta', deltaText),
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
      return _buildEmptyTabState('No form submissions', Icons.description_outlined);
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
          form['shiftTitle'] ?? AppLocalizations.of(context)!.commonUnknownClass,
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
                  _buildDetailRow('Submitted', DateFormat('MMM d, h:mm a').format(submittedAt)),
                if (shiftEnd != null)
                  _buildDetailRow('Shift End', DateFormat('MMM d, h:mm a').format(shiftEnd)),
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
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[700]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )),
                if (responses.length > 10)
                  Text(
                    '... and ${responses.length - 10} more',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
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
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
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
    if (value is String && value.length > 50) return '${value.substring(0, 50)}...';
    return value.toString();
  }
}
