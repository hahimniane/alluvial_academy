import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../../core/models/job_opportunity.dart';
import '../../../core/models/employee_model.dart';
import '../../../core/services/job_board_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../shift_management/widgets/create_shift_dialog.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

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
                  return Center(child: Text(AppLocalizations.of(context)!.commonErrorWithDetails(snapshot.error ?? 'Unknown error')));
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
                          AppLocalizations.of(context)!.noFilledOpportunitiesYet,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Group jobs by parent (using parentLinkId or parentEmail)
                final groupedJobs = _groupJobsByParent(jobs);
                
                return ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: groupedJobs.length,
                  itemBuilder: (context, index) {
                    final group = groupedJobs[index];
                    if (group.jobs.length == 1) {
                      // Single student - show normal card
                      return _FilledJobCard(job: group.jobs.first);
                    } else {
                      // Multiple students from same parent - show grouped card
                      return _ParentGroupCard(group: group);
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  /// Groups jobs by parent (parentLinkId or parentEmail)
  List<_ParentJobGroup> _groupJobsByParent(List<JobOpportunity> jobs) {
    final Map<String, _ParentJobGroup> groups = {};
    
    for (final job in jobs) {
      // Use parentLinkId if available, otherwise fall back to parentEmail
      final groupKey = job.parentLinkId ?? job.parentEmail ?? job.id;
      
      if (groups.containsKey(groupKey)) {
        groups[groupKey]!.jobs.add(job);
      } else {
        groups[groupKey] = _ParentJobGroup(
          parentName: job.parentName,
          parentEmail: job.parentEmail,
          jobs: [job],
        );
      }
    }
    
    // Sort groups by most recent job
    final sortedGroups = groups.values.toList()
      ..sort((a, b) {
        final aDate = a.jobs.first.acceptedAt ?? a.jobs.first.createdAt;
        final bDate = b.jobs.first.acceptedAt ?? b.jobs.first.createdAt;
        return bDate.compareTo(aDate);
      });
    
    return sortedGroups;
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
                  AppLocalizations.of(context)!.jobFilledOpportunities,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xff111827),
                  ),
                ),
                Text(
                  AppLocalizations.of(context)!.finalizeSchedulesForMatchedStudentsAnd,
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

/// Model for grouping jobs by parent
class _ParentJobGroup {
  final String? parentName;
  final String? parentEmail;
  final List<JobOpportunity> jobs;
  
  _ParentJobGroup({
    this.parentName,
    this.parentEmail,
    required this.jobs,
  });
}

/// Card that displays multiple students from the same parent
class _ParentGroupCard extends StatefulWidget {
  final _ParentJobGroup group;
  
  const _ParentGroupCard({required this.group});
  
  @override
  State<_ParentGroupCard> createState() => _ParentGroupCardState();
}

class _ParentGroupCardState extends State<_ParentGroupCard> {
  bool _isExpanded = true;
  
  @override
  Widget build(BuildContext context) {
    final studentCount = widget.group.jobs.length;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xff6366F1), width: 2),
      ),
      elevation: 3,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Parent Header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xffEEF2FF),
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(14),
                  bottom: _isExpanded ? Radius.zero : const Radius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xff6366F1).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.family_restroom, color: Color(0xff4F46E5), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget.group.parentName ?? 'Parent',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xff1E293B),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xff6366F1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$studentCount students',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (widget.group.parentEmail != null)
                          Text(
                            widget.group.parentEmail!,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xff64748B),
                            ),
                          ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0 : 0.5,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_up, color: Color(0xff6366F1)),
                  ),
                ],
              ),
            ),
          ),
          
          // Student Cards (expanded)
          AnimatedCrossFade(
            firstChild: Column(
              children: widget.group.jobs.map((job) {
                return _FilledJobCard(
                  job: job,
                  isPartOfGroup: true,
                  studentIndex: widget.group.jobs.indexOf(job) + 1,
                  totalStudents: studentCount,
                );
              }).toList(),
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState: _isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

class _FilledJobCard extends StatefulWidget {
  final JobOpportunity job;
  final bool isPartOfGroup;
  final int? studentIndex;
  final int? totalStudents;

  const _FilledJobCard({
    required this.job,
    this.isPartOfGroup = false,
    this.studentIndex,
    this.totalStudents,
  });

  @override
  State<_FilledJobCard> createState() => _FilledJobCardState();
}

class _FilledJobCardState extends State<_FilledJobCard> {
  bool _isLoadingTeacher = false;
  bool _isCreatingStudent = false;
  bool _isRevoking = false; // For revoke action
  bool _isClosing = false;  // For archive/close without rebroadcast
  bool _studentCreatedSuccessfully = false; // Prevent duplicate creation
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

  /// Admin revokes teacher acceptance and re-broadcasts the job.
  /// Uses the same teacher name as shown in "Matched with Teacher" (_teacherName).
  Future<void> _revokeAcceptance() async {
    final teacherDisplayName = _teacherName ?? 'Unknown';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Revoke acceptance?', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text(
          'This will remove the match with the current teacher and make this opportunity available again for another teacher.\n\n'
          'Teacher: $teacherDisplayName\n'
          'Student: ${widget.job.studentName}',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Revoke', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isRevoking = true);
    try {
      await JobBoardService().adminRevokeAcceptance(widget.job.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Acceptance revoked. Job re-broadcast for other teachers.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRevoking = false);
    }
  }

  /// Admin closes the opportunity without re-broadcasting (like archive).
  /// Uses the same teacher name as shown in "Matched with Teacher" (_teacherName).
  Future<void> _closeJob() async {
    final teacherDisplayName = _teacherName ?? 'Unknown';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Close without re-broadcasting?', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text(
          'This opportunity will be closed and will not be offered to teachers again.\n\n'
          'Teacher: $teacherDisplayName\n'
          'Student: ${widget.job.studentName}',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[700]),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isClosing = true);
    try {
      await JobBoardService().adminCloseJob(widget.job.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opportunity closed. It will not be offered to teachers again.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isClosing = false);
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
    // Prevent duplicate creation
    if (_studentCreatedSuccessfully) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student account already created!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
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
      
      // Improved name extraction: prioritize contact fields, then parse studentName
      String firstName = '';
      String lastName = '';
      
      // First, try to get from contact fields
      if (contact['firstName'] != null && contact['firstName'].toString().trim().isNotEmpty) {
        firstName = contact['firstName'].toString().trim();
      }
      if (contact['lastName'] != null && contact['lastName'].toString().trim().isNotEmpty) {
        lastName = contact['lastName'].toString().trim();
      }
      
      // If firstName or lastName is missing, try parsing studentName
      if (firstName.isEmpty || lastName.isEmpty) {
        final fullName = widget.job.studentName.trim();
        if (fullName.isNotEmpty) {
          final parts = fullName.split(' ').where((p) => p.isNotEmpty).toList();
          if (parts.isNotEmpty) {
            if (firstName.isEmpty) {
              firstName = parts.first;
            }
            if (lastName.isEmpty && parts.length > 1) {
              lastName = parts.sublist(1).join(' ');
            }
          }
        }
      }
      
      // Final fallbacks to ensure we always have values
      if (firstName.isEmpty) {
        firstName = 'Student';
      }
      if (lastName.isEmpty) {
        lastName = 'Unknown';
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
        final studentCode = result.data['studentCode']?.toString() ?? '';
        setState(() {
          _studentCreatedSuccessfully = true; // Disable button permanently
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.studentAccountCreatedIdStudentcode(studentCode)),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        // Show detailed error message from Cloud Function
        final errorMessage = e.message ?? e.code ?? 'Unknown error';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating student: $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating student: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreatingStudent = false);
    }
  }

  Future<void> _createShift() async {
    if (widget.job.acceptedByTeacherId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.teacherInformationNotAvailable), backgroundColor: Colors.red),
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
      final program = enrollmentData['program'] as Map<String, dynamic>? ?? {};
      final metadata = enrollmentData['metadata'] as Map<String, dynamic>? ?? {};
      
      // 2. Handle Student Account - find student by email
      final studentEmail = contact['email'] as String?;
      Employee? preloadedStudent;
      
      if (studentEmail != null && studentEmail.isNotEmpty) {
        // Try to find student by email to preload for faster dialog
        try {
          final studentQuery = await FirebaseFirestore.instance
              .collection('users')
              .where('e-mail', isEqualTo: studentEmail)
              .where('user_type', isEqualTo: 'student')
              .limit(1)
              .get();
          
          if (studentQuery.docs.isNotEmpty) {
            final doc = studentQuery.docs.first;
            final data = doc.data() as Map<String, dynamic>;
            
            // Helper to format Timestamp
            String formatTimestamp(dynamic timestamp) {
              if (timestamp is Timestamp) {
                return timestamp.toDate().toString();
              }
              return timestamp?.toString() ?? 'Never';
            }
            
            preloadedStudent = Employee(
              firstName: data['first_name'] ?? '',
              lastName: data['last_name'] ?? '',
              email: data['e-mail'] ?? '',
              countryCode: data['country_code'] ?? '',
              mobilePhone: data['phone_number'] ?? '',
              userType: data['user_type'] ?? 'student',
              title: data['title'] ?? '',
              employmentStartDate: formatTimestamp(data['employment_start_date']),
              kioskCode: data['kiosk_code'] ?? doc.id,
              studentCode: data['student_code'] ?? data['studentCode'] ?? '',
              dateAdded: formatTimestamp(data['date_added']),
              lastLogin: formatTimestamp(data['last_login']),
              documentId: doc.id,
              isAdminTeacher: data['is_admin_teacher'] as bool? ?? false,
              isActive: data['is_active'] as bool? ?? true,
            );
            AppLogger.info('Preloaded student: ${preloadedStudent?.documentId ?? 'unknown'}');
          }
        } catch (e) {
          AppLogger.warning('Could not preload student: $e');
        }
      }
      
      // 3. Preload teacher data for faster dialog
      Employee? preloadedTeacher;
      if (widget.job.acceptedByTeacherId != null) {
        try {
          final teacherDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.job.acceptedByTeacherId!)
              .get();
          
          if (teacherDoc.exists) {
            final data = teacherDoc.data() as Map<String, dynamic>;
            
            // Helper to format Timestamp
            String formatTimestamp(dynamic timestamp) {
              if (timestamp is Timestamp) {
                return timestamp.toDate().toString();
              }
              return timestamp?.toString() ?? 'Never';
            }
            
            preloadedTeacher = Employee(
              firstName: data['first_name'] ?? '',
              lastName: data['last_name'] ?? '',
              email: data['e-mail'] ?? '',
              countryCode: data['country_code'] ?? '',
              mobilePhone: data['phone_number'] ?? '',
              userType: data['user_type'] ?? 'teacher',
              title: data['title'] ?? '',
              employmentStartDate: formatTimestamp(data['employment_start_date']),
              kioskCode: data['kiosk_code'] ?? '',
              dateAdded: formatTimestamp(data['date_added']),
              lastLogin: formatTimestamp(data['last_login']),
              documentId: teacherDoc.id,
              isAdminTeacher: data['is_admin_teacher'] as bool? ?? false,
              isActive: data['is_active'] as bool? ?? true,
            );
            AppLogger.info('Preloaded teacher: ${preloadedTeacher?.email ?? 'unknown'}');
          }
        } catch (e) {
          AppLogger.warning('Could not preload teacher: $e');
        }
      }
      
      // 4. --- TIMEZONE CONVERSION MAGIC ---
      // Goal: Open the dialog showing the TEACHER'S selected times if available
      
      final studentTzName = preferences['timeZone'] ?? widget.job.timeZone ?? 'UTC';
      // Use the teacher's timezone loaded from Firestore, fallback to UTC
      final teacherTzName = _teacherTimezone ?? 'UTC'; 
      
      // Check if teacher has selected specific times (priority)
      final teacherSelectedTimes = widget.job.teacherSelectedTimes ?? 
          metadata['teacherSelectedTimes'] as Map<String, dynamic>?;
      
      List<dynamic>? rawDays;
      TimeOfDay? initialStartTime;
      bool usingTeacherSelection = false;
      
      // If teacher selected specific times, use those
      if (teacherSelectedTimes != null && teacherSelectedTimes.isNotEmpty) {
        usingTeacherSelection = true;
        rawDays = teacherSelectedTimes.keys.toList();
        
        // Use first selected time slot - format: "10:00 AM - 11:30 AM"
        final firstEntry = teacherSelectedTimes.entries.first;
        final timeSlot = firstEntry.value.toString();
        final startPart = timeSlot.split('-').first.trim();
        
        try {
          final format = DateFormat("h:mm a");
          final dt = format.parse(startPart);
          // Teacher's selection is already in teacher's timezone
          initialStartTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
          AppLogger.info('Using teacher selected time: $startPart for days: $rawDays');
        } catch (e) {
          AppLogger.warning('Error parsing teacher selected time: $e');
        }
      } else {
        // Fall back to student's original selection with timezone conversion
        final rawTimeSlots = preferences['timeSlots'] as List<dynamic>? ?? widget.job.timeSlots;
        rawDays = preferences['days'] as List<dynamic>? ?? widget.job.days;
        
        if (rawTimeSlots != null && rawTimeSlots.isNotEmpty) {
          // Parse "10:00 AM"
          final firstSlot = rawTimeSlots.first.toString().split('-')[0].trim();
          
          try {
            // Parse using a standard format
            final format = DateFormat("h:mm a"); 
            final dt = format.parse(firstSlot);

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
          }
        }
      }
      
      final sessionDuration = program['sessionDuration'] ?? widget.job.sessionDuration ?? '60 minutes';

      // 5. Open Dialog with preloaded data for faster initialization
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
          
          // Preloaded data for optimization
          preloadedTeacher: preloadedTeacher,
          preloadedStudent: preloadedStudent,
          sessionDuration: sessionDuration,
          
          onShiftCreated: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!.shiftCreatedSyncedToTeacherTimezone),
                backgroundColor: Colors.green,
              ),
            );
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.errorE), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use different card styling when part of a parent group
    final isGrouped = widget.isPartOfGroup;
    
    return Card(
      margin: EdgeInsets.only(bottom: isGrouped ? 0 : 16),
      shape: RoundedRectangleBorder(
        borderRadius: isGrouped 
            ? BorderRadius.zero 
            : BorderRadius.circular(16),
        side: isGrouped 
            ? BorderSide.none 
            : const BorderSide(color: Color(0xff10B981), width: 1.5),
      ),
      elevation: isGrouped ? 0 : 2,
      color: Colors.white,
      child: Container(
        decoration: isGrouped 
            ? BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              )
            : null,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // Show student index when part of group
                    if (isGrouped && widget.studentIndex != null) ...[
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xff6366F1).withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xff6366F1)),
                        ),
                        child: Center(
                          child: Text(
                            '${widget.studentIndex}',
                            style: GoogleFonts.inter(
                              color: const Color(0xff4F46E5),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
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
                            AppLocalizations.of(context)?.matched ?? 'MATCHED',
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
                  ],
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
                      const SizedBox(height: 6),
                      // Duration and Class Type badges
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
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
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (widget.job.classType != null && widget.job.classType!.isNotEmpty)
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
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      // Teacher's selected times (green box) or original request (gray)
                      if (widget.job.hasTeacherSelectedTimes) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xffD1FAE5),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xff10B981)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle, size: 14, color: Color(0xff059669)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Teacher\'s Selected Schedule:',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xff065F46),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ...widget.job.teacherSelectedTimes!.entries.map((entry) => 
                                Padding(
                                  padding: const EdgeInsets.only(left: 18, top: 2),
                                  child: Text(
                                    '${entry.key}: ${entry.value}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: const Color(0xff047857),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Requested: ${widget.job.timeSlots.isNotEmpty ? widget.job.timeSlots.first : "TBD"} (${widget.job.timeZone})',
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[700]),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1),
            ),
            
            // Action History Section
            _buildActionHistory(),
            
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1),
            ),
            
            // Teacher Section
            _isLoadingTeacher
                ? Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
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
                              _teacherName ??
                                  AppLocalizations.of(context)!.commonUnknownTeacher,
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
            
            // Revoke vs Archiver: two actions for admin
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (_isRevoking || _isClosing) ? null : _revokeAcceptance,
                    icon: _isRevoking
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                        : const Icon(Icons.undo, color: Colors.red, size: 18),
                    label: Text(
                      _isRevoking ? 'Revoking...' : 'Revoke & Re-broadcast',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                        fontSize: 13,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (_isRevoking || _isClosing) ? null : _closeJob,
                    icon: _isClosing
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey))
                        : const Icon(Icons.archive_outlined, color: Color(0xff4B5563), size: 18),
                    label: Text(
                      _isClosing ? 'Closing...' : 'Archive (close)',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xff4B5563),
                        fontSize: 13,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xff4B5563)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _studentCreatedSuccessfully
                      // Show success state after account creation
                      ? Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xffD1FAE5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xff10B981)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle, color: Color(0xff059669), size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Account Created',
                                style: GoogleFonts.inter(
                                  color: const Color(0xff059669),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : OutlinedButton.icon(
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
                      AppLocalizations.of(context)!.finalizeSchedule,
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
  
  /// Helper to safely parse timestamp from action history (handles both String and Timestamp)
  Timestamp? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value;
    if (value is String) {
      try {
        final dateTime = DateTime.parse(value);
        return Timestamp.fromDate(dateTime);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Widget _buildActionHistory() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('enrollments')
          .doc(widget.job.enrollmentId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }
        
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final metadata = data['metadata'] as Map<String, dynamic>? ?? {};
        
        // Collect all action info
        final List<Map<String, dynamic>> actions = [];
        
        // Check for contacted info
        if (metadata['contactedAt'] != null) {
          final contactedAt = _parseTimestamp(metadata['contactedAt']);
          actions.add({
            'action': 'Marked as Contacted',
            'by': metadata['contactedByName'] ?? metadata['contactedBy'] ?? 'Admin',
            'at': contactedAt,
            'icon': Icons.phone,
            'color': const Color(0xff3B82F6),
          });
        }
        
        // Check for broadcasted info
        if (metadata['broadcastedAt'] != null) {
          final broadcastedAt = _parseTimestamp(metadata['broadcastedAt']);
          actions.add({
            'action': 'Broadcasted to Teachers',
            'by': metadata['broadcastedByName'] ?? metadata['broadcastedBy'] ?? 'Admin',
            'at': broadcastedAt,
            'icon': Icons.sensors,
            'color': const Color(0xff10B981),
          });
        }
        
        // Check for matched info (teacher accepted)
        if (metadata['matchedAt'] != null) {
          final matchedAt = _parseTimestamp(metadata['matchedAt']);
          actions.add({
            'action': 'Matched with Teacher',
            'by': metadata['matchedTeacherName'] ?? metadata['matchedTeacherId'] ?? 'Teacher',
            'at': matchedAt,
            'icon': Icons.handshake,
            'color': const Color(0xff8B5CF6),
          });
        }
        
        // Check action history array
        final actionHistory = metadata['actionHistory'] as List<dynamic>?;
        if (actionHistory != null && actionHistory.isNotEmpty) {
          // Add any additional actions from history
          for (final entry in actionHistory) {
            if (entry is Map<String, dynamic>) {
              final actionType = entry['action'] as String? ?? '';
              final timestamp = _parseTimestamp(entry['timestamp']);
              if (actionType == 'teacher_accepted' && 
                  !actions.any((a) => a['action'] == 'Matched with Teacher')) {
                actions.add({
                  'action': 'Matched with Teacher',
                  'by': entry['teacherName'] ?? entry['teacherId'] ?? 'Teacher',
                  'at': timestamp,
                  'icon': Icons.handshake,
                  'color': const Color(0xff8B5CF6),
                });
              } else if (actionType == 'admin_revoked') {
                actions.add({
                  'action': 'Admin Revoked (Re-broadcast)',
                  'by': entry['adminName'] ?? entry['adminEmail'] ?? 'Admin',
                  'at': timestamp,
                  'icon': Icons.undo,
                  'color': Colors.red,
                });
              } else if (actionType == 'teacher_withdrawn') {
                actions.add({
                  'action': 'Teacher Withdrew',
                  'by': entry['teacherName'] ?? entry['teacherId'] ?? 'Teacher',
                  'at': timestamp,
                  'icon': Icons.exit_to_app,
                  'color': Colors.orange,
                });
              } else if (actionType == 'admin_closed') {
                actions.add({
                  'action': 'Closed by admin (no re-broadcast)',
                  'by': entry['adminName'] ?? entry['adminEmail'] ?? 'Admin',
                  'at': timestamp,
                  'icon': Icons.archive_outlined,
                  'color': const Color(0xff4B5563),
                });
              }
            }
          }
        }
        
        if (actions.isEmpty) return const SizedBox.shrink();
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xffF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xffE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.history, size: 16, color: Color(0xff64748B)),
                  const SizedBox(width: 6),
                  Text(
                    'Activity History',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff475569),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...actions.map((action) {
                final timestamp = action['at'] as Timestamp?;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: (action['color'] as Color).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(
                          action['icon'] as IconData,
                          size: 14,
                          color: action['color'] as Color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              action['action'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xff1E293B),
                              ),
                            ),
                            Text(
                              'by ${action['by']}${timestamp != null ? ' • ${DateFormat('MMM d, h:mm a').format(timestamp.toDate())}' : ''}',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: const Color(0xff64748B),
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
      },
    );
  }
}
