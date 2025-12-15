import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../../core/models/job_opportunity.dart';
import '../../../core/services/job_board_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../shift_management/widgets/create_shift_dialog.dart';

class FilledOpportunitiesScreen extends StatefulWidget {
  const FilledOpportunitiesScreen({super.key});

  @override
  State<FilledOpportunitiesScreen> createState() => _FilledOpportunitiesScreenState();
}

class _FilledOpportunitiesScreenState extends State<FilledOpportunitiesScreen> {
  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones(); // Initialize timezone database for conversions
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: StreamBuilder<List<JobOpportunity>>(
              stream: JobBoardService().getAcceptedJobs(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final jobs = snapshot.data ?? [];

                if (jobs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'No filled opportunities yet',
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
                  itemCount: jobs.length,
                  itemBuilder: (context, index) {
                    return _FilledJobCard(job: jobs[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          const Icon(Icons.handshake_rounded, color: Color(0xff10B981), size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filled Opportunities',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xff111827),
                  ),
                ),
                Text(
                  'Finalize schedules for matched students and teachers',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xff6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilledJobCard extends StatefulWidget {
  final JobOpportunity job;

  const _FilledJobCard({required this.job});

  @override
  State<_FilledJobCard> createState() => _FilledJobCardState();
}

class _FilledJobCardState extends State<_FilledJobCard> {
  bool _isLoadingTeacher = false;
  bool _isCreatingStudent = false;
  String? _teacherName;
  String? _teacherEmail;
  String? _teacherTimezone; // We will load this from Firestore

  @override
  void initState() {
    super.initState();
    _loadTeacherInfo();
  }

  Future<void> _loadTeacherInfo() async {
    if (widget.job.acceptedByTeacherId == null) return;
    
    setState(() => _isLoadingTeacher = true);
    try {
      final teacherDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.job.acceptedByTeacherId!)
          .get();
      
      if (teacherDoc.exists) {
        final data = teacherDoc.data() as Map<String, dynamic>;
        setState(() {
          _teacherName = '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim();
          _teacherEmail = data['e-mail'] ?? '';
          // CRITICAL: Get the teacher's timezone from their profile (e.g., "GMT", "Africa/Abidjan")
          _teacherTimezone = data['timezone'] ?? 'UTC'; 
        });
      }
    } catch (e) {
      AppLogger.error('Error loading teacher info: $e');
    } finally {
      if (mounted) setState(() => _isLoadingTeacher = false);
    }
  }

  /// Check if student exists in the system by email (Helper method)
  Future<bool> _checkStudentExists(String email) async {
    try {
      final studentQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('e-mail', isEqualTo: email)
          .where('user_type', isEqualTo: 'student')
          .limit(1)
          .get();
      return studentQuery.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }


  Future<void> _createStudentAccount() async {
    setState(() => _isCreatingStudent = true);
    try {
      final enrollmentDoc = await FirebaseFirestore.instance
          .collection('enrollments')
          .doc(widget.job.enrollmentId)
          .get();
      
      if (!enrollmentDoc.exists) {
        throw Exception('Enrollment not found');
      }

      final enrollmentData = enrollmentDoc.data()!;
      final contact = enrollmentData['contact'] as Map<String, dynamic>? ?? {};
      
      String firstName = '';
      String lastName = '';
      final fullName = widget.job.studentName.trim();
      if (fullName.isNotEmpty) {
        final parts = fullName.split(' ');
        firstName = parts.first;
        if (parts.length > 1) {
          lastName = parts.sublist(1).join(' ');
        }
      }

      final studentData = {
        'firstName': firstName,
        'lastName': lastName,
        'isAdultStudent': widget.job.isAdult,
        'email': contact['email'],
        'phoneNumber': contact['phone'],
        'guardianIds': contact['guardianId'] != null ? [contact['guardianId']] : [],
      };

      final callable = FirebaseFunctions.instance.httpsCallable('createStudentAccount');
      final result = await callable.call(studentData);
      
      if (mounted) {
        final studentCode = result.data['studentCode'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Student Account Created! ID: $studentCode'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating student: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreatingStudent = false);
    }
  }

  Future<void> _createShift() async {
    if (widget.job.acceptedByTeacherId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teacher information not available'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      // 1. Get Enrollment Details (Source of Truth)
      final enrollmentDoc = await FirebaseFirestore.instance
          .collection('enrollments')
          .doc(widget.job.enrollmentId)
          .get();
      
      if (!enrollmentDoc.exists) return;

      final enrollmentData = enrollmentDoc.data() as Map<String, dynamic>;
      final contact = enrollmentData['contact'] as Map<String, dynamic>? ?? {};
      final preferences = enrollmentData['preferences'] as Map<String, dynamic>? ?? {};
      
      // 2. Handle Student Account
      final studentEmail = contact['email'] as String?;
      
      // 3. --- TIMEZONE CONVERSION MAGIC ---
      // Goal: Open the dialog showing the TEACHER'S time, not the student's.
      
      final studentTzName = preferences['timeZone'] ?? widget.job.timeZone ?? 'UTC';
      // Use the teacher's timezone loaded from Firestore, fallback to UTC
      final teacherTzName = _teacherTimezone ?? 'UTC'; 
      
      final rawTimeSlots = preferences['timeSlots'] as List<dynamic>? ?? widget.job.timeSlots;
      final rawDays = preferences['days'] as List<dynamic>? ?? widget.job.days;

      TimeOfDay? initialStartTime;
      
      if (rawTimeSlots != null && rawTimeSlots.isNotEmpty) {
        // Parse "10:00 AM"
        final firstSlot = rawTimeSlots.first.toString().split('-')[0].trim();
        
        try {
          // Parse using a standard format
          final format = DateFormat("h:mm a"); 
          final dt = format.parse(firstSlot); // Note: This creates a naive datetime

          // 1. Create TZ DateTime for Student
          final studentLocation = tz.getLocation(studentTzName);
          final now = tz.TZDateTime.now(studentLocation);
          final studentDateTime = tz.TZDateTime(
            studentLocation,
            now.year, now.month, now.day,
            dt.hour, dt.minute,
          );

          // 2. Convert to Teacher Timezone
          final teacherLocation = tz.getLocation(teacherTzName);
          final teacherDateTime = tz.TZDateTime.from(studentDateTime, teacherLocation);

          // 3. Set the initial time for the dialog
          initialStartTime = TimeOfDay(hour: teacherDateTime.hour, minute: teacherDateTime.minute);
          
          AppLogger.info('Converted $firstSlot ($studentTzName) -> ${initialStartTime.format(context)} ($teacherTzName)');

        } catch (e) {
          AppLogger.warning('Error converting time: $e');
          // Fallback: Use the raw time without conversion if parsing fails
        }
      }

      // 4. Open Dialog
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => CreateShiftDialog(
          // Pre-fill Teacher
          initialTeacherId: _teacherEmail ?? widget.job.acceptedByTeacherId,
          
          // Pre-fill Student
          initialStudentEmail: studentEmail,
          
          // Pre-fill Subject
          initialSubjectName: enrollmentData['subject'] as String? ?? widget.job.subject,
          
          // Pre-fill Schedule (In Teacher's Timezone!)
          initialDays: rawDays?.map((d) => d.toString()).toList(),
          initialTimezone: teacherTzName, // Force dialog to use Teacher's TZ
          initialTime: initialStartTime, // The converted time
          
          onShiftCreated: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Shift created & Synced to Teacher Timezone!'),
                backgroundColor: Colors.green,
              ),
            );
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xff10B981), width: 1.5),
      ),
      elevation: 2,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xff10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xff10B981)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, size: 14, color: Color(0xff10B981)),
                      const SizedBox(width: 6),
                      Text(
                        'MATCHED',
                        style: GoogleFonts.inter(
                          color: const Color(0xff065F46),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.job.acceptedAt != null)
                  Text(
                    'Accepted: ${DateFormat('MMM d').format(widget.job.acceptedAt!)}',
                    style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 12),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Student Section
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person, color: Colors.blue, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.job.studentName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xff1E293B),
                        ),
                      ),
                      Text(
                        '${widget.job.subject} • ${widget.job.studentAge} yo',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xff64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Req: ${widget.job.timeSlots.first} (${widget.job.timeZone})',
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1),
            ),
            
            // Teacher Section
            _isLoadingTeacher
                ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                : Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.school, color: Colors.orange, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _teacherName ?? 'Unknown Teacher',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xff1E293B),
                              ),
                            ),
                            Text(
                              _teacherTimezone ?? 'Timezone not set',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: const Color(0xff64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
            
            const SizedBox(height: 20),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isCreatingStudent ? null : _createStudentAccount,
                    icon: _isCreatingStudent 
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.person_add_outlined),
                    label: const Text('Create Account'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _createShift,
                    icon: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 18),
                    label: Text(
                      'Finalize Schedule',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
