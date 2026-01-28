import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../../core/models/job_opportunity.dart';
import '../../../core/services/job_board_service.dart';
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

    setState(() => _isAccepting = true);

    try {
      await JobBoardService().acceptJob(widget.job.id, currentUser.uid);
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
            // Age, Subject, Grade
            _buildInfoRow(Icons.person, 'Age: ${widget.job.studentAge.isNotEmpty ? widget.job.studentAge : "N/A"}'),
            _buildInfoRow(Icons.book, 'Subject: ${widget.job.subject}'),
            _buildInfoRow(Icons.school, 'Grade: ${widget.job.gradeLevel}'),
            
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
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: widget.isFilled
                  ? OutlinedButton(
                      onPressed: null,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.jobAlreadyFilled,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.red[700],
                        ),
                      ),
                    )
                  : ElevatedButton(
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
                              AppLocalizations.of(context)!.jobAcceptStudent,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
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
                            AppLocalizations.of(context)!.slotStudenttzabbr,
                            style: GoogleFonts.inter(
                              color: Colors.grey[600],
                              fontSize: 12,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppLocalizations.of(context)!.convertedslotTeachertzabbr,
                            style: GoogleFonts.inter(
                              color: const Color(0xff1E40AF),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ] else
                          Text(
                            AppLocalizations.of(context)!.slotStudenttzabbr,
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
