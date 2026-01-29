import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../../core/models/job_opportunity.dart';
import '../../../core/models/teaching_shift.dart';
import '../../../core/services/job_board_service.dart';
import '../../../core/services/shift_service.dart';
import '../../../core/services/timezone_service.dart';
import '../../../core/utils/timezone_utils.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class TeacherJobBoardScreen extends StatelessWidget {
  const TeacherJobBoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.jobNewStudentOpportunities,
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xff111827),
                  ),
                ),
                Text(
                  AppLocalizations.of(context)!.jobAcceptNewStudents,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xff6B7280),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<JobOpportunity>>(
              stream: JobBoardService().getAllJobs(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text(AppLocalizations.of(context)!.commonErrorWithDetails(snapshot.error ?? 'Unknown error')));
                }

                final allJobs = snapshot.data ?? [];
                final openJobs = allJobs.where((j) => j.status == 'open').toList();
                final filledJobs = allJobs.where((j) => j.status == 'accepted').toList();

                if (openJobs.isEmpty && filledJobs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_turned_in, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(context)!.jobNoOpportunities,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: openJobs.length + (filledJobs.isNotEmpty ? filledJobs.length + 1 : 0),
                  itemBuilder: (context, index) {
                    // Show filled jobs section header
                    if (index == openJobs.length && filledJobs.isNotEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16, top: 8),
                        child: Text(
                          AppLocalizations.of(context)!.jobFilledOpportunities,
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.red[700],
                          ),
                        ),
                      );
                    }
                    
                    // Show filled jobs
                    if (index > openJobs.length) {
                      final filledIndex = index - openJobs.length - 1;
                      return _JobCard(job: filledJobs[filledIndex], isFilled: true);
                    }
                    
                    // Show open jobs
                    return _JobCard(job: openJobs[index], isFilled: false);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _JobCard extends StatefulWidget {
  final JobOpportunity job;
  final bool isFilled;

  const _JobCard({required this.job, this.isFilled = false});

  @override
  State<_JobCard> createState() => _JobCardState();
}

class _JobCardState extends State<_JobCard> {
  bool _isAccepting = false;
  bool _isWithdrawing = false;
  String? _teacherTimezone;
  bool _isLoadingTimezone = true;

  @override
  void initState() {
    super.initState();
    // Initialize timezone database once when the widget is first created
    TimezoneUtils.initializeTimezones();
    _loadTeacherTimezone();
  }

  Future<void> _loadTeacherTimezone() async {
    try {
      final timezone = await TimezoneService.getCurrentUserTimezone();
      if (mounted) {
        setState(() {
          _teacherTimezone = timezone;
          _isLoadingTimezone = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _teacherTimezone = 'UTC';
          _isLoadingTimezone = false;
        });
      }
    }
  }

  /// Convert a time slot from student's timezone to teacher's timezone
  String _convertTimeSlot(String timeSlot, String studentTz, String teacherTz) {
    if (studentTz.isEmpty || teacherTz.isEmpty || studentTz == teacherTz) {
      return timeSlot; // No conversion needed
    }

    try {
      // Parse time slot (e.g., "10:00 AM - 11:00 AM")
      final parts = timeSlot.split(' - ');
      if (parts.length != 2) return timeSlot; // Invalid format

      final startTimeStr = parts[0].trim();
      final endTimeStr = parts[1].trim();

      // Parse start time
      final startTime = _parseTimeString(startTimeStr);
      if (startTime == null) return timeSlot;

      // Parse end time
      final endTime = _parseTimeString(endTimeStr);
      if (endTime == null) return timeSlot;

      // Use today's date for conversion (we only care about the time)
      final today = DateTime.now();
      final studentStart = tz.TZDateTime(
        tz.getLocation(studentTz),
        today.year,
        today.month,
        today.day,
        startTime.hour,
        startTime.minute,
      );

      final studentEnd = tz.TZDateTime(
        tz.getLocation(studentTz),
        today.year,
        today.month,
        today.day,
        endTime.hour,
        endTime.minute,
      );

      // Convert to teacher's timezone
      final teacherLocation = tz.getLocation(teacherTz);
      final teacherStart = tz.TZDateTime.from(studentStart, teacherLocation);
      final teacherEnd = tz.TZDateTime.from(studentEnd, teacherLocation);

      // Format back to "h:mm a" format
      final formatter = DateFormat('h:mm a');
      final convertedStart = formatter.format(teacherStart);
      final convertedEnd = formatter.format(teacherEnd);

      return '$convertedStart - $convertedEnd';
    } catch (e) {
      // If conversion fails, return original
      return timeSlot;
    }
  }

  /// Parse time string like "10:00 AM" to {hour: 10, minute: 0}
  ({int hour, int minute})? _parseTimeString(String timeStr) {
    try {
      final match = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)', caseSensitive: false).firstMatch(timeStr);
      if (match == null) return null;

      var hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      final period = match.group(3)!.toUpperCase();

      if (period == 'PM' && hour < 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;

      return (hour: hour, minute: minute);
    } catch (e) {
      return null;
    }
  }

  /// Get timezone abbreviation
  String _getTimezoneAbbr(String timezoneId) {
    try {
      return TimezoneUtils.getTimezoneAbbreviation(timezoneId);
    } catch (e) {
      return timezoneId.split('/').last;
    }
  }

  Future<void> _acceptJob() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    // Use job timezone when teacher TZ not loaded so conflict detection matches "Available Times (…)" 
    final effectiveTz = (_teacherTimezone != null && _teacherTimezone!.isNotEmpty && _teacherTimezone != 'UTC')
        ? _teacherTimezone!
        : (widget.job.timeZone.isNotEmpty ? widget.job.timeZone : 'UTC');
    // Use a full-height modal sheet so "Choose times" is obvious and visible on mobile
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        maxChildSize: 0.98,
        minChildSize: 0.5,
        expand: false,
        builder: (context, _) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: _TimeSelectionDialog(
                  job: widget.job,
                  teacherTimezone: effectiveTz,
                  teacherId: currentUser.uid,
                  inModalSheet: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    
    // User cancelled
    if (result == null) return;

    // Ensure we send the teacher's chosen times (from conflict picker or initial suggestion)
    final raw = result['selectedTimes'];
    final Map<String, String>? selectedTimes = (raw != null && raw is Map)
        ? Map<String, String>.from(raw)
        : null;

    setState(() => _isAccepting = true);

    try {
      // Accept with selected time preferences
      await JobBoardService().acceptJob(
        widget.job.id,
        currentUser.uid,
        selectedTimes: selectedTimes,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.jobAcceptedSuccess),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorE), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isAccepting = false);
    }
  }

  Future<void> _withdrawFromJob() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Withdraw from this student?',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'This will re-broadcast the opportunity to other teachers. You can accept it again if it\'s still available.',
          style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[700]),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Withdraw', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;

    setState(() => _isWithdrawing = true);

    try {
      await JobBoardService().withdrawFromJob(widget.job.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have withdrawn. The job is now available for other teachers.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isWithdrawing = false);
    }
  }
  
  /// Check if current user is the one who accepted this job
  bool get _isMyAcceptedJob {
    final currentUser = FirebaseAuth.instance.currentUser;
    return currentUser != null && widget.job.acceptedByTeacherId == currentUser.uid;
  }

  @override
  Widget build(BuildContext context) {
    final studentTz = widget.job.timeZone.isNotEmpty ? widget.job.timeZone : 'UTC';
    final teacherTz = _teacherTimezone ?? 'UTC';
    final needsConversion = studentTz != teacherTz && !_isLoadingTimezone;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: widget.isFilled 
          ? const BorderSide(color: Colors.red, width: 2)
          : BorderSide.none,
      ),
      elevation: 2,
      color: widget.isFilled ? Colors.red[50] : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: widget.isFilled 
                            ? Colors.red[100] 
                            : const Color(0xffEFF6FF),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: widget.isFilled 
                              ? Colors.red[300]! 
                              : const Color(0xffBFDBFE),
                          ),
                        ),
                        child: Text(
                          widget.job.subject,
                          style: GoogleFonts.inter(
                            color: widget.isFilled 
                              ? Colors.red[900] 
                              : const Color(0xff1D4ED8),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.isFilled)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.jobFilled,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  DateFormat('MMM d').format(widget.job.createdAt),
                  style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Student Name
            Text(
              widget.job.studentName.isNotEmpty ? widget.job.studentName : 'Student',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xff111827),
              ),
            ),
            const SizedBox(height: 12),
            // Age, Subject, Grade, Duration, Class Type
            _buildInfoRow(Icons.person, 'Age: ${widget.job.studentAge.isNotEmpty ? widget.job.studentAge : "N/A"}'),
            _buildInfoRow(Icons.book, 'Subject: ${widget.job.subject}'),
            _buildInfoRow(Icons.school, 'Grade: ${widget.job.gradeLevel}'),
            
            // Session Duration with visual badge
            Row(
              children: [
                Icon(Icons.timer_outlined, size: 16, color: Colors.grey[400]),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xffFEF3C7),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xffF59E0B)),
                  ),
                  child: Text(
                    widget.job.durationDisplay,
                    style: GoogleFonts.inter(
                      color: const Color(0xff92400E),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (widget.job.classType != null && widget.job.classType!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xffEDE9FE),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xff8B5CF6)),
                    ),
                    child: Text(
                      widget.job.classType!,
                      style: GoogleFonts.inter(
                        color: const Color(0xff5B21B6),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            
            // Timezone Info with Conversion
            if (needsConversion) ...[
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xffEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xffBFDBFE)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.public, size: 16, color: Color(0xff3B82F6)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Student timezone: ${_getTimezoneAbbr(studentTz)} → Your timezone: ${_getTimezoneAbbr(teacherTz)}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xff1E40AF),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              _buildInfoRow(Icons.public, 'Timezone: ${_getTimezoneAbbr(studentTz)}'),
            ],
            
            const SizedBox(height: 8),
            _buildInfoRow(Icons.calendar_today, 'Days: ${widget.job.days.join(", ")}'),
            
            // Time Slots with Conversion
            if (_isLoadingTimezone)
              _buildInfoRow(Icons.access_time, 'Times: ${widget.job.timeSlots.join(", ")}')
            else if (needsConversion)
              _buildTimeSlotsWithConversion()
            else
              _buildInfoRow(Icons.access_time, 'Times: ${widget.job.timeSlots.join(", ")}'),
            
            if (widget.isFilled && widget.job.acceptedAt != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(Icons.check_circle, 'Accepted on ${DateFormat('MMM d, yyyy').format(widget.job.acceptedAt!)}'),
              // Show teacher's selected times if different from original
              if (widget.job.teacherSelectedTimes != null && widget.job.teacherSelectedTimes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xffD1FAE5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xff10B981)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.schedule, size: 14, color: Color(0xff059669)),
                          const SizedBox(width: 6),
                          Text(
                            'Your Selected Times:',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xff065F46),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ...widget.job.teacherSelectedTimes!.entries.map((e) => Padding(
                        padding: const EdgeInsets.only(left: 20, top: 2),
                        child: Text(
                          '${e.key}: ${e.value}',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xff047857)),
                        ),
                      )),
                    ],
                  ),
                ),
              ],
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: widget.isFilled ? 48 : null,
              child: widget.isFilled
                  ? _isMyAcceptedJob
                      // Teacher can withdraw from their own accepted jobs
                      ? ElevatedButton.icon(
                          onPressed: _isWithdrawing ? null : _withdrawFromJob,
                          icon: _isWithdrawing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.undo_rounded, size: 18),
                          label: Text(
                            _isWithdrawing ? 'Withdrawing...' : 'Withdraw & Re-broadcast',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange[600],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        )
                      // Job filled by another teacher
                      : OutlinedButton(
                          onPressed: null,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            AppLocalizations.of(context)?.jobAlreadyFilled ?? 'Filled by Another Teacher',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: Colors.red[700],
                            ),
                          ),
                        )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 48,
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isAccepting ? null : _acceptJob,
                            style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff10B981),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isAccepting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Text(
                                  'Choose times & accept',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tap to pick your preferred time for each day',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xff6B7280),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSlotsWithConversion() {
    final studentTz = widget.job.timeZone.isNotEmpty ? widget.job.timeZone : 'UTC';
    final teacherTz = _teacherTimezone ?? 'UTC';
    final studentTzAbbr = _getTimezoneAbbr(studentTz);
    final teacherTzAbbr = _getTimezoneAbbr(teacherTz);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time, size: 16, color: Colors.grey[400]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.jobPreferredTimes,
                  style: GoogleFonts.inter(
                    color: const Color(0xff4B5563),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...widget.job.timeSlots.map((slot) {
            final convertedSlot = _convertTimeSlot(slot, studentTz, teacherTz);
            final isConverted = convertedSlot != slot;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 6, right: 8),
                    decoration: BoxDecoration(
                      color: isConverted ? const Color(0xff3B82F6) : Colors.grey[400],
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isConverted) ...[
                          Text(
                            '$slot ($studentTzAbbr)',
                            style: GoogleFonts.inter(
                              color: Colors.grey[600],
                              fontSize: 12,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$convertedSlot ($teacherTzAbbr)',
                            style: GoogleFonts.inter(
                              color: const Color(0xff1E40AF),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ] else
                          Text(
                            slot,
                            style: GoogleFonts.inter(
                              color: const Color(0xff4B5563),
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[400]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(color: const Color(0xff4B5563), fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// Busy range in minutes from midnight (for conflict detection)
class _BusyRange {
  final int startMinutes;
  final int endMinutes;
  _BusyRange(this.startMinutes, this.endMinutes);
}

/// Dialog/sheet for teachers to select specific times for each day.
/// When [inModalSheet] is true, builds content only (no Dialog) for use in a bottom sheet.
class _TimeSelectionDialog extends StatefulWidget {
  final JobOpportunity job;
  final String teacherTimezone;
  final String? teacherId;
  final bool inModalSheet;

  const _TimeSelectionDialog({
    required this.job,
    required this.teacherTimezone,
    this.teacherId,
    this.inModalSheet = false,
  });

  @override
  State<_TimeSelectionDialog> createState() => _TimeSelectionDialogState();
}

class _TimeSelectionDialogState extends State<_TimeSelectionDialog> {
  // Map of day -> selected time slot
  final Map<String, String> _selectedTimes = {};
  bool _loadingShifts = true;
  Map<String, List<_BusyRange>> _busyRangesByDay = {};

  static const List<String> _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    // Initialize with first available time slot for each day
    for (final day in widget.job.days) {
      if (widget.job.timeSlots.isNotEmpty) {
        _selectedTimes[day] = widget.job.timeSlots.first;
      }
    }
    if (widget.teacherId != null) {
      _loadTeacherShifts();
    } else {
      _loadingShifts = false;
    }
  }

  Future<void> _loadTeacherShifts() async {
    final tid = widget.teacherId;
    if (tid == null) {
      setState(() => _loadingShifts = false);
      return;
    }
    try {
      TimezoneUtils.initializeTimezones();
      final tzStr = widget.teacherTimezone;
      if (tzStr.isEmpty) {
        debugPrint('JOB_BOARD: teacherTimezone is empty, skipping conflict load');
        if (mounted) setState(() => _loadingShifts = false);
        return;
      }
      // Use same stream as teacher calendar so we see the same shifts
      final shifts = await ShiftService.getTeacherShifts(tid)
          .first
          .timeout(const Duration(seconds: 15), onTimeout: () => <TeachingShift>[]);
      
      debugPrint('JOB_BOARD: loaded ${shifts.length} shifts for teacher $tid, tz=$tzStr');
      
      final Map<String, List<_BusyRange>> byDay = {};
      final now = DateTime.now();
      
      // 1. Process Shifts
      try {
        final loc = tz.getLocation(tzStr);
        int added = 0;
        for (final s in shifts) {
          if (s.shiftEnd.isBefore(now)) continue;
          
          final utcStart = DateTime.fromMillisecondsSinceEpoch(s.shiftStart.millisecondsSinceEpoch, isUtc: true);
          final utcEnd = DateTime.fromMillisecondsSinceEpoch(s.shiftEnd.millisecondsSinceEpoch, isUtc: true);
          final startLocal = tz.TZDateTime.from(utcStart, loc);
          final endLocal = tz.TZDateTime.from(utcEnd, loc);
          
          final weekdayIndex = startLocal.weekday - 1;
          if (weekdayIndex < 0 || weekdayIndex >= _dayNames.length) continue;
          
          final dayStr = _dayNames[weekdayIndex];
          final startM = startLocal.hour * 60 + startLocal.minute;
          var endM = endLocal.hour * 60 + endLocal.minute;
          
          if (endLocal.isBefore(startLocal) || (startLocal.day != endLocal.day && endM < startM)) {
            endM = 24 * 60;
          } else if (startLocal.day != endLocal.day) {
            endM = 24 * 60;
          }
          
          byDay.putIfAbsent(dayStr, () => []).add(_BusyRange(startM, endM));
          added++;
        }
        debugPrint('JOB_BOARD: added $added future shift ranges; byDay keys: ${byDay.keys.join(",")}');
        for (final k in byDay.keys) {
          final r = byDay[k]!;
          debugPrint('JOB_BOARD:   $k: ${r.map((b) => "${b.startMinutes}-${b.endMinutes}").join(", ")}');
        }
        
        // 2. Process Accepted Jobs
        final acceptedJobs = await JobBoardService().getAcceptedJobsForTeacher(tid);
        debugPrint('JOB_BOARD: ${acceptedJobs.length} accepted jobs for teacher');
        for (final job in acceptedJobs) {
          final jobTz = job.timeZone.isNotEmpty ? job.timeZone : 'UTC';
          final dayToSlot = Map<String, String>.from(job.teacherSelectedTimes ?? {});
          if (dayToSlot.isEmpty && job.days.isNotEmpty && job.timeSlots.isNotEmpty) {
            for (final d in job.days) {
              dayToSlot[d] = job.timeSlots.first;
            }
          }
          for (final entry in dayToSlot.entries) {
            final tr = _slotToTeacherRange(
              entry.key,
              entry.value,
              jobTz,
              widget.teacherTimezone,
            );
            if (tr != null) {
              byDay.putIfAbsent(tr.day, () => []).add(_BusyRange(tr.startM, tr.endM));
            }
          }
        }
        
        for (final k in byDay.keys) {
          byDay[k] = _mergeRanges(byDay[k]!);
        }
      } catch (e, st) {
        debugPrint('JOB_BOARD: Error processing shifts/jobs: $e');
        debugPrint('JOB_BOARD: $st');
      }
      
      if (mounted) {
        setState(() {
          _busyRangesByDay = byDay;
          _loadingShifts = false;
        });
      }
    } catch (e, st) {
      debugPrint('JOB_BOARD: Error loading teacher shifts: $e');
      debugPrint('JOB_BOARD: $st');
      if (mounted) setState(() => _loadingShifts = false);
    }
  }

  /// Returns (teacherDayStr, startMinutes, endMinutes) or null if parse fails.
  static ({String day, int startM, int endM})? _slotToTeacherRange(
    String dayStr,
    String slotStr,
    String studentTz,
    String teacherTz,
  ) {
    final parts = slotStr.split(' - ');
    if (parts.length != 2) return null;
    final startMatch = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)', caseSensitive: false).firstMatch(parts[0].trim());
    final endMatch = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)', caseSensitive: false).firstMatch(parts[1].trim());
    if (startMatch == null || endMatch == null) return null;
    var sh = int.parse(startMatch.group(1)!), sm = int.parse(startMatch.group(2)!);
    if (startMatch.group(3)!.toUpperCase() == 'PM' && sh < 12) sh += 12;
    if (startMatch.group(3)!.toUpperCase() == 'AM' && sh == 12) sh = 0;
    var eh = int.parse(endMatch.group(1)!), em = int.parse(endMatch.group(2)!);
    if (endMatch.group(3)!.toUpperCase() == 'PM' && eh < 12) eh += 12;
    if (endMatch.group(3)!.toUpperCase() == 'AM' && eh == 12) eh = 0;
    try {
      final studentLoc = tz.getLocation(studentTz);
      final teacherLoc = tz.getLocation(teacherTz);
      final ref = DateTime.now();
      int weekday = _dayNames.indexOf(dayStr) + 1;
      if (weekday == 0) return null;
      var dayOffset = weekday - ref.weekday;
      if (dayOffset < 0) dayOffset += 7;
      if (dayOffset == 0 && (ref.hour > sh || (ref.hour == sh && ref.minute >= sm))) dayOffset = 7;
      final refDate = ref.add(Duration(days: dayOffset));
      final studentStart = tz.TZDateTime(studentLoc, refDate.year, refDate.month, refDate.day, sh, sm);
      final studentEnd = tz.TZDateTime(studentLoc, refDate.year, refDate.month, refDate.day, eh, em);
      final teacherStart = tz.TZDateTime.from(studentStart, teacherLoc);
      final teacherEnd = tz.TZDateTime.from(studentEnd, teacherLoc);
      final teacherDayStr = _dayNames[teacherStart.weekday - 1];
      final tStartM = teacherStart.hour * 60 + teacherStart.minute;
      var tEndM = teacherEnd.hour * 60 + teacherEnd.minute;
      if (teacherEnd.day != teacherStart.day) tEndM += 24 * 60;
      return (day: teacherDayStr, startM: tStartM, endM: tEndM);
    } catch (_) {
      return null;
    }
  }

  static List<_BusyRange> _mergeRanges(List<_BusyRange> ranges) {
    if (ranges.isEmpty) return [];
    ranges = List.from(ranges)..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    final merged = <_BusyRange>[ranges.first];
    for (var i = 1; i < ranges.length; i++) {
      final r = ranges[i];
      final last = merged.last;
      if (r.startMinutes <= last.endMinutes) {
        merged[merged.length - 1] = _BusyRange(last.startMinutes, last.endMinutes > r.endMinutes ? last.endMinutes : r.endMinutes);
      } else {
        merged.add(r);
      }
    }
    return merged;
  }

  bool _slotConflictsWithTeacher(String day, String slotStr) {
    final parts = slotStr.split(' - ');
    if (parts.length != 2) return false;
    final startMatch = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)', caseSensitive: false).firstMatch(parts[0].trim());
    final endMatch = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)', caseSensitive: false).firstMatch(parts[1].trim());
    if (startMatch == null || endMatch == null) return false;
    var sh = int.parse(startMatch.group(1)!), sm = int.parse(startMatch.group(2)!);
    if (startMatch.group(3)!.toUpperCase() == 'PM' && sh < 12) sh += 12;
    if (startMatch.group(3)!.toUpperCase() == 'AM' && sh == 12) sh = 0;
    var eh = int.parse(endMatch.group(1)!), em = int.parse(endMatch.group(2)!);
    if (endMatch.group(3)!.toUpperCase() == 'PM' && eh < 12) eh += 12;
    if (endMatch.group(3)!.toUpperCase() == 'AM' && eh == 12) eh = 0;
    int startM = sh * 60 + sm, endM = eh * 60 + em;
    final studentTz = widget.job.timeZone.isNotEmpty ? widget.job.timeZone : 'UTC';
    final teacherTz = widget.teacherTimezone;
    if (studentTz == teacherTz) {
      final busy = _busyRangesByDay[day] ?? [];
      final overlap = busy.any((b) => startM < b.endMinutes && endM > b.startMinutes);
      debugPrint('JOB_BOARD: conflict? $day $slotStr => startM=$startM endM=$endM busy=${busy.map((b) => "${b.startMinutes}-${b.endMinutes}").join(",")} => $overlap');
      return overlap;
    }
    try {
      final studentLoc = tz.getLocation(studentTz);
      final teacherLoc = tz.getLocation(teacherTz);
      final ref = DateTime.now();
      int weekday = _dayNames.indexOf(day) + 1;
      if (weekday == 0) return false;
      var dayOffset = weekday - ref.weekday;
      if (dayOffset < 0) dayOffset += 7;
      if (dayOffset == 0 && (ref.hour > sh || (ref.hour == sh && ref.minute >= sm))) dayOffset = 7;
      final refDate = ref.add(Duration(days: dayOffset));
      final studentStart = tz.TZDateTime(studentLoc, refDate.year, refDate.month, refDate.day, sh, sm);
      final studentEnd = tz.TZDateTime(studentLoc, refDate.year, refDate.month, refDate.day, eh, em);
      final teacherStart = tz.TZDateTime.from(studentStart, teacherLoc);
      final teacherEnd = tz.TZDateTime.from(studentEnd, teacherLoc);
      final teacherDayStr = _dayNames[teacherStart.weekday - 1];
      final tStartM = teacherStart.hour * 60 + teacherStart.minute;
      var tEndM = teacherEnd.hour * 60 + teacherEnd.minute;
      // When slot spans midnight in teacher TZ, check both days
      if (teacherEnd.day != teacherStart.day) {
        final nextWeekday = teacherEnd.weekday;
        final nextDayStr = _dayNames[nextWeekday - 1];
        final endMNextDay = teacherEnd.hour * 60 + teacherEnd.minute;
        final busy1 = _busyRangesByDay[teacherDayStr] ?? [];
        for (final b in busy1) {
          if (tStartM < b.endMinutes && (24 * 60) > b.startMinutes) return true;
        }
        final busy2 = _busyRangesByDay[nextDayStr] ?? [];
        for (final b in busy2) {
          if (0 < b.endMinutes && endMNextDay > b.startMinutes) return true;
        }
        return false;
      }
      final busy = _busyRangesByDay[teacherDayStr] ?? [];
      for (final b in busy) {
        if (tStartM < b.endMinutes && tEndM > b.startMinutes) return true;
      }
    } catch (_) {}
    return false;
  }

  /// True if the currently proposed slots (one per day) conflict with the teacher's schedule.
  /// When there is no teacher or we are still loading, returns false (no conflict → show simple accept).
  bool get _hasProposedSlotsConflict {
    if (widget.teacherId == null || _loadingShifts) return false;
    for (final day in widget.job.days) {
      final slot = _selectedTimes[day];
      if (slot != null && _slotConflictsWithTeacher(day, slot)) return true;
    }
    return false;
  }
  
  /// Generate time slots based on the available range
  List<String> _generateTimeSlots(String rangeSlot) {
    // Parse range like "10:00 AM - 2:00 PM" into discrete slots
    final parts = rangeSlot.split(' - ');
    if (parts.length != 2) return [rangeSlot];
    
    try {
      final startTime = _parseTimeString(parts[0].trim());
      final endTime = _parseTimeString(parts[1].trim());
      
      if (startTime == null || endTime == null) return [rangeSlot];
      
      final slots = <String>[];
      var currentHour = startTime.hour;
      var currentMinute = startTime.minute;
      
      // Generate slots based on session duration
      final durationMinutes = _parseDurationMinutes(widget.job.sessionDuration ?? '60 minutes');
      
      while (currentHour < endTime.hour || 
             (currentHour == endTime.hour && currentMinute < endTime.minute)) {
        final startFormatted = _formatTime(currentHour, currentMinute);
        
        // Calculate end time for this slot
        var endHour = currentHour;
        var endMinute = currentMinute + durationMinutes;
        while (endMinute >= 60) {
          endMinute -= 60;
          endHour++;
        }
        
        // Don't go past the end time
        if (endHour > endTime.hour || (endHour == endTime.hour && endMinute > endTime.minute)) {
          break;
        }
        
        final endFormatted = _formatTime(endHour, endMinute);
        slots.add('$startFormatted - $endFormatted');
        
        // Move to next slot
        currentHour = endHour;
        currentMinute = endMinute;
      }
      
      return slots.isEmpty ? [rangeSlot] : slots;
    } catch (e) {
      return [rangeSlot];
    }
  }
  
  int _parseDurationMinutes(String duration) {
    final d = duration.toLowerCase();
    if (d.contains('1 hr 30')) return 90;
    if (d.contains('2 hr 30')) return 150;
    if (d.contains('30 mins')) return 30;
    if (d.contains('1 hr')) return 60;
    if (d.contains('2 hrs')) return 120;
    if (d.contains('3 hrs')) return 180;
    if (d.contains('4 hrs')) return 240;
    final match = RegExp(r'(\d+)').firstMatch(duration);
    return match != null ? int.parse(match.group(1)!) : 60;
  }
  
  ({int hour, int minute})? _parseTimeString(String timeStr) {
    try {
      final match = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)', caseSensitive: false).firstMatch(timeStr);
      if (match == null) return null;

      var hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      final period = match.group(3)!.toUpperCase();

      if (period == 'PM' && hour < 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;

      return (hour: hour, minute: minute);
    } catch (e) {
      return null;
    }
  }
  
  String _formatTime(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  /// Slots when the teacher has no class that day (same duration as the job).
  /// Lets the teacher pick an alternative time and accept subject to admin confirmation.
  List<String> _getFreeSlotsForDay(String day) {
    if (_loadingShifts || _busyRangesByDay.isEmpty) return [];
    final durationMinutes = _parseDurationMinutes(widget.job.sessionDuration ?? '60 minutes');
    const workStart = 6 * 60;   // 6h
    const workEnd = 23 * 60;    // 23h
    const step = 30;            // pas de 30 min
    final busy = _busyRangesByDay[day] ?? [];
    final slots = <String>[];
    for (var startM = workStart; startM + durationMinutes <= workEnd; startM += step) {
      final endM = startM + durationMinutes;
      final overlaps = busy.any((b) => startM < b.endMinutes && endM > b.startMinutes);
      if (overlaps) continue;
      final h0 = startM ~/ 60, m0 = startM % 60;
      final h1 = endM ~/ 60, m1 = endM % 60;
      slots.add('${_formatTime(h0, m0)} - ${_formatTime(h1, m1)}');
    }
    return slots;
  }
  
  @override
  Widget build(BuildContext context) {
    // Fix: generate slots from ALL time ranges (Morning AND Afternoon etc.), not just the first
    final rawSlots = widget.job.timeSlots
        .expand((slotRange) => _generateTimeSlots(slotRange))
        .toList();
    final availableSlots = rawSlots.isNotEmpty
        ? List<String>.from(LinkedHashSet<String>.from(rawSlots))
        : (widget.job.timeSlots.isEmpty ? <String>[] : List<String>.from(widget.job.timeSlots));
    
    final maxDialogHeight = MediaQuery.of(context).size.height * 0.88;
    final content = Container(
      constraints: widget.inModalSheet
          ? const BoxConstraints(maxWidth: 500)
          : BoxConstraints(maxWidth: 500, maxHeight: maxDialogHeight),
      padding: const EdgeInsets.all(24),
      child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xff10B981).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.schedule, color: Color(0xff10B981), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Your Preferred Times',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xff111827),
                        ),
                      ),
                      Text(
                        'Choose specific time slots for each teaching day',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xff6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Scrollable middle section to prevent overflow on small screens
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xffF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person, size: 20, color: Color(0xff6B7280)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${widget.job.studentName} • ${widget.job.subject}',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xff374151),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xffFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xffF59E0B)),
                            ),
                            child: Text(
                              widget.job.durationDisplay,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xff92400E),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_loadingShifts)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xff3B82F6)),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Checking your schedule for conflicts...',
                              style: GoogleFonts.inter(fontSize: 13, color: Color(0xff64748B)),
                            ),
                          ],
                        ),
                      )
                    else if (_hasProposedSlotsConflict) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Slots marked with "You have another class" conflict with your current schedule. Choose a different time for those days.',
                                style: GoogleFonts.inter(fontSize: 12, color: Color(0xff92400E), fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'Available Times (${widget.teacherTimezone})',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xff374151),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Pick one slot per day. Green = you\'re free, orange = you have another class. '
                        'If you pick a different free slot than the student requested, it will be accepted pending admin confirmation.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xff6B7280),
                        ),
                      ),
                      if (widget.inModalSheet && widget.job.days.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              Icon(Icons.swipe_up, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Scroll down to see and pick a time for each day.',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 14),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 120),
                        child: widget.job.days.isEmpty && availableSlots.isNotEmpty
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Pick your preferred time:',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xff374151),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _buildDayTimeSelector('Preferred', availableSlots),
                                ],
                              )
                            : (widget.job.days.isEmpty || availableSlots.isEmpty)
                                ? Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    child: Text(
                                      widget.job.days.isEmpty && availableSlots.isEmpty
                                          ? 'No days or times set for this opportunity. Ask admin to update it.'
                                          : widget.job.days.isEmpty
                                              ? 'No days set. Ask admin to add preferred days.'
                                              : 'No time slots available. Ask admin to add preferred times.',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  )
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: widget.job.days
                                        .map<Widget>((day) {
                                          final freeSlots = _getFreeSlotsForDay(day);
                                          final merged = List<String>.from(
                                            LinkedHashSet<String>.from([...freeSlots, ...availableSlots]),
                                          );
                                          return _buildDayTimeSelector(day, merged);
                                        })
                                        .toList(),
                                  ),
                      ),
                    ]
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No conflicts with your schedule. Accept with the suggested times?',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xff374151),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final conflictingDays = <String>[];
                      for (final e in _selectedTimes.entries) {
                        if (_slotConflictsWithTeacher(e.key, e.value)) {
                          conflictingDays.add(e.key);
                        }
                      }
                      // If there are conflicts, ask for confirmation instead of blocking
                      if (conflictingDays.isNotEmpty) {
                        final shouldProceed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(
                              'Schedule conflict',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                            ),
                            content: Text(
                              'You already have a class on: ${conflictingDays.join(", ")}.\n\nDo you still want to accept this slot?',
                              style: GoogleFonts.inter(),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Accept anyway'),
                              ),
                            ],
                          ),
                        );
                        if (shouldProceed != true || !context.mounted) return;
                      }
                      if (!context.mounted) return;
                      // Return a snapshot so the exact teacher selection is sent to acceptJob
                      Navigator.pop(context, {
                        'selectedTimes': Map<String, String>.from(_selectedTimes),
                      });
                    },
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(
                      'Confirm & Accept',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    if (widget.inModalSheet) return content;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: content,
    );
  }

  Widget _buildDayTimeSelector(String day, List<String> availableSlots) {
    // If we have a selection for this day but it's not in availableSlots, show it so user can keep or change
    final slotsToShow = availableSlots.isNotEmpty
        ? availableSlots
        : (_selectedTimes[day] != null ? [_selectedTimes[day]!] : <String>[]);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xff3B82F6), width: 1.5),
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xffF8FAFC),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xff3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  day,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xff1D4ED8),
                  ),
                ),
              ),
              const Spacer(),
              if (_selectedTimes[day] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xff10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _selectedTimes[day]!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff059669),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Tap a time below to choose for $day:',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xff64748B),
            ),
          ),
          const SizedBox(height: 10),
          slotsToShow.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No time slots available for this day.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              : Wrap(
            spacing: 8,
            runSpacing: 8,
            children: slotsToShow.map((slot) {
              final isSelected = _selectedTimes[day] == slot;
              final isConflict = _slotConflictsWithTeacher(day, slot);
              // Visual feedback: selected+conflict = dark orange, selected+safe = green, unselected+conflict = light orange, unselected+safe = white
              Color bgColor;
              Color borderColor;
              Color textColor;
              if (isSelected) {
                if (isConflict) {
                  bgColor = Colors.orange[800]!;
                  borderColor = Colors.red[900]!;
                  textColor = Colors.white;
                } else {
                  bgColor = const Color(0xff10B981);
                  borderColor = const Color(0xff059669);
                  textColor = Colors.white;
                }
              } else {
                if (isConflict) {
                  bgColor = const Color(0xffFEF3C7);
                  borderColor = const Color(0xffF59E0B);
                  textColor = const Color(0xff92400E);
                } else {
                  bgColor = Colors.white;
                  borderColor = const Color(0xffD1D5DB);
                  textColor = const Color(0xff374151);
                }
              }
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedTimes[day] = slot;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Tooltip(
                  message: isConflict ? 'You have another class at this time' : '',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: bgColor,
                      border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                slot,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: textColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isConflict) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 14,
                                color: isSelected ? Colors.white : Colors.orange[800],
                              ),
                            ],
                          ],
                        ),
                        if (isConflict && !isSelected)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'You have another class',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xffB45309),
                              ),
                            ),
                          ),
                        if (isConflict && isSelected)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'Conflict ignored',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

