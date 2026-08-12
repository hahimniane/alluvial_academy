import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/app_search.dart';
import '../../../l10n/app_localizations.dart';
import '../models/student_attendance_overview.dart';
import '../services/admin_student_attendance_service.dart';

enum _StudentAttendancePeriod { weekly, monthly }

class AdminStudentAttendanceScreen extends StatefulWidget {
  const AdminStudentAttendanceScreen({super.key});

  @override
  State<AdminStudentAttendanceScreen> createState() =>
      _AdminStudentAttendanceScreenState();
}

class _AdminStudentAttendanceScreenState
    extends State<AdminStudentAttendanceScreen> {
  final _service = AdminStudentAttendanceService();
  final _searchController = TextEditingController();
  _StudentAttendancePeriod _period = _StudentAttendancePeriod.weekly;
  DateTime _referenceDate = DateTime.now();
  late Future<StudentAttendanceOverview> _overviewFuture;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _overviewFuture = _loadOverview();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<StudentAttendanceOverview> _loadOverview({
    bool forceRefresh = false,
  }) {
    return _service.loadOverview(
      periodType:
          _period == _StudentAttendancePeriod.weekly ? 'weekly' : 'monthly',
      referenceDate: _referenceDate,
      forceRefresh: forceRefresh,
    );
  }

  void _reload({bool forceRefresh = false}) {
    setState(() {
      _overviewFuture = _loadOverview(forceRefresh: forceRefresh);
    });
  }

  void _setPeriod(_StudentAttendancePeriod period) {
    if (_period == period) return;
    setState(() {
      _period = period;
      _referenceDate = DateTime.now();
      _overviewFuture = _loadOverview();
    });
  }

  void _movePeriod(int direction) {
    final current = _referenceDate;
    setState(() {
      _referenceDate = _period == _StudentAttendancePeriod.weekly
          ? current.add(Duration(days: 7 * direction))
          : DateTime(current.year, current.month + direction, 1);
      _overviewFuture = _loadOverview();
    });
  }

  bool get _canMoveNext {
    final now = DateTime.now();
    if (_period == _StudentAttendancePeriod.monthly) {
      return _referenceDate.year < now.year ||
          (_referenceDate.year == now.year && _referenceDate.month < now.month);
    }
    final nextReference = _referenceDate.add(const Duration(days: 7));
    return !nextReference.isAfter(now);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: FutureBuilder<StudentAttendanceOverview>(
          future: _overviewFuture,
          builder: (context, snapshot) {
            return Column(
              children: [
                _buildHeader(l10n, snapshot.data),
                Expanded(
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? const Center(child: CircularProgressIndicator())
                      : snapshot.hasError
                          ? _buildErrorState(l10n)
                          : _buildOverview(
                              l10n,
                              snapshot.data!,
                            ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(
    AppLocalizations l10n,
    StudentAttendanceOverview? overview,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final title = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.studentAttendanceAdminTitle,
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    l10n.studentAttendanceAdminSubtitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              );
              final actions = Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _periodButton(
                    l10n.studentAttendanceWeekly,
                    _period == _StudentAttendancePeriod.weekly,
                    () => _setPeriod(_StudentAttendancePeriod.weekly),
                  ),
                  _periodButton(
                    l10n.studentAttendanceMonthly,
                    _period == _StudentAttendancePeriod.monthly,
                    () => _setPeriod(_StudentAttendancePeriod.monthly),
                  ),
                  IconButton.filledTonal(
                    tooltip: l10n.studentAttendanceRefresh,
                    onPressed: () => _reload(forceRefresh: true),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              );

              if (constraints.maxWidth < 760) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: 16),
                    actions,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: title),
                  const SizedBox(width: 20),
                  actions,
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              IconButton(
                tooltip: l10n.studentAttendancePrevious,
                onPressed: () => _movePeriod(-1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  _periodLabel(l10n, overview),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF334155),
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.studentAttendanceNext,
                onPressed: _canMoveNext ? () => _movePeriod(1) : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _periodButton(String label, bool selected, VoidCallback onPressed) {
    return FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor:
            selected ? const Color(0xFFDBEAFE) : const Color(0xFFF1F5F9),
        foregroundColor:
            selected ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
      ),
      child: Text(label),
    );
  }

  String _periodLabel(
    AppLocalizations l10n,
    StudentAttendanceOverview? overview,
  ) {
    final start = overview?.periodStart?.toLocal();
    final exclusiveEnd = overview?.periodEnd?.toLocal();
    if (start == null || exclusiveEnd == null) return '';
    final end = exclusiveEnd.subtract(const Duration(days: 1));
    final formatter = DateFormat('MMM d, yyyy');
    return l10n.studentAttendancePeriodLabel(
      formatter.format(start),
      formatter.format(end),
    );
  }

  Widget _buildOverview(
    AppLocalizations l10n,
    StudentAttendanceOverview overview,
  ) {
    final students = overview.students.where((student) {
      return AppSearch.matches(
        query: _searchQuery,
        names: [student.studentName],
        emails: [student.studentEmail],
        phones: [student.studentPhone],
        ids: [student.studentId],
      );
    }).toList();

    return RefreshIndicator(
      onRefresh: () async => _reload(forceRefresh: true),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildSummary(l10n, overview),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final count = Text(
                l10n.studentAttendanceStudentsTracked(overview.students.length),
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF334155),
                ),
              );
              final search = SizedBox(
                width: constraints.maxWidth < 640 ? double.infinity : 330,
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: l10n.studentAttendanceSearchHint,
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
              );
              if (constraints.maxWidth < 640) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [count, const SizedBox(height: 12), search],
                );
              }
              return Row(
                children: [
                  Expanded(child: count),
                  search,
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          if (students.isEmpty)
            _buildEmptyState(l10n)
          else
            ...students.map((student) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildStudentCard(l10n, student),
                )),
        ],
      ),
    );
  }

  Widget _buildSummary(
    AppLocalizations l10n,
    StudentAttendanceOverview overview,
  ) {
    final totals = overview.totals;
    final cards = [
      _summaryCard(
        Icons.schedule_rounded,
        l10n.studentAttendanceClassTime,
        _formatHours(l10n, totals.totalPresenceMinutes),
        const Color(0xFF2563EB),
      ),
      _summaryCard(
        Icons.co_present_rounded,
        l10n.studentAttendanceAttended,
        totals.attendedClasses.toString(),
        const Color(0xFF059669),
      ),
      _summaryCard(
        Icons.event_busy_rounded,
        l10n.studentAttendanceMissed,
        totals.absentClasses.toString(),
        const Color(0xFFDC2626),
      ),
      _summaryCard(
        Icons.watch_later_rounded,
        l10n.studentAttendanceLate,
        totals.lateClasses.toString(),
        const Color(0xFFD97706),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 960
            ? 4
            : constraints.maxWidth >= 520
                ? 2
                : 1;
        final width = (constraints.maxWidth - ((columns - 1) * 12)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children:
              cards.map((card) => SizedBox(width: width, child: card)).toList(),
        );
      },
    );
  }

  Widget _summaryCard(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(
    AppLocalizations l10n,
    StudentAttendanceOverviewRow student,
  ) {
    final initial = student.studentName.trim().isEmpty
        ? '?'
        : student.studentName.trim().substring(0, 1).toUpperCase();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final identity = Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFDBEAFE),
                foregroundColor: const Color(0xFF1D4ED8),
                child: Text(initial),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.studentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    if (student.studentEmail.isNotEmpty)
                      Text(
                        student.studentEmail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
          final metrics = Wrap(
            spacing: 14,
            runSpacing: 10,
            children: [
              _studentMetric(
                l10n.studentAttendanceClassTime,
                _formatHours(l10n, student.totalPresenceMinutes),
                const Color(0xFF2563EB),
              ),
              _studentMetric(
                l10n.studentAttendanceAttended,
                student.attendedClasses.toString(),
                const Color(0xFF059669),
              ),
              _studentMetric(
                l10n.studentAttendanceMissed,
                student.absentClasses.toString(),
                const Color(0xFFDC2626),
              ),
              _studentMetric(
                l10n.studentAttendanceLate,
                student.lateClasses.toString(),
                const Color(0xFFD97706),
              ),
              _studentMetric(
                l10n.studentAttendanceRate,
                '${(student.attendanceRate * 100).round()}%',
                const Color(0xFF7C3AED),
              ),
            ],
          );

          if (constraints.maxWidth < 760) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                identity,
                const SizedBox(height: 14),
                metrics,
              ],
            );
          }
          return Row(
            children: [
              SizedBox(width: 260, child: identity),
              const SizedBox(width: 18),
              Expanded(child: metrics),
            ],
          );
        },
      ),
    );
  }

  Widget _studentMetric(String label, String value, Color color) {
    return SizedBox(
      width: 92,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Icon(Icons.event_available_rounded,
              size: 42, color: Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          Text(
            l10n.studentAttendanceNoDataTitle,
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.studentAttendanceNoDataBody,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: const Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 44, color: Color(0xFFDC2626)),
            const SizedBox(height: 12),
            Text(
              l10n.studentAttendanceLoadError,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }

  String _formatHours(AppLocalizations l10n, double minutes) {
    return l10n.studentAttendanceHoursValue((minutes / 60).toStringAsFixed(1));
  }
}
