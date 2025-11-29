import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/models/teaching_shift.dart';
import '../../../core/enums/shift_enums.dart';
import '../../../core/services/shift_form_service.dart';
import '../../../core/utils/app_logger.dart';

class ShiftDetailsDialog extends StatefulWidget {
  final TeachingShift shift;
  final VoidCallback? onPublishShift;
  final VoidCallback? onUnpublishShift;
  final VoidCallback? onClaimShift;
  final Function(ShiftStatus)? onCorrectStatus;

  const ShiftDetailsDialog({
    super.key,
    required this.shift,
    this.onPublishShift,
    this.onUnpublishShift,
    this.onClaimShift,
    this.onCorrectStatus,
  });

  @override
  State<ShiftDetailsDialog> createState() => _ShiftDetailsDialogState();
}

class _ShiftDetailsDialogState extends State<ShiftDetailsDialog> {
  Map<String, dynamic>? _formResponse;
  Map<String, dynamic>? _formTemplate;
  Map<String, String>? _timesheetData;
  bool _isLoadingForm = true;

  @override
  void initState() {
    super.initState();
    _loadFormData();
  }

  Future<void> _loadFormData() async {
    setState(() => _isLoadingForm = true);
    
    try {
      // Load form template
      final template = await ShiftFormService.getReadinessFormTemplate();
      
      // Find timesheet entry for this shift
      final timesheetQuery = await FirebaseFirestore.instance
          .collection('timesheet_entries')
          .where('shift_id', isEqualTo: widget.shift.id)
          .where('clock_out_time', isNotEqualTo: null)
          .orderBy('clock_out_time', descending: true)
          .limit(1)
          .get();
      
      if (timesheetQuery.docs.isNotEmpty) {
        final timesheetDoc = timesheetQuery.docs.first;
        final timesheetData = timesheetDoc.data();
        
        // Get form response if linked
        final formResponseId = timesheetData['form_response_id'] as String?;
        if (formResponseId != null) {
          final formResponseDoc = await FirebaseFirestore.instance
              .collection('form_responses')
              .doc(formResponseId)
              .get();
          
          if (formResponseDoc.exists) {
            setState(() {
              _formResponse = formResponseDoc.data();
              _formTemplate = template;
              _timesheetData = {
                'clockIn': timesheetData['clock_in_time'] != null
                    ? DateFormat('MMM d, yyyy h:mm a').format(
                        (timesheetData['clock_in_time'] as Timestamp).toDate())
                    : 'N/A',
                'clockOut': timesheetData['clock_out_time'] != null
                    ? DateFormat('MMM d, yyyy h:mm a').format(
                        (timesheetData['clock_out_time'] as Timestamp).toDate())
                    : 'N/A',
                'actualHours': timesheetData['total_hours'] ?? '0:00',
                'reportedHours': _formResponse?['reportedHours']?.toString() ?? 'N/A',
              };
            });
          }
        } else {
          // No form response, but we have timesheet data
          setState(() {
            _timesheetData = {
              'clockIn': timesheetData['clock_in_time'] != null
                  ? DateFormat('MMM d, yyyy h:mm a').format(
                      (timesheetData['clock_in_time'] as Timestamp).toDate())
                  : 'N/A',
              'clockOut': timesheetData['clock_out_time'] != null
                  ? DateFormat('MMM d, yyyy h:mm a').format(
                      (timesheetData['clock_out_time'] as Timestamp).toDate())
                  : 'N/A',
              'actualHours': timesheetData['total_hours'] ?? '0:00',
              'reportedHours': 'Not submitted',
            };
          });
        }
      }
    } catch (e) {
      AppLogger.error('ShiftDetailsDialog: Error loading form data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingForm = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 600,
        height: 700,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildBasicInfo(),
                    const SizedBox(height: 24),
                    _buildScheduleInfo(),
                    const SizedBox(height: 24),
                    _buildParticipantsInfo(),
                    const SizedBox(height: 24),
                    _buildStatusInfo(),
                    if (widget.shift.notes != null) ...[
                      const SizedBox(height: 24),
                      _buildNotesInfo(),
                    ],
                    // NEW: Form submission section
                    if (_timesheetData != null) ...[
                      const SizedBox(height: 24),
                      _buildFormSubmissionSection(),
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
                  widget.shift.displayName,
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
                    widget.shift.status.name.toUpperCase(),
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
        _buildInfoRow('Subject', widget.shift.effectiveSubjectDisplayName),
        _buildInfoRow('Teacher', widget.shift.teacherName),
        _buildInfoRow(
            'Duration', '${widget.shift.shiftDurationHours.toStringAsFixed(1)} hours'),
        _buildInfoRow(
            'Hourly Rate', '\$${widget.shift.hourlyRate.toStringAsFixed(2)}'),
        _buildInfoRow(
            'Total Payment', '\$${widget.shift.totalPayment.toStringAsFixed(2)}'),
      ],
    );
  }

  Widget _buildScheduleInfo() {
    return _buildSection(
      'Schedule',
      Icons.schedule,
      [
        _buildInfoRow('Date', _formatDate(widget.shift.shiftStart)),
        _buildInfoRow('Start Time', _formatTime(widget.shift.shiftStart)),
        _buildInfoRow('End Time', _formatTime(widget.shift.shiftEnd)),
        _buildInfoRow('Admin Timezone', widget.shift.adminTimezone),
        _buildInfoRow('Teacher Timezone', widget.shift.teacherTimezone),
        if (widget.shift.recurrence != RecurrencePattern.none) ...[
          _buildInfoRow('Recurrence', _getRecurrenceText()),
          if (widget.shift.recurrenceEndDate != null)
            _buildInfoRow(
                'Recurrence End', _formatDate(widget.shift.recurrenceEndDate!)),
        ],
      ],
    );
  }

  Widget _buildParticipantsInfo() {
    return _buildSection(
      'Participants',
      Icons.people,
      [
        _buildInfoRow('Teacher', widget.shift.teacherName),
        _buildInfoRow(
          'Students (${widget.shift.studentNames.length})',
          widget.shift.studentNames.isNotEmpty
              ? widget.shift.studentNames.join(', ')
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
        _buildInfoRow('Current Status', widget.shift.status.name.toUpperCase()),
        _buildInfoRow('Can Clock In', widget.shift.canClockIn ? 'Yes' : 'No'),
        _buildInfoRow(
            'Currently Active', widget.shift.isCurrentlyActive ? 'Yes' : 'No'),
        _buildInfoRow('Has Expired', widget.shift.hasExpired ? 'Yes' : 'No'),
        _buildInfoRow('Created', _formatDateTime(widget.shift.createdAt)),
        if (widget.shift.lastModified != null)
          _buildInfoRow('Last Modified', _formatDateTime(widget.shift.lastModified!)),
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
            widget.shift.notes!,
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

  Widget _buildFormSubmissionSection() {
    if (_isLoadingForm) {
      return _buildSection(
        'Class Completion Form',
        Icons.assignment,
        [
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
        ],
      );
    }

    final children = <Widget>[];
    
    // Actual hours worked (from timesheet)
    if (_timesheetData != null) {
      children.addAll([
        _buildInfoRow('Clock In', _timesheetData!['clockIn'] ?? 'N/A'),
        _buildInfoRow('Clock Out', _timesheetData!['clockOut'] ?? 'N/A'),
        _buildInfoRow('Actual Hours', _timesheetData!['actualHours'] ?? '0:00'),
        _buildInfoRow('Reported Hours', _timesheetData!['reportedHours'] ?? 'Not submitted'),
        const Divider(height: 24),
      ]);
    }

    // Form responses
    if (_formResponse != null && _formTemplate != null) {
      final responses = _formResponse!['responses'] as Map<String, dynamic>? ?? {};
      final fieldsData = _formTemplate!['fields'] as Map<String, dynamic>? ?? {};
      
      if (responses.isNotEmpty) {
        children.add(
          Text(
            'Form Responses',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xff374151),
            ),
          ),
        );
        children.add(const SizedBox(height: 12));
        
        // Sort fields by order
        final fieldsList = <Map<String, dynamic>>[];
        fieldsData.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            fieldsList.add({'id': key, ...value});
          }
        });
        fieldsList.sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));
        
        for (var field in fieldsList) {
          final fieldId = field['id'];
          final label = field['label'] ?? fieldId;
          final response = responses[fieldId];
          
          if (response != null) {
            String displayValue;
            if (response is List) {
              displayValue = response.join(', ');
            } else if (response is bool) {
              displayValue = response ? 'Yes' : 'No';
            } else {
              displayValue = response.toString();
            }
            
            children.add(_buildInfoRow(label, displayValue));
          }
        }
      } else {
        children.add(
          Text(
            'No form submitted yet',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xff9CA3AF),
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      }
    } else {
      children.add(
        Text(
          'Form not submitted',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xff9CA3AF),
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return _buildSection('Class Completion Form', Icons.assignment, children);
  }

  Widget _buildActions(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isMyShift = currentUser?.uid == widget.shift.teacherId;
    final canPublish =
        isMyShift && widget.shift.status == ShiftStatus.scheduled && !widget.shift.hasExpired;
    final isPublished = widget.shift.isPublished;

    // Check if shift is marked as missed but hasn't actually started yet
    final now = DateTime.now();
    final isMissedBeforeStart =
        widget.shift.status == ShiftStatus.missed && now.isBefore(widget.shift.shiftStart);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xffE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Action buttons on the left
          Row(
            children: [
              // Correct Status button for prematurely missed shifts
              if (isMissedBeforeStart && widget.onCorrectStatus != null)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onCorrectStatus!(ShiftStatus.scheduled);
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(
                    'Mark as Scheduled',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff0386FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              if (isMissedBeforeStart && widget.onCorrectStatus != null)
                const SizedBox(width: 12),
              // Publish/Unpublish button for shift owner
              if (canPublish && widget.onPublishShift != null && !isPublished)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onPublishShift!();
                  },
                  icon: const Icon(Icons.publish, size: 18),
                  label: Text(
                    'Publish Shift',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff0386FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              if (canPublish && widget.onUnpublishShift != null && isPublished)
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onUnpublishShift!();
                  },
                  icon: const Icon(Icons.unpublished, size: 18),
                  label: Text(
                    'Unpublish',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xffF59E0B),
                    side: const BorderSide(color: Color(0xffF59E0B)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),

              // Claim button for other teachers viewing published shifts
              if (!isMyShift && isPublished && widget.onClaimShift != null)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onClaimShift!();
                  },
                  icon: const Icon(Icons.add_task, size: 18),
                  label: Text(
                    'Claim Shift',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
            ],
          ),

          // Close button on the right
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
    switch (widget.shift.status) {
      case ShiftStatus.scheduled:
        return const Color(0xff0386FF);
      case ShiftStatus.active:
        return const Color(0xff10B981);
      case ShiftStatus.partiallyCompleted:
        return const Color(0xffF97316);
      case ShiftStatus.fullyCompleted:
        return const Color(0xff6366F1);
      case ShiftStatus.completed:
        return const Color(0xff6B7280);
      case ShiftStatus.missed:
        return const Color(0xffEF4444);
      case ShiftStatus.cancelled:
        return const Color(0xffF59E0B);
    }
  }

  IconData _getStatusIcon() {
    switch (widget.shift.status) {
      case ShiftStatus.scheduled:
        return Icons.schedule;
      case ShiftStatus.active:
        return Icons.play_circle_fill;
      case ShiftStatus.partiallyCompleted:
        return Icons.timelapse;
      case ShiftStatus.fullyCompleted:
        return Icons.check_circle;
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
    switch (widget.shift.recurrence) {
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
