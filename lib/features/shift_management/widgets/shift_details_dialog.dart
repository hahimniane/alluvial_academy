import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/teaching_shift.dart';

class ShiftDetailsDialog extends StatelessWidget {
  final TeachingShift shift;

  const ShiftDetailsDialog({
    super.key,
    required this.shift,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBasicInfo(),
                    const SizedBox(height: 24),
                    _buildScheduleInfo(),
                    const SizedBox(height: 24),
                    _buildParticipantsInfo(),
                    const SizedBox(height: 24),
                    _buildStatusInfo(),
                    if (shift.notes != null) ...[
                      const SizedBox(height: 24),
                      _buildNotesInfo(),
                    ],
                  ],
                ),
              ),
            ),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xffE2E8F0))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getStatusColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getStatusIcon(),
              color: _getStatusColor(),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shift.displayName,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xff111827),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    shift.status.name.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfo() {
    return _buildSection(
      'Basic Information',
      Icons.info_outline,
      [
        _buildInfoRow('Subject', shift.subjectDisplayName),
        _buildInfoRow('Teacher', shift.teacherName),
        _buildInfoRow(
            'Duration', '${shift.shiftDurationHours.toStringAsFixed(1)} hours'),
        _buildInfoRow(
            'Hourly Rate', '\$${shift.hourlyRate.toStringAsFixed(2)}'),
        _buildInfoRow(
            'Total Payment', '\$${shift.totalPayment.toStringAsFixed(2)}'),
      ],
    );
  }

  Widget _buildScheduleInfo() {
    return _buildSection(
      'Schedule',
      Icons.schedule,
      [
        _buildInfoRow('Date', _formatDate(shift.shiftStart)),
        _buildInfoRow('Start Time', _formatTime(shift.shiftStart)),
        _buildInfoRow('End Time', _formatTime(shift.shiftEnd)),
        _buildInfoRow('Admin Timezone', shift.adminTimezone),
        _buildInfoRow('Teacher Timezone', shift.teacherTimezone),
        if (shift.recurrence != RecurrencePattern.none) ...[
          _buildInfoRow('Recurrence', _getRecurrenceText()),
          if (shift.recurrenceEndDate != null)
            _buildInfoRow(
                'Recurrence End', _formatDate(shift.recurrenceEndDate!)),
        ],
      ],
    );
  }

  Widget _buildParticipantsInfo() {
    return _buildSection(
      'Participants',
      Icons.people,
      [
        _buildInfoRow('Teacher', shift.teacherName),
        _buildInfoRow(
          'Students (${shift.studentNames.length})',
          shift.studentNames.isNotEmpty
              ? shift.studentNames.join(', ')
              : 'No students assigned',
        ),
      ],
    );
  }

  Widget _buildStatusInfo() {
    return _buildSection(
      'Status & Timing',
      Icons.access_time,
      [
        _buildInfoRow('Current Status', shift.status.name.toUpperCase()),
        _buildInfoRow('Can Clock In', shift.canClockIn ? 'Yes' : 'No'),
        _buildInfoRow(
            'Currently Active', shift.isCurrentlyActive ? 'Yes' : 'No'),
        _buildInfoRow('Has Expired', shift.hasExpired ? 'Yes' : 'No'),
        _buildInfoRow('Created', _formatDateTime(shift.createdAt)),
        if (shift.lastModified != null)
          _buildInfoRow('Last Modified', _formatDateTime(shift.lastModified!)),
      ],
    );
  }

  Widget _buildNotesInfo() {
    return _buildSection(
      'Notes',
      Icons.note,
      [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xffF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xffE2E8F0)),
          ),
          child: Text(
            shift.notes!,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xff374151),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xffE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xffF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(bottom: BorderSide(color: Color(0xffE2E8F0))),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: const Color(0xff0386FF)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xff374151),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xff6B7280),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xff374151),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xffE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.inter(
                color: const Color(0xff6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (shift.status) {
      case ShiftStatus.scheduled:
        return const Color(0xff0386FF);
      case ShiftStatus.active:
        return const Color(0xff10B981);
      case ShiftStatus.completed:
        return const Color(0xff6B7280);
      case ShiftStatus.missed:
        return const Color(0xffEF4444);
      case ShiftStatus.cancelled:
        return const Color(0xffF59E0B);
    }
  }

  IconData _getStatusIcon() {
    switch (shift.status) {
      case ShiftStatus.scheduled:
        return Icons.schedule;
      case ShiftStatus.active:
        return Icons.play_circle_fill;
      case ShiftStatus.completed:
        return Icons.check_circle;
      case ShiftStatus.missed:
        return Icons.cancel;
      case ShiftStatus.cancelled:
        return Icons.block;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${_formatDate(dateTime)} at ${_formatTime(dateTime)}';
  }

  String _getRecurrenceText() {
    switch (shift.recurrence) {
      case RecurrencePattern.none:
        return 'No Recurrence';
      case RecurrencePattern.daily:
        return 'Daily';
      case RecurrencePattern.weekly:
        return 'Weekly';
      case RecurrencePattern.monthly:
        return 'Monthly';
    }
  }
}
