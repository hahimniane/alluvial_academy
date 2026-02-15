import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/teacher_audit_full.dart';
import '../../../core/services/teacher_audit_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

// ─── Palette ─────────────────────────────────────────────────────────────────
const _blue = Color(0xff0078D4);
const _green = Color(0xFF10B981);
const _orange = Color(0xFFF59E0B);
const _red = Color(0xFFEF4444);
const _slate = Color(0xff64748B);
const _bg = Color(0xFFF8FAFC);
const _border = Color(0xFFE2E8F0);

/// Teacher's monthly audit view — 3 tabs, zero extra Firestore queries.
/// Data comes from TeacherAuditFull (detailedShifts, detailedForms) already loaded.
class TeacherAuditDetailScreen extends StatefulWidget {
  final String? yearMonth;
  const TeacherAuditDetailScreen({super.key, this.yearMonth});

  @override
  State<TeacherAuditDetailScreen> createState() => _TeacherAuditDetailScreenState();
}

class _TeacherAuditDetailScreenState extends State<TeacherAuditDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  TeacherAuditFull? _audit;
  bool _isLoading = true;
  String _selectedYearMonth = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _selectedYearMonth =
        widget.yearMonth ?? DateFormat('yyyy-MM').format(DateTime.now());
    _loadAudit();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadAudit() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    final audit = await TeacherAuditService.getMyAudit(
      yearMonth: _selectedYearMonth,
    );

    // Teachers only see completed audits
    if (audit == null ||
        audit.status != AuditStatus.completed ||
        audit.oderId != user.uid) {
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
          final isSelected = m == _selectedYearMonth;
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, m),
            child: Text(
              DateFormat('MMMM yyyy').format(date),
              style: TextStyle(
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? _blue : null,
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
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(
          AppLocalizations.of(context)!.myMonthlyReport,
          style: GoogleFonts.inter(
              fontWeight: FontWeight.w600, fontSize: 16, color: const Color(0xff1E293B)),
        ),
        actions: [
          TextButton.icon(
            onPressed: _selectMonth,
            icon: const Icon(Icons.calendar_month_outlined, size: 16),
            label: Text(
              DateFormat('MMM yyyy')
                  .format(DateTime.parse('$_selectedYearMonth-01')),
              style: GoogleFonts.inter(fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _loadAudit,
            tooltip: AppLocalizations.of(context)!.commonRefresh,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _border)),
            ),
            child: TabBar(
              controller: _tab,
              labelColor: _blue,
              unselectedLabelColor: _slate,
              indicatorColor: _blue,
              indicatorWeight: 2,
              labelStyle:
                  GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
              tabs: [
                Tab(text: AppLocalizations.of(context)!.teacherAuditTabSummary),
                Tab(text: AppLocalizations.of(context)!.teacherAuditTabMyClasses),
                Tab(text: AppLocalizations.of(context)!.teacherAuditTabDispute),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _blue))
          : _audit == null
              ? _buildEmptyState()
              : TabBarView(
                  controller: _tab,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _SummaryTab(audit: _audit!),
                    _ClassesTab(audit: _audit!),
                    _DisputeTab(
                        audit: _audit!, onSubmit: _loadAudit),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: _border),
              ),
              child: const Icon(Icons.assessment_outlined,
                  size: 48, color: _slate),
            ),
            const SizedBox(height: 20),
            Text(
              AppLocalizations.of(context)!.teacherAuditReportNotAvailable,
              style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff1E293B)),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.teacherAuditReportNotFinalizedMessage(
                DateFormat('MMMM yyyy').format(DateTime.parse('$_selectedYearMonth-01')),
              ),
              style: GoogleFonts.inter(fontSize: 14, color: _slate),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ONGLET 1 — Résumé (score, salaire, KPIs, barres, paiement, issues)
// ─────────────────────────────────────────────────────────────────────────────
class _SummaryTab extends StatelessWidget {
  final TeacherAuditFull audit;
  const _SummaryTab({required this.audit});

  Color get _tierColor {
    switch (audit.performanceTier) {
      case 'excellent':
        return _green;
      case 'good':
        return _blue;
      case 'needsImprovement':
        return _orange;
      default:
        return _red;
    }
  }

  String get _tierLabel {
    switch (audit.performanceTier) {
      case 'excellent':
        return 'Excellent 🏆';
      case 'good':
        return 'Bien 👍';
      case 'needsImprovement':
        return 'À améliorer';
      default:
        return 'Critique';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ps = audit.paymentSummary;
    final netPay = ps?.totalNetPayment ?? 0;
    final grossPay = ps?.totalGrossPayment ?? 0;
    final hasIssues = audit.issues.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Hero : Score + Salaire ─────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      value: audit.overallScore / 100,
                      strokeWidth: 7,
                      strokeCap: StrokeCap.round,
                      backgroundColor: _tierColor.withOpacity(0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(_tierColor),
                    ),
                  ),
                  Text(
                    '${audit.overallScore.toStringAsFixed(0)}%',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _tierColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tierLabel,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _tierColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMMM yyyy')
                          .format(DateTime.parse('${audit.yearMonth}-01')),
                      style: GoogleFonts.inter(
                          fontSize: 13, color: _slate),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _green.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.payments_outlined,
                              size: 16, color: _green),
                          const SizedBox(width: 6),
                          Text(
                            '\$${netPay.toStringAsFixed(2)} net',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ── 4 chiffres clés ────────────────────────────────────────────────
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.1,
          children: [
            _KpiTile(
              icon: Icons.school_outlined,
              color: _blue,
              label: AppLocalizations.of(context)!.teacherAuditClassesLabel,
              value:
                  '${audit.totalClassesCompleted} / ${audit.totalClassesScheduled}',
              sub: 'Taux ${audit.completionRate.clamp(0, 100).toStringAsFixed(0)}%',
            ),
            _KpiTile(
              icon: Icons.timer_outlined,
              color: const Color(0xFF8B5CF6),
              label: AppLocalizations.of(context)!.teacherAuditHoursLabel,
              value:
                  '${audit.totalHoursTaught.toStringAsFixed(1)} h',
              sub: '${audit.hoursTaughtBySubject.length} matière(s)',
            ),
            _KpiTile(
              icon: Icons.description_outlined,
              color: audit.readinessFormsSubmitted >=
                      audit.readinessFormsRequired
                  ? _green
                  : _orange,
              label: AppLocalizations.of(context)!.teacherAuditFormsLabel,
              value:
                  '${audit.readinessFormsSubmitted} / ${audit.readinessFormsRequired}',
              sub: 'Conformité ${audit.formComplianceRate.clamp(0, 100).toStringAsFixed(0)}%',
            ),
            _KpiTile(
              icon: Icons.access_time_outlined,
              color:
                  audit.lateClockIns == 0 ? _green : _orange,
              label: AppLocalizations.of(context)!.teacherAuditPunctualityLabel,
              value: '${audit.punctualityRate.clamp(0, 100).toStringAsFixed(0)}%',
              sub: audit.lateClockIns == 0
                  ? '✓ Aucun retard'
                  : '${audit.lateClockIns} retard(s)',
            ),
          ],
        ),

        const SizedBox(height: 12),

        // ── Barres de progression ──────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context)!.teacherAuditPerformanceSection,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _slate,
                      letterSpacing: 0.5)),
              const SizedBox(height: 12),
              _RateBar(
                label: AppLocalizations.of(context)!.auditCompletionRateLabel,
                rate: audit.completionRate,
                good: 80,
                warn: 60,
              ),
              const SizedBox(height: 10),
              _RateBar(
                label: AppLocalizations.of(context)!.teacherAuditPunctualityLabel,
                rate: audit.punctualityRate,
                good: 85,
                warn: 70,
              ),
              const SizedBox(height: 10),
              _RateBar(
                label: AppLocalizations.of(context)!.teacherAuditFormsLabel,
                rate: audit.formComplianceRate,
                good: 90,
                warn: 70,
              ),
            ],
          ),
        ),

        // ── Récap paiement détaillé ────────────────────────────────────────
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context)!.teacherAuditPaymentSection,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _slate,
                      letterSpacing: 0.5)),
              const SizedBox(height: 12),
              _PayRow(label: AppLocalizations.of(context)!.teacherAuditGross, value: '\$${grossPay.toStringAsFixed(2)}'),
              if (ps != null && ps.totalPenalties > 0)
                _PayRow(
                  label: AppLocalizations.of(context)!.teacherAuditPenalties,
                  value: '-\$${ps.totalPenalties.toStringAsFixed(2)}',
                  color: _red,
                ),
              if (ps != null && ps.totalBonuses > 0)
                _PayRow(
                  label: AppLocalizations.of(context)!.teacherAuditBonuses,
                  value: '+\$${ps.totalBonuses.toStringAsFixed(2)}',
                  color: _green,
                ),
              if (ps != null && ps.adminAdjustment != 0) ...[
                _PayRow(
                  label: AppLocalizations.of(context)!.teacherAuditAdminAdjustment,
                  value:
                      '${ps.adminAdjustment >= 0 ? '+' : ''}\$${ps.adminAdjustment.toStringAsFixed(2)}',
                  color: ps.adminAdjustment >= 0 ? _green : _red,
                ),
              ],
              const Divider(height: 16, color: _border),
              _PayRow(
                label: AppLocalizations.of(context)!.teacherAuditNetToReceive,
                value: '\$${netPay.toStringAsFixed(2)}',
                isBold: true,
                color: _green,
                fontSize: 16,
              ),
              if (ps != null && ps.paymentsBySubject.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...ps.paymentsBySubject.values.map((sp) =>
                    _SubjectPayRow(payment: sp)),
              ],
            ],
          ),
        ),

        // ── Issues ────────────────────────────────────────────────────────
        if (hasIssues) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _red.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 16, color: _red),
                    const SizedBox(width: 6),
                    Text(AppLocalizations.of(context)!.teacherAuditPointsOfAttention,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _slate,
                          letterSpacing: 0.5,
                        )),
                  ],
                ),
                const SizedBox(height: 10),
                ...audit.issues.map((issue) {
                  final sev = issue.severity;
                  final col = sev == 'high'
                      ? _red
                      : sev == 'medium'
                          ? _orange
                          : Colors.yellow.shade700;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: col.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: col.withOpacity(0.25)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          sev == 'high'
                              ? Icons.error_outline
                              : Icons.warning_amber_outlined,
                          size: 16,
                          color: col,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                issue.type
                                    .replaceAll('_', ' ')
                                    .toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: col,
                                ),
                              ),
                              if (issue.description.isNotEmpty)
                                Text(
                                  issue.description,
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: const Color(
                                          0xff374151)),
                                ),
                            ],
                          ),
                        ),
                        if (issue.penaltyAmount != null &&
                            issue.penaltyAmount! > 0)
                          Text(
                            '-\$${issue.penaltyAmount!.toStringAsFixed(2)}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _red,
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ONGLET 2 — Mes classes (audit.detailedShifts + audit.detailedForms, no Firestore)
// ─────────────────────────────────────────────────────────────────────────────
class _ClassesTab extends StatelessWidget {
  final TeacherAuditFull audit;
  const _ClassesTab({required this.audit});

  @override
  Widget build(BuildContext context) {
    final shifts = audit.detailedShifts;

    // ShiftIds that have a form (full id + last 8 chars for suffix matching)
    final formsShiftIds = <String>{};
    for (final f in audit.detailedForms) {
      final sid = (f['shiftId'] as String?) ?? '';
      if (sid.isNotEmpty) {
        formsShiftIds.add(sid);
        if (sid.length >= 8) {
          formsShiftIds.add(sid.substring(sid.length - 8));
        }
      }
    }

    bool hasFormForShift(String shiftId) {
      if (formsShiftIds.contains(shiftId)) return true;
      if (shiftId.length >= 8 &&
          formsShiftIds.contains(shiftId.substring(shiftId.length - 8))) {
        return true;
      }
      return false;
    }

    if (shifts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 48, color: _slate),
            const SizedBox(height: 12),
            Text(AppLocalizations.of(context)!.noClassesFound,
                style:
                    GoogleFonts.inter(color: _slate, fontSize: 14)),
          ],
        ),
      );
    }

    // Sort by start (detailedShifts use 'start', not 'scheduledAt')
    final sorted = [...shifts]..sort((a, b) {
        final aT =
            (a['start'] as Timestamp?)?.toDate() ??
                DateTime(1970);
        final bT =
            (b['start'] as Timestamp?)?.toDate() ??
                DateTime(1970);
        return aT.compareTo(bT);
      });

    final done = sorted
        .where((s) =>
            (s['status'] as String?) == 'completed' ||
            (s['status'] as String?) == 'fullyCompleted' ||
            (s['status'] as String?) == 'partiallyCompleted')
        .length;
    final missed = sorted
        .where((s) => (s['status'] as String?) == 'missed')
        .length;

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 10),
          child: Row(
            children: [
              _MiniStat(
                label: 'Total',
                value: '${sorted.length}',
                icon: Icons.event_note_outlined,
              ),
              const SizedBox(width: 20),
              _MiniStat(
                label: 'Réalisées',
                value: '$done',
                icon: Icons.check_circle_outline,
                color: _green,
              ),
              const SizedBox(width: 20),
              _MiniStat(
                label: 'Manquées',
                value: '$missed',
                icon: Icons.cancel_outlined,
                color: missed > 0 ? _red : _slate,
              ),
              const SizedBox(width: 20),
              _MiniStat(
                label: 'Forms',
                value: '${audit.readinessFormsSubmitted}',
                icon: Icons.description_outlined,
                color: _blue,
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: _border),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: sorted.length,
            separatorBuilder: (_, __) => const Divider(
                height: 1, indent: 56, color: Color(0xFFF1F5F9)),
            itemBuilder: (context, index) {
              final shift = sorted[index];
              final shiftId =
                  (shift['id'] as String?) ?? '';
              final title =
                  (shift['title'] as String?) ?? '—';
              final status =
                  (shift['status'] as String?) ?? '';
              final startAt =
                  (shift['start'] as Timestamp?)
                      ?.toDate();
              final duration =
                  (shift['duration'] as num?)
                          ?.toDouble() ??
                      0;
              final hasForm = hasFormForShift(shiftId);

              final isDone = status == 'completed' ||
                  status == 'fullyCompleted' ||
                  status == 'partiallyCompleted';
              final isMissed = status == 'missed';

              final statusColor = isDone
                  ? _green
                  : isMissed
                      ? _red
                      : _orange;
              final statusBg = isDone
                  ? const Color(0xFFDCFCE7)
                  : isMissed
                      ? const Color(0xFFFEE2E2)
                      : const Color(0xFFFEF3C7);

              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isDone
                        ? Icons.check
                        : isMissed
                            ? Icons.close
                            : Icons.schedule,
                    size: 20,
                    color: statusColor,
                  ),
                ),
                title: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xff1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  startAt != null
                      ? DateFormat('EEE d MMM · HH:mm')
                          .format(startAt)
                      : '—',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: _slate),
                ),
                trailing: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  crossAxisAlignment:
                      CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: hasForm
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFFEF3C7),
                        borderRadius:
                            BorderRadius.circular(10),
                      ),
                      child: Text(
                        hasForm ? '✓ Form' : 'Form ?',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: hasForm
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFB45309),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      duration > 0
                          ? '${duration.toStringAsFixed(1)}h'
                          : '',
                      style: GoogleFonts.inter(
                          fontSize: 10, color: _slate),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ONGLET 3 — Contester
// ─────────────────────────────────────────────────────────────────────────────
class _DisputeTab extends StatefulWidget {
  final TeacherAuditFull audit;
  final VoidCallback onSubmit;

  const _DisputeTab(
      {required this.audit, required this.onSubmit});

  @override
  State<_DisputeTab> createState() => _DisputeTabState();
}

class _DisputeTabState extends State<_DisputeTab> {
  final _formKey = GlobalKey<FormState>();
  final _reasonCtrl = TextEditingController();
  final _suggCtrl = TextEditingController();
  String? _selectedField;
  bool _isSubmitting = false;

  static const _disputeFields = [
    {'id': 'classes_count', 'label': 'Nombre de classes'},
    {'id': 'hours_taught', 'label': 'Heures enseignées'},
    {'id': 'punctuality_rate', 'label': 'Taux de ponctualité'},
    {'id': 'forms_count', 'label': 'Nombre de formulaires'},
    {'id': 'payment_amount', 'label': 'Montant du paiement'},
    {'id': 'overall_score', 'label': 'Score global'},
    {'id': 'other', 'label': 'Autre'},
  ];

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _suggCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      await TeacherAuditService.submitDispute(
        auditId: widget.audit.id,
        field: _selectedField!,
        reason: _reasonCtrl.text.trim(),
        suggestedValue: _suggCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.teacherAuditContestationSent),
            backgroundColor: _green,
          ),
        );
        widget.onSubmit();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.teacherAuditContestationError(e.toString())),
            backgroundColor: _red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Color _disputeStatusColor(String s) {
    if (s == 'accepted') return _green;
    if (s == 'rejected') return _red;
    return _orange;
  }

  @override
  Widget build(BuildContext context) {
    final existingDispute =
        widget.audit.reviewChain?.teacherDispute;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _blue.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: _blue.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 18, color: _blue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.teacherAuditDisputeInfoMessage,
                    style: GoogleFonts.inter(
                        fontSize: 13, color: _blue),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (existingDispute != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _disputeStatusColor(
                        existingDispute.status)
                    .withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _disputeStatusColor(
                        existingDispute.status)),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        existingDispute.status == 'accepted'
                            ? Icons.check_circle
                            : existingDispute.status ==
                                    'rejected'
                                ? Icons.cancel
                                : Icons.pending,
                        color: _disputeStatusColor(
                            existingDispute.status),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(AppLocalizations.of(context)!.teacherAuditExistingDispute,
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: _disputeStatusColor(
                                  existingDispute.status))),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _disputeStatusColor(
                              existingDispute.status),
                          borderRadius:
                              BorderRadius.circular(6),
                        ),
                        child: Text(
                          existingDispute.status.toUpperCase(),
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _DisputeInfoRow(
                      label: AppLocalizations.of(context)!.teacherAuditDisputeFieldLabel,
                      value: existingDispute.field),
                  _DisputeInfoRow(
                      label: AppLocalizations.of(context)!.teacherAuditReasonLabel,
                      value: existingDispute.reason),
                  if (existingDispute
                      .adminResponse.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(AppLocalizations.of(context)!.teacherAuditAdminResponse,
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _slate)),
                    Text(existingDispute.adminResponse,
                        style: GoogleFonts.inter(
                            fontSize: 13)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (existingDispute == null ||
              existingDispute.status == 'rejected') ...[
            Text(AppLocalizations.of(context)!.teacherAuditNewDispute,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff1E293B),
                )),
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedField,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color:
                            const Color(0xff1E293B)),
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.teacherAuditFieldToDispute,
                      labelStyle: GoogleFonts.inter(
                          fontSize: 13),
                      border:
                          OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                      8)),
                      contentPadding:
                          const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12),
                    ),
                    items: _disputeFields
                        .map((f) => DropdownMenuItem(
                              value: f['id'],
                              child: Text(f['label']!,
                                  style:
                                      GoogleFonts.inter(
                                          fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedField = v),
                    validator: (v) => v == null
                        ? AppLocalizations.of(context)!.teacherAuditSelectField
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _reasonCtrl,
                    maxLines: 4,
                    style: GoogleFonts.inter(fontSize: 13),
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.teacherAuditReasonLabel,
                      hintText:
                          AppLocalizations.of(context)!.teacherAuditDetailReason,
                      hintStyle: GoogleFonts.inter(
                          fontSize: 12, color: _slate),
                      border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Champ requis';
                      }
                      if (v.trim().length < 20) {
                        return 'Détaillez davantage (20 car. min)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _suggCtrl,
                    style: GoogleFonts.inter(fontSize: 13),
                    decoration: InputDecoration(
                      labelText:
                          AppLocalizations.of(context)!.teacherAuditSuggestedValue,
                      hintText: AppLocalizations.of(context)!.teacherAuditExampleValue,
                      hintStyle: GoogleFonts.inter(
                          fontSize: 12, color: _slate),
                      border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting
                          ? null
                          : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white),
                            )
                          : const Icon(Icons.send_outlined,
                              size: 18),
                      label: Text(
                        _isSubmitting
                            ? AppLocalizations.of(context)!.teacherAuditSending
                            : AppLocalizations.of(context)!.teacherAuditSendDispute,
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(8)),
                        elevation: 0,
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets helpers
// ─────────────────────────────────────────────────────────────────────────────

class _KpiTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String sub;

  const _KpiTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 10, color: _slate)),
                Text(value,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xff1E293B),
                    )),
                Text(sub,
                    style: GoogleFonts.inter(
                        fontSize: 10, color: _slate),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RateBar extends StatelessWidget {
  final String label;
  final double rate;
  final double good;
  final double warn;

  const _RateBar({
    required this.label,
    required this.rate,
    this.good = 80,
    this.warn = 60,
  });

  Color get _color {
    if (rate >= good) return _green;
    if (rate >= warn) return _orange;
    return _red;
  }

  @override
  Widget build(BuildContext context) {
    final clamped = rate.clamp(0.0, 100.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12, color: _slate)),
            Text('${clamped.toStringAsFixed(0)}%',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _color,
                )),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: clamped / 100,
            minHeight: 6,
            backgroundColor: const Color(0xffF1F5F9),
            valueColor: AlwaysStoppedAnimation<Color>(_color),
          ),
        ),
      ],
    );
  }
}

class _PayRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? color;
  final double fontSize;

  const _PayRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.color,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                fontSize: fontSize,
                fontWeight: isBold
                    ? FontWeight.w700
                    : FontWeight.normal,
                color: isBold
                    ? const Color(0xff1E293B)
                    : _slate,
              )),
          Text(value,
              style: GoogleFonts.inter(
                fontSize: fontSize,
                fontWeight: isBold
                    ? FontWeight.w700
                    : FontWeight.w600,
                color: color ??
                    (isBold
                        ? const Color(0xff1E293B)
                        : _slate),
              )),
        ],
      ),
    );
  }
}

class _SubjectPayRow extends StatelessWidget {
  final SubjectPayment payment;
  const _SubjectPayRow({required this.payment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(payment.subjectName,
                style: GoogleFonts.inter(
                    fontSize: 12, color: _slate),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          Text('${payment.hoursTaught.toStringAsFixed(1)}h',
              style: GoogleFonts.inter(
                  fontSize: 11, color: _slate)),
          const SizedBox(width: 8),
          Text(
              '@ \$${payment.hourlyRate.toStringAsFixed(0)}/h',
              style: GoogleFonts.inter(
                  fontSize: 11, color: _slate)),
          const SizedBox(width: 8),
          Text(
            '= \$${payment.netAmount.toStringAsFixed(2)}',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _green,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _MiniStat(
      {required this.label,
      required this.value,
      required this.icon,
      this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color ?? _slate),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color ?? const Color(0xff1E293B),
                )),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 10, color: _slate)),
          ],
        ),
      ],
    );
  }
}

class _DisputeInfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _DisputeInfoRow(
      {required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 54,
            child: Text('$label :',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: _slate,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
              child: Text(value,
                  style:
                      GoogleFonts.inter(fontSize: 12))),
        ],
      ),
    );
  }
}
