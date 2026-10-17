import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../models/teaching_shift.dart';
import '../services/shift_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../l10n/app_localizations.dart';

/// Clean, mobile-friendly dialog for teachers to request a makeup session for a missed shift.
class RescheduleRequestDialog extends StatefulWidget {
  final TeachingShift shift;

  const RescheduleRequestDialog({
    super.key,
    required this.shift,
  });

  @override
  State<RescheduleRequestDialog> createState() =>
      _RescheduleRequestDialogState();
}

class _RescheduleRequestDialogState extends State<RescheduleRequestDialog> {
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  String _selectedReason = 'power_outage';
  final TextEditingController _notesController = TextEditingController();
  bool _isSubmitting = false;
  String? _conflictError;

  @override
  void initState() {
    super.initState();
    // Default proposed date to tomorrow
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _selectedDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    _selectedTime = TimeOfDay.fromDateTime(widget.shift.shiftStart);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  int get _durationMinutes {
    final diff =
        widget.shift.shiftEnd.difference(widget.shift.shiftStart).inMinutes;
    return diff > 0 ? diff : 60;
  }

  DateTime get _proposedStartLocal {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

  DateTime get _proposedEndLocal {
    return _proposedStartLocal.add(Duration(minutes: _durationMinutes));
  }

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

  Future<void> _submitRequest(AppLocalizations loc) async {
    setState(() {
      _isSubmitting = true;
      _conflictError = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final startUtc = _proposedStartLocal.toUtc();
      final endUtc = _proposedEndLocal.toUtc();

      // Check conflict for teacher
      final hasConflict = await ShiftService.hasConflictingShift(
        teacherId: widget.shift.teacherId,
        shiftStart: startUtc,
        shiftEnd: endUtc,
        excludeShiftId: widget.shift.id,
      );

      if (hasConflict) {
        setState(() {
          _conflictError = loc.rescheduleConflictWarning;
          _isSubmitting = false;
        });
        return;
      }

      final subjectName = widget.shift.subjectDisplayName ??
          widget.shift.subject.name;

      final requestData = <String, dynamic>{
        'teacher_id': widget.shift.teacherId,
        'teacher_name': widget.shift.teacherName,
        'original_shift_id': widget.shift.id,
        'subject': subjectName,
        if (widget.shift.subjectId != null)
          'subject_id': widget.shift.subjectId,
        if (widget.shift.subjectDisplayName != null)
          'subject_display_name': widget.shift.subjectDisplayName,
        'student_ids': widget.shift.studentIds,
        'student_names': widget.shift.studentNames,
        'hourly_rate': widget.shift.hourlyRate,
        'video_provider': widget.shift.videoProvider.name,
        'proposed_start': Timestamp.fromDate(startUtc),
        'proposed_end': Timestamp.fromDate(endUtc),
        'proposed_timezone': widget.shift.teacherTimezone,
        'reason_category': _selectedReason,
        'notes': _notesController.text.trim(),
        'status': 'pending',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('reschedule_requests')
          .add(requestData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.makeupRequestSubmitted),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      AppLogger.error('Error submitting reschedule request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final subjectTitle = widget.shift.subjectDisplayName ??
        widget.shift.subject.name;
    final studentsText = widget.shift.studentNames.isNotEmpty
        ? widget.shift.studentNames.join(', ')
        : loc.commonNone;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0386FF).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.sync,
                        color: Color(0xFF0386FF), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.requestMakeupClassTitle,
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          loc.requestMakeupClassSubtitle,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Class context chip
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subjectTitle,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      studentsText,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loc.proposedDuration(_durationMinutes),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF0386FF),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Proposed Date
              Text(
                loc.proposedDate,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final initDate = _selectedDate.isBefore(today) ? today : _selectedDate;
                  final firstDate = _selectedDate.isBefore(today) ? _selectedDate : today;
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: initDate,
                    firstDate: firstDate,
                    lastDate: today.add(const Duration(days: 60)),
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedDate = picked;
                      _conflictError = null;
                    });
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    color: Colors.white,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('EEE, MMM d, yyyy').format(_selectedDate),
                        style: GoogleFonts.inter(
                            fontSize: 14, color: const Color(0xFF1E293B)),
                      ),
                      const Icon(Icons.calendar_today,
                          size: 18, color: Color(0xFF64748B)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Proposed Start Time
              Text(
                loc.proposedStartTime,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _selectedTime,
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedTime = picked;
                      _conflictError = null;
                    });
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    color: Colors.white,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedTime.format(context),
                        style: GoogleFonts.inter(
                            fontSize: 14, color: const Color(0xFF1E293B)),
                      ),
                      const Icon(Icons.access_time,
                          size: 18, color: Color(0xFF64748B)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Reason dropdown
              Text(
                loc.reasonForReschedule,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedReason,
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                items: [
                  'power_outage',
                  'internet',
                  'illness',
                  'student_absent',
                  'personal',
                  'other',
                ].map((key) {
                  return DropdownMenuItem<String>(
                    value: key,
                    child: Text(_reasonLabel(loc, key),
                        style: GoogleFonts.inter(fontSize: 13)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedReason = val);
                },
              ),
              const SizedBox(height: 14),

              // Optional Notes
              Text(
                loc.notesOptional,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: loc.notesHint,
                  hintStyle: GoogleFonts.inter(fontSize: 12),
                  contentPadding: const EdgeInsets.all(10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),

              // Conflict error banner if present
              if (_conflictError != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Color(0xFFDC2626), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _conflictError!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF991B1B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 18),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : () => _submitRequest(loc),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0386FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          loc.submitRequest,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
