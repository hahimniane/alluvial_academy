import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:alluwalacademyadmin/features/time_clock/enums/timesheet_enums.dart';
import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import 'package:alluwalacademyadmin/core/services/teacher_metrics_service.dart';
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
  DateTime? _shiftStartTime;
  String? _adminTimezone;
  String? _teacherTimezone;
  
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
    
    // Check if timesheet is approved - if so, show confirmation before editing
    final status = widget.timesheetData['status'] as String?;
    final editApproved = widget.timesheetData['edit_approved'] as bool?;
    final isApproved = status == 'approved' || editApproved == true;
    
    if (isApproved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showApprovalWarning();
        }
      });
    }
    
    _initializeTimes();
    _notesController = TextEditingController(
      text: widget.timesheetData['employee_notes'] ?? '',
    );
    _checkForFollowingShift();
  }

  /// Shows a warning if the timesheet was already approved
  void _showApprovalWarning() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B)),
            const SizedBox(width: 8),
            const Text("Approved Timesheet"),
          ],
        ),
        content: const Text(
          "This timesheet has already been approved. Editing it will void the current approval and send it back to 'Pending' for admin review. Do you want to proceed?",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Pop warning
              Navigator.pop(context); // Pop edit dialog
            },
            child: Text(
              AppLocalizations.of(context)!.commonCancel,
              style: GoogleFonts.inter(color: const Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
            ),
            child: const Text("Proceed"),
          ),
        ],
      ),
    );
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

      if (_clockInDateTime != null && _clockOutDateTime != null) {
        _clockOutDateTime = _ensureClockOutAfterClockIn(_clockOutDateTime!);
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
        if (_clockOutDateTime != null) {
          _clockOutDateTime = _ensureClockOutAfterClockIn(_clockOutDateTime!);
          _clockOutTimeController.text = DateFormat('h:mm a').format(_clockOutDateTime!);
        }
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

      // Shift window for billable hours / pay (same rules as TeacherMetricsService)
      final shiftStartTimestamp = shiftData['shift_start'] as Timestamp?;
      if (shiftStartTimestamp != null) {
        _shiftStartTime = shiftStartTimestamp.toDate();
      }
      final shiftEndTimestamp = shiftData['shift_end'] as Timestamp?;
      if (shiftEndTimestamp != null) {
        _shiftEndTime = shiftEndTimestamp.toDate();
      }

      // Get timezones
      _adminTimezone = shiftData['admin_timezone'] as String?;
      _teacherTimezone = shiftData['teacher_timezone'] as String?;

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

  /// If [out] is not strictly after clock-in, add whole days until it is (overnight sessions).
  DateTime _ensureClockOutAfterClockIn(DateTime out) {
    if (_clockInDateTime == null) return out;
    var result = out;
    for (var i = 0; i < 3 && !result.isAfter(_clockInDateTime!); i++) {
      result = result.add(const Duration(days: 1));
    }
    return result;
  }

  bool get _clockOutOnLaterCalendarDayThanTimesheet {
    if (_clockOutDateTime == null ||
        _timesheetDate == null ||
        _clockInDateTime == null) {
      return false;
    }
    final resolved = _ensureClockOutAfterClockIn(_clockOutDateTime!);
    final ts = DateTime(_timesheetDate!.year, _timesheetDate!.month, _timesheetDate!.day);
    final od = DateTime(resolved.year, resolved.month, resolved.day);
    return od.isAfter(ts);
  }

  /// Same caps as payroll / TeacherMetricsService when shift window is loaded.
  Duration _billableDurationForEdit() {
    if (_clockInDateTime == null || _clockOutDateTime == null) {
      return Duration.zero;
    }
    final out = _ensureClockOutAfterClockIn(_clockOutDateTime!);
    if (_shiftStartTime != null && _shiftEndTime != null) {
      final shiftMap = <String, dynamic>{
        'shift_start': Timestamp.fromDate(_shiftStartTime!),
        'shift_end': Timestamp.fromDate(_shiftEndTime!),
      };
      final h = TeacherMetricsService.billableHoursForShiftClock(
        shift: shiftMap,
        clockIn: _clockInDateTime!,
        clockOut: out,
      );
      return Duration(seconds: (h * 3600.0).round());
    }
    return out.difference(_clockInDateTime!);
  }

  double _billableHoursForEdit() {
    final d = _billableDurationForEdit();
    if (_clockInDateTime == null || _clockOutDateTime == null) return 0.0;
    return d.inSeconds / 3600.0;
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

    final resolvedClockOut = _ensureClockOutAfterClockIn(_clockOutDateTime!);
    if (resolvedClockOut != _clockOutDateTime) {
      setState(() {
        _clockOutDateTime = resolvedClockOut;
        _clockOutTimeController.text = DateFormat('h:mm a').format(resolvedClockOut);
      });
    }

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
      final hourlyRate = (widget.timesheetData['hourly_rate'] as num?)?.toDouble() ?? 0.0;

      final billableDuration = _billableDurationForEdit();
      final hoursWorked = _billableHoursForEdit();

      final hours = billableDuration.inHours;
      final minutes = billableDuration.inMinutes % 60;
      final seconds = billableDuration.inSeconds % 60;
      final totalHoursStr = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

      final recalculatedPay = hoursWorked * hourlyRate;

      final effectiveEnd = _shiftEndTime != null &&
              _clockOutDateTime!.isAfter(_shiftEndTime!)
          ? _shiftEndTime!
          : _clockOutDateTime!;

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
        'payment_amount': widget.timesheetData['payment_amount'],
        'total_pay': widget.timesheetData['total_pay'],
        'effective_end_timestamp': widget.timesheetData['effective_end_timestamp'],
      };

      // Update timesheet entry (includes recalculated pay)
      final updateData = <String, dynamic>{
        'clock_in_timestamp': Timestamp.fromDate(_clockInDateTime!),
        'clock_out_timestamp': Timestamp.fromDate(_clockOutDateTime!),
        'effective_end_timestamp': Timestamp.fromDate(effectiveEnd),
        'start_time': startTimeStr,
        'end_time': endTimeStr,
        'total_hours': totalHoursStr,
        'payment_amount': recalculatedPay,
        'total_pay': recalculatedPay,
        'status': 'pending', // Set to pending for admin review
        'employee_notes': _notesController.text.trim(),
        'edited_at': FieldValue.serverTimestamp(),
        'edited_by': FirebaseAuth.instance.currentUser?.uid,
        'is_edited': true, // Mark as edited
        'edit_approved': false, // Edit not yet approved
        'original_data': originalData, // Store original data for comparison
        
        // Audit fields for post-approval corrections
        'approval_voided_at': widget.timesheetData['status'] == 'approved' || widget.timesheetData['edit_approved'] == true 
            ? FieldValue.serverTimestamp() 
            : null,
        'previous_status': widget.timesheetData['status'],
        'previous_payment_amount': widget.timesheetData['payment_amount'] ?? widget.timesheetData['total_pay'],
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

  Widget _timezoneRow(String label, String value) {
    return Row(
      children: [
        const Icon(Icons.public, size: 14, color: Color(0xFF64748B)),
        const SizedBox(width: 8),
        Text(
          "$label: ",
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF334155),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hourlyRate = widget.timesheetData['hourly_rate'] as num? ?? 0.0;
    final Duration previewBillable;
    final double hoursWorked;
    if (_clockOutDateTime != null &&
        _clockInDateTime != null &&
        _shiftStartTime != null &&
        _shiftEndTime != null) {
      final shiftMap = <String, dynamic>{
        'shift_start': Timestamp.fromDate(_shiftStartTime!),
        'shift_end': Timestamp.fromDate(_shiftEndTime!),
      };
      hoursWorked = TeacherMetricsService.billableHoursForShiftClock(
        shift: shiftMap,
        clockIn: _clockInDateTime!,
        clockOut: _clockOutDateTime!,
      );
      previewBillable = Duration(seconds: (hoursWorked * 3600.0).round());
    } else if (_clockOutDateTime != null && _clockInDateTime != null) {
      previewBillable = _clockOutDateTime!.difference(_clockInDateTime!);
      hoursWorked = previewBillable.inSeconds / 3600.0;
    } else {
      previewBillable = const Duration();
      hoursWorked = 0.0;
    }
    final hours = previewBillable.inHours;
    final minutes = previewBillable.inMinutes % 60;
    final totalHoursStr = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';

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
                
                // Timezone info
                if (_adminTimezone != null || _teacherTimezone != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_teacherTimezone != null)
                          _timezoneRow("Your Timezone", _teacherTimezone!),
                        if (_adminTimezone != null && _adminTimezone != _teacherTimezone)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: _timezoneRow("Shift Timezone (Admin)", _adminTimezone!),
                          ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 8),

                // Live Duration Readout
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBAE6FD)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, color: Color(0xFF0284C7), size: 20),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Billable duration (used for pay)",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF0284C7),
                            ),
                          ),
                          Text(
                            () {
                              if (_clockInDateTime == null || _clockOutDateTime == null) return "--:--:--";
                              final duration = _billableDurationForEdit();
                              if (duration.isNegative) return "Invalid (End before Start)";
                              final hours = duration.inHours;
                              final minutes = duration.inMinutes % 60;
                              final seconds = duration.inSeconds % 60;
                              return "${hours}h ${minutes}m ${seconds}s";
                            }(),
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0C4A6E),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.timesheetClockInTime,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      "Local Time",
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.timesheetClockOutTime,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      "Local Time",
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
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
                if (_clockOutOnLaterCalendarDayThanTimesheet) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.wb_twilight_outlined,
                          size: 16, color: Color(0xFF0284C7)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.of(context)!
                                  .timesheetClockOutNextDayHint,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                height: 1.35,
                                color: const Color(0xFF0369A1),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('EEE, MMM d, yyyy').format(
                                _ensureClockOutAfterClockIn(_clockOutDateTime!),
                              ),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0C4A6E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
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
