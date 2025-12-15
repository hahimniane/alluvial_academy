import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../core/models/teaching_shift.dart';
import '../../../core/services/shift_service.dart';
import '../../../core/services/timezone_service.dart';
import '../../../core/utils/timezone_utils.dart';
import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

/// Dialog for teachers to directly reschedule shifts
class RescheduleShiftDialog extends StatefulWidget {
  final TeachingShift shift;

  const RescheduleShiftDialog({
    super.key,
    required this.shift,
  });

  @override
  State<RescheduleShiftDialog> createState() => _RescheduleShiftDialogState();
}

class _RescheduleShiftDialogState extends State<RescheduleShiftDialog> {
  DateTime? _newStartTime;
  DateTime? _newEndTime;
  final TextEditingController _reasonController = TextEditingController();
  bool _isLoading = false;
  String _selectedTimezone = 'UTC';
  String? _teacherTimezone;

  @override
  void initState() {
    super.initState();
    _loadTeacherTimezone();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadTeacherTimezone() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (userDoc.exists) {
        final timezone = userDoc.data()?['timezone'] as String?;
        setState(() {
          _teacherTimezone = timezone;
          _selectedTimezone = timezone ?? widget.shift.teacherTimezone;
        });
      } else {
        setState(() {
          _selectedTimezone = widget.shift.teacherTimezone;
        });
      }
    } catch (e) {
      AppLogger.error('Error loading teacher timezone: $e');
      setState(() {
        _selectedTimezone = widget.shift.teacherTimezone;
      });
    }
  }

  Future<void> _submitRescheduleRequest() async {
    if (_newStartTime == null || _newEndTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both start and end times'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_newEndTime!.isBefore(_newStartTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End time must be after start time'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');

      // Store original times for audit trail
      final originalStartTime = widget.shift.shiftStart;
      final originalEndTime = widget.shift.shiftEnd;
      final modificationReason = _reasonController.text.trim();

      // Convert selected times from selected timezone to UTC
      // The _newStartTime and _newEndTime are in the selected timezone
      final naiveStart = DateTime(
        _newStartTime!.year,
        _newStartTime!.month,
        _newStartTime!.day,
        _newStartTime!.hour,
        _newStartTime!.minute,
      );
      
      final naiveEnd = DateTime(
        _newEndTime!.year,
        _newEndTime!.month,
        _newEndTime!.day,
        _newEndTime!.hour,
        _newEndTime!.minute,
      );

      // Convert to UTC using the selected timezone
      final utcStart = TimezoneUtils.convertToUtc(naiveStart, _selectedTimezone);
      final utcEnd = TimezoneUtils.convertToUtc(naiveEnd, _selectedTimezone);

      // Create updated shift with new times (in UTC)
      final updatedShift = widget.shift.copyWith(
        shiftStart: utcStart,
        shiftEnd: utcEnd,
        teacherTimezone: _selectedTimezone, // Update teacher timezone if changed
      );

      // Update shift using standard update method which handles lifecycle tasks
      // This ensures cloud tasks are rescheduled to the new times
      await ShiftService.updateShift(updatedShift);

      // Also update shift document with teacher modification metadata
      await FirebaseFirestore.instance
          .collection('teaching_shifts')
          .doc(widget.shift.id)
          .update({
        // Store modification history
        'teacher_modified': true,
        'teacher_modified_at': FieldValue.serverTimestamp(),
        'teacher_modified_by': user.uid,
        'teacher_modification_reason': modificationReason.isNotEmpty 
            ? modificationReason 
            : 'Schedule adjustment requested by teacher',
        'original_start_time': Timestamp.fromDate(originalStartTime),
        'original_end_time': Timestamp.fromDate(originalEndTime),
        'modification_count': FieldValue.increment(1),
      });

      // Log modification for audit trail
      await FirebaseFirestore.instance
          .collection('shift_modifications')
          .add({
        'shift_id': widget.shift.id,
        'teacher_id': user.uid,
        'teacher_name': widget.shift.teacherName,
        'original_start_time': Timestamp.fromDate(originalStartTime),
        'original_end_time': Timestamp.fromDate(originalEndTime),
        'new_start_time': Timestamp.fromDate(utcStart),
        'new_end_time': Timestamp.fromDate(utcEnd),
        'timezone_used': _selectedTimezone,
        'reason': modificationReason.isNotEmpty 
            ? modificationReason 
            : 'Schedule adjustment',
        'modified_at': FieldValue.serverTimestamp(),
        'modified_by_type': 'teacher',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              modificationReason.isNotEmpty
                  ? 'Shift rescheduled successfully! Reason: $modificationReason'
                  : 'Shift rescheduled successfully!',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.pop(context, true); // Return true to indicate refresh needed
      }
    } catch (e) {
      AppLogger.error('Error rescheduling shift: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rescheduling shift: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header (fixed)
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0386FF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.schedule, color: Color(0xFF0386FF), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Reschedule Shift',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Direct Update',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade700,
                      ),
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
            ),
            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

            // Current Schedule
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Schedule:',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${DateFormat('MMM d, h:mm a').format(widget.shift.shiftStart)} - ${DateFormat('h:mm a').format(widget.shift.shiftEnd)}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Timezone Selection
            _buildTimezoneSelection(),
            const SizedBox(height: 20),

            // New Start Time
            Text(
              'New Start Time:',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 8),
            _buildTimePicker(
              'Start Time',
              _newStartTime ?? TimezoneUtils.convertToTimezone(widget.shift.shiftStart, _selectedTimezone),
              (time) => setState(() => _newStartTime = time),
            ),
            const SizedBox(height: 16),

            // New End Time
            Text(
              'New End Time:',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 8),
            _buildTimePicker(
              'End Time',
              _newEndTime ?? TimezoneUtils.convertToTimezone(widget.shift.shiftEnd, _selectedTimezone),
              (time) => setState(() => _newEndTime = time),
            ),
            const SizedBox(height: 16),

            // Conversion Preview
            if (_newStartTime != null && _newEndTime != null)
              _buildConversionPreview(),
            const SizedBox(height: 16),

            // Reason
            Text(
              'Reason for rescheduling (required):',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 100, // Fixed height to prevent overflow
              child: TextField(
                controller: _reasonController,
                maxLines: null, // Allow unlimited lines within the fixed height
                expands: true, // Fill the available height
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: 'e.g., Student requested to move class 1 hour later',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            // Footer buttons (fixed)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitRescheduleRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0386FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              'Apply Changes',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Changes will be applied immediately. The shift will be updated and you can clock in at the new time.',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.blue.shade700,
                            ),
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
    );
  }

  Widget _buildTimePicker(String label, DateTime initialTime, Function(DateTime) onTimeSelected) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: initialTime,
          firstDate: DateTime.now().subtract(const Duration(days: 7)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (date != null) {
          final time = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(initialTime),
          );
          if (time != null) {
            final selectedDateTime = DateTime(
              date.year,
              date.month,
              date.day,
              time.hour,
              time.minute,
            );
            onTimeSelected(selectedDateTime);
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.access_time, size: 20, color: Color(0xFF6B7280)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    DateFormat('MMM d, h:mm a').format(initialTime),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: Color(0xFF6B7280)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${TimezoneUtils.getTimezoneAbbreviation(_selectedTimezone)}',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimezoneSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Timezone',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF374151),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'The timezone for the times you select below',
              child: Icon(
                Icons.info_outline,
                size: 16,
                color: const Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: TimezoneUtils.getCommonTimezones()
                      .contains(_selectedTimezone)
                  ? _selectedTimezone
                  : 'UTC',
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF6B7280)),
              style: GoogleFonts.inter(
                color: const Color(0xFF111827),
                fontSize: 14,
              ),
              items: TimezoneUtils.getCommonTimezones().map((String tz) {
                return DropdownMenuItem<String>(
                  value: tz,
                  child: Text(tz),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedTimezone = newValue;
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConversionPreview() {
    if (_newStartTime == null || _newEndTime == null) {
      return const SizedBox.shrink();
    }

    // Get teacher's timezone for comparison
    final teacherTz = _teacherTimezone ?? widget.shift.teacherTimezone;
    if (teacherTz == _selectedTimezone) {
      return const SizedBox.shrink();
    }

    // Convert selected times (in selected timezone) to teacher's timezone
    final naiveStart = DateTime(
      _newStartTime!.year,
      _newStartTime!.month,
      _newStartTime!.day,
      _newStartTime!.hour,
      _newStartTime!.minute,
    );
    
    final naiveEnd = DateTime(
      _newEndTime!.year,
      _newEndTime!.month,
      _newEndTime!.day,
      _newEndTime!.hour,
      _newEndTime!.minute,
    );

    // Convert to UTC first, then to teacher's timezone
    final utcStart = TimezoneUtils.convertToUtc(naiveStart, _selectedTimezone);
    final utcEnd = TimezoneUtils.convertToUtc(naiveEnd, _selectedTimezone);
    final teacherStart = TimezoneUtils.convertToTimezone(utcStart, teacherTz);
    final teacherEnd = TimezoneUtils.convertToTimezone(utcEnd, teacherTz);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.swap_horiz, size: 16, color: Color(0xFF6B7280)),
              const SizedBox(width: 8),
              Text(
                'Preview in Teacher Timezone',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${DateFormat('MMM d, h:mm a').format(teacherStart)} - ${DateFormat('h:mm a').format(teacherEnd)}',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF374151),
            ),
          ),
          Text(
            '(${TimezoneUtils.getTimezoneAbbreviation(teacherTz)})',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

