import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/enums/timesheet_enums.dart';
import '../../../l10n/app_localizations.dart';
import '../models/timesheet_entry.dart';

/// Single label/value row (admin detail views).
Widget timesheetAdminDetailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

/// Original vs edited comparison row (used by edit dialogs and detail drawer).
Widget timesheetAdminComparisonRow(String field, String original, String edited) {
  final isChanged = original != edited;
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: isChanged ? const Color(0xFFFEF2F2) : Colors.white,
      border: const Border(
        top: BorderSide(color: Color(0xFFE2E8F0)),
      ),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            field,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1E293B),
            ),
          ),
        ),
        Expanded(
          child: Text(
            original,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isChanged
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF64748B),
              decoration: isChanged ? TextDecoration.lineThrough : null,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isChanged) ...[
                const Icon(Icons.arrow_forward, size: 16, color: Color(0xFF10B981)),
                const SizedBox(width: 4),
              ],
              Text(
                edited,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: isChanged ? FontWeight.w600 : FontWeight.normal,
                  color: isChanged
                      ? const Color(0xFF10B981)
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Original snapshot vs current timesheet fields (clock in/out, hours).
Widget timesheetAdminOriginalDataComparison(
  BuildContext context,
  TimesheetEntry timesheet,
) {
  final l10n = AppLocalizations.of(context)!;
  if (timesheet.originalData == null) return const SizedBox.shrink();

  final original = timesheet.originalData!;

  String originalStart = original['start_time'] ?? 'N/A';
  String originalEnd = original['end_time'] ?? 'N/A';
  String originalHours = original['total_hours'] ?? 'N/A';

  if (original['clock_in_timestamp'] != null) {
    try {
      final originalClockIn =
          (original['clock_in_timestamp'] as Timestamp).toDate();
      originalStart = DateFormat('h:mm a').format(originalClockIn);
    } catch (_) {}
  }
  if (original['clock_out_timestamp'] != null) {
    try {
      final originalClockOut =
          (original['clock_out_timestamp'] as Timestamp).toDate();
      originalEnd = DateFormat('h:mm a').format(originalClockOut);
    } catch (_) {}
  }

  return Container(
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFFE2E8F0)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.field,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  l10n.original,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: Text(
                  l10n.formCurrentMonth,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        timesheetAdminComparisonRow('Clock In', originalStart, timesheet.start),
        timesheetAdminComparisonRow('Clock Out', originalEnd, timesheet.end),
        timesheetAdminComparisonRow(
            'Total Hours', originalHours, timesheet.totalHours),
      ],
    ),
  );
}

Widget _detailStatusChip(BuildContext context, TimesheetStatus status) {
  final l10n = AppLocalizations.of(context)!;
  Color color;
  String text;
  switch (status) {
    case TimesheetStatus.approved:
      color = Colors.green;
      text = l10n.timesheetApproved;
      break;
    case TimesheetStatus.rejected:
      color = Colors.red;
      text = l10n.timesheetRejected;
      break;
    case TimesheetStatus.pending:
      color = Colors.orange;
      text = l10n.timesheetPending;
      break;
    case TimesheetStatus.draft:
      color = Colors.grey;
      text = l10n.timesheetDraft;
      break;
  }
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    ),
  );
}

/// Right-hand detail content (used inside [Drawer]).
class TimesheetReviewDetailDrawer extends StatelessWidget {
  const TimesheetReviewDetailDrawer({
    super.key,
    required this.timesheet,
    required this.onClose,
    required this.onApprove,
    required this.onReject,
  });

  final TimesheetEntry timesheet;
  final VoidCallback onClose;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Material(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                  tooltip: l10n.commonClose,
                ),
                Expanded(
                  child: Text(
                    l10n.timesheetDetailsTitle,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _detailStatusChip(context, timesheet.status),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  timesheetAdminDetailRow('Teacher:', timesheet.teacherName),
                  timesheetAdminDetailRow('Date:', timesheet.date),
                  timesheetAdminDetailRow('Student:', timesheet.subject),
                  timesheetAdminDetailRow('Start Time:', timesheet.start),
                  timesheetAdminDetailRow('End Time:', timesheet.end),
                  timesheetAdminDetailRow('Total Hours:', timesheet.totalHours),
                  timesheetAdminDetailRow('Description:', timesheet.description),
                  if (timesheet.isEdited && !timesheet.editApproved) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFCD34D)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.edit,
                              color: Color(0xFFD97706), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.thisTimesheetWasEditedAndRequires,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFD97706),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (timesheet.description.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      l10n.description,
                      style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        timesheet.description,
                        style: GoogleFonts.inter(fontSize: 14),
                      ),
                    ),
                  ],
                  if (timesheet.employeeNotes != null &&
                      timesheet.employeeNotes!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.note_outlined,
                            color: Color(0xFFD97706),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.employeeNotes,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFD97706),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFCD34D)),
                      ),
                      child: Text(
                        timesheet.employeeNotes!,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                  if (timesheet.isEdited) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.history,
                            color: Color(0xFF1E40AF),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.editInformation,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E40AF),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (timesheet.originalData != null)
                      timesheetAdminOriginalDataComparison(context, timesheet)
                    else
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFCD34D)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.info_outline,
                                    color: Color(0xFFD97706), size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    l10n.originalDataNotAvailable,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFFD97706),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.thisTimesheetWasEditedButThe,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF92400E),
                              ),
                            ),
                            if (timesheet.editedAt != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Edited: ${DateFormat('MMM d, yyyy h:mm a').format(timesheet.editedAt!.toDate())}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF92400E),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                  if (timesheet.managerNotes != null &&
                      timesheet.managerNotes!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.admin_panel_settings_outlined,
                            color: Color(0xFF1E40AF),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.managerNotes,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E40AF),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDBEAFE),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF93C5FD)),
                      ),
                      child: Text(
                        timesheet.managerNotes!,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF1E3A8A),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onClose,
                  child: Text(l10n.commonClose),
                ),
                if (timesheet.status == TimesheetStatus.pending) ...[
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: onReject,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(l10n.reject),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: onApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(l10n.approve),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
