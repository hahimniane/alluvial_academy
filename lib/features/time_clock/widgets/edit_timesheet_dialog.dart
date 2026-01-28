import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/enums/timesheet_enums.dart';
import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class EditTimesheetDialog extends StatefulWidget {
  final String timesheetId;
  final Map<String, dynamic> timesheetData;
  final VoidCallback? onUpdated;

  const EditTimesheetDialog({
    super.key,
    required this.timesheetId,
    required this.timesheetData,
    this.onUpdated,
  });

  @override
  State<EditTimesheetDialog> createState() => _EditTimesheetDialogState();
}

class _EditTimesheetDialogState extends State<EditTimesheetDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _hasFollowingShift = false;
  bool _isCheckingShifts = true;
  DateTime? _shiftEndTime;
  
  // Time controllers
  late TextEditingController _clockInTimeController;
  late TextEditingController _clockOutTimeController;
  late TextEditingController _notesController;
  
  // Date for the timesheet
  DateTime? _timesheetDate;
  DateTime? _clockInDateTime;
  DateTime? _clockOutDateTime;

  @override
  void initState() {
    super.initState();
    
    // Check if timesheet is approved - if so, close dialog immediately
    final status = widget.timesheetData['status'] as String?;
    final editApproved = widget.timesheetData['edit_approved'] as bool?;
    
    if (status == 'approved' || editApproved == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.timesheetApprovedLocked),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
      return;
    }
    
    _initializeTimes();
    _notesController = TextEditingController(
      text: widget.timesheetData['employee_notes'] ?? '',
    );
    _checkForFollowingShift();
  }

  void _initializeTimes() {
    try {
      // Get the date from the timesheet
      final dateStr = widget.timesheetData['date'] as String?;
      if (dateStr != null && dateStr.isNotEmpty) {
        // Try multiple date formats
        final formats = ['MMM dd, yyyy', 'yyyy-MM-dd', 'MM/dd/yyyy'];
        for (var format in formats) {
          try {
            _timesheetDate = DateFormat(format).parse(dateStr);
            break;
          } catch (e) {
            continue;
          }
        }
      }
      
      // If date parsing failed, use today
      _timesheetDate ??= DateTime.now();

      // Get clock-in time
      Timestamp? clockInTimestamp;
      if (widget.timesheetData['clock_in_timestamp'] != null) {
        clockInTimestamp = widget.timesheetData['clock_in_timestamp'] as Timestamp;
      } else if (widget.timesheetData['clock_in_time'] != null) {
        clockInTimestamp = widget.timesheetData['clock_in_time'] as Timestamp;
      }
      
      if (clockInTimestamp != null) {
        _clockInDateTime = clockInTimestamp.toDate();
      } else {
        // Fallback: try parsing start_time string
        final startTimeStr = widget.timesheetData['start_time'] as String?;
        if (startTimeStr != null && startTimeStr.isNotEmpty) {
          try {
            final timeOnly = DateFormat('h:mm a').parse(startTimeStr);
            _clockInDateTime = DateTime(
              _timesheetDate!.year,
              _timesheetDate!.month,
              _timesheetDate!.day,
              timeOnly.hour,
              timeOnly.minute,
            );
          } catch (e) {
            _clockInDateTime = DateTime(
              _timesheetDate!.year,
              _timesheetDate!.month,
              _timesheetDate!.day,
              9,
              0,
            );
          }
        } else {
          _clockInDateTime = DateTime(
            _timesheetDate!.year,
            _timesheetDate!.month,
            _timesheetDate!.day,
            9,
            0,
          );
        }
      }

      // Get clock-out time
      Timestamp? clockOutTimestamp;
      if (widget.timesheetData['clock_out_timestamp'] != null) {
        clockOutTimestamp = widget.timesheetData['clock_out_timestamp'] as Timestamp;
      } else if (widget.timesheetData['clock_out_time'] != null) {
        clockOutTimestamp = widget.timesheetData['clock_out_time'] as Timestamp;
      }
      
      if (clockOutTimestamp != null) {
        _clockOutDateTime = clockOutTimestamp.toDate();
      } else {
        // Fallback: try parsing end_time string
        final endTimeStr = widget.timesheetData['end_time'] as String?;
        if (endTimeStr != null && endTimeStr.isNotEmpty) {
          try {
            final timeOnly = DateFormat('h:mm a').parse(endTimeStr);
            _clockOutDateTime = DateTime(
              _timesheetDate!.year,
              _timesheetDate!.month,
              _timesheetDate!.day,
              timeOnly.hour,
              timeOnly.minute,
            );
          } catch (e) {
            // Default to 1 hour after clock-in
            _clockOutDateTime = _clockInDateTime!.add(const Duration(hours: 1));
          }
        } else {
          // Default to 1 hour after clock-in
          _clockOutDateTime = _clockInDateTime!.add(const Duration(hours: 1));
        }
      }

      _clockInTimeController = TextEditingController(
        text: DateFormat('h:mm a').format(_clockInDateTime!),
      );
      _clockOutTimeController = TextEditingController(
        text: DateFormat('h:mm a').format(_clockOutDateTime!),
      );
    } catch (e) {
      AppLogger.error('Error initializing times: $e');
      // Default values
      _timesheetDate = DateTime.now();
      _clockInDateTime = DateTime.now().copyWith(hour: 9, minute: 0);
      _clockOutDateTime = DateTime.now().copyWith(hour: 10, minute: 0);
      _clockInTimeController = TextEditingController(text: '9:00 AM');
      _clockOutTimeController = TextEditingController(text: AppLocalizations.of(context)!.time1000Am);
    }
  }

  @override
  void dispose() {
    _clockInTimeController.dispose();
    _clockOutTimeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectClockInTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_clockInDateTime!),
    );
    if (picked != null) {
      setState(() {
        _clockInDateTime = DateTime(
          _timesheetDate!.year,
          _timesheetDate!.month,
          _timesheetDate!.day,
          picked.hour,
          picked.minute,
        );
        _clockInTimeController.text = DateFormat('h:mm a').format(_clockInDateTime!);
      });
    }
  }

  /// Check if there's a following shift that would prevent editing the end time
  Future<void> _checkForFollowingShift() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isCheckingShifts = false);
        return;
      }

      // Get the shift ID from the timesheet data
      final shiftId = widget.timesheetData['shift_id'] ?? widget.timesheetData['shiftId'];
      if (shiftId == null) {
        setState(() => _isCheckingShifts = false);
        return;
      }

      // Fetch the current shift to get its end time
      final shiftDoc = await FirebaseFirestore.instance
          .collection('teaching_shifts')
          .doc(shiftId)
          .get();

      if (!shiftDoc.exists) {
        setState(() => _isCheckingShifts = false);
        return;
      }

      final shiftData = shiftDoc.data();
      if (shiftData == null) {
        setState(() => _isCheckingShifts = false);
        return;
      }

      // Get shift end time
      final shiftEndTimestamp = shiftData['shift_end'] as Timestamp?;
      if (shiftEndTimestamp != null) {
        _shiftEndTime = shiftEndTimestamp.toDate();
      }

      // Query for any shifts that start within 15 minutes after this shift ends
      if (_shiftEndTime != null) {
        final followingShiftsQuery = await FirebaseFirestore.instance
            .collection('teaching_shifts')
            .where('teacher_id', isEqualTo: user.uid)
            .where('shift_start', isGreaterThanOrEqualTo: Timestamp.fromDate(_shiftEndTime!))
            .where('shift_start', isLessThanOrEqualTo: Timestamp.fromDate(_shiftEndTime!.add(const Duration(minutes: 15))))
            .limit(1)
            .get();

        if (mounted) {
          setState(() {
            _hasFollowingShift = followingShiftsQuery.docs.isNotEmpty;
            _isCheckingShifts = false;
          });
        }
      } else {
        setState(() => _isCheckingShifts = false);
      }
    } catch (e) {
      AppLogger.error('Error checking for following shifts: $e');
      if (mounted) {
        setState(() => _isCheckingShifts = false);
      }
    }
  }

  Future<void> _selectClockOutTime() async {
    // Prevent editing if there's a following shift
    if (_hasFollowingShift) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.cannotEditClockOutTimeYou),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_clockOutDateTime!),
    );
    if (picked != null) {
      DateTime newClockOutDateTime = DateTime(
        _timesheetDate!.year,
        _timesheetDate!.month,
        _timesheetDate!.day,
        picked.hour,
        picked.minute,
      );

      // Enforce maximum clock-out time at shift end
      if (_shiftEndTime != null && newClockOutDateTime.isAfter(_shiftEndTime!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.timeClockClockOutExceed(
                DateFormat('h:mm a').format(_shiftEndTime!))),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
        // Cap at shift end time
        newClockOutDateTime = _shiftEndTime!;
      }

      setState(() {
        _clockOutDateTime = newClockOutDateTime;
        _clockOutTimeController.text = DateFormat('h:mm a').format(_clockOutDateTime!);
      });
    }
  }

  Future<void> _saveTimesheet() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate that clock-out is after clock-in
    if (_clockOutDateTime!.isBefore(_clockInDateTime!) || 
        _clockOutDateTime!.isAtSameMomentAs(_clockInDateTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.clockOutTimeMustBeAfter),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Calculate total hours
      final duration = _clockOutDateTime!.difference(_clockInDateTime!);
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      final totalHoursStr = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
      
      // Format times for display
      final startTimeStr = DateFormat('h:mm a').format(_clockInDateTime!);
      final endTimeStr = DateFormat('h:mm a').format(_clockOutDateTime!);

      // Store original data before editing (for admin review)
      final originalData = <String, dynamic>{
        'clock_in_timestamp': widget.timesheetData['clock_in_timestamp'] ?? widget.timesheetData['clock_in_time'],
        'clock_out_timestamp': widget.timesheetData['clock_out_timestamp'] ?? widget.timesheetData['clock_out_time'],
        'start_time': widget.timesheetData['start_time'] ?? '',
        'end_time': widget.timesheetData['end_time'] ?? '',
        'total_hours': widget.timesheetData['total_hours'] ?? '00:00',
      };

      // Update timesheet entry
      final updateData = <String, dynamic>{
        'clock_in_timestamp': Timestamp.fromDate(_clockInDateTime!),
        'clock_out_timestamp': Timestamp.fromDate(_clockOutDateTime!),
        'start_time': startTimeStr,
        'end_time': endTimeStr,
        'total_hours': totalHoursStr,
        'status': 'pending', // Set to pending for admin review
        'employee_notes': _notesController.text.trim(),
        'edited_at': FieldValue.serverTimestamp(),
        'edited_by': FirebaseAuth.instance.currentUser?.uid,
        'is_edited': true, // Mark as edited
        'edit_approved': false, // Edit not yet approved
        'original_data': originalData, // Store original data for comparison
      };

      await FirebaseFirestore.instance
          .collection('timesheet_entries')
          .doc(widget.timesheetId)
          .update(updateData);

      AppLogger.debug('Timesheet updated successfully: ${widget.timesheetId}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.timesheetUpdatedSuccess),
            backgroundColor: Colors.green,
          ),
        );
        widget.onUpdated?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      AppLogger.error('Error updating timesheet: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorUpdatingTimesheetE),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration = _clockOutDateTime != null && _clockInDateTime != null
        ? _clockOutDateTime!.difference(_clockInDateTime!)
        : const Duration();
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final totalHoursStr = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';

    // Calculate payment amount immediately
    final hourlyRate = widget.timesheetData['hourly_rate'] as num? ?? 0.0;
    final hoursWorked = duration.inSeconds / 3600.0;
    final calculatedPayment = hoursWorked * hourlyRate.toDouble();

    // Get original payment for comparison
    final originalPayment = widget.timesheetData['payment_amount'] as num? ??
                           widget.timesheetData['total_pay'] as num? ?? 0.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
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
                        color: const Color(0xFF0386FF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.edit,
                        color: Color(0xFF0386FF),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.timesheetEditTimesheet,
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Info banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context)!.timesheetEditNote,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFFD97706),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Warning banner for following shift restriction
                if (_hasFollowingShift)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber, color: Color(0xFFEF4444), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context)!.clockOutTimeCannotBeEdited,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFFEF4444),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_hasFollowingShift) const SizedBox(height: 16),
                
                // Max time warning
                if (_shiftEndTime != null && !_hasFollowingShift)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDEEBFF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF90CAF9)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, color: Color(0xFF0386FF), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context)!
                                .timeClockClockOutExceedShort(
                                    DateFormat('h:mm a')
                                        .format(_shiftEndTime!)),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF0386FF),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_shiftEndTime != null && !_hasFollowingShift) const SizedBox(height: 16),
                const SizedBox(height: 8),

                // Date display (read-only)
                Text(
                  AppLocalizations.of(context)!.timesheetDate,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 20, color: Color(0xFF64748B)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          DateFormat('EEEE, MMMM d, yyyy').format(_timesheetDate!),
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: const Color(0xFF1E293B),
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Clock In Time
                Text(
                  AppLocalizations.of(context)!.timesheetClockInTime,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _selectClockInTime,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, size: 20, color: Color(0xFF0386FF)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _clockInTimeController.text,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Clock Out Time
                Text(
                  AppLocalizations.of(context)!.timesheetClockOutTime,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _selectClockOutTime,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, size: 20, color: Color(0xFF10B981)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _clockOutTimeController.text,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Total Hours (calculated, read-only)
                Text(
                  'Total Hours',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer, size: 20, color: Color(0xFF10B981)),
                      const SizedBox(width: 12),
                      Text(
                        '$totalHoursStr (${hours}h ${minutes}m)',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Payment Calculation (calculated, read-only)
                Text(
                  AppLocalizations.of(context)!.timesheetPaymentCalculation,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: calculatedPayment != originalPayment.toDouble()
                        ? const Color(0xFFFEF3C7) // Yellow if changed
                        : const Color(0xFFF0FDF4), // Green if same
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: calculatedPayment != originalPayment.toDouble()
                          ? const Color(0xFFFCD34D)
                          : const Color(0xFFBBF7D0)
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.attach_money,
                            size: 20,
                            color: calculatedPayment != originalPayment.toDouble()
                                ? const Color(0xFFD97706)
                                : const Color(0xFF10B981),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '\$${calculatedPayment.toStringAsFixed(2)}',
                                  style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: calculatedPayment != originalPayment.toDouble()
                                        ? const Color(0xFFD97706)
                                        : const Color(0xFF15803D),
                                  ),
                                ),
                                if (calculatedPayment != originalPayment.toDouble())
                                  Text(
                                    'Original: \$${originalPayment.toStringAsFixed(2)}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: const Color(0xFF92400E),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (calculatedPayment != originalPayment.toDouble())
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            calculatedPayment > originalPayment.toDouble()
                                ? '⚠️ Payment will increase by \$${(calculatedPayment - originalPayment.toDouble()).toStringAsFixed(2)}'
                                : '⚠️ Payment will decrease by \$${(-calculatedPayment + originalPayment.toDouble()).toStringAsFixed(2)}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFFD97706),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Notes (Mandatory)
                Text(
                  AppLocalizations.of(context)!.notes,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please provide a reason for editing this timesheet';
                    }
                    if (value.trim().length < 10) {
                      return 'Please provide more details (at least 10 characters)';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.explainWhyYouAreEditingThis,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    errorMaxLines: 2,
                  ),
                ),
                const SizedBox(height: 24),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                      child: Text(
                        AppLocalizations.of(context)!.commonCancel,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveTimesheet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0386FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              AppLocalizations.of(context)!.timesheetSaveChanges,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
