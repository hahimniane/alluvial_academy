import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alluwalacademyadmin/core/enums/shift_enums.dart';
import 'package:alluwalacademyadmin/core/models/invoice.dart';
import 'package:alluwalacademyadmin/core/models/payment.dart';
import 'package:alluwalacademyadmin/core/services/invoice_service.dart';
import 'package:alluwalacademyadmin/core/services/parent_service.dart';
import 'package:alluwalacademyadmin/core/services/payment_service.dart';
import 'package:alluwalacademyadmin/core/services/user_role_service.dart';
import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import 'package:alluwalacademyadmin/features/parent/screens/invoice_detail_screen.dart';
import 'package:alluwalacademyadmin/features/parent/screens/parent_invoices_screen.dart';
import 'package:alluwalacademyadmin/features/parent/screens/payment_history_screen.dart';
import 'package:alluwalacademyadmin/features/parent/screens/payment_screen.dart';
import 'package:alluwalacademyadmin/features/parent/widgets/children_list_widget.dart';
import 'package:alluwalacademyadmin/features/parent/widgets/financial_summary_card.dart';
import 'package:alluwalacademyadmin/features/parent/widgets/invoice_card.dart';
import 'package:alluwalacademyadmin/features/parent/screens/student_detail_screen.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class ParentDashboardScreen extends StatefulWidget {
  final String? parentId;

  const ParentDashboardScreen({super.key, this.parentId});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  String? _parentId;
  Future<List<Map<String, dynamic>>>? _childrenFuture;
  Future<Map<String, double>>? _summaryFuture;
  Future<_ParentProgressOverview>? _progressOverviewFuture;
  Future<_ParentAttendanceAnalyticsOverview>? _attendanceAnalyticsFuture;
  _AttendanceReportPeriod _attendancePeriod = _AttendanceReportPeriod.weekly;
  String? _parentFirstName;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final parentId = widget.parentId ??
        UserRoleService.getCurrentUserId() ??
        FirebaseAuth.instance.currentUser?.uid;

    Map<String, dynamic>? userData;
    try {
      userData = await UserRoleService.getCurrentUserData();
    } catch (e) {
      AppLogger.error('ParentDashboard: Failed to load user data: $e');
    }

    if (!mounted) return;
    final childrenFuture =
        parentId == null ? null : ParentService.getParentChildren(parentId);

    setState(() {
      _parentId = parentId;
      _parentFirstName = (userData?['first_name'] ?? '').toString().trim();
      _childrenFuture = childrenFuture;
      _summaryFuture =
          parentId == null ? null : ParentService.getFinancialSummary(parentId);
      _progressOverviewFuture =
          childrenFuture?.then(_buildParentProgressOverview);
      _attendanceAnalyticsFuture = childrenFuture?.then(
        (children) => _buildParentAttendanceAnalyticsOverview(
          children,
          period: _attendancePeriod,
        ),
      );
    });
  }

  Future<void> _refresh() async {
    final parentId = _parentId;
    if (parentId == null) return;
    final childrenFuture = ParentService.getParentChildren(parentId);
    setState(() {
      _childrenFuture = childrenFuture;
      _summaryFuture = ParentService.getFinancialSummary(parentId);
      _progressOverviewFuture =
          childrenFuture.then(_buildParentProgressOverview);
      _attendanceAnalyticsFuture = childrenFuture.then(
        (children) => _buildParentAttendanceAnalyticsOverview(
          children,
          period: _attendancePeriod,
          forceRefresh: true,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final parentId = _parentId;
    if (parentId == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Text(
            AppLocalizations.of(context)!.unableToLoadParentAccountPlease,
            style: GoogleFonts.inter(color: const Color(0xFF6B7280)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _parentFirstName == null || _parentFirstName!.isEmpty
                      ? 'Parent Dashboard'
                      : 'Welcome, $_parentFirstName',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 16),
                FutureBuilder<Map<String, double>>(
                  future: _summaryFuture,
                  builder: (context, snapshot) {
                    final data = snapshot.data;
                    final outstanding = data?['outstanding'] ?? 0;
                    final overdue = data?['overdue'] ?? 0;
                    final paid = data?['paid'] ?? 0;
                    return FinancialSummaryCard(
                      outstanding: outstanding,
                      overdue: overdue,
                      paid: paid,
                      onPayNow: outstanding > 0
                          ? () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ParentInvoicesScreen(
                                    parentId: parentId,
                                    initialStatus: InvoiceStatus.pending,
                                  ),
                                ),
                              );
                            }
                          : null,
                    );
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _quickAction(
                        icon: Icons.receipt_long_rounded,
                        title: AppLocalizations.of(context)!.invoices,
                        subtitle: AppLocalizations.of(context)!.viewAndPay,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ParentInvoicesScreen(parentId: parentId),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _quickAction(
                        icon: Icons.payments_rounded,
                        title: AppLocalizations.of(context)!.payments,
                        subtitle: AppLocalizations.of(context)!.history,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  PaymentHistoryScreen(parentId: parentId),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FutureBuilder<_ParentProgressOverview>(
                  future: _progressOverviewFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildProgressLoadingCard();
                    }

                    if (snapshot.hasError) {
                      return _errorCard(
                          'Failed to load progress insights: ${snapshot.error}');
                    }

                    final overview = snapshot.data;
                    if (overview == null || overview.children.isEmpty) {
                      return _emptyCard(
                        icon: Icons.insights_rounded,
                        title: 'Progress insights will appear here',
                        subtitle:
                            'Once classes are scheduled, you will see weekly and child-level progress charts.',
                      );
                    }

                    return _buildProgressOverviewSection(overview);
                  },
                ),
                const SizedBox(height: 16),
                FutureBuilder<_ParentAttendanceAnalyticsOverview>(
                  future: _attendanceAnalyticsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildAttendanceAnalyticsLoadingCard();
                    }

                    if (snapshot.hasError) {
                      return _errorCard(
                        'Failed to load attendance analytics: ${snapshot.error}',
                      );
                    }

                    final overview = snapshot.data;
                    if (overview == null || overview.children.isEmpty) {
                      return _emptyCard(
                        icon: Icons.analytics_rounded,
                        title: 'Attendance analytics will appear here',
                        subtitle:
                            'Weekly and monthly attendance insights will show once classes and joins are recorded.',
                      );
                    }

                    return _buildAttendanceAnalyticsSection(overview);
                  },
                ),
                const SizedBox(height: 16),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _childrenFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator()));
                    }
                    if (snapshot.hasError) {
                      return _errorCard(
                          'Failed to load children: ${snapshot.error}');
                    }
                    final children =
                        snapshot.data ?? const <Map<String, dynamic>>[];
                    return ChildrenListWidget(
                      children: children,
                      onChildTap: (child) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => StudentDetailScreen(
                              studentId: child['id'] as String,
                              studentName: child['name'] as String,
                              parentId: parentId,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 20),
                _sectionHeader(
                  title: AppLocalizations.of(context)!.recentInvoices,
                  actionLabel: 'See all',
                  onAction: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ParentInvoicesScreen(parentId: parentId),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                StreamBuilder<List<Invoice>>(
                  stream: InvoiceService.getParentInvoices(parentId, limit: 5),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator()));
                    }
                    if (snapshot.hasError) {
                      return _errorCard(
                          'Failed to load invoices: ${snapshot.error}');
                    }
                    final invoices = snapshot.data ?? const <Invoice>[];
                    if (invoices.isEmpty) {
                      return _emptyCard(
                        icon: Icons.receipt_long_rounded,
                        title: AppLocalizations.of(context)!.noInvoicesYet,
                        subtitle: AppLocalizations.of(context)!
                            .whenInvoicesAreCreatedTheyWill,
                      );
                    }
                    return Column(
                      children: invoices
                          .map(
                            (inv) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: InvoiceCard(
                                invoice: inv,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => InvoiceDetailScreen(
                                          invoiceId: inv.id),
                                    ),
                                  );
                                },
                                onPayNow: inv.isFullyPaid ||
                                        inv.status == InvoiceStatus.cancelled
                                    ? null
                                    : () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => PaymentScreen(
                                                invoiceId: inv.id),
                                          ),
                                        );
                                      },
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 20),
                _sectionHeader(
                  title: AppLocalizations.of(context)!.recentPayments,
                  actionLabel: 'See all',
                  onAction: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            PaymentHistoryScreen(parentId: parentId),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                StreamBuilder<List<Payment>>(
                  stream: PaymentService.getPaymentHistory(parentId, limit: 5),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator()));
                    }
                    if (snapshot.hasError) {
                      return _errorCard(
                          'Failed to load payments: ${snapshot.error}');
                    }
                    final payments = snapshot.data ?? const <Payment>[];
                    if (payments.isEmpty) {
                      return _emptyCard(
                        icon: Icons.payments_rounded,
                        title: AppLocalizations.of(context)!.noPaymentsYet,
                        subtitle: AppLocalizations.of(context)!
                            .paymentHistoryWillAppearOnceYou,
                      );
                    }
                    return _paymentsList(payments);
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<_ParentProgressOverview> _buildParentProgressOverview(
    List<Map<String, dynamic>> children,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(const Duration(days: 6));
    final monthStart = now.subtract(const Duration(days: 30));
    final dayLabels = List<DateTime>.generate(
      7,
      (i) => weekStart.add(Duration(days: i)),
    );

    if (children.isEmpty) {
      return _ParentProgressOverview(
        children: const [],
        dayLabels: dayLabels,
        classesByDay: List<int>.filled(7, 0),
        topSubjects: const [],
        averageAttendanceRate: 0,
        totalLearningHours: 0,
        classesThisWeek: 0,
      );
    }

    final childSnapshots = await Future.wait<_ChildProgressSnapshot>(
      children.map(
        (child) => _buildChildProgressSnapshot(
          child,
          now: now,
          monthStart: monthStart,
          weekStart: weekStart,
        ),
      ),
    );

    final sortedChildren = [...childSnapshots]..sort((a, b) {
        final level = a.attentionLevel.index.compareTo(b.attentionLevel.index);
        if (level != 0) return level;
        return a.attendanceRate.compareTo(b.attendanceRate);
      });

    final classesByDay = List<int>.filled(7, 0);
    final subjectTotals = <String, int>{};
    double totalAttendance = 0;
    int attendanceContributors = 0;
    double totalLearningHours = 0;
    int classesThisWeek = 0;

    for (final child in sortedChildren) {
      for (var i = 0; i < child.weeklyClassCounts.length && i < 7; i++) {
        classesByDay[i] += child.weeklyClassCounts[i];
      }

      totalLearningHours += child.learningHoursLast30Days;
      classesThisWeek += child.classesLast7Days;

      if (child.totalTrackedClasses > 0) {
        totalAttendance += child.attendanceRate;
        attendanceContributors += 1;
      }

      child.subjectBreakdown.forEach((subject, subjectCount) {
        subjectTotals[subject] = (subjectTotals[subject] ?? 0) + subjectCount;
      });
    }

    final topSubjects = subjectTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _ParentProgressOverview(
      children: sortedChildren,
      dayLabels: dayLabels,
      classesByDay: classesByDay,
      topSubjects: topSubjects.take(4).toList(),
      averageAttendanceRate: attendanceContributors > 0
          ? totalAttendance / attendanceContributors
          : 0,
      totalLearningHours: totalLearningHours,
      classesThisWeek: classesThisWeek,
    );
  }

  Future<_ParentAttendanceAnalyticsOverview>
      _buildParentAttendanceAnalyticsOverview(
    List<Map<String, dynamic>> children, {
    required _AttendanceReportPeriod period,
    bool forceRefresh = false,
  }) async {
    if (children.isEmpty) {
      return _ParentAttendanceAnalyticsOverview(
        period: period,
        children: const [],
        averageAttendanceRate: 0,
        averagePunctualityRate: 0,
        totalScheduledClasses: 0,
        totalAttendedClasses: 0,
        totalLateClasses: 0,
        totalTeacherAbsentIncidents: 0,
        totalJoinsBeforeStartEvents: 0,
      );
    }

    final childSnapshots = await Future.wait<_ChildAttendanceAnalyticsSnapshot>(
      children.map(
        (child) => _buildChildAttendanceAnalyticsSnapshot(
          child,
          period: period,
          forceRefresh: forceRefresh,
        ),
      ),
    );

    final sortedChildren = [...childSnapshots]..sort((a, b) {
        final rateCompare = a.attendanceRate.compareTo(b.attendanceRate);
        if (rateCompare != 0) return rateCompare;
        return b.scheduledClasses.compareTo(a.scheduledClasses);
      });

    double totalAttendance = 0;
    double totalPunctuality = 0;
    int contributingChildren = 0;
    int totalScheduledClasses = 0;
    int totalAttendedClasses = 0;
    int totalLateClasses = 0;
    int totalTeacherAbsentIncidents = 0;
    int totalJoinsBeforeStartEvents = 0;

    for (final child in sortedChildren) {
      totalScheduledClasses += child.scheduledClasses;
      totalAttendedClasses += child.attendedClasses;
      totalLateClasses += child.lateClasses;
      totalTeacherAbsentIncidents += child.teacherAbsentClasses;
      totalJoinsBeforeStartEvents += child.joinsBeforeStartEvents;

      if (child.scheduledClasses > 0) {
        totalAttendance += child.attendanceRate;
        totalPunctuality += child.punctualityRate;
        contributingChildren += 1;
      }
    }

    return _ParentAttendanceAnalyticsOverview(
      period: period,
      children: sortedChildren,
      averageAttendanceRate:
          contributingChildren > 0 ? totalAttendance / contributingChildren : 0,
      averagePunctualityRate: contributingChildren > 0
          ? totalPunctuality / contributingChildren
          : 0,
      totalScheduledClasses: totalScheduledClasses,
      totalAttendedClasses: totalAttendedClasses,
      totalLateClasses: totalLateClasses,
      totalTeacherAbsentIncidents: totalTeacherAbsentIncidents,
      totalJoinsBeforeStartEvents: totalJoinsBeforeStartEvents,
    );
  }

  Future<_ChildAttendanceAnalyticsSnapshot>
      _buildChildAttendanceAnalyticsSnapshot(
    Map<String, dynamic> child, {
    required _AttendanceReportPeriod period,
    bool forceRefresh = false,
  }) async {
    final childId = (child['id'] ?? '').toString().trim();
    final childName = (child['name'] ?? 'Student').toString().trim();

    if (childId.isEmpty) {
      return _ChildAttendanceAnalyticsSnapshot.empty(
        id: childId,
        name: childName.isEmpty ? 'Student' : childName,
      );
    }

    final report = await ParentService.getStudentAttendanceReport(
      childId,
      periodType: _periodTypeValue(period),
      forceRefresh: forceRefresh,
    );

    if (report == null) {
      return _ChildAttendanceAnalyticsSnapshot.empty(
        id: childId,
        name: childName.isEmpty ? 'Student' : childName,
      );
    }

    final metrics = _asMap(report['metrics']);
    final rates = _asMap(report['rates']);
    final averages = _asMap(report['averages']);

    final scheduledClasses = _asInt(metrics['scheduled_classes']);
    final attendedClasses = _asInt(metrics['attended_classes']);
    final absentClasses = _asInt(metrics['absent_classes']);
    final lateClasses = _asInt(metrics['late_classes']);
    final onTimeClasses = _asInt(metrics['on_time_classes']);
    final teacherAbsentClasses =
        _asInt(metrics['student_present_teacher_absent_classes']);
    final joinsBeforeStartEvents =
        _asInt(metrics['total_joins_before_start_events']);
    final totalPresenceMinutes =
        _asDouble(metrics['total_student_presence_minutes']) ?? 0.0;
    final totalOverlapMinutes =
        _asDouble(metrics['total_teacher_overlap_minutes']) ?? 0.0;

    final attendanceRate = _asDouble(rates['attendance_rate']) ??
        (scheduledClasses > 0 ? attendedClasses / scheduledClasses : 0.0);
    final punctualityRate = _asDouble(rates['punctuality_rate']) ??
        (attendedClasses > 0 ? onTimeClasses / attendedClasses : 0.0);
    final lateRate = _asDouble(rates['late_rate']) ??
        (attendedClasses > 0 ? lateClasses / attendedClasses : 0.0);
    final presenceCoverageRate =
        _asDouble(rates['presence_coverage_rate']) ?? 0.0;
    final teacherOverlapRate = _asDouble(rates['teacher_overlap_rate']) ?? 0.0;
    final averageJoinOffsetMinutes =
        _asDouble(averages['average_join_offset_minutes']) ?? 0.0;

    return _ChildAttendanceAnalyticsSnapshot(
      id: childId,
      name: childName.isEmpty ? 'Student' : childName,
      hasReport: true,
      scheduledClasses: scheduledClasses,
      attendedClasses: attendedClasses,
      absentClasses: absentClasses,
      lateClasses: lateClasses,
      onTimeClasses: onTimeClasses,
      teacherAbsentClasses: teacherAbsentClasses,
      joinsBeforeStartEvents: joinsBeforeStartEvents,
      attendanceRate: attendanceRate.clamp(0.0, 1.0),
      punctualityRate: punctualityRate.clamp(0.0, 1.0),
      lateRate: lateRate.clamp(0.0, 1.0),
      presenceCoverageRate: presenceCoverageRate.clamp(0.0, 1.0),
      teacherOverlapRate: teacherOverlapRate.clamp(0.0, 1.0),
      averageJoinOffsetMinutes: averageJoinOffsetMinutes,
      totalPresenceMinutes: totalPresenceMinutes,
      totalOverlapMinutes: totalOverlapMinutes,
    );
  }

  String _periodTypeValue(_AttendanceReportPeriod period) {
    switch (period) {
      case _AttendanceReportPeriod.weekly:
        return 'weekly';
      case _AttendanceReportPeriod.monthly:
        return 'monthly';
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return const <String, dynamic>{};
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) {
      return int.tryParse(value.trim()) ?? 0;
    }
    return 0;
  }

  double? _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  void _setAttendancePeriod(_AttendanceReportPeriod period) {
    if (_attendancePeriod == period) return;
    final childrenFuture = _childrenFuture;
    if (childrenFuture == null) return;
    setState(() {
      _attendancePeriod = period;
      _attendanceAnalyticsFuture = childrenFuture.then(
        (children) => _buildParentAttendanceAnalyticsOverview(
          children,
          period: period,
        ),
      );
    });
  }

  Future<_ChildProgressSnapshot> _buildChildProgressSnapshot(
    Map<String, dynamic> child, {
    required DateTime now,
    required DateTime monthStart,
    required DateTime weekStart,
  }) async {
    final childId = (child['id'] ?? '').toString();
    final childName = (child['name'] ?? 'Student').toString().trim();
    final weeklyClassCounts = List<int>.filled(7, 0);

    if (childId.isEmpty) {
      return _ChildProgressSnapshot(
        id: childId,
        name: childName.isEmpty ? 'Student' : childName,
        attendanceRate: 0,
        completedClasses: 0,
        missedClasses: 0,
        cancelledClasses: 0,
        totalTrackedClasses: 0,
        classesLast7Days: 0,
        recentClasses: 0,
        previousClasses: 0,
        learningHoursLast30Days: 0,
        weeklyClassCounts: weeklyClassCounts,
        subjectBreakdown: const {},
        primarySubject: 'No completed classes',
        attentionLevel: _ChildAttentionLevel.watch,
      );
    }

    final shifts = await ParentService.getStudentShiftsHistory(
      childId,
      startDate: monthStart,
      endDate: now,
    );

    int completed = 0;
    int missed = 0;
    int cancelled = 0;
    int recentClasses = 0;
    int previousClasses = 0;
    double learningHours = 0;
    final subjectBreakdown = <String, int>{};

    final recentStart = now.subtract(const Duration(days: 7));
    final previousStart = now.subtract(const Duration(days: 14));
    final today = DateTime(now.year, now.month, now.day);

    for (final shift in shifts) {
      final shiftStart = shift.shiftStart;
      final shiftDay =
          DateTime(shiftStart.year, shiftStart.month, shiftStart.day);
      final dayIndex = shiftDay.difference(weekStart).inDays;
      if (dayIndex >= 0 && dayIndex < 7 && !shiftDay.isAfter(today)) {
        weeklyClassCounts[dayIndex] += 1;
      }

      if (shiftStart.isAfter(recentStart)) {
        recentClasses += 1;
      } else if (shiftStart.isAfter(previousStart)) {
        previousClasses += 1;
      }

      if (_isCompletedStatus(shift.status)) {
        completed += 1;
        final durationHours =
            shift.shiftEnd.difference(shift.shiftStart).inMinutes / 60.0;
        learningHours += durationHours > 0 ? durationHours : 0;

        final subjectRaw =
            (shift.subjectDisplayName ?? shift.subject.name).toString().trim();
        final subjectName = subjectRaw.isEmpty ? 'General' : subjectRaw;
        subjectBreakdown[subjectName] =
            (subjectBreakdown[subjectName] ?? 0) + 1;
      } else if (shift.status == ShiftStatus.missed) {
        missed += 1;
      } else if (shift.status == ShiftStatus.cancelled) {
        cancelled += 1;
      }
    }

    final tracked = completed + missed + cancelled;
    final attendanceRate = tracked > 0 ? completed / tracked : 0.0;

    final subjectEntries = subjectBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final primarySubject = subjectEntries.isEmpty
        ? 'No completed classes'
        : subjectEntries.first.key;

    return _ChildProgressSnapshot(
      id: childId,
      name: childName.isEmpty ? 'Student' : childName,
      attendanceRate: attendanceRate,
      completedClasses: completed,
      missedClasses: missed,
      cancelledClasses: cancelled,
      totalTrackedClasses: tracked,
      classesLast7Days: recentClasses,
      recentClasses: recentClasses,
      previousClasses: previousClasses,
      learningHoursLast30Days: learningHours,
      weeklyClassCounts: weeklyClassCounts,
      subjectBreakdown: subjectBreakdown,
      primarySubject: primarySubject,
      attentionLevel: _attentionLevelForRate(attendanceRate, tracked),
    );
  }

  bool _isCompletedStatus(ShiftStatus status) {
    return status == ShiftStatus.completed ||
        status == ShiftStatus.fullyCompleted ||
        status == ShiftStatus.partiallyCompleted;
  }

  _ChildAttentionLevel _attentionLevelForRate(
      double attendanceRate, int trackedClasses) {
    if (trackedClasses == 0) return _ChildAttentionLevel.watch;
    if (attendanceRate >= 0.8) return _ChildAttentionLevel.onTrack;
    if (attendanceRate >= 0.6) return _ChildAttentionLevel.watch;
    return _ChildAttentionLevel.needsSupport;
  }

  Widget _buildProgressLoadingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F2B57),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Building family progress insights...',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceAnalyticsLoadingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Loading attendance analytics...',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceAnalyticsSection(
      _ParentAttendanceAnalyticsOverview overview) {
    final periodLabel = overview.period == _AttendanceReportPeriod.weekly
        ? 'Weekly'
        : 'Monthly';
    final averageAttendancePercent =
        (overview.averageAttendanceRate * 100).round();
    final averagePunctualityPercent =
        (overview.averagePunctualityRate * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attendance Analytics',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$periodLabel attendance signals from actual class joins and overlap.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Wrap(
                spacing: 8,
                children: [
                  _buildAttendancePeriodChip(
                    label: 'Weekly',
                    selected:
                        _attendancePeriod == _AttendanceReportPeriod.weekly,
                    onTap: () =>
                        _setAttendancePeriod(_AttendanceReportPeriod.weekly),
                  ),
                  _buildAttendancePeriodChip(
                    label: 'Monthly',
                    selected:
                        _attendancePeriod == _AttendanceReportPeriod.monthly,
                    onTap: () =>
                        _setAttendancePeriod(_AttendanceReportPeriod.monthly),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                _buildAttendanceMetricCard(
                  icon: Icons.fact_check_rounded,
                  label: 'Attendance Avg',
                  value: '$averageAttendancePercent%',
                  accent: const Color(0xFF1D4ED8),
                ),
                _buildAttendanceMetricCard(
                  icon: Icons.alarm_on_rounded,
                  label: 'Punctuality Avg',
                  value: '$averagePunctualityPercent%',
                  accent: const Color(0xFF0F766E),
                ),
                _buildAttendanceMetricCard(
                  icon: Icons.watch_later_rounded,
                  label: 'Late Classes',
                  value: '${overview.totalLateClasses}',
                  accent: const Color(0xFFD97706),
                ),
                _buildAttendanceMetricCard(
                  icon: Icons.warning_amber_rounded,
                  label: 'Teacher Absent',
                  value: '${overview.totalTeacherAbsentIncidents}',
                  accent: const Color(0xFFDC2626),
                ),
              ];

              if (constraints.maxWidth < 680) {
                return Column(
                  children: cards
                      .map(
                        (card) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: card,
                        ),
                      )
                      .toList(),
                );
              }

              return Row(
                children: List<Widget>.generate(cards.length, (index) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: index == cards.length - 1 ? 0 : 10,
                      ),
                      child: cards[index],
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(height: 14),
          Text(
            'By Child',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          ...overview.children.map(
            (child) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildChildAttendanceAnalyticsCard(child),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendancePeriodChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1D4ED8) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFF1D4ED8) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11.2,
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

  Widget _buildChildAttendanceAnalyticsCard(
      _ChildAttendanceAnalyticsSnapshot child) {
    final attendancePercent = (child.attendanceRate * 100).round();
    final latePercent = (child.lateRate * 100).round();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  child.name,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$attendancePercent% attendance',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E40AF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              _inlineMetric('Scheduled', '${child.scheduledClasses}',
                  const Color(0xFF334155)),
              _inlineMetric('Attended', '${child.attendedClasses}',
                  const Color(0xFF15803D)),
              _inlineMetric(
                  'Absent', '${child.absentClasses}', const Color(0xFFDC2626)),
              _inlineMetric('Late', '$latePercent%', const Color(0xFFD97706)),
              _inlineMetric('Teacher Absent', '${child.teacherAbsentClasses}',
                  const Color(0xFFB91C1C)),
              _inlineMetric('Early Joins', '${child.joinsBeforeStartEvents}',
                  const Color(0xFF0F766E)),
            ],
          ),
          const SizedBox(height: 10),
          _dualProgressRow(
            labelLeft: 'Attendance',
            valueLeft: child.attendanceRate,
            colorLeft: const Color(0xFF2563EB),
            labelRight: 'Punctuality',
            valueRight: child.punctualityRate,
            colorRight: const Color(0xFF0F766E),
          ),
          const SizedBox(height: 8),
          Text(
            'Avg join offset: ${_formatJoinOffset(child.averageJoinOffsetMinutes)}  •  Presence: ${child.totalPresenceMinutes.toStringAsFixed(1)}m  •  Overlap: ${child.totalOverlapMinutes.toStringAsFixed(1)}m',
            style: GoogleFonts.inter(
              fontSize: 10.8,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inlineMetric(String label, String value, Color color) {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF334155),
        ),
        children: [
          TextSpan(
            text: '$value ',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          TextSpan(text: label),
        ],
      ),
    );
  }

  Widget _dualProgressRow({
    required String labelLeft,
    required double valueLeft,
    required Color colorLeft,
    required String labelRight,
    required double valueRight,
    required Color colorRight,
  }) {
    return Row(
      children: [
        Expanded(
          child: _singleProgress(
            label: labelLeft,
            value: valueLeft,
            color: colorLeft,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _singleProgress(
            label: labelRight,
            value: valueRight,
            color: colorRight,
          ),
        ),
      ],
    );
  }

  Widget _singleProgress({
    required String label,
    required double value,
    required Color color,
  }) {
    final normalized = value.clamp(0.0, 1.0);
    final percent = (normalized * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10.8,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF475569),
                ),
              ),
            ),
            Text(
              '$percent%',
              style: GoogleFonts.inter(
                fontSize: 10.8,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: normalized,
            minHeight: 6,
            backgroundColor: const Color(0xFFE2E8F0),
            color: color,
          ),
        ),
      ],
    );
  }

  String _formatJoinOffset(double minutes) {
    if (minutes.isNaN || minutes.isInfinite) return '--';
    if (minutes == 0) return 'On time';
    final absoluteMinutes = minutes.abs().toStringAsFixed(1);
    if (minutes < 0) return '$absoluteMinutes min early';
    return '$absoluteMinutes min late';
  }

  Widget _buildProgressOverviewSection(_ParentProgressOverview overview) {
    final averageAttendancePercent =
        (overview.averageAttendanceRate * 100).round();
    final supportCount = overview.needsSupportChildren;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F2B57), Color(0xFF1659B7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F2B57).withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Family Progress Overview',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Track attendance and learning momentum for all your children in one place.',
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.86),
                        fontSize: 12.5,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 86,
                height: 86,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: overview.averageAttendanceRate.clamp(0.0, 1.0),
                      strokeWidth: 8,
                      backgroundColor: Colors.white.withValues(alpha: 0.24),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$averageAttendancePercent%',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Avg',
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.86),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 680;
              final cards = [
                _buildProgressMetricCard(
                  icon: Icons.family_restroom_rounded,
                  label: 'Children',
                  value: '${overview.children.length}',
                  hint: 'Linked accounts',
                ),
                _buildProgressMetricCard(
                  icon: Icons.calendar_month_rounded,
                  label: 'Classes This Week',
                  value: '${overview.classesThisWeek}',
                  hint: 'Last 7 days',
                ),
                _buildProgressMetricCard(
                  icon: Icons.schedule_rounded,
                  label: 'Learning Hours',
                  value: overview.totalLearningHours.toStringAsFixed(1),
                  hint: 'Past 30 days',
                ),
                _buildProgressMetricCard(
                  icon: Icons.warning_amber_rounded,
                  label: 'Needs Support',
                  value: '$supportCount',
                  hint: 'Attendance under 60%',
                  accent: supportCount > 0
                      ? const Color(0xFFFCA5A5)
                      : const Color(0xFFA7F3D0),
                ),
              ];

              if (isNarrow) {
                return Column(
                  children: cards
                      .map(
                        (card) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: card,
                        ),
                      )
                      .toList(),
                );
              }

              return Row(
                children: List<Widget>.generate(cards.length, (index) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                          right: index == cards.length - 1 ? 0 : 10),
                      child: cards[index],
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildWeeklyActivityChart(overview),
          if (overview.topSubjects.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Top Subjects',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: overview.topSubjects
                  .map(
                    (entry) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.24)),
                      ),
                      child: Text(
                        '${entry.key} (${entry.value})',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            'Child Performance',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ...overview.children.map(
            (child) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildChildProgressCard(child),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required String hint,
    Color accent = const Color(0xFFBFDBFE),
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  hint,
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyActivityChart(_ParentProgressOverview overview) {
    final maxCount = overview.classesByDay.fold<int>(
      0,
      (current, value) => value > current ? value : current,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Weekly Activity',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${overview.classesThisWeek} classes',
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 112,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(overview.classesByDay.length, (index) {
                final value = overview.classesByDay[index];
                final normalized = maxCount == 0 ? 0.0 : value / maxCount;
                final barHeight = maxCount == 0 ? 8.0 : 10 + (normalized * 60);
                final dayLabel =
                    DateFormat('EEE').format(overview.dayLabels[index]);

                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        height: 12,
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '$value',
                              style: GoogleFonts.inter(
                                color: Colors.white.withValues(alpha: 0.86),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: AnimatedContainer(
                            duration:
                                Duration(milliseconds: 320 + (index * 35)),
                            height: barHeight,
                            width: 16,
                            decoration: BoxDecoration(
                              color: Colors.white
                                  .withValues(alpha: value == 0 ? 0.3 : 0.88),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 12,
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              dayLabel,
                              style: GoogleFonts.inter(
                                color: Colors.white.withValues(alpha: 0.86),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChildProgressCard(_ChildProgressSnapshot child) {
    final attendancePercent = (child.attendanceRate * 100).round();
    final trendDelta = child.recentClasses - child.previousClasses;
    final trendIcon = trendDelta > 0
        ? Icons.trending_up_rounded
        : trendDelta < 0
            ? Icons.trending_down_rounded
            : Icons.trending_flat_rounded;
    final trendColor = trendDelta > 0
        ? const Color(0xFF16A34A)
        : trendDelta < 0
            ? const Color(0xFFDC2626)
            : const Color(0xFF6B7280);
    final badgeColor = _attentionColor(child.attentionLevel);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFE0E7FF),
                foregroundColor: const Color(0xFF1E3A8A),
                child: Text(
                  child.name.isEmpty ? '?' : child.name[0].toUpperCase(),
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.name,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      child.primarySubject,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF4B5563),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _attentionLabel(child.attentionLevel),
                  style: GoogleFonts.inter(
                    color: badgeColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildSegmentedAttendanceBar(child),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildChildMetric(
                  label: 'Attendance',
                  value: child.totalTrackedClasses == 0
                      ? '--'
                      : '$attendancePercent%',
                  valueColor: const Color(0xFF0F172A),
                ),
              ),
              Expanded(
                child: _buildChildMetric(
                  label: 'Last 7 Days',
                  value:
                      '${child.classesLast7Days} class${child.classesLast7Days == 1 ? '' : 'es'}',
                  valueColor: const Color(0xFF1D4ED8),
                ),
              ),
              Expanded(
                child: _buildChildMetric(
                  label: 'Learning Hours',
                  value: '${child.learningHoursLast30Days.toStringAsFixed(1)}h',
                  valueColor: const Color(0xFF0F766E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(trendIcon, size: 16, color: trendColor),
              const SizedBox(width: 6),
              Text(
                trendDelta == 0
                    ? 'Stable vs previous week'
                    : trendDelta > 0
                        ? '+$trendDelta class activity vs previous week'
                        : '$trendDelta class activity vs previous week',
                style: GoogleFonts.inter(
                  color: trendColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedAttendanceBar(_ChildProgressSnapshot child) {
    final total = child.totalTrackedClasses;
    if (total == 0) {
      return Container(
        height: 8,
        decoration: BoxDecoration(
          color: const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(999),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            if (child.completedClasses > 0)
              Expanded(
                flex: child.completedClasses,
                child: Container(color: const Color(0xFF16A34A)),
              ),
            if (child.missedClasses > 0)
              Expanded(
                flex: child.missedClasses,
                child: Container(color: const Color(0xFFDC2626)),
              ),
            if (child.cancelledClasses > 0)
              Expanded(
                flex: child.cancelledClasses,
                child: Container(color: const Color(0xFF9CA3AF)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChildMetric({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Color _attentionColor(_ChildAttentionLevel level) {
    switch (level) {
      case _ChildAttentionLevel.needsSupport:
        return const Color(0xFFDC2626);
      case _ChildAttentionLevel.watch:
        return const Color(0xFFD97706);
      case _ChildAttentionLevel.onTrack:
        return const Color(0xFF15803D);
    }
  }

  String _attentionLabel(_ChildAttentionLevel level) {
    switch (level) {
      case _ChildAttentionLevel.needsSupport:
        return 'Needs Support';
      case _ChildAttentionLevel.watch:
        return 'Watch';
      case _ChildAttentionLevel.onTrack:
        return 'On Track';
    }
  }

  Widget _quickAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF1D4ED8)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader({
    required String title,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
        ),
        TextButton(
          onPressed: onAction,
          child: Text(
            actionLabel,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0386FF),
            ),
          ),
        ),
      ],
    );
  }

  Widget _paymentsList(List<Payment> payments) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: payments.map((p) {
          final amount = NumberFormat.simpleCurrency().format(p.amount);
          final created = p.createdAt == null
              ? ''
              : DateFormat.yMMMd().format(p.createdAt!);
          return ListTile(
            leading: _paymentStatusDot(p.status),
            title: Text(
              amount,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF111827),
              ),
            ),
            subtitle: Text(
              '${p.status.name.toUpperCase()}${created.isEmpty ? '' : ' • $created'}',
              style: GoogleFonts.inter(
                  fontSize: 12, color: const Color(0xFF6B7280)),
            ),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: Color(0xFF9CA3AF)),
            onTap: () async {
              final invoiceId = p.invoiceId.trim();
              if (invoiceId.isEmpty) return;
              final doc = await FirebaseFirestore.instance
                  .collection('invoices')
                  .doc(invoiceId)
                  .get();
              if (!mounted) return;
              if (!doc.exists) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(
                          AppLocalizations.of(context)!
                              .invoiceNotFoundForThisPayment,
                          style: GoogleFonts.inter())),
                );
                return;
              }
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => InvoiceDetailScreen(invoiceId: invoiceId)),
              );
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _paymentStatusDot(PaymentStatus status) {
    Color color;
    switch (status) {
      case PaymentStatus.completed:
        color = const Color(0xFF16A34A);
        break;
      case PaymentStatus.failed:
        color = const Color(0xFFDC2626);
        break;
      case PaymentStatus.processing:
        color = const Color(0xFF2563EB);
        break;
      case PaymentStatus.pending:
        color = const Color(0xFFF59E0B);
        break;
    }

    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _emptyCard(
      {required IconData icon,
      required String title,
      required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Icon(icon, color: const Color(0xFF6B7280)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF7F1D1D),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ChildAttentionLevel {
  needsSupport,
  watch,
  onTrack,
}

class _ParentProgressOverview {
  const _ParentProgressOverview({
    required this.children,
    required this.dayLabels,
    required this.classesByDay,
    required this.topSubjects,
    required this.averageAttendanceRate,
    required this.totalLearningHours,
    required this.classesThisWeek,
  });

  final List<_ChildProgressSnapshot> children;
  final List<DateTime> dayLabels;
  final List<int> classesByDay;
  final List<MapEntry<String, int>> topSubjects;
  final double averageAttendanceRate;
  final double totalLearningHours;
  final int classesThisWeek;

  int get needsSupportChildren => children
      .where(
          (child) => child.attentionLevel == _ChildAttentionLevel.needsSupport)
      .length;
}

class _ChildProgressSnapshot {
  const _ChildProgressSnapshot({
    required this.id,
    required this.name,
    required this.attendanceRate,
    required this.completedClasses,
    required this.missedClasses,
    required this.cancelledClasses,
    required this.totalTrackedClasses,
    required this.classesLast7Days,
    required this.recentClasses,
    required this.previousClasses,
    required this.learningHoursLast30Days,
    required this.weeklyClassCounts,
    required this.subjectBreakdown,
    required this.primarySubject,
    required this.attentionLevel,
  });

  final String id;
  final String name;
  final double attendanceRate;
  final int completedClasses;
  final int missedClasses;
  final int cancelledClasses;
  final int totalTrackedClasses;
  final int classesLast7Days;
  final int recentClasses;
  final int previousClasses;
  final double learningHoursLast30Days;
  final List<int> weeklyClassCounts;
  final Map<String, int> subjectBreakdown;
  final String primarySubject;
  final _ChildAttentionLevel attentionLevel;
}

enum _AttendanceReportPeriod {
  weekly,
  monthly,
}

class _ParentAttendanceAnalyticsOverview {
  const _ParentAttendanceAnalyticsOverview({
    required this.period,
    required this.children,
    required this.averageAttendanceRate,
    required this.averagePunctualityRate,
    required this.totalScheduledClasses,
    required this.totalAttendedClasses,
    required this.totalLateClasses,
    required this.totalTeacherAbsentIncidents,
    required this.totalJoinsBeforeStartEvents,
  });

  final _AttendanceReportPeriod period;
  final List<_ChildAttendanceAnalyticsSnapshot> children;
  final double averageAttendanceRate;
  final double averagePunctualityRate;
  final int totalScheduledClasses;
  final int totalAttendedClasses;
  final int totalLateClasses;
  final int totalTeacherAbsentIncidents;
  final int totalJoinsBeforeStartEvents;
}

class _ChildAttendanceAnalyticsSnapshot {
  const _ChildAttendanceAnalyticsSnapshot({
    required this.id,
    required this.name,
    required this.hasReport,
    required this.scheduledClasses,
    required this.attendedClasses,
    required this.absentClasses,
    required this.lateClasses,
    required this.onTimeClasses,
    required this.teacherAbsentClasses,
    required this.joinsBeforeStartEvents,
    required this.attendanceRate,
    required this.punctualityRate,
    required this.lateRate,
    required this.presenceCoverageRate,
    required this.teacherOverlapRate,
    required this.averageJoinOffsetMinutes,
    required this.totalPresenceMinutes,
    required this.totalOverlapMinutes,
  });

  factory _ChildAttendanceAnalyticsSnapshot.empty({
    required String id,
    required String name,
  }) {
    return _ChildAttendanceAnalyticsSnapshot(
      id: id,
      name: name,
      hasReport: false,
      scheduledClasses: 0,
      attendedClasses: 0,
      absentClasses: 0,
      lateClasses: 0,
      onTimeClasses: 0,
      teacherAbsentClasses: 0,
      joinsBeforeStartEvents: 0,
      attendanceRate: 0,
      punctualityRate: 0,
      lateRate: 0,
      presenceCoverageRate: 0,
      teacherOverlapRate: 0,
      averageJoinOffsetMinutes: 0,
      totalPresenceMinutes: 0,
      totalOverlapMinutes: 0,
    );
  }

  final String id;
  final String name;
  final bool hasReport;
  final int scheduledClasses;
  final int attendedClasses;
  final int absentClasses;
  final int lateClasses;
  final int onTimeClasses;
  final int teacherAbsentClasses;
  final int joinsBeforeStartEvents;
  final double attendanceRate;
  final double punctualityRate;
  final double lateRate;
  final double presenceCoverageRate;
  final double teacherOverlapRate;
  final double averageJoinOffsetMinutes;
  final double totalPresenceMinutes;
  final double totalOverlapMinutes;
}
