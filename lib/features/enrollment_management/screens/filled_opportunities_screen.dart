import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../core/models/job_opportunity.dart';
import '../../../core/services/job_board_service.dart';
import '../../shift_management/widgets/create_shift_dialog.dart';

class FilledOpportunitiesScreen extends StatelessWidget {
  const FilledOpportunitiesScreen({super.key});

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
          const Icon(Icons.check_circle, color: Colors.red, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filled Opportunities',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xff111827),
                  ),
                ),
                Text(
                  'Create shifts for matched teacher-student pairs',
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
  String? _teacherName;
  String? _teacherEmail;

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
        });
      }
      } catch (e) {
        // Error loading teacher info - will show teacher ID instead
      } finally {
      if (mounted) setState(() => _isLoadingTeacher = false);
    }
  }

  /// Check if student exists in the system by email
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

  /// Create student account from enrollment data
  Future<String?> _createStudentFromEnrollment(
    Map<String, dynamic> enrollmentData,
    Map<String, dynamic> contact,
    Map<String, dynamic> student,
  ) async {
    try {
      // Parse student name
      final studentName = student['name'] as String? ?? 
                         enrollmentData['studentName'] as String? ?? 
                         'Student';
      
      // Split name into first and last name
      final nameParts = studentName.trim().split(' ');
      final firstName = nameParts.first;
      final lastName = nameParts.length > 1 
          ? nameParts.sublist(1).join(' ') 
          : 'Student'; // Default last name if only one word
      
      // Determine if adult student
      final studentAge = student['age'] as String?;
      bool isAdultStudent = false;
      if (studentAge != null && studentAge.isNotEmpty) {
        try {
          final age = int.parse(studentAge);
          isAdultStudent = age >= 18;
        } catch (e) {
          // If age parsing fails, check if parent name exists
          // If parent exists, likely a minor
          final parentName = contact['parentName'] as String?;
          isAdultStudent = parentName == null || parentName.isEmpty;
        }
      } else {
        // No age provided - if parent name exists, assume minor
        final parentName = contact['parentName'] as String?;
        isAdultStudent = parentName == null || parentName.isEmpty;
      }
      
      // Get contact information
      final email = contact['email'] as String? ?? '';
      final phone = contact['phone'] as String? ?? '';
      final parentName = contact['parentName'] as String?;
      
      // Prepare student data for creation
      final studentData = {
        'firstName': firstName,
        'lastName': lastName,
        'isAdultStudent': isAdultStudent,
        'phoneNumber': phone,
        if (email.isNotEmpty) 'email': email,
      };
      
      // If minor student and parent exists, try to find parent guardian ID
      if (!isAdultStudent && parentName != null && parentName.isNotEmpty) {
        try {
          // Try to find parent by email or name
          final parentQuery = await FirebaseFirestore.instance
              .collection('users')
              .where('e-mail', isEqualTo: email)
              .where('user_type', isEqualTo: 'parent')
              .limit(1)
              .get();
          
          if (parentQuery.docs.isNotEmpty) {
            studentData['guardianIds'] = [parentQuery.docs.first.id];
          }
        } catch (e) {
          // Parent not found, continue without guardian
        }
      }
      
      // Call Firebase function to create student
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('createStudentAccount');
      
      final result = await callable.call(studentData);
      
      if (result.data != null && result.data['success'] == true) {
        // Return the email used (could be alias email or provided email)
        return result.data['aliasEmail'] as String? ?? email;
      } else {
        return null;
      }
    } catch (e) {
      print('Error creating student account: $e');
      return null;
    }
  }

  Future<void> _createShift() async {
    if (widget.job.acceptedByTeacherId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teacher information not available'), backgroundColor: Colors.red),
      );
      return;
    }

    // Get enrollment details to find student and preferences
    try {
      final enrollmentDoc = await FirebaseFirestore.instance
          .collection('enrollments')
          .doc(widget.job.enrollmentId)
          .get();
      
      if (!enrollmentDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enrollment not found'), backgroundColor: Colors.red),
        );
        return;
      }

      final enrollmentData = enrollmentDoc.data() as Map<String, dynamic>;
      final contact = enrollmentData['contact'] as Map<String, dynamic>? ?? {};
      final preferences = enrollmentData['preferences'] as Map<String, dynamic>? ?? {};
      final student = enrollmentData['student'] as Map<String, dynamic>? ?? {};
      
      // Get teacher email
      String? teacherEmail;
      try {
        final teacherDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.job.acceptedByTeacherId!)
            .get();
        if (teacherDoc.exists) {
          final teacherData = teacherDoc.data() as Map<String, dynamic>;
          teacherEmail = teacherData['e-mail'] as String?;
        }
      } catch (e) {
        // Error loading teacher email - will use teacher ID instead
      }
      
      // Get student email from enrollment
      String? studentEmail = contact['email'] as String?;
      
      // Check if student exists, if not create student account
      String? finalStudentEmail = studentEmail;
      if (studentEmail != null && studentEmail.isNotEmpty) {
        final studentExists = await _checkStudentExists(studentEmail);
        if (!studentExists) {
          // Student doesn't exist, create account
          if (!mounted) return;
          
          // Show loading dialog
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Creating student account...'),
                    ],
                  ),
                ),
              ),
            ),
          );
          
          try {
            final createdStudentEmail = await _createStudentFromEnrollment(
              enrollmentData,
              contact,
              student,
            );
            
            // Close loading dialog
            if (mounted) Navigator.pop(context);
            
            if (createdStudentEmail != null) {
              finalStudentEmail = createdStudentEmail;
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Student account created successfully!'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            } else {
              // Failed to create student, show error and return
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to create student account. Please create the student manually first.'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 5),
                ),
              );
              return;
            }
          } catch (e) {
            // Close loading dialog if still open
            if (mounted) Navigator.pop(context);
            
            // Show error
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error creating student account: $e'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
            return;
          }
        }
      }
      
      // Extract subject
      final subject = enrollmentData['subject'] as String? ?? widget.job.subject;
      
      // Extract timezone
      final timezone = preferences['timeZone'] as String? ?? widget.job.timeZone;
      
      // Extract days and time slots
      final daysList = preferences['days'] as List<dynamic>? ?? widget.job.days;
      final timeSlotsList = preferences['timeSlots'] as List<dynamic>? ?? widget.job.timeSlots;

      // Show dialog to create shift with pre-filled information
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => CreateShiftDialog(
          initialTeacherId: teacherEmail ?? widget.job.acceptedByTeacherId,
          initialStudentEmail: finalStudentEmail,
          initialSubjectName: subject,
          initialDays: daysList?.map((d) => d.toString()).toList(),
          initialTimeSlots: timeSlotsList?.map((t) => t.toString()).toList(),
          initialTimezone: timezone,
          onShiftCreated: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Shift created successfully!'),
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
        side: const BorderSide(color: Colors.red, width: 2),
      ),
      elevation: 2,
      color: Colors.red[50],
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
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'FILLED',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                if (widget.job.acceptedAt != null)
                  Text(
                    'Accepted: ${DateFormat('MMM d, yyyy').format(widget.job.acceptedAt!)}',
                    style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 12),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Student Info
            Text(
              'Student: ${widget.job.studentName.isNotEmpty ? widget.job.studentName : "N/A"}',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xff111827),
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.person, 'Age: ${widget.job.studentAge.isNotEmpty ? widget.job.studentAge : "N/A"}'),
            _buildInfoRow(Icons.book, 'Subject: ${widget.job.subject}'),
            _buildInfoRow(Icons.school, 'Grade: ${widget.job.gradeLevel}'),
            _buildInfoRow(Icons.public, 'Timezone: ${widget.job.timeZone}'),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.calendar_today, 'Days: ${widget.job.days.join(", ")}'),
            _buildInfoRow(Icons.access_time, 'Times: ${widget.job.timeSlots.join(", ")}'),
            
            const Divider(height: 32),
            
            // Teacher Info
            _isLoadingTeacher
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: CircularProgressIndicator(),
                  )
                : _teacherName != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Accepted by Teacher:',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xff6B7280),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _teacherName!,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xff111827),
                            ),
                          ),
                          if (_teacherEmail != null && _teacherEmail!.isNotEmpty)
                            Text(
                              _teacherEmail!,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      )
                    : Text(
                        'Teacher ID: ${widget.job.acceptedByTeacherId ?? "N/A"}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
            
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _createShift,
                icon: const Icon(Icons.schedule),
                label: Text(
                  'Create Shift for This Match',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff3B82F6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
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

