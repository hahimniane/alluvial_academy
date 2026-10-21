import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../services/reschedule_request_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../l10n/app_localizations.dart';

/// Admin screen to review and manage teacher makeup reschedule requests.
class RescheduleRequestsScreen extends StatefulWidget {
  const RescheduleRequestsScreen({super.key});

  @override
  State<RescheduleRequestsScreen> createState() =>
      _RescheduleRequestsScreenState();
}

class _RescheduleRequestsScreenState extends State<RescheduleRequestsScreen> {
  final Set<String> _processingIds = {};

  String _reasonLabel(AppLocalizations loc, String key) {
    switch (key) {
      case 'power_outage':
        return loc.reasonPowerOutage;
      case 'internet':
        return loc.reasonInternet;
      case 'illness':
        return loc.reasonIllness;
      case 'student_absent':
        return loc.reasonStudentAbsent;
      case 'personal':
        return loc.reasonPersonal;
      case 'other':
      default:
        return loc.reasonOther;
    }
  }

  Future<void> _approveRequest({
    required BuildContext context,
    required String requestId,
    DateTime? customStart,
  }) async {
    final loc = AppLocalizations.of(context)!;
    setState(() => _processingIds.add(requestId));

    try {
      await RescheduleRequestService.approve(requestId, startTime: customStart);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.rescheduleRequestApproved),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error approving reschedule request: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(RescheduleRequestService.errorMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(requestId));
      }
    }
  }

  Future<void> _adjustTimeAndApprove({
    required BuildContext context,
    required String requestId,
    required Map<String, dynamic> data,
  }) async {
    final originalStart = (data['proposed_start'] as Timestamp).toDate();

    final selectedDate = originalStart;
    final selectedTime = TimeOfDay.fromDateTime(originalStart);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initDate = selectedDate.isBefore(today) ? today : selectedDate;
    final firstDate = selectedDate.isBefore(today) ? selectedDate : today;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initDate,
      firstDate: firstDate,
      lastDate: today.add(const Duration(days: 90)),
    );
    if (pickedDate == null || !context.mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: selectedTime,
    );
    if (pickedTime == null || !context.mounted) return;

    final newStart = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    await _approveRequest(
      context: context,
      requestId: requestId,
      customStart: newStart,
    );
  }

  Future<void> _declineRequest({
    required BuildContext context,
    required String requestId,
  }) async {
    final loc = AppLocalizations.of(context)!;
    final reasonController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.declineRequest),
        content: TextField(
          controller: reasonController,
          decoration: InputDecoration(
            hintText: loc.declineReasonHint,
            labelText: loc.declineReason,
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: Text(loc.declineRequest),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    setState(() => _processingIds.add(requestId));
    try {
      await RescheduleRequestService.decline(
        requestId,
        reason: reasonController.text.trim(),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.rescheduleRequestDeclined),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error declining reschedule request: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(RescheduleRequestService.errorMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(requestId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          loc.rescheduleRequestsTitle,
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection(RescheduleRequestService.collection)
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline,
                      size: 48, color: Color(0xFF10B981)),
                  const SizedBox(height: 12),
                  Text(
                    loc.commonNone,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            );
          }

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView.separated(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final isBusy = _processingIds.contains(doc.id);

              final teacherName =
                  data['teacher_name'] as String? ?? loc.commonUnknown;
              final subject = data['subject'] as String? ?? 'Other';
              final studentNames =
                  (data['student_names'] as List<dynamic>?)?.join(', ') ?? '';
              final start = (data['proposed_start'] as Timestamp).toDate();
              final end = (data['proposed_end'] as Timestamp).toDate();
              final reason = data['reason_category'] as String? ?? 'other';
              final notes = data['notes'] as String? ?? '';

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Teacher & Reason badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              teacherName,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _reasonLabel(loc, reason),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Class details
                      Text(
                        '$subject • $studentNames',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Proposed Time
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time,
                                size: 16, color: Color(0xFF0386FF)),
                            const SizedBox(width: 8),
                            Text(
                              '${DateFormat('EEE, MMM d, yyyy').format(start)} • ${DateFormat('h:mm a').format(start)} - ${DateFormat('h:mm a').format(end)}',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (notes.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          notes,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),

                      // Action Buttons
                      if (isBusy)
                        const Center(
                          child: SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _approveRequest(
                                context: context,
                                requestId: doc.id,
                              ),
                              icon: const Icon(Icons.check, size: 16),
                              label: Text(loc.approveAndSchedule),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                textStyle: GoogleFonts.inter(
                                    fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _adjustTimeAndApprove(
                                context: context,
                                requestId: doc.id,
                                data: data,
                              ),
                              icon: const Icon(Icons.edit, size: 16),
                              label: Text(loc.adjustTimeAndApprove),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF0386FF),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                textStyle: GoogleFonts.inter(
                                    fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _declineRequest(
                                context: context,
                                requestId: doc.id,
                              ),
                              icon: const Icon(Icons.close, size: 16),
                              label: Text(loc.declineRequest),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFDC2626),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                textStyle: GoogleFonts.inter(
                                    fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
    },
      ),
    );
  }
}
