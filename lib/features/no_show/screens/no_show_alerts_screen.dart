import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alluwalacademyadmin/core/models/employee_model.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';
import '../models/no_show_report.dart';
import '../services/no_show_service.dart';

class _NoShowReviewActionOption {
  final String key;
  final String label;
  final IconData icon;

  const _NoShowReviewActionOption({
    required this.key,
    required this.label,
    required this.icon,
  });
}

class _NoShowReviewDraft {
  final List<String> actionKeys;
  final List<String> actionLabels;
  final String note;

  const _NoShowReviewDraft({
    required this.actionKeys,
    required this.actionLabels,
    required this.note,
  });
}

/// Admin screen listing no-show alerts with search, type/status filters, a
/// repeat-absence patterns band, and a review workflow.
class NoShowAlertsScreen extends StatefulWidget {
  const NoShowAlertsScreen({super.key});

  @override
  State<NoShowAlertsScreen> createState() => _NoShowAlertsScreenState();
}

class _NoShowAlertsScreenState extends State<NoShowAlertsScreen> {
  static const _amber = Color(0xffF59E0B);
  static const _red = Color(0xffEF4444);
  static const _green = Color(0xff10B981);
  static const _slate = Color(0xff64748B);
  static const _border = Color(0xffE2E8F0);

  bool _loading = true;
  bool _enriching = false;
  bool _showAdvancedFilters = false;
  int _loadGeneration = 0;
  String? _error;
  List<NoShowReport> _reports = [];
  List<Employee> _teachers = [];
  List<Employee> _students = [];
  String _search = '';
  String _typeFilter = 'all'; // all | teacher | student
  String _statusFilter = 'all'; // all | pending | reviewed
  String _dateFilter = 'all'; // all | today | 7d | 30d | custom
  String _attendanceFilter = 'all'; // all | never_joined | late | present
  String? _selectedTeacherId;
  String? _selectedStudentId;
  DateTime? _fromDate;
  DateTime? _toDate;
  final Set<String> _reviewing = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    setState(() {
      _loading = true;
      _enriching = false;
      _error = null;
    });
    try {
      final reports = await NoShowService.fetchReports(
        limitN: 120,
        enrich: false,
      );
      if (!mounted) return;
      setState(() {
        _reports = reports;
        _loading = false;
        _enriching = reports.isNotEmpty;
      });
      unawaited(_loadPeople(generation));
      unawaited(_loadFullBaseHistory(generation));
      unawaited(_enrichReports(generation, reports));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadPeople(int generation) async {
    try {
      final results = await Future.wait([
        NoShowService.fetchAvailableTeachers(),
        NoShowService.fetchAvailableStudents(),
      ]);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _teachers = results[0];
        _students = results[1];
      });
    } catch (_) {}
  }

  Future<void> _loadFullBaseHistory(int generation) async {
    try {
      final reports = await NoShowService.fetchReports(
        limitN: 500,
        enrich: false,
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        final currentByKey = {
          for (final report in _reports) report.reviewKey: report,
        };
        _reports = reports
            .map((report) =>
                _mergeHistoryReport(report, currentByKey[report.reviewKey]))
            .toList(growable: false);
      });
    } catch (_) {}
  }

  Future<void> _enrichReports(
    int generation,
    List<NoShowReport> baseReports,
  ) async {
    try {
      final enriched = await NoShowService.enrichReports(baseReports);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        final enrichedByKey = {
          for (final report in enriched) report.reviewKey: report,
        };
        _reports = _reports.map((current) {
          final detail = enrichedByKey[current.reviewKey];
          if (detail == null) return current;
          return _mergeReportDetails(current, detail);
        }).toList(growable: false);
        _enriching = false;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _enriching = false);
    }
  }

  NoShowReport _mergeReportDetails(
    NoShowReport base,
    NoShowReport detail,
  ) {
    return base.copyWith(
      shiftStart: detail.shiftStart,
      shiftEnd: detail.shiftEnd,
      detectedAfterMinutes: detail.detectedAfterMinutes,
      teacherPresence: detail.teacherPresence,
      studentPresences: detail.studentPresences,
    );
  }

  NoShowReport _mergeHistoryReport(
    NoShowReport base,
    NoShowReport? current,
  ) {
    if (current == null) return base;
    var merged = _mergeReportDetails(base, current);
    final currentReviewedAt = current.reviewedAt;
    final baseReviewedAt = base.reviewedAt;
    final shouldPreserveLocalReview = currentReviewedAt != null &&
        (baseReviewedAt == null || currentReviewedAt.isAfter(baseReviewedAt));
    if (shouldPreserveLocalReview) {
      merged = merged.copyWith(
        status: current.status,
        reviewedBy: current.reviewedBy,
        reviewedByName: current.reviewedByName,
        reviewedByEmail: current.reviewedByEmail,
        reviewedAt: current.reviewedAt,
        reviewActions: current.reviewActions,
        reviewActionLabels: current.reviewActionLabels,
        reviewNote: current.reviewNote,
      );
    }
    return merged;
  }

  Employee? _selectedTeacher() => _employeeById(_teachers, _selectedTeacherId);

  Employee? _selectedStudent() => _employeeById(_students, _selectedStudentId);

  Employee? _employeeById(List<Employee> employees, String? id) {
    if (id == null) return null;
    for (final employee in employees) {
      if (employee.documentId == id) return employee;
    }
    return null;
  }

  String _employeeName(Employee employee) {
    final name = '${employee.firstName} ${employee.lastName}'.trim();
    return name.isNotEmpty ? name : employee.email;
  }

  List<_NoShowReviewActionOption> _reviewActionOptions(
    AppLocalizations l10n,
  ) {
    return [
      _NoShowReviewActionOption(
        key: 'contacted_teacher',
        label: l10n.noShowReviewActionContactedTeacher,
        icon: Icons.call_outlined,
      ),
      _NoShowReviewActionOption(
        key: 'contacted_student_parent',
        label: l10n.noShowReviewActionContactedStudentParent,
        icon: Icons.forum_outlined,
      ),
      _NoShowReviewActionOption(
        key: 'confirmed_teacher_late',
        label: l10n.noShowReviewActionConfirmedTeacherLate,
        icon: Icons.person_search_outlined,
      ),
      _NoShowReviewActionOption(
        key: 'confirmed_student_late',
        label: l10n.noShowReviewActionConfirmedStudentLate,
        icon: Icons.manage_search_outlined,
      ),
      _NoShowReviewActionOption(
        key: 'excused_absence',
        label: l10n.noShowReviewActionExcusedAbsence,
        icon: Icons.event_available_outlined,
      ),
      _NoShowReviewActionOption(
        key: 'rescheduled_class',
        label: l10n.noShowReviewActionRescheduledClass,
        icon: Icons.update_outlined,
      ),
      _NoShowReviewActionOption(
        key: 'technical_issue_followup',
        label: l10n.noShowReviewActionTechnicalFollowup,
        icon: Icons.support_agent_outlined,
      ),
      _NoShowReviewActionOption(
        key: 'payroll_billing_followup',
        label: l10n.noShowReviewActionBillingFollowup,
        icon: Icons.receipt_long_outlined,
      ),
      _NoShowReviewActionOption(
        key: 'escalated_to_admin',
        label: l10n.noShowReviewActionEscalatedAdmin,
        icon: Icons.report_problem_outlined,
      ),
      _NoShowReviewActionOption(
        key: 'false_alarm',
        label: l10n.noShowReviewActionFalseAlarm,
        icon: Icons.check_circle_outline,
      ),
    ];
  }

  List<NoShowReport> _filtered() {
    final q = _search.trim().toLowerCase();
    return _reports.where((r) {
      if (!_matchesDateFilter(r)) return false;
      if (!_matchesPersonFilters(r)) return false;
      if (!_matchesAttendanceFilter(r)) return false;
      if (_typeFilter == 'teacher' && !r.isTeacherNoShow) return false;
      if (_typeFilter == 'student' && !r.isStudentNoShow) return false;
      if (_statusFilter == 'pending' && r.isReviewed) return false;
      if (_statusFilter == 'reviewed' && !r.isReviewed) return false;
      if (q.isEmpty) return true;
      return r.teacherName.toLowerCase().contains(q) ||
          r.reporterName.toLowerCase().contains(q) ||
          r.shiftName.toLowerCase().contains(q) ||
          r.studentNames.any((s) => s.toLowerCase().contains(q));
    }).toList();
  }

  bool _matchesPersonFilters(NoShowReport r) {
    if (_selectedTeacherId != null &&
        r.teacherId != _selectedTeacherId &&
        r.teacherPresence?.userId != _selectedTeacherId) {
      return _enriching && r.teacherPresence == null;
    }
    if (_selectedStudentId != null &&
        !r.studentPresences.any((p) => p.userId == _selectedStudentId)) {
      return _enriching && r.studentPresences.isEmpty;
    }
    return true;
  }

  bool _matchesDateFilter(NoShowReport r) {
    if (_fromDate == null && _toDate == null) return true;
    final when = r.when;
    if (when == null) return false;
    final local = when.toLocal();
    if (_fromDate != null && local.isBefore(_startOfDay(_fromDate!))) {
      return false;
    }
    if (_toDate != null && local.isAfter(_endOfDay(_toDate!))) {
      return false;
    }
    return true;
  }

  bool _matchesAttendanceFilter(NoShowReport r) {
    if (_attendanceFilter == 'all') return true;
    final presences = _presenceTargets(r);
    if (presences.isEmpty) return _enriching;
    if (_attendanceFilter == 'never_joined') {
      return presences.any((p) => !p.joined);
    }
    if (_attendanceFilter == 'late') {
      return presences.any((p) => p.joinedLate);
    }
    if (_attendanceFilter == 'present') {
      return presences.any((p) => p.totalPresentMinutes > 0);
    }
    return true;
  }

  List<NoShowParticipantPresence> _presenceTargets(NoShowReport r) {
    if (_typeFilter == 'teacher') {
      return [if (r.teacherPresence != null) r.teacherPresence!];
    }
    if (_selectedStudentId != null) {
      return r.studentPresences
          .where((p) => p.userId == _selectedStudentId)
          .toList(growable: false);
    }
    if (_typeFilter == 'student') return r.studentPresences;
    return r.relevantPresences;
  }

  DateTime _startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  DateTime _endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

  void _setDateFilter(String value) {
    final today = _startOfDay(DateTime.now());
    setState(() {
      _dateFilter = value;
      if (value == 'all') {
        _fromDate = null;
        _toDate = null;
      } else if (value == 'today') {
        _fromDate = today;
        _toDate = today;
      } else if (value == '7d') {
        _fromDate = today.subtract(const Duration(days: 6));
        _toDate = today;
      } else if (value == '30d') {
        _fromDate = today.subtract(const Duration(days: 29));
        _toDate = today;
      }
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart
        ? (_fromDate ?? DateTime.now())
        : (_toDate ?? _fromDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dateFilter = 'custom';
      if (isStart) {
        _fromDate = picked;
        if (_toDate != null && _toDate!.isBefore(picked)) _toDate = picked;
      } else {
        _toDate = picked;
        if (_fromDate != null && _fromDate!.isAfter(picked)) {
          _fromDate = picked;
        }
      }
    });
  }

  Future<void> _pickTeacher(AppLocalizations l10n) async {
    if (_teachers.isEmpty) return;
    final selected = await showDialog<Employee>(
      context: context,
      builder: (context) => _NoShowEmployeeSelectionDialog(
        employees: _teachers,
        selectedId: _selectedTeacherId,
        title: l10n.selectTeacher,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _selectedTeacherId = selected.documentId);
  }

  Future<void> _pickStudent(AppLocalizations l10n) async {
    if (_students.isEmpty) return;
    final selected = await showDialog<Employee>(
      context: context,
      builder: (context) => _NoShowEmployeeSelectionDialog(
        employees: _students,
        selectedId: _selectedStudentId,
        title: l10n.selectStudent,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _selectedStudentId = selected.documentId);
  }

  Future<void> _markReviewed(NoShowReport r) async {
    final l10n = AppLocalizations.of(context)!;
    final review = await showDialog<_NoShowReviewDraft>(
      context: context,
      builder: (context) => _NoShowReviewDialog(
        report: r,
        actions: _reviewActionOptions(l10n),
      ),
    );
    if (review == null || !mounted) return;

    setState(() => _reviewing.add(r.reviewKey));
    try {
      final update = await NoShowService.markReviewed(
        r,
        actionKeys: review.actionKeys,
        actionLabels: review.actionLabels,
        note: review.note,
      );
      if (!mounted) return;
      setState(() {
        final i = _reports.indexWhere((x) => x.reviewKey == r.reviewKey);
        if (i != -1) {
          _reports[i] = _reports[i].copyWith(
            status: 'reviewed',
            reviewedBy: update.reviewedBy,
            reviewedByName: update.reviewedByName,
            reviewedByEmail: update.reviewedByEmail,
            reviewedAt: update.reviewedAt,
            reviewActions: update.reviewActions,
            reviewActionLabels: update.reviewActionLabels,
            reviewNote: update.reviewNote,
          );
        }
        _reviewing.remove(r.reviewKey);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _reviewing.remove(r.reviewKey));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: _red),
      );
    }
  }

  Future<void> _copySummary(AppLocalizations l10n, NoShowReport r) async {
    await Clipboard.setData(ClipboardData(text: _summaryText(l10n, r)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.noShowCopied),
        backgroundColor: _green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(
          l10n.noShowAlertsTitle,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xff1E293B),
          ),
        ),
        actions: [
          IconButton(
            tooltip:
                MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
            icon: const Icon(Icons.refresh, color: _slate),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorState(l10n)
              : Column(
                  children: [
                    _patternsBand(l10n),
                    _filterBar(l10n),
                    Expanded(child: _list(l10n)),
                  ],
                ),
    );
  }

  Widget _errorState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: _red, size: 40),
          const SizedBox(height: 12),
          Text(l10n.noShowLoadError,
              style: GoogleFonts.inter(fontSize: 14, color: _slate)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _load, child: Text(l10n.noShowRetry)),
        ],
      ),
    );
  }

  // ---- Patterns band -------------------------------------------------------

  Widget _patternsBand(AppLocalizations l10n) {
    final reports = _filtered();
    final total = reports.length;
    final teacherCount = reports.where((r) => r.isTeacherNoShow).length;
    final studentCount = reports.where((r) => r.isStudentNoShow).length;
    final pending = reports.where((r) => !r.isReviewed).length;
    final patterns = NoShowService.computeTeacherPatterns(reports)
        .where((p) => p.teacherNoShows > 0)
        .take(3)
        .toList();
    final topText = patterns
        .map((p) => '${p.teacherName} ${p.teacherNoShows}')
        .join('  ·  ');

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      child: Wrap(
        spacing: 10,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _compactMetric(Icons.event_busy, _slate, l10n.noShowStatTotal, total),
          _compactMetric(
            Icons.person_off,
            _red,
            l10n.noShowStatTeacher,
            teacherCount,
          ),
          _compactMetric(
            Icons.school,
            _amber,
            l10n.noShowStatStudent,
            studentCount,
          ),
          _compactMetric(
            Icons.rate_review,
            const Color(0xff3B82F6),
            l10n.noShowStatPending,
            pending,
          ),
          if (patterns.isNotEmpty) ...[
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Text(
                '${l10n.noShowTopAbsent}: $topText',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff64748B),
                ),
              ),
            ),
          ],
          if (_enriching)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _compactMetric(IconData icon, Color color, String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '$value',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: const Color(0xff1E293B),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: const Color(0xff64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, Color color, {bool outlined = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: outlined ? color : Colors.transparent),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  // ---- Filters -------------------------------------------------------------

  Widget _filterBar(AppLocalizations l10n) {
    final selectedTeacher = _selectedTeacher();
    final selectedStudent = _selectedStudent();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: l10n.noShowSearchHint,
                      hintStyle: GoogleFonts.inter(fontSize: 12),
                      prefixIcon: const Icon(Icons.search, size: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => setState(
                  () => _showAdvancedFilters = !_showAdvancedFilters,
                ),
                icon: Icon(
                  _showAdvancedFilters
                      ? Icons.expand_less
                      : Icons.tune_outlined,
                  size: 16,
                ),
                label: Text(
                  _showAdvancedFilters ? l10n.hide : l10n.filters,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      _hasAdvancedFilters ? const Color(0xff1a6ef5) : _slate,
                  side: BorderSide(
                    color:
                        _hasAdvancedFilters ? const Color(0xff1a6ef5) : _border,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _filterChip(
                l10n.noShowFilterAll,
                !_hasAnyFilters,
                () => setState(() {
                  _typeFilter = 'all';
                  _statusFilter = 'all';
                  _dateFilter = 'all';
                  _attendanceFilter = 'all';
                  _selectedTeacherId = null;
                  _selectedStudentId = null;
                  _fromDate = null;
                  _toDate = null;
                }),
              ),
              _filterChip(l10n.noShowTeacher, _typeFilter == 'teacher',
                  () => setState(() => _typeFilter = 'teacher')),
              _filterChip(l10n.noShowStudent, _typeFilter == 'student',
                  () => setState(() => _typeFilter = 'student')),
              _filterChip(
                l10n.noShowNeedsReview,
                _statusFilter == 'pending',
                () => setState(() => _statusFilter =
                    _statusFilter == 'pending' ? 'all' : 'pending'),
              ),
              _filterChip(
                l10n.noShowReviewed,
                _statusFilter == 'reviewed',
                () => setState(() => _statusFilter =
                    _statusFilter == 'reviewed' ? 'all' : 'reviewed'),
              ),
              _filterChip(l10n.noShowDateAll, _dateFilter == 'all',
                  () => _setDateFilter('all')),
              _filterChip(l10n.noShowDateToday, _dateFilter == 'today',
                  () => _setDateFilter('today')),
              _filterChip(l10n.noShowDate7Days, _dateFilter == '7d',
                  () => _setDateFilter('7d')),
              _filterChip(l10n.noShowDate30Days, _dateFilter == '30d',
                  () => _setDateFilter('30d')),
            ],
          ),
          if (_showAdvancedFilters) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xffF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _personFilterButton(
                    label: l10n.roleTeacher,
                    value: selectedTeacher == null
                        ? l10n.noShowFilterAll
                        : _employeeName(selectedTeacher),
                    icon: Icons.person_outline,
                    hasValue: selectedTeacher != null,
                    onTap: () => _pickTeacher(l10n),
                    onClear: selectedTeacher == null
                        ? null
                        : () => setState(() => _selectedTeacherId = null),
                  ),
                  _personFilterButton(
                    label: l10n.roleStudent,
                    value: selectedStudent == null
                        ? l10n.noShowFilterAll
                        : _employeeName(selectedStudent),
                    icon: Icons.school_outlined,
                    hasValue: selectedStudent != null,
                    onTap: () => _pickStudent(l10n),
                    onClear: selectedStudent == null
                        ? null
                        : () => setState(() => _selectedStudentId = null),
                  ),
                  _dateButton(
                    label: l10n.noShowFromDate,
                    date: _fromDate,
                    onTap: () => _pickDate(isStart: true),
                  ),
                  _dateButton(
                    label: l10n.noShowToDate,
                    date: _toDate,
                    onTap: () => _pickDate(isStart: false),
                  ),
                  _filterChip(
                    l10n.noShowAttendanceAll,
                    _attendanceFilter == 'all',
                    () => setState(() => _attendanceFilter = 'all'),
                  ),
                  _filterChip(
                    l10n.noShowNeverJoined,
                    _attendanceFilter == 'never_joined',
                    () => setState(() => _attendanceFilter = 'never_joined'),
                  ),
                  _filterChip(
                    l10n.noShowJoinedLate,
                    _attendanceFilter == 'late',
                    () => setState(() => _attendanceFilter = 'late'),
                  ),
                  _filterChip(
                    l10n.noShowHadPresence,
                    _attendanceFilter == 'present',
                    () => setState(() => _attendanceFilter = 'present'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool get _hasAdvancedFilters {
    return _selectedTeacherId != null ||
        _selectedStudentId != null ||
        _attendanceFilter != 'all' ||
        _dateFilter == 'custom';
  }

  bool get _hasAnyFilters {
    return _typeFilter != 'all' ||
        _statusFilter != 'all' ||
        _dateFilter != 'all' ||
        _attendanceFilter != 'all' ||
        _selectedTeacherId != null ||
        _selectedStudentId != null;
  }

  Widget _personFilterButton({
    required String label,
    required String value,
    required IconData icon,
    required bool hasValue,
    required VoidCallback onTap,
    required VoidCallback? onClear,
  }) {
    return SizedBox(
      width: 250,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: hasValue ? const Color(0xff1a6ef5) : _border,
              ),
            ),
            child: Row(
              children: [
                Icon(icon,
                    size: 16,
                    color: hasValue ? const Color(0xff1a6ef5) : _slate),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xff94A3B8),
                        ),
                      ),
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xff1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
                if (onClear != null)
                  IconButton(
                    onPressed: onClear,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints.tightFor(width: 28, height: 28),
                    icon: const Icon(Icons.close, size: 15, color: _slate),
                  )
                else
                  const Icon(Icons.expand_more, size: 16, color: _slate),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateButton({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    final text = date == null ? label : DateFormat('MMM d').format(date);
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.calendar_today_outlined, size: 14),
      label: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: _slate,
        side: const BorderSide(color: _border),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xffEFF6FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: selected ? const Color(0xff1a6ef5) : _border),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? const Color(0xff1a6ef5) : _slate)),
      ),
    );
  }

  // ---- List ----------------------------------------------------------------

  Widget _list(AppLocalizations l10n) {
    final rows = _filtered();
    if (rows.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available, size: 44, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(l10n.noShowEmpty,
                style: GoogleFonts.inter(
                    fontSize: 14, color: const Color(0xff94A3B8))),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        itemCount: rows.length,
        itemBuilder: (context, i) => _card(l10n, rows[i]),
      ),
    );
  }

  Widget _card(AppLocalizations l10n, NoShowReport r) {
    final when = r.when;
    final dateText =
        when == null ? '' : DateFormat('MMM d, yyyy · h:mm a').format(when);
    final typeColor = r.isTeacherNoShow ? _red : _amber;
    final busy = _reviewing.contains(r.reviewKey);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.event_busy, size: 16, color: typeColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.shiftName,
                        style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w700),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    if (dateText.isNotEmpty)
                      Text(dateText,
                          style: GoogleFonts.inter(
                              fontSize: 11, color: const Color(0xff94A3B8))),
                  ],
                ),
              ),
              _statusBadge(l10n, r),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (r.isTeacherNoShow) _pill(l10n.noShowTeacher, _red),
              if (r.isStudentNoShow) _pill(l10n.noShowStudent, _amber),
              if (r.reporterName.isNotEmpty)
                _tag(l10n.noShowReportedBy(r.reporterName)),
              if (r.teacherName.isNotEmpty)
                _tag(l10n.noShowTeacherLabel(r.teacherName)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_scheduleText(r).isNotEmpty)
                _tag(l10n.noShowScheduled(_scheduleText(r))),
              if (r.detectedAfterMinutes != null)
                _tag(l10n.noShowDetectedAfter(r.detectedAfterMinutes!)),
            ],
          ),
          _attendanceDetails(l10n, r),
          _reviewDetails(l10n, r),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _copySummary(l10n, r),
                  icon: const Icon(Icons.copy, size: 16, color: _slate),
                  label: Text(l10n.noShowCopySummary,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xff1E293B))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _border),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
                if (!r.isReviewed)
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => _markReviewed(r),
                    icon: busy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.check, size: 16, color: _green),
                    label: Text(l10n.noShowMarkReviewed,
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xff1E293B))),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _border),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _attendanceDetails(AppLocalizations l10n, NoShowReport r) {
    final rows = <Widget>[
      if (r.teacherPresence != null)
        _presenceRow(l10n, r.teacherPresence!, _red),
      ..._studentPresencesForDisplay(r)
          .map((p) => _presenceRow(l10n, p, _amber)),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 10, color: Color(0xffE2E8F0)),
            rows[i],
          ],
        ],
      ),
    );
  }

  Widget _reviewDetails(AppLocalizations l10n, NoShowReport r) {
    if (!r.isReviewed) return const SizedBox.shrink();

    final reviewer = _reviewerLabel(r);
    final actionLabels = _reviewActionLabelsForReport(l10n, r);
    final note = r.reviewNote?.trim() ?? '';
    if (reviewer.isEmpty && actionLabels.isEmpty && note.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (reviewer.isNotEmpty) _tag(l10n.noShowReviewedBy(reviewer)),
              for (final label in actionLabels) _tag(label),
            ],
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xffF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _border),
              ),
              child: Text(
                l10n.noShowReviewNoteLabel(note),
                style: GoogleFonts.inter(fontSize: 11, color: _slate),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<NoShowParticipantPresence> _studentPresencesForDisplay(
    NoShowReport report,
  ) {
    if (_selectedStudentId == null) return report.studentPresences;
    return report.studentPresences
        .where((presence) => presence.userId == _selectedStudentId)
        .toList(growable: false);
  }

  Widget _presenceRow(
    AppLocalizations l10n,
    NoShowParticipantPresence presence,
    Color color,
  ) {
    final roleLabel = presence.role == 'teacher'
        ? l10n.noShowRoleTeacher
        : l10n.noShowRoleStudent;
    final name = presence.name.trim().isNotEmpty ? presence.name : roleLabel;
    final detail = _presenceDetail(l10n, presence);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(
            presence.role == 'teacher' ? Icons.person_off : Icons.school,
            size: 14,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                presence.role == 'teacher'
                    ? l10n.noShowTeacherLabel(name)
                    : l10n.noShowStudentLabel(name),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xff334155),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xff64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _scheduleText(NoShowReport r) {
    final start = r.shiftStart?.toLocal();
    if (start == null) return '';
    final startText = DateFormat('MMM d, yyyy · h:mm a').format(start);
    final end = r.shiftEnd?.toLocal();
    if (end == null) return startText;
    return '$startText-${DateFormat('h:mm a').format(end)}';
  }

  String _presenceDetail(
    AppLocalizations l10n,
    NoShowParticipantPresence presence,
  ) {
    final pieces = <String>[];
    final joinedAt = presence.firstJoinedAt?.toLocal();
    if (joinedAt == null) {
      pieces.add(l10n.noShowNoJoinRecorded);
    } else {
      pieces.add(l10n.noShowJoinedAt(DateFormat('h:mm a').format(joinedAt)));
      final offsetText = _joinOffsetText(l10n, presence.joinOffsetMinutes);
      if (offsetText.isNotEmpty) pieces.add(offsetText);
    }
    pieces.add(l10n.noShowPresentMinutes(presence.totalPresentMinutes));
    return pieces.join(' · ');
  }

  String _joinOffsetText(AppLocalizations l10n, int? minutes) {
    if (minutes == null) return '';
    if (minutes > 0) return l10n.noShowJoinOffsetLate(minutes);
    if (minutes < 0) return l10n.noShowJoinOffsetEarly(minutes.abs());
    return l10n.noShowJoinOffsetOnTime;
  }

  String _reviewerLabel(NoShowReport r) {
    final name = r.reviewedByName?.trim() ?? '';
    if (name.isNotEmpty) return name;
    final email = r.reviewedByEmail?.trim() ?? '';
    if (email.isNotEmpty) return email;
    return r.reviewedBy?.trim() ?? '';
  }

  List<String> _reviewActionLabelsForReport(
    AppLocalizations l10n,
    NoShowReport r,
  ) {
    final labelsByKey = {
      for (final option in _reviewActionOptions(l10n)) option.key: option.label,
    };
    if (r.reviewActions.isNotEmpty) {
      final resolved = <String>[];
      for (var i = 0; i < r.reviewActions.length; i++) {
        final key = r.reviewActions[i];
        final fallback =
            i < r.reviewActionLabels.length ? r.reviewActionLabels[i] : key;
        final label = labelsByKey[key] ?? fallback;
        if (label.trim().isNotEmpty) resolved.add(label);
      }
      return resolved;
    }
    return r.reviewActionLabels;
  }

  String _summaryText(AppLocalizations l10n, NoShowReport r) {
    final reviewer = _reviewerLabel(r);
    final reviewActionLabels = _reviewActionLabelsForReport(l10n, r);
    final reviewNote = r.reviewNote?.trim() ?? '';
    final lines = <String>[
      '${l10n.noShowSummaryClass}: ${r.shiftName}',
      '${l10n.noShowSummaryAlert}: ${_alertTypes(l10n, r).join(', ')}',
      if (_scheduleText(r).isNotEmpty)
        '${l10n.noShowSummaryScheduled}: ${_scheduleText(r)}',
      if (r.detectedAfterMinutes != null)
        '${l10n.noShowSummaryDetected}: ${l10n.noShowDetectedAfter(r.detectedAfterMinutes!)}',
      if (r.teacherPresence != null)
        '${l10n.noShowRoleTeacher}: ${_presenceSummary(l10n, r.teacherPresence!)}',
      for (final student in _studentPresencesForDisplay(r))
        '${l10n.noShowRoleStudent}: ${_presenceSummary(l10n, student)}',
      '${l10n.noShowSummaryStatus}: ${r.isReviewed ? l10n.noShowReviewed : l10n.noShowNeedsReview}',
      if (reviewer.isNotEmpty) l10n.noShowReviewedBy(reviewer),
      if (reviewActionLabels.isNotEmpty)
        l10n.noShowReviewActionsLabel(reviewActionLabels.join(', ')),
      if (reviewNote.isNotEmpty) l10n.noShowReviewNoteLabel(reviewNote),
    ];
    return lines.join('\n');
  }

  String _presenceSummary(
    AppLocalizations l10n,
    NoShowParticipantPresence presence,
  ) {
    final name = presence.name.trim().isNotEmpty
        ? presence.name.trim()
        : (presence.role == 'teacher'
            ? l10n.noShowRoleTeacher
            : l10n.noShowRoleStudent);
    return '$name - ${_presenceDetail(l10n, presence)}';
  }

  List<String> _alertTypes(AppLocalizations l10n, NoShowReport r) {
    return [
      if (r.isTeacherNoShow) l10n.noShowTeacher,
      if (r.isStudentNoShow) l10n.noShowStudent,
    ];
  }

  Widget _statusBadge(AppLocalizations l10n, NoShowReport r) {
    final reviewed = r.isReviewed;
    final color = reviewed ? _green : _amber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(reviewed ? l10n.noShowReviewed : l10n.noShowNeedsReview,
          style: GoogleFonts.inter(
              fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xffF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: GoogleFonts.inter(fontSize: 11, color: _slate)),
    );
  }
}

class _NoShowEmployeeSelectionDialog extends StatefulWidget {
  final List<Employee> employees;
  final String? selectedId;
  final String title;

  const _NoShowEmployeeSelectionDialog({
    required this.employees,
    required this.selectedId,
    required this.title,
  });

  @override
  State<_NoShowEmployeeSelectionDialog> createState() =>
      _NoShowEmployeeSelectionDialogState();
}

class _NoShowEmployeeSelectionDialogState
    extends State<_NoShowEmployeeSelectionDialog> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Employee> get _filteredEmployees {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return widget.employees;
    return widget.employees.where((employee) {
      return employee.firstName.toLowerCase().contains(query) ||
          employee.lastName.toLowerCase().contains(query) ||
          employee.email.toLowerCase().contains(query) ||
          employee.studentCode.toLowerCase().contains(query) ||
          employee.kioskCode.toLowerCase().contains(query) ||
          employee.documentId.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 500,
        height: 600,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: l10n.search,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _filteredEmployees.isEmpty
                    ? Center(
                        child: Text(
                          l10n.noUsersFound,
                          style: GoogleFonts.inter(
                            color: const Color(0xff9CA3AF),
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredEmployees.length,
                        itemBuilder: (context, index) {
                          final employee = _filteredEmployees[index];
                          final isSelected =
                              employee.documentId == widget.selectedId;
                          final isStudent =
                              employee.userType.trim().toLowerCase() ==
                                  'student';
                          final code = employee.studentCode.trim().isNotEmpty
                              ? employee.studentCode.trim()
                              : employee.kioskCode.trim();
                          final name =
                              '${employee.firstName} ${employee.lastName}'
                                  .trim();

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            isThreeLine: isStudent,
                            leading: CircleAvatar(
                              backgroundColor: isSelected
                                  ? const Color(0xff0386FF)
                                  : const Color(0xffF3F4F6),
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xff6B7280),
                                ),
                              ),
                            ),
                            title: Text(
                              name.isNotEmpty ? name : employee.email,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: isStudent
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.idDisplaystudentcode(code.isEmpty
                                            ? employee.documentId
                                            : code),
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: const Color(0xff059669),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        employee.email,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: const Color(0xff6B7280),
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    employee.email,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: const Color(0xff6B7280),
                                    ),
                                  ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle,
                                    color: Color(0xff0386FF))
                                : null,
                            onTap: () => Navigator.pop(context, employee),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.commonCancel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoShowReviewDialog extends StatefulWidget {
  final NoShowReport report;
  final List<_NoShowReviewActionOption> actions;

  const _NoShowReviewDialog({
    required this.report,
    required this.actions,
  });

  @override
  State<_NoShowReviewDialog> createState() => _NoShowReviewDialogState();
}

class _NoShowReviewDialogState extends State<_NoShowReviewDialog> {
  final _noteController = TextEditingController();
  final Set<String> _selectedKeys = {};

  bool get _canSubmit =>
      _selectedKeys.isNotEmpty || _noteController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _noteController.addListener(_onNoteChanged);
  }

  @override
  void dispose() {
    _noteController
      ..removeListener(_onNoteChanged)
      ..dispose();
    super.dispose();
  }

  void _onNoteChanged() => setState(() {});

  void _submit() {
    final selected = widget.actions
        .where((action) => _selectedKeys.contains(action.key))
        .toList(growable: false);
    Navigator.pop(
      context,
      _NoShowReviewDraft(
        actionKeys:
            selected.map((action) => action.key).toList(growable: false),
        actionLabels:
            selected.map((action) => action.label).toList(growable: false),
        note: _noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final maxHeight = MediaQuery.of(context).size.height * 0.86;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 560, maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.noShowReviewTitle,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xff1E293B),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Text(
                widget.report.shiftName,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xff64748B),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 18),
              Text(
                l10n.noShowReviewActionsPrompt,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xff334155),
                ),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.actions.map((action) {
                      final selected = _selectedKeys.contains(action.key);
                      return FilterChip(
                        selected: selected,
                        avatar: Icon(action.icon, size: 16),
                        label: Text(
                          action.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        labelStyle: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (value) {
                          setState(() {
                            if (value) {
                              _selectedKeys.add(action.key);
                            } else {
                              _selectedKeys.remove(action.key);
                            }
                          });
                        },
                      );
                    }).toList(growable: false),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _noteController,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: l10n.noShowReviewOtherLabel,
                  hintText: l10n.noShowReviewOtherHint,
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.commonCancel),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _canSubmit ? _submit : null,
                    icon: const Icon(Icons.rate_review_outlined, size: 16),
                    label: Text(l10n.noShowReviewSubmit),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
