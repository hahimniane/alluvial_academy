import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/teaching_shift.dart';
import '../../../core/enums/shift_enums.dart';
import '../../../core/services/shift_service.dart';
import '../../../core/services/shift_timesheet_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/shift_form_service.dart';
import '../../../form_screen.dart';
import '../../time_clock/widgets/edit_timesheet_dialog.dart';

class ShiftDetailsDialog extends StatefulWidget {
  final TeachingShift shift;
  final VoidCallback? onPublishShift;
  final VoidCallback? onClaimShift;
  final VoidCallback? onRefresh;

  const ShiftDetailsDialog({
    super.key,
    required this.shift,
    this.onPublishShift,
    this.onClaimShift,
    this.onRefresh,
  });

  @override
  State<ShiftDetailsDialog> createState() => _ShiftDetailsDialogState();
}

class _ShiftDetailsDialogState extends State<ShiftDetailsDialog> {
  bool _isLoading = true;
  bool _isClockingIn = false;
  bool _isClockingOut = false;
  Map<String, dynamic>? _timesheetEntry;
  Map<String, dynamic>? _formResponse;

  // Mapping of long question IDs to simplified labels for the Readiness Form
  static const Map<String, String> _simplifiedLabels = {
    '1762629945642': 'Teacher Name',
    '1754405971187': 'Equipment Used',
    '1754406115874': 'Class Type',
    '1754406288023': 'Class Day',
    '1754406414139': 'Duration (Hrs)',
    '1754406457284': 'Present Students',
    '1754406487572': 'Absent Students',
    '1754406512129': 'Late Students',
    '1754406537658': 'Weekly Video Rec',
    '1754406625835': 'Punctuality',
    '1754406729715': 'Weekly Status',
    '1754406826688': 'Clock-In Status',
    '1754406914911': 'Clock-Out Status',
    '1754407016623': 'Monthly Bayana',
    '1754407079872': 'Off-Schedule?',
    '1754407111959': 'Off-Schedule Reason',
    '1754407141413': 'Missed Bayana',
    '1754407184691': 'Topics Taught',
    '1754407218568': 'Student Work',
    '1754407297953': 'Curriculum Used',
    '1754407417507': 'Coach Support',
    '1754407509366': 'Teacher\'s Note',
    '1756564707506': 'Class Category',
    '1764288691217': 'Zoom Host',
  };

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);
    try {
      debugPrint("🔍 Loading details for shift: ${widget.shift.id}");
      
      // 1. Find Timesheet Entry for this shift
      // Try multiple queries to be robust
      QuerySnapshot timesheetQuery = await FirebaseFirestore.instance
          .collection('timesheet_entries')
          .where('shift_id', isEqualTo: widget.shift.id)
          .limit(1)
          .get();
      
      if (timesheetQuery.docs.isEmpty) {
        debugPrint("⚠️ No timesheet found by shift_id (snake_case). Trying shiftId (camelCase)...");
        timesheetQuery = await FirebaseFirestore.instance
          .collection('timesheet_entries')
          .where('shiftId', isEqualTo: widget.shift.id)
          .limit(1)
          .get();
      }
      
      if (timesheetQuery.docs.isNotEmpty) {
        final timesheetDoc = timesheetQuery.docs.first;
        debugPrint("✅ Found timesheet: ${timesheetDoc.id}");
        
        if (mounted) {
          setState(() {
             _timesheetEntry = timesheetDoc.data() as Map<String, dynamic>;
             _timesheetEntry!['id'] = timesheetDoc.id;
          });
        }
        
        // 2. Find Form Response
        final formId = _timesheetEntry!['form_response_id'];
        Map<String, dynamic>? formResponse;
        
        if (formId != null) {
          final formDoc = await FirebaseFirestore.instance
              .collection('form_responses')
              .doc(formId)
              .get();
          if (formDoc.exists) {
            formResponse = formDoc.data();
          }
        } else {
          // Fallback queries for form response
          var formQuery = await FirebaseFirestore.instance
              .collection('form_responses')
              .where('timesheetId', isEqualTo: timesheetDoc.id)
              .limit(1)
              .get();
          
          if (formQuery.docs.isEmpty) {
            formQuery = await FirebaseFirestore.instance
                .collection('form_responses')
                .where('timesheet_id', isEqualTo: timesheetDoc.id)
                .limit(1)
                .get();
          }

          if (formQuery.docs.isNotEmpty) {
            formResponse = formQuery.docs.first.data();
          }
        }
        
        if (mounted) {
            setState(() {
            _formResponse = formResponse;
            });
          }
        } else {
        debugPrint("❌ No timesheet found for shift: ${widget.shift.id} after all attempts");
      }
    } catch (e) {
      debugPrint("Error loading shift details: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Check if clock-in is allowed right now
  bool get _canClockInNow {
    final now = DateTime.now();
    final shiftStart = widget.shift.shiftStart;
    final shiftEnd = widget.shift.shiftEnd;

    // Allow clock-in from shift start to shift end
    return now.isAfter(shiftStart.subtract(const Duration(minutes: 1))) &&
        now.isBefore(shiftEnd) &&
        widget.shift.status == ShiftStatus.scheduled;
  }

  // Check if this is an upcoming shift (not yet time to clock in)
  bool get _isUpcoming {
    final now = DateTime.now();
    return widget.shift.shiftStart.isAfter(now) &&
        widget.shift.status == ShiftStatus.scheduled;
  }

  // Check if shift is currently active (clocked in)
  bool get _isActive {
    if (_timesheetEntry != null) {
      final clockIn = _timesheetEntry!['clock_in_time'] ?? _timesheetEntry!['clock_in_timestamp'];
      final clockOut = _timesheetEntry!['clock_out_time'] ?? _timesheetEntry!['clock_out_timestamp'];
      if (clockIn != null && clockOut == null) return true;
    }
    return widget.shift.status == ShiftStatus.active;
  }

  // Check if shift is completed
  bool get _isCompleted {
    if (_timesheetEntry != null) {
      final clockOut = _timesheetEntry!['clock_out_time'] ?? _timesheetEntry!['clock_out_timestamp'];
      if (clockOut != null) return true;
    }
    
    return widget.shift.status == ShiftStatus.completed ||
        widget.shift.status == ShiftStatus.fullyCompleted ||
        widget.shift.status == ShiftStatus.partiallyCompleted;
  }

  // Check if shift was missed
  bool get _isMissed {
    final now = DateTime.now();
    return (widget.shift.status == ShiftStatus.missed) ||
        (widget.shift.shiftEnd.isBefore(now) &&
            widget.shift.status == ShiftStatus.scheduled &&
            _timesheetEntry == null);
  }

  Future<void> _handleClockIn() async {
    setState(() => _isClockingIn = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');

      // Get location
      final location = await LocationService.getCurrentLocation();
      if (location == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to get location. Please enable location services.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Clock in
      final result = await ShiftTimesheetService.clockInToShift(
        user.uid,
        widget.shift.id,
        location: location,
        platform: 'mobile',
      );

      if (result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Clocked in successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
          widget.onRefresh?.call();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to clock in'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isClockingIn = false);
    }
  }

  Future<void> _handleClockOut() async {
    setState(() => _isClockingOut = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');

      // Get location
      final location = await LocationService.getCurrentLocation();
      if (location == null) {
      if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to get location. Please enable location services.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Clock out
      final result = await ShiftTimesheetService.clockOutFromShift(
        user.uid,
        widget.shift.id,
        location: location,
      );

      if (result['success'] == true) {
        if (mounted) {
          Navigator.pop(context); // Close the shift details dialog

          // Extract timesheetId from the result
          // The service returns 'timesheetEntry' with 'documentId' inside
          final timesheetEntry = result['timesheetEntry'] as Map<String, dynamic>?;
          final timesheetId = timesheetEntry?['documentId'] ?? _timesheetEntry?['id'];
          
          debugPrint('🕐 Clock-out successful. TimesheetId: $timesheetId');

          // Navigate to the ACTUAL Readiness Form from the database
          // This uses the same form that appears in "Available Forms"
          if (timesheetId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FormScreen(
                  timesheetId: timesheetId,
                  shiftId: widget.shift.id,
                  autoSelectFormId: ShiftFormService.readinessFormId, // The actual form ID
                ),
              ),
            ).then((_) {
              // Refresh after returning from form
              widget.onRefresh?.call();
            });
          } else {
            // If no timesheetId, still refresh
            widget.onRefresh?.call();
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to clock out'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isClockingOut = false);
      }
    }

  void _showEditTimesheetDialog(String timesheetId) {
    if (_timesheetEntry == null) return;
    
    showDialog(
      context: context,
      builder: (context) => EditTimesheetDialog(
        timesheetId: timesheetId,
        timesheetData: Map<String, dynamic>.from(_timesheetEntry!),
        onUpdated: () {
          // Reload timesheet data after edit
          _loadDetails();
          widget.onRefresh?.call();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 750),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                          _buildStatusBanner(),
                          const SizedBox(height: 20),
                          _buildShiftInfoSection(),
                          const SizedBox(height: 20),
                          _buildParticipantsSection(),
                          const SizedBox(height: 20),
                          _buildTimesheetSection(),
                          const SizedBox(height: 20),
                          _buildApprovalStatusSection(),
                          const SizedBox(height: 20),
                          _buildFormSection(),
                  ],
                ),
              ),
            ),
            _buildFooterActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0386FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.event_note, color: Color(0xFF0386FF), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shift Details',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                Text(
                  widget.shift.displayName,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF64748B)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    Color color;
    String label;
    IconData icon;
    String subtitle = '';

    if (_isActive) {
      color = const Color(0xFF10B981);
      label = "In Progress";
      icon = Icons.play_circle_fill;
      subtitle = "You are currently clocked in";
    } else if (_isCompleted) {
      color = const Color(0xFF8B5CF6);
      label = "Completed";
      icon = Icons.check_circle;
      subtitle = "This shift has been completed";
    } else if (_isMissed) {
      color = const Color(0xFFEF4444);
      label = "Missed";
      icon = Icons.cancel;
      subtitle = "This shift was not attended";
    } else if (_canClockInNow) {
      color = const Color(0xFF10B981);
      label = "Ready to Start";
      icon = Icons.login;
      subtitle = "You can clock in now!";
    } else if (_isUpcoming) {
      color = const Color(0xFF0386FF);
      label = "Upcoming";
      icon = Icons.schedule;
      final timeUntil = widget.shift.shiftStart.difference(DateTime.now());
      if (timeUntil.inDays > 0) {
        subtitle = "Starts in ${timeUntil.inDays} day${timeUntil.inDays > 1 ? 's' : ''}";
      } else if (timeUntil.inHours > 0) {
        subtitle = "Starts in ${timeUntil.inHours} hour${timeUntil.inHours > 1 ? 's' : ''}";
      } else {
        subtitle = "Starts in ${timeUntil.inMinutes} minute${timeUntil.inMinutes > 1 ? 's' : ''}";
      }
    } else {
      color = const Color(0xFF64748B);
      label = widget.shift.status.name.toUpperCase();
      icon = Icons.info_outline;
    }

    return Container(
      padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
        color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
                  ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                    style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                    ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: color.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftInfoSection() {
    final duration = widget.shift.shiftEnd.difference(widget.shift.shiftStart);
    final hours = duration.inMinutes / 60.0;

    return _buildSection(
      title: "Schedule Information",
      icon: Icons.calendar_today_outlined,
      children: [
        _detailRow("Date", DateFormat('EEEE, MMMM d, yyyy').format(widget.shift.shiftStart)),
        _detailRow("Time", "${DateFormat('h:mm a').format(widget.shift.shiftStart)} - ${DateFormat('h:mm a').format(widget.shift.shiftEnd)}"),
        _detailRow("Duration", "${hours.toStringAsFixed(1)} hours"),
        _detailRow("Subject", widget.shift.effectiveSubjectDisplayName),
        if (widget.shift.hourlyRate > 0)
          _detailRow("Hourly Rate", "\$${widget.shift.hourlyRate.toStringAsFixed(2)}/hr"),
        if (widget.shift.notes != null && widget.shift.notes!.isNotEmpty)
          _detailRow("Notes", widget.shift.notes!),
      ],
    );
  }

  Widget _buildParticipantsSection() {
    return _buildSection(
      title: "Participants",
      icon: Icons.people_outline,
      children: [
        _detailRow("Teacher", widget.shift.teacherName),
        if (widget.shift.studentNames.isNotEmpty)
          _detailRow(
            "Students",
            widget.shift.studentNames.length == 1
                ? widget.shift.studentNames.first
                : "${widget.shift.studentNames.length} students",
          ),
        if (widget.shift.studentNames.length > 1)
          Padding(
            padding: const EdgeInsets.only(left: 24, top: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: widget.shift.studentNames.map((name) {
                return Chip(
                  label: Text(name, style: GoogleFonts.inter(fontSize: 12)),
                  backgroundColor: const Color(0xFFF1F5F9),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
        ),
      ],
    );
  }

  Widget _buildTimesheetSection() {
    // 1. If we have a timesheet entry, ALWAYS show it
    if (_timesheetEntry != null) {
      // Support both field naming conventions
      final clockIn = _timesheetEntry!['clock_in_time'] ?? _timesheetEntry!['clock_in_timestamp'];
      
      if (clockIn != null && clockIn is Timestamp) {
        final start = clockIn.toDate();
        
        // Support both field naming conventions for clock out
        final clockOutRaw = _timesheetEntry!['clock_out_time'] ?? _timesheetEntry!['clock_out_timestamp'];
        final end = clockOutRaw != null && clockOutRaw is Timestamp ? clockOutRaw.toDate() : null;

    // Check if timesheet is completed (has clock-out time)
    final isCompleted = end != null;
    final timesheetId = _timesheetEntry!['id'] as String?;
    
    return _buildSection(
          title: "Timesheet Record",
          icon: Icons.access_time,
          children: [
            _detailRow("Clock In", DateFormat('h:mm a').format(start)),
            _detailRow("Clock Out", end != null ? DateFormat('h:mm a').format(end) : "Still active"),
            if (end != null) ...[
              _detailRow("Worked", "${end.difference(start).inMinutes} minutes"),
              if (_timesheetEntry!['reported_hours'] != null)
                _detailRow("Reported Hours", "${_timesheetEntry!['reported_hours']} hrs"),
            ],
            // Add Edit button for completed timesheets
            if (isCompleted && timesheetId != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showEditTimesheetDialog(timesheetId),
                  icon: const Icon(Icons.edit, size: 18),
                  label: Text(
                    "Edit Timesheet",
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0386FF),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    side: const BorderSide(color: Color(0xFF0386FF)),
                  ),
                ),
              ),
            ],
      ],
    );
  }
    }

    // 2. If no timesheet, show warning ONLY if it should exist (past/completed)
    final now = DateTime.now();
    // Check if shift is past its end time
    final isPast = widget.shift.shiftEnd.isBefore(now);
    // Check if shift is marked as completed/missed or is past due
    final shouldHaveTimesheet = _isCompleted || _isMissed || isPast;
    
    // Only show warning if it should have a timesheet but doesn't (and isn't active)
    if (shouldHaveTimesheet && !_isActive && !_canClockInNow && !_isUpcoming) {
      return Container(
        padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFCA5A5)),
          ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 24),
            const SizedBox(width: 12),
            Expanded(
          child: Text(
                "No timesheet record found for this past shift.",
            style: GoogleFonts.inter(
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFDC2626),
            ),
          ),
        ),
      ],
        ),
      );
    }
    
    return const SizedBox.shrink();
  }

  // Approval status and earnings section
  Widget _buildApprovalStatusSection() {
    // Only show if there's a timesheet entry
    if (_timesheetEntry == null) return const SizedBox.shrink();
    
    final status = (_timesheetEntry!['status'] as String?) ?? 'pending';
    final approvedBy = _timesheetEntry!['approved_by'] as String?;
    final approvedAt = _timesheetEntry!['approved_at'] as Timestamp?;
    final isEdited = _timesheetEntry!['is_edited'] as bool? ?? false;
    final editApproved = _timesheetEntry!['edit_approved'] as bool? ?? false;
    
    // Calculate earnings
    final clockIn = _timesheetEntry!['clock_in_time'] ?? _timesheetEntry!['clock_in_timestamp'];
    final clockOut = _timesheetEntry!['clock_out_time'] ?? _timesheetEntry!['clock_out_timestamp'];
    final hourlyRate = (widget.shift.hourlyRate > 0) 
        ? widget.shift.hourlyRate 
        : (_timesheetEntry!['hourly_rate'] as num?)?.toDouble() ?? 15.0;
    
    double hoursWorked = 0;
    double earnings = 0;
    
    if (clockIn != null && clockOut != null && clockIn is Timestamp && clockOut is Timestamp) {
      final duration = clockOut.toDate().difference(clockIn.toDate());
      hoursWorked = duration.inMinutes / 60.0;
      earnings = hoursWorked * hourlyRate;
    }
    
    // Determine status display
    Color statusColor;
    IconData statusIcon;
    String statusText;
    String statusSubtitle = '';
    
    switch (status.toLowerCase()) {
      case 'approved':
        statusColor = const Color(0xFF10B981);
        statusIcon = Icons.check_circle;
        statusText = 'Approved';
        if (approvedAt != null) {
          statusSubtitle = 'Approved on ${DateFormat('MMM d, yyyy').format(approvedAt.toDate())}';
        }
        break;
      case 'paid':
        statusColor = const Color(0xFF059669);
        statusIcon = Icons.payments;
        statusText = 'Paid';
        statusSubtitle = 'Payment processed';
        break;
      case 'rejected':
        statusColor = const Color(0xFFEF4444);
        statusIcon = Icons.cancel;
        statusText = 'Rejected';
        statusSubtitle = 'Please review and resubmit';
        break;
      default: // pending
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.pending;
        statusText = 'Pending Approval';
        statusSubtitle = 'Awaiting admin review';
    }
    
    // Check for edit status
    if (isEdited && !editApproved) {
      statusColor = const Color(0xFF8B5CF6);
      statusIcon = Icons.edit_note;
      statusText = 'Edit Pending';
      statusSubtitle = 'Your edit is awaiting approval';
    }
    
    return _buildSection(
      title: "Approval & Earnings",
      icon: Icons.verified,
      children: [
        // Status badge
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                    if (statusSubtitle.isNotEmpty)
                      Text(
                        statusSubtitle,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: statusColor.withOpacity(0.8),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Earnings card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF0386FF).withOpacity(0.1),
                const Color(0xFF10B981).withOpacity(0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estimated Earnings',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${earnings.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (status == 'approved' || status == 'paid') 
                          ? const Color(0xFF10B981).withOpacity(0.2)
                          : const Color(0xFFF59E0B).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      (status == 'approved' || status == 'paid') 
                          ? Icons.check_circle 
                          : Icons.schedule,
                      color: (status == 'approved' || status == 'paid') 
                          ? const Color(0xFF10B981) 
                          : const Color(0xFFF59E0B),
                      size: 28,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildEarningDetail(
                    label: 'Hours',
                    value: '${hoursWorked.toStringAsFixed(1)}h',
                    icon: Icons.access_time,
                  ),
                  _buildEarningDetail(
                    label: 'Rate',
                    value: '\$${hourlyRate.toStringAsFixed(2)}/hr',
                    icon: Icons.attach_money,
                  ),
                  _buildEarningDetail(
                    label: 'Status',
                    value: status == 'approved' || status == 'paid' ? '✓ Confirmed' : 'Pending',
                    icon: (status == 'approved' || status == 'paid') 
                        ? Icons.verified 
                        : Icons.pending,
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Manager notes if available
        if (_timesheetEntry!['manager_notes'] != null && 
            (_timesheetEntry!['manager_notes'] as String).isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.comment, size: 18, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Manager Notes',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _timesheetEntry!['manager_notes'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
  
  Widget _buildEarningDetail({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF64748B)),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildFormSection() {
    final isReportSubmitted = _formResponse != null;
    
    bool hasTimesheet = false;
    if (_timesheetEntry != null) {
      final clockOut = _timesheetEntry!['clock_out_time'] ?? _timesheetEntry!['clock_out_timestamp'];
      hasTimesheet = clockOut != null;
    }

    if (isReportSubmitted) {
      // Show submitted form info
    return Container(
        padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Row(
              children: [
                const Icon(Icons.assignment_turned_in, color: Color(0xFF15803D), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                Text(
                        "Class Report Submitted",
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                          color: const Color(0xFF15803D),
                  ),
                ),
                      if (_formResponse!['reportedHours'] != null)
                        Text(
                          "Hours Logged: ${_formResponse!['reportedHours']} hrs",
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF166534),
                          ),
                        ),
                    ],
            ),
          ),
        ],
      ),
            // Show form responses if available
            if (_formResponse!['responses'] != null) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              ...(_formResponse!['responses'] as Map<String, dynamic>).entries.map((entry) {
                if (entry.value == null || entry.value.toString().isEmpty) {
                  return const SizedBox.shrink();
                }
    return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
            child: Text(
                    "${_formatFieldName(entry.key)}: ${entry.value}",
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF4B5563)),
                  ),
                );
              }).toList(),
            ],
          ],
        ),
      );
    } else if (hasTimesheet) {
      // Shift done but no report - show button to fill the ACTUAL form from database
      return Container(
            padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFCD34D)),
              ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 24),
                const SizedBox(width: 12),
          Expanded(
            child: Text(
                    "Class Report Not Submitted",
              style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFD97706),
              ),
            ),
          ),
        ],
      ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Navigate to the ACTUAL Readiness Form from the database
                  Navigator.pop(context); // Close the dialog first
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FormScreen(
                        timesheetId: _timesheetEntry!['id'],
                        shiftId: widget.shift.id,
                        autoSelectFormId: ShiftFormService.readinessFormId, // The actual form ID
                      ),
                    ),
                  ).then((_) {
                    // Refresh after returning from form
                    widget.onRefresh?.call();
                  });
                },
                icon: const Icon(Icons.assignment),
                label: const Text("Fill Class Report Now"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
            ),
          ),
        ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  String _formatFieldName(String fieldName) {
    // Check if we have a simplified label for this field ID
    if (_simplifiedLabels.containsKey(fieldName)) {
      return _simplifiedLabels[fieldName]!;
    }

    // Fallback to formatting the key if it's not in our map
    return fieldName
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '')
        .join(' ');
    }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
              children: [
            Icon(icon, size: 16, color: const Color(0xFF64748B)),
                const SizedBox(width: 8),
          Text(
                  title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
            ),
          ),
              ],
            ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
            padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
            style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
          style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
        ),
      );
    }

  Widget _buildFooterActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Row(
        children: [
          // Close button
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Text(
                "Close",
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
            ),
          ),
            ),
          ),

          // Clock In/Out or Claim button
          if (_canClockInNow && !_isActive) ...[
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _isClockingIn ? null : _handleClockIn,
                icon: _isClockingIn
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.login),
                  label: Text(
                  _isClockingIn ? "Clocking In..." : "Clock In",
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    ),
                  ),
          ] else if (_isActive) ...[
                const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _isClockingOut ? null : _handleClockOut,
                icon: _isClockingOut
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.logout),
                  label: Text(
                  _isClockingOut ? "Clocking Out..." : "Clock Out",
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
          ] else if (_isUpcoming) ...[
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: null, // Disabled
                icon: const Icon(Icons.schedule),
                  label: Text(
                  "Clock In (Not Yet)",
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF94A3B8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
          ] else if (widget.onClaimShift != null) ...[
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  widget.onClaimShift?.call();
                  },
                icon: const Icon(Icons.add_task),
                  label: Text(
                  "Claim Shift",
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
            ],
        ],
      ),
    );
  }
}

