import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alluwalacademyadmin/features/audit/models/teacher_audit_full.dart';
import 'package:alluwalacademyadmin/features/audit/services/audit_message_composer.dart';
import '../services/audit_class_log_row_builder.dart';
import '../services/teacher_audit_service.dart';
import '../../chat/services/chat_service.dart';
import '../../chat/models/chat_user.dart';
import '../../chat/screens/chat_screen.dart';
import '../../../l10n/app_localizations.dart';
import 'audit_shared_widgets.dart';
import 'audit_tabs/audit_assignments_tab.dart';
import 'audit_tabs/audit_class_log_tab.dart';
import 'audit_tabs/audit_evaluation_tab.dart';
import 'audit_tabs/audit_forms_tab.dart';

class AuditDetailFullPanel extends StatefulWidget {
  final TeacherAuditFull audit;
  final bool enableEditing;
  final ValueChanged<TeacherAuditFull>? onAuditChanged;

  /// Admin-only: open resolve/view dispute UI; return updated audit after resolve.
  final Future<TeacherAuditFull?> Function(TeacherAuditFull audit,
      {required bool readOnly})? onTeacherDisputePressed;

  const AuditDetailFullPanel({
    super.key,
    required this.audit,
    this.enableEditing = false,
    this.onAuditChanged,
    this.onTeacherDisputePressed,
  });

  static String disputeFieldDisplayLabel(
      AppLocalizations l10n, String fieldId) {
    switch (fieldId) {
      case 'classes_count':
        return l10n.teacherAuditDisputeOptionClassesCount;
      case 'hours_taught':
        return l10n.teacherAuditDisputeOptionHoursTaught;
      case 'punctuality_rate':
        return l10n.teacherAuditDisputeOptionPunctualityRate;
      case 'forms_count':
        return l10n.teacherAuditDisputeOptionFormsCount;
      case 'payment_amount':
        return l10n.teacherAuditDisputeOptionPaymentAmount;
      case 'overall_score':
        return l10n.teacherAuditDisputeOptionOverallScore;
      case 'other':
        return l10n.teacherAuditDisputeOptionOther;
      default:
        return fieldId;
    }
  }

  static String fieldLabel(BuildContext context, String field) {
    final l10n = AppLocalizations.of(context)!;
    switch (field) {
      case 'totalClassesMissed':
        return l10n.auditFieldTotalClassesMissed;
      case 'totalClassesCancelled':
        return l10n.auditFieldTotalClassesCancelled;
      case 'staffMeetingsScheduled':
        return l10n.auditFieldStaffMeetingsScheduled;
      case 'staffMeetingsMissed':
        return l10n.auditFieldStaffMeetingsMissed;
      case 'meetingLateArrivals':
        return l10n.auditFieldMeetingLateArrivals;
      case 'quizzesGiven':
        return l10n.auditFieldQuizzesGiven;
      case 'assignmentsGiven':
        return l10n.auditFieldAssignmentsGiven;
      case 'overdueTasks':
        return l10n.auditFieldOverdueTasks;
      case 'weeklyRecordingsSent':
        return l10n.auditFieldWeeklyRecordingsSent;
      case 'classRemindersSet':
        return l10n.auditFieldClassRemindersSet;
      case 'internetDropOffs':
        return l10n.auditFieldInternetDropOffs;
      case 'midtermCompleted':
        return l10n.auditFieldMidtermCompleted;
      case 'finalExamCompleted':
        return l10n.auditFieldFinalExamCompleted;
      case 'semesterProjectStatus':
        return l10n.auditFieldSemesterProjectStatus;
      default:
        return field;
    }
  }

  @override
  State<AuditDetailFullPanel> createState() => _AuditDetailFullPanelState();
}

class _AuditDetailFullPanelState extends State<AuditDetailFullPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  late TeacherAuditFull _currentAudit;
  String? _makeupAutoOpenedForAuditId;

  void _maybeAutoOpenTeachingFormsTab() {
    if (!mounted) return;
    if (_makeupAutoOpenedForAuditId == _currentAudit.id) return;
    if (_currentAudit.pendingMakeupAdminDecisionsCount == 0) return;
    _makeupAutoOpenedForAuditId = _currentAudit.id;
    _tab.animateTo(1);
  }

  String _buildAuditDiscussionDraft(TeacherAuditFull audit) {
    return AuditMessageComposer.compose(
      audit: audit,
      l10n: AppLocalizations.of(context)!,
      channel: AuditMessageChannel.chatDraft,
    );
  }

  @override
  void initState() {
    super.initState();
    _currentAudit = widget.audit;
    _tab = TabController(length: 4, vsync: this);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _maybeAutoOpenTeachingFormsTab());
  }

  @override
  void didUpdateWidget(covariant AuditDetailFullPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _currentAudit = widget.audit;
    if (oldWidget.audit.id != widget.audit.id) {
      _makeupAutoOpenedForAuditId = null;
    }
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _maybeAutoOpenTeachingFormsTab());
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Color _statusColor(AuditStatus s) {
    switch (s) {
      case AuditStatus.completed:
        return const Color(0xFF10B981);
      case AuditStatus.coachSubmitted:
        return const Color(0xFF3B82F6);
      case AuditStatus.disputed:
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  String _statusLabel(AuditStatus s) {
    final l10n = AppLocalizations.of(context)!;
    switch (s) {
      case AuditStatus.completed:
        return l10n.auditStatusCompleted;
      case AuditStatus.coachSubmitted:
        return l10n.auditStatusSubmitted;
      case AuditStatus.disputed:
        return l10n.auditStatusDisputed;
      default:
        return l10n.auditStatusPending;
    }
  }

  Future<void> _openQuickDialog(String type) async {
    final l10n = AppLocalizations.of(context)!;
    String title;
    Widget content;
    if (type == 'overview') {
      title = l10n.auditTabOverview;
      content = _OverviewDialogContent(audit: _currentAudit);
    } else if (type == 'payment') {
      title = l10n.auditPaymentSummary;
      content = _PaymentDialogContent(audit: _currentAudit);
    } else {
      title = l10n.auditTabChangeLog;
      content = _ChangeLogDialogContent(audit: _currentAudit);
    }
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 860,
          height: 620,
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                    border:
                        Border(bottom: BorderSide(color: Color(0xffE2E8F0)))),
                child: Row(
                  children: [
                    Text(title,
                        style: GoogleFonts.inter(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close)),
                  ],
                ),
              ),
              Expanded(child: content),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audit = _currentAudit;
    final l10n = AppLocalizations.of(context)!;
    final ack = audit.teacherAcknowledgedAt;
    final dispute = audit.reviewChain?.teacherDispute;
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final ackText = ack != null
        ? l10n.adminAuditTeacherPayslipAcknowledgedOn(
            DateFormat.yMMMd(localeTag).add_jm().format(ack),
          )
        : l10n.adminAuditTeacherPayslipNotAcknowledged;

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: const Color(0xffE2E8F0),
                child: Text(
                  audit.teacherName.isNotEmpty
                      ? audit.teacherName[0].toUpperCase()
                      : '?',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xff334155)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      audit.teacherName,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xff1E293B)),
                    ),
                    Text(
                      '${audit.teacherEmail} · ${audit.yearMonth}',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: const Color(0xff64748B)),
                    ),
                  ],
                ),
              ),
              AuditDetailPill(
                  label: '${audit.overallScore.toStringAsFixed(0)}%',
                  color: const Color(0xff1a6ef5)),
              const SizedBox(width: 6),
              AuditDetailPill(
                  label: _statusLabel(audit.status),
                  color: _statusColor(audit.status)),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _tab.animateTo(3),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff1a6ef5),
                    foregroundColor: Colors.white),
                child:
                    Text(AppLocalizations.of(context)!.performanceEvaluation),
              ),
              const SizedBox(width: 4),
              _AuditDiscussionChatIcon(
                audit: audit,
                onOpenChat: () async {
                  final l10n = AppLocalizations.of(context)!;
                  final chatId =
                      await TeacherAuditService.ensureAuditDiscussionChatId(
                          audit.id);
                  if (!context.mounted) return;
                  if (chatId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.errorE)),
                    );
                    return;
                  }
                  final u = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(audit.oderId)
                      .get();
                  final d = u.data() ?? {};
                  final nameFromDoc =
                      '${d['first_name'] ?? ''} ${d['last_name'] ?? ''}'.trim();
                  final chatUser = ChatUser(
                    id: audit.oderId,
                    name: audit.teacherName.isNotEmpty
                        ? audit.teacherName
                        : (nameFromDoc.isNotEmpty ? nameFromDoc : audit.oderId),
                    email: audit.teacherEmail.isNotEmpty
                        ? audit.teacherEmail
                        : (d['email'] ?? d['e-mail'] ?? '').toString(),
                  );
                  if (!context.mounted) return;
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ChatScreen(
                        chatUser: chatUser,
                        initialMessage: _buildAuditDiscussionDraft(audit),
                        forceAllowMessaging: true,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip:
                    AppLocalizations.of(context)!.auditShareWithTeacherTooltip,
                onPressed: () async {
                  final l10n = AppLocalizations.of(context)!;
                  final text = AuditMessageComposer.compose(
                    audit: audit,
                    l10n: l10n,
                    channel: AuditMessageChannel.shareLink,
                  );
                  await Clipboard.setData(ClipboardData(text: text));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.auditShareWithTeacherCopied)),
                  );
                },
                icon: const Icon(Icons.share_outlined, size: 22),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                onSelected: _openQuickDialog,
                itemBuilder: (context) => [
                  PopupMenuItem(
                      value: 'overview',
                      child:
                          Text(AppLocalizations.of(context)!.auditTabOverview)),
                  PopupMenuItem(
                      value: 'payment',
                      child: Text(
                          AppLocalizations.of(context)!.auditPaymentSummary)),
                  PopupMenuItem(
                      value: 'changelog',
                      child: Text(
                          AppLocalizations.of(context)!.auditTabChangeLog)),
                ],
              ),
            ],
          ),
        ),
        Material(
          color: const Color(0xFFF8FAFC),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.fact_check_outlined,
                        size: 18, color: Colors.grey.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.adminAuditTeacherPayslipAckShort,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xff64748B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ackText,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xff1E293B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (dispute != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xffE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.adminAuditTeacherDisputeSummaryTitle,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xff64748B),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: dispute.status == 'pending'
                                    ? const Color(0xFFFFF7ED)
                                    : (dispute.status == 'accepted'
                                        ? const Color(0xFFECFDF5)
                                        : const Color(0xFFFEF2F2)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                dispute.status.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: dispute.status == 'pending'
                                      ? const Color(0xFFC2410C)
                                      : (dispute.status == 'accepted'
                                          ? const Color(0xFF047857)
                                          : const Color(0xFFB91C1C)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${l10n.teacherAuditDisputeFieldLabel}: ${AuditDetailFullPanel.disputeFieldDisplayLabel(l10n, dispute.field)}',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: const Color(0xff334155)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dispute.reason,
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              height: 1.35,
                              color: const Color(0xff475569)),
                        ),
                        if (dispute.suggestedValue != null &&
                            '${dispute.suggestedValue}'.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            l10n.adminAuditTeacherDisputeSuggestedValue,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xff64748B),
                            ),
                          ),
                          Text(
                            '${dispute.suggestedValue}',
                            style: GoogleFonts.inter(fontSize: 12),
                          ),
                        ],
                        if (widget.enableEditing &&
                            widget.onTeacherDisputePressed != null) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: dispute.status == 'pending'
                                ? TextButton.icon(
                                    onPressed: () async {
                                      final u =
                                          await widget.onTeacherDisputePressed!(
                                        _currentAudit,
                                        readOnly: false,
                                      );
                                      if (u != null && mounted) {
                                        setState(() => _currentAudit = u);
                                        widget.onAuditChanged?.call(u);
                                      }
                                    },
                                    icon: const Icon(Icons.gavel_outlined,
                                        size: 18),
                                    label: Text(l10n
                                        .adminAuditResolveTeacherDisputeButton),
                                  )
                                : TextButton.icon(
                                    onPressed: () async {
                                      final u =
                                          await widget.onTeacherDisputePressed!(
                                        _currentAudit,
                                        readOnly: true,
                                      );
                                      if (u != null && mounted) {
                                        setState(() => _currentAudit = u);
                                        widget.onAuditChanged?.call(u);
                                      }
                                    },
                                    icon: const Icon(Icons.visibility_outlined,
                                        size: 18),
                                    label:
                                        Text(l10n.adminAuditViewTeacherDispute),
                                  ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_currentAudit.pendingMakeupAdminDecisionsCount > 0)
          Material(
            color: const Color(0xFFFFF7ED),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFD97706), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!
                          .auditMakeupPendingAdminBanner(
                        _currentAudit.pendingMakeupAdminDecisionsCount,
                      ),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xff9A3412),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _tab.animateTo(1),
                    child: Text(
                      AppLocalizations.of(context)!
                          .auditMakeupOpenTeachingFormsTab,
                    ),
                  ),
                ],
              ),
            ),
          ),
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border:
                Border(bottom: BorderSide(color: Color(0xffE2E8F0), width: 1)),
          ),
          child: TabBar(
            controller: _tab,
            isScrollable: false,
            labelColor: const Color(0xff0078D4),
            unselectedLabelColor: const Color(0xff64748B),
            indicatorColor: const Color(0xff0078D4),
            indicatorWeight: 2,
            labelStyle:
                GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
            tabs: const [
              Tab(text: 'Class log'),
              Tab(text: 'Teaching forms'),
              Tab(text: 'Assignments & assessments'),
              Tab(text: 'Evaluation'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              AuditClassLogTab(audit: audit),
              AuditFormsTab(
                audit: audit,
                autoSelectPendingMakeupOnce: true,
                onAuditChanged: (updated) {
                  setState(() => _currentAudit = updated);
                  widget.onAuditChanged?.call(updated);
                },
              ),
              AuditAssignmentsTab(audit: audit),
              AuditEvaluationTab(
                audit: audit,
                onAuditChanged: (updated) {
                  setState(() => _currentAudit = updated);
                  widget.onAuditChanged?.call(updated);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AuditDiscussionChatIcon extends StatelessWidget {
  final TeacherAuditFull audit;
  final Future<void> Function() onOpenChat;

  const _AuditDiscussionChatIcon({
    required this.audit,
    required this.onOpenChat,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final chatService = ChatService();
    final stored = audit.discussionChatId?.trim();
    final cid = (stored != null && stored.isNotEmpty)
        ? stored
        : chatService.individualChatIdWith(audit.oderId);
    if (cid == null) {
      return IconButton(
        tooltip: l10n.auditDiscussionAdminButton,
        onPressed: () => onOpenChat(),
        icon: const Icon(Icons.chat_bubble_outline, size: 22),
      );
    }
    return StreamBuilder<int>(
      stream: chatService.watchUnreadIncomingMessageCount(cid),
      builder: (context, snap) {
        final count = snap.data ?? 0;
        final tooltip = count > 0
            ? l10n.auditDiscussionUnreadBadgeTooltip(count)
            : l10n.auditDiscussionAdminButton;
        return Semantics(
          label: tooltip,
          button: true,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: tooltip,
                onPressed: () => onOpenChat(),
                icon: const Icon(Icons.chat_bubble_outline, size: 22),
              ),
              if (count > 0)
                Positioned(
                  right: 4,
                  top: 6,
                  child: IgnorePointer(
                    child: Container(
                      constraints:
                          const BoxConstraints(minWidth: 18, minHeight: 18),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        count > 99 ? '99+' : count.toString(),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _OverviewDialogContent extends StatelessWidget {
  final TeacherAuditFull audit;
  const _OverviewDialogContent({required this.audit});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AuditSectionTitle(
            title: AppLocalizations.of(context)!.auditKeyIndicators),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.7,
          children: [
            AuditKpiCard(
                icon: Icons.school_outlined,
                color: const Color(0xFF3B82F6),
                label: AppLocalizations.of(context)!.auditClassesCompleted,
                value:
                    '${audit.totalClassesCompleted}/${audit.totalClassesScheduled}'),
            AuditKpiCard(
                icon: Icons.timer_outlined,
                color: const Color(0xFF10B981),
                label: AppLocalizations.of(context)!.auditHoursTaught,
                value: '${audit.totalWorkedHours.toStringAsFixed(2)}h'),
            AuditKpiCard(
                icon: Icons.description_outlined,
                color: const Color(0xFF8B5CF6),
                label: AppLocalizations.of(context)!.auditTabForms,
                value:
                    '${audit.readinessFormsSubmitted}/${audit.readinessFormsRequired}'),
          ],
        ),
      ],
    );
  }
}

class _PaymentDialogContent extends StatelessWidget {
  final TeacherAuditFull audit;
  const _PaymentDialogContent({required this.audit});

  @override
  Widget build(BuildContext context) {
    final ps = audit.paymentSummary;
    if (ps == null) {
      return const AuditEmptyState(
          icon: Icons.payments_outlined, message: 'No payment data');
    }
    final totals = AuditClassLogRowBuilder.computeTotals(audit);
    final gross = totals.grossBySource;
    final coachDelta = ps.coachAdjustmentLines.fold<double>(
        0.0, (acc, e) => acc + (e.type == 'bonus' ? e.amount : -e.amount));
    final net = gross -
        ps.totalPenalties +
        ps.totalBonuses +
        ps.adminAdjustment +
        coachDelta -
        ps.totalAdvanceDeduction;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: AuditPayCard(
                label: AppLocalizations.of(context)!.auditGrossSalary,
                amount: gross,
                color: const Color(0xFF3B82F6),
                icon: Icons.account_balance_wallet_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AuditPayCard(
                label: AppLocalizations.of(context)!.auditNetSalary,
                amount: net,
                color: const Color(0xFF10B981),
                icon: Icons.payments_outlined,
                isHighlighted: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ChangeLogDialogContent extends StatelessWidget {
  final TeacherAuditFull audit;
  const _ChangeLogDialogContent({required this.audit});

  String _factorLabel(String factorId) {
    final f = audit.auditFactors.where((e) => e.id == factorId);
    if (f.isNotEmpty && f.first.title.trim().isNotEmpty) {
      return f.first.title.trim();
    }
    return factorId;
  }

  String _friendlyFieldLabel(BuildContext context, AuditChangeEntry e) {
    final raw = e.field.trim();
    if (raw.startsWith('auditFactor.')) {
      final parts = raw.split('.');
      if (parts.length >= 3) {
        final factorId = parts[1];
        final subField = parts[2];
        final factor = _factorLabel(factorId);
        switch (subField) {
          case 'rating':
            return '$factor · Rating';
          case 'outcome':
            return '$factor · Observation';
          case 'paycutRecommendation':
            return '$factor · Payment impact';
          case 'coachActionPlan':
            return '$factor · Action plan';
          case 'mentorReview':
            return '$factor · Mentor review';
          case 'ceoReview':
            return '$factor · CEO review';
          case 'isNotApplicable':
            return '$factor · N/A';
          default:
            return '$factor · $subField';
        }
      }
    }
    if (raw == 'paymentSummary.coachAdjustmentLines') {
      return 'Coach payment lines';
    }
    return AuditDetailFullPanel.fieldLabel(context, raw);
  }

  bool _isCoachLinesField(AuditChangeEntry e) =>
      e.field.trim() == 'paymentSummary.coachAdjustmentLines';

  List<String> _parseCoachLineSignatures(dynamic value) {
    final txt = (value ?? '').toString().trim();
    if (txt.isEmpty) return const [];
    final out = <String>[];
    for (final line in txt.split('~')) {
      final p = line.split('|');
      if (p.length < 4) continue;
      final type = p[1];
      final amountRaw = p[2];
      final reason = p[3].trim().isEmpty ? '—' : p[3].trim();
      final amount = double.tryParse(amountRaw);
      final money = amount == null
          ? amountRaw
          : '${amount < 0 ? '-' : ''}\$${amount.abs().toStringAsFixed(2)}';
      final prefix = type == 'bonus' ? '+' : '-';
      out.add('$type $prefix$money — $reason');
    }
    return out;
  }

  String _displayValue(dynamic v) {
    if (v == null) return '—';
    if (v is bool) return v ? 'Yes' : 'No';
    final s = v.toString().trim();
    return s.isEmpty ? '—' : s;
  }

  @override
  Widget build(BuildContext context) {
    final entries = List<AuditChangeEntry>.from(audit.changeLog)
      ..sort((a, b) => b.changedAt.compareTo(a.changedAt));
    if (entries.isEmpty) {
      return AuditEmptyState(
        icon: Icons.history,
        message: AppLocalizations.of(context)!.auditNoChangesRecorded,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const Divider(color: Color(0xffE2E8F0)),
      itemBuilder: (context, index) {
        final e = entries[index];
        final isCoachLines = _isCoachLinesField(e);
        final oldLines = isCoachLines
            ? _parseCoachLineSignatures(e.oldValue)
            : const <String>[];
        final newLines = isCoachLines
            ? _parseCoachLineSignatures(e.newValue)
            : const <String>[];
        final removed = isCoachLines
            ? oldLines.where((line) => !newLines.contains(line)).toList()
            : const <String>[];
        final added = isCoachLines
            ? newLines.where((line) => !oldLines.contains(line)).toList()
            : const <String>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(e.adminName,
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(_friendlyFieldLabel(context, e),
                style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            if (!isCoachLines)
              Text(
                '${_displayValue(e.oldValue)} → ${_displayValue(e.newValue)}',
                style: GoogleFonts.inter(fontSize: 12),
              ),
            if (isCoachLines && removed.isEmpty && added.isEmpty)
              Text(
                '${_displayValue(e.oldValue)} → ${_displayValue(e.newValue)}',
                style: GoogleFonts.inter(fontSize: 12),
              ),
            if (isCoachLines && removed.isNotEmpty)
              ...removed.map((line) => Text(
                    'Removed: $line',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: const Color(0xFFB91C1C)),
                  )),
            if (isCoachLines && added.isNotEmpty)
              ...added.map((line) => Text(
                    'Added: $line',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: const Color(0xFF166534)),
                  )),
            if (e.reason.trim().isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                'Reason: ${e.reason}',
                style: GoogleFonts.inter(
                    fontSize: 11, color: const Color(0xff64748B)),
              ),
            ],
            Text(DateFormat('MMM d, yyyy HH:mm').format(e.changedAt),
                style: GoogleFonts.inter(
                    fontSize: 11, color: const Color(0xff94A3B8))),
          ],
        );
      },
    );
  }
}
