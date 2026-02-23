import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:html' as html;
import 'dart:convert';
import '../../core/models/teacher_audit_metrics.dart';
import '../../core/services/audit_metrics_service.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// Admin dashboard for viewing teacher audit metrics
class AuditDashboardScreen extends StatefulWidget {
  const AuditDashboardScreen({super.key});

  @override
  State<AuditDashboardScreen> createState() => _AuditDashboardScreenState();
}

class _AuditDashboardScreenState extends State<AuditDashboardScreen> {
  // Filters
  String _selectedMonth = '';
  String? _selectedTeacherId;
  PerformanceTier? _selectedTier;
  bool _pilotOnly = true; // Start with pilot data

  // Data
  List<TeacherAuditMetrics> _metrics = [];
  List<String> _availableMonths = [];
  List<Map<String, String>> _teachers = [];
  Map<String, dynamic> _summary = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);

    // Get available months
    _availableMonths = await AuditMetricsService.getAvailableMonths(pilotOnly: _pilotOnly);

    // Default to current month if available, otherwise first available
    final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
    if (_availableMonths.contains(currentMonth)) {
      _selectedMonth = currentMonth;
    } else if (_availableMonths.isNotEmpty) {
      _selectedMonth = _availableMonths.first;
    } else {
      _selectedMonth = currentMonth;
    }

    // Get teachers
    _teachers = await AuditMetricsService.getTeachersWithMetrics(pilotOnly: _pilotOnly);

    await _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    setState(() => _isLoading = true);

    try {
      List<TeacherAuditMetrics> metrics;

      if (_selectedTeacherId != null) {
        // Single teacher
        final m = await AuditMetricsService.getMetrics(
          oderId: _selectedTeacherId!,
          yearMonth: _selectedMonth,
          pilotOnly: _pilotOnly,
        );
        metrics = m != null ? [m] : [];
      } else if (_selectedTier != null) {
        // Filter by tier
        metrics = await AuditMetricsService.getMetricsByTier(
          yearMonth: _selectedMonth,
          tier: _selectedTier!,
          pilotOnly: _pilotOnly,
        );
      } else {
        // All metrics
        metrics = await AuditMetricsService.getAllMetricsForMonth(
          _selectedMonth,
          pilotOnly: _pilotOnly,
        );
      }

      _summary = await AuditMetricsService.getMonthSummary(
        _selectedMonth,
        pilotOnly: _pilotOnly,
      );

      setState(() {
        _metrics = metrics;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorLoadingMetricsE)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.teacherAuditDashboard,
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xff111827),
        elevation: 0,
        actions: [
          // Pilot toggle
          Row(
            children: [
              Text(
                AppLocalizations.of(context)!.pilotOnly,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
              ),
              Switch(
                value: _pilotOnly,
                onChanged: (value) {
                  setState(() => _pilotOnly = value);
                  _initializeData();
                },
                activeColor: const Color(0xff8B5CF6),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Export button
          ElevatedButton.icon(
            onPressed: _exportToCSV,
            icon: const Icon(Icons.download, size: 18),
            label: Text(AppLocalizations.of(context)!.exportCsv),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff0386FF),
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _generateReport,
            icon: const Icon(Icons.picture_as_pdf, size: 18),
            label: Text(AppLocalizations.of(context)!.exportPdf),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff10B981),
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Filters
          _buildFilters(),
          // Summary cards
          if (!_isLoading) _buildSummaryCards(),
          // Metrics list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _metrics.isEmpty
                    ? _buildEmptyState()
                    : _buildMetricsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          // Month picker
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _availableMonths.contains(_selectedMonth) ? _selectedMonth : null,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.dashboardMonth,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: _availableMonths.map((m) {
                final date = DateTime.parse('$m-01');
                return DropdownMenuItem(
                  value: m,
                  child: Text(DateFormat('MMMM yyyy').format(date)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedMonth = value);
                  _loadMetrics();
                }
              },
            ),
          ),
          SizedBox(width: 16),
          // Teacher picker
          Expanded(
            child: DropdownButtonFormField<String?>(
              value: _selectedTeacherId,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.roleTeacher,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: [
                DropdownMenuItem(value: null, child: Text(AppLocalizations.of(context)!.allTeachers)),
                ..._teachers.map((t) => DropdownMenuItem(
                      value: t['userId'],
                      child: Text(t['name'] ?? t['email'] ?? 'Unknown'),
                    )),
              ],
              onChanged: (value) {
                setState(() => _selectedTeacherId = value);
                _loadMetrics();
              },
            ),
          ),
          SizedBox(width: 16),
          // Tier picker
          Expanded(
            child: DropdownButtonFormField<PerformanceTier?>(
              value: _selectedTier,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.performanceTier,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: [
                DropdownMenuItem(value: null, child: Text(AppLocalizations.of(context)!.allTiers)),
                ...PerformanceTier.values.map((t) => DropdownMenuItem(
                      value: t,
                      child: Row(
                        children: [
                          Text(t.emoji),
                          const SizedBox(width: 8),
                          Text(t.displayName),
                        ],
                      ),
                    )),
              ],
              onChanged: (value) {
                setState(() => _selectedTier = value);
                _loadMetrics();
              },
            ),
          ),
          const SizedBox(width: 16),
          // Refresh button
          IconButton(
            onPressed: _loadMetrics,
            icon: const Icon(Icons.refresh),
            tooltip: AppLocalizations.of(context)!.commonRefresh,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final tierCounts = _summary['tierCounts'] as Map<String, int>? ?? {};

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildSummaryCard(
            'Total Teachers',
            '${_summary['totalTeachers'] ?? 0}',
            Icons.people,
            const Color(0xff0386FF),
          ),
          const SizedBox(width: 16),
          _buildSummaryCard(
            'Avg Score',
            '${(_summary['avgOverallScore'] ?? 0).toStringAsFixed(1)}%',
            Icons.score,
            const Color(0xff10B981),
          ),
          const SizedBox(width: 16),
          _buildSummaryCard(
            'Completion Rate',
            '${(_summary['avgCompletionRate'] ?? 0).toStringAsFixed(1)}%',
            Icons.check_circle,
            const Color(0xff8B5CF6),
          ),
          const SizedBox(width: 16),
          _buildSummaryCard(
            'Excellent',
            '${tierCounts['Excellent'] ?? 0}',
            Icons.emoji_events,
            const Color(0xffF59E0B),
          ),
          const SizedBox(width: 16),
          _buildSummaryCard(
            'Critical',
            '${tierCounts['Critical'] ?? 0}',
            Icons.warning,
            const Color(0xffEF4444),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
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
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
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
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xff111827),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _metrics.length,
      itemBuilder: (context, index) {
        final metrics = _metrics[index];
        return _buildMetricsCard(metrics);
      },
    );
  }

  Widget _buildMetricsCard(TeacherAuditMetrics metrics) {
    final tierColor = _getTierColor(metrics.performanceTier);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tierColor.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              CircleAvatar(
                backgroundColor: tierColor.withOpacity(0.1),
                child: Text(
                  metrics.teacherName.isNotEmpty
                      ? metrics.teacherName[0].toUpperCase()
                      : '?',
                  style: TextStyle(color: tierColor, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metrics.teacherName,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      metrics.teacherEmail,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // Overall score badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: tierColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Text(
                      metrics.performanceTier.emoji,
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${metrics.overallScore.toStringAsFixed(1)}%',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: tierColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Metrics grid
          Row(
            children: [
              _buildMetricChip('📅 Completion', metrics.completionRate, '%'),
              const SizedBox(width: 12),
              _buildMetricChip('⏰ Punctuality', metrics.punctualityRate, '%'),
              const SizedBox(width: 12),
              _buildMetricChip('📝 Forms', metrics.formComplianceRate, '%'),
              const SizedBox(width: 12),
              _buildMetricChip('📚 Scheduled', metrics.scheduledClasses.toDouble(), ''),
              const SizedBox(width: 12),
              _buildMetricChip('✅ Completed', metrics.completedClasses.toDouble(), ''),
              const SizedBox(width: 12),
              _buildMetricChip('❌ Missed', metrics.missedClasses.toDouble(), ''),
            ],
          ),
          // Flags
          if (metrics.flags.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              '🚩 Flags (${metrics.flags.length})',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: metrics.flags.take(5).map((flag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xffFEF2F2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xffFECACA)),
                  ),
                  child: Text(
                    flag.description,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xffDC2626),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricChip(String label, double value, String suffix) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xffF8FAFC),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              suffix.isEmpty
                  ? value.toInt().toString()
                  : '${value.toStringAsFixed(1)}$suffix',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xff111827),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.noAuditDataAvailable,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.runTheComputeScriptToGenerate,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _computeMetricsForPilot,
            icon: const Icon(Icons.calculate),
            label: Text(AppLocalizations.of(context)!.computeMetricsNow),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff8B5CF6),
              foregroundColor: Colors.white,
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

  Future<void> _computeMetricsForPilot() async {
    // Compute metrics directly in Dart for the pilot user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.computingMetricsThisMayTakeA)),
    );

    try {
      // Get pilot user info
      final pilotDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc('Thz8PIVUGpS5cjlIYBJAemjoQxw1')
          .get();

      if (!pilotDoc.exists) {
        throw Exception('Pilot user not found');
      }

      final userData = pilotDoc.data()!;
      final metrics = await AuditMetricsService.computeAndSaveMetrics(
        oderId: 'Thz8PIVUGpS5cjlIYBJAemjoQxw1',
        teacherEmail: userData['email'] ?? '',
        teacherName: '${userData['first_name'] ?? ''} ${userData['last_name'] ?? ''}'.trim(),
        yearMonth: _selectedMonth,
        pilotOnly: true,
      );

      if (metrics != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Metrics computed! Score: ${metrics.overallScore.toStringAsFixed(1)}%')),
        );
        _loadMetrics();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.errorE), backgroundColor: Colors.red),
      );
    }
  }

  void _exportToCSV() {
    if (_metrics.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.noDataToExport)),
      );
      return;
    }

    final csvData = StringBuffer();
    // Header
    csvData.writeln('Teacher Name,Email,Month,Scheduled,Completed,Missed,Completion Rate,Punctuality Rate,Form Compliance,Overall Score,Tier');

    // Data rows
    for (final m in _metrics) {
      csvData.writeln(
        '${m.teacherName},${m.teacherEmail},${m.yearMonth},${m.scheduledClasses},${m.completedClasses},${m.missedClasses},${m.completionRate.toStringAsFixed(1)},${m.punctualityRate.toStringAsFixed(1)},${m.formComplianceRate.toStringAsFixed(1)},${m.overallScore.toStringAsFixed(1)},${m.performanceTier.displayName}',
      );
    }

    // Download
    final bytes = utf8.encode(csvData.toString());
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'audit_report_$_selectedMonth.csv')
      ..click();
    html.Url.revokeObjectUrl(url);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.csvExportedSuccessfully)),
    );
  }

  void _generateReport() {
    // For now, generate a simple HTML report that can be printed as PDF
    if (_metrics.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.noDataToExport)),
      );
      return;
    }

    final htmlContent = StringBuffer();
    htmlContent.writeln('''
<!DOCTYPE html>
<html>
<head>
  <title>Audit Report - $_selectedMonth</title>
  <style>
    body { font-family: Arial, sans-serif; padding: 20px; }
    h1 { color: #111827; }
    .summary { display: flex; gap: 20px; margin-bottom: 30px; }
    .summary-card { background: #f8fafc; padding: 15px; border-radius: 8px; flex: 1; }
    .summary-card h3 { margin: 0 0 5px 0; font-size: 14px; color: #6b7280; }
    .summary-card p { margin: 0; font-size: 24px; font-weight: bold; }
    table { width: 100%; border-collapse: collapse; }
    th, td { padding: 12px; text-align: left; border-bottom: 1px solid #e5e7eb; }
    th { background: #f8fafc; font-weight: 600; }
    .excellent { color: #10B981; }
    .good { color: #0386FF; }
    .needsImprovement { color: #F59E0B; }
    .critical { color: #EF4444; }
  </style>
</head>
<body>
  <h1>🏫 Teacher Audit Report</h1>
  <h2>Period: ${DateFormat('MMMM yyyy').format(DateTime.parse('$_selectedMonth-01'))}</h2>
  
  <div class="summary">
    <div class="summary-card">
      <h3>Total Teachers</h3>
      <p>${_metrics.length}</p>
    </div>
    <div class="summary-card">
      <h3>Avg Score</h3>
      <p>${(_summary['avgOverallScore'] ?? 0).toStringAsFixed(1)}%</p>
    </div>
    <div class="summary-card">
      <h3>Avg Completion</h3>
      <p>${(_summary['avgCompletionRate'] ?? 0).toStringAsFixed(1)}%</p>
    </div>
  </div>
  
  <table>
    <thead>
      <tr>
        <th>Teacher</th>
        <th>Scheduled</th>
        <th>Completed</th>
        <th>Missed</th>
        <th>Completion</th>
        <th>Punctuality</th>
        <th>Forms</th>
        <th>Score</th>
        <th>Tier</th>
      </tr>
    </thead>
    <tbody>
''');

    for (final m in _metrics) {
      htmlContent.writeln('''
      <tr>
        <td><strong>${m.teacherName}</strong><br><small>${m.teacherEmail}</small></td>
        <td>${m.scheduledClasses}</td>
        <td>${m.completedClasses}</td>
        <td>${m.missedClasses}</td>
        <td>${m.completionRate.toStringAsFixed(1)}%</td>
        <td>${m.punctualityRate.toStringAsFixed(1)}%</td>
        <td>${m.formComplianceRate.toStringAsFixed(1)}%</td>
        <td><strong>${m.overallScore.toStringAsFixed(1)}%</strong></td>
        <td class="${m.performanceTier.name}">${m.performanceTier.emoji} ${m.performanceTier.displayName}</td>
      </tr>
''');
    }

    htmlContent.writeln('''
    </tbody>
  </table>
  
  <p style="margin-top: 30px; color: #6b7280; font-size: 12px;">
    Generated on ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}
  </p>
</body>
</html>
''');

    // Open in new tab for printing
    final blob = html.Blob([htmlContent.toString()], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.reportOpenedInNewTabUse)),
    );
  }
}

