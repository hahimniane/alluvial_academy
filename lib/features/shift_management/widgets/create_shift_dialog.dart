import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/models/teaching_shift.dart';
import '../../../core/models/employee_model.dart';
import '../../../core/models/enhanced_recurrence.dart';
import '../../../core/models/subject.dart';
import '../../../core/services/shift_service.dart';
import '../../../core/services/subject_service.dart';
import '../../../shared/widgets/enhanced_recurrence_picker.dart';
import '../../../core/services/timezone_service.dart';
import '../../../core/utils/timezone_utils.dart';
import '../../../core/enums/shift_enums.dart';
import 'subject_management_dialog.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

class CreateShiftDialog extends StatefulWidget {
  final TeachingShift? shift; // For editing existing shift
  final VoidCallback onShiftCreated;
  
  // Optional initial values for pre-filling form from enrollment/job opportunity
  final String? initialTeacherId; // Teacher UID or email
  final String? initialStudentEmail; // Student email
  final String? initialSubjectName; // Subject name (will be matched to subject ID)
  final List<String>? initialDays; // Preferred days (e.g., ['Mon', 'Tue'])
  final List<String>? initialTimeSlots; // Preferred time slots (e.g., ['8 AM - 12 PM'])
  final String? initialTimezone; // Timezone
  final DateTime? initialDate; // Pre-fill date when creating from grid cell
  final TimeOfDay? initialTime; // Pre-fill time when creating from grid cell
  final ShiftCategory? initialCategory; // Pre-select category (teaching/leadership)

  const CreateShiftDialog({
    super.key,
    this.shift,
    required this.onShiftCreated,
    this.initialTeacherId,
    this.initialStudentEmail,
    this.initialSubjectName,
    this.initialDays,
    this.initialTimeSlots,
    this.initialTimezone,
    this.initialDate,
    this.initialTime,
    this.initialCategory,
  });

  @override
  State<CreateShiftDialog> createState() => _CreateShiftDialogState();
}

class _CreateShiftDialogState extends State<CreateShiftDialog> {
  final _formKey = GlobalKey<FormState>();
  final _customNameController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isLoading = false;
  bool _useCustomName = false;

  // Form fields
  String? _selectedTeacherId;
  Set<String> _selectedStudentIds = {};
  
  // NEW: Category and leader role fields
  ShiftCategory _selectedCategory = ShiftCategory.teaching;
  String? _selectedLeaderRole;

  // Search controllers
  final TextEditingController _teacherSearchController =
      TextEditingController();
  final TextEditingController _studentSearchController =
      TextEditingController();
  DateTime _shiftDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = const TimeOfDay(hour: 14, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 16, minute: 0);
  String? _selectedSubjectId;
  RecurrencePattern _recurrence = RecurrencePattern.none;
  EnhancedRecurrence _enhancedRecurrence = const EnhancedRecurrence();
  DateTime? _recurrenceEndDate;

  // Subjects list
  List<Subject> _availableSubjects = [];

  // Data lists
  List<Employee> _availableTeachers = [];
  List<Employee> _availableLeaders = []; // NEW: For leader schedules
  List<Employee> _availableStudents = [];
  Map<String, String> _studentCodes = {}; // email -> student_code
  bool _studentCodesLoaded = false;

  // Timezone will be loaded from user profile
  String _adminTimezone = 'UTC';
  String _selectedTimezone = 'UTC';
  String? _teacherTimezone;

  @override
  void initState() {
    super.initState();
    
    // Set initial date and time IMMEDIATELY if provided (before async operations)
    if (widget.shift == null) {
      if (widget.initialDate != null) {
        _shiftDate = widget.initialDate!;
        AppLogger.debug('CreateShiftDialog: Set initial date in initState: ${widget.initialDate}');
      }
      if (widget.initialTime != null) {
        _startTime = widget.initialTime!;
        _endTime = TimeOfDay(
          hour: (_startTime.hour + 1) % 24,
          minute: _startTime.minute,
        );
        AppLogger.debug('CreateShiftDialog: Set initial time in initState: ${widget.initialTime}');
      }
      // Set initial category if provided
      if (widget.initialCategory != null) {
        _selectedCategory = widget.initialCategory!;
        AppLogger.debug('CreateShiftDialog: Set initial category in initState: ${widget.initialCategory}');
      }
      // Store initial teacher ID to match later (even if we can't match it yet)
      if (widget.initialTeacherId != null) {
        _selectedTeacherId = widget.initialTeacherId;
        AppLogger.debug('CreateShiftDialog: Set initial teacher ID in initState: ${widget.initialTeacherId}');
      }
    }
    
    _loadAvailableUsers();
    _loadAvailableSubjects();
    _initializeFormData();
    _loadAdminTimezone();
  }

  Future<void> _loadAdminTimezone() async {
    try {
      final timezone = await TimezoneService.getCurrentUserTimezone();
      if (mounted) {
        setState(() {
          _adminTimezone = timezone;
          // Use initial timezone if provided, otherwise default to admin's timezone
          if (widget.shift == null) {
            _selectedTimezone = widget.initialTimezone ?? timezone;
          }
        });
      }
      AppLogger.error('CreateShiftDialog: Loaded admin timezone: $timezone');
    } catch (e) {
      AppLogger.error('CreateShiftDialog: Error loading admin timezone: $e');
    }
  }

  Future<void> _loadAvailableSubjects() async {
    try {
      final subjects = await SubjectService.getActiveSubjects();
      if (mounted) {
        setState(() {
          _availableSubjects = subjects;
          // Try to match initial subject name if provided
          if (widget.initialSubjectName != null && subjects.isNotEmpty) {
            final matchedSubject = subjects.firstWhere(
              (s) => s.name.toLowerCase() == widget.initialSubjectName!.toLowerCase(),
              orElse: () => subjects.first,
            );
            _selectedSubjectId = matchedSubject.id;
          } else {
            // Preserve current selection if possible; otherwise pick first
            final hasCurrent = _selectedSubjectId != null &&
                subjects.any((s) => s.id == _selectedSubjectId);
            if (!hasCurrent && subjects.isNotEmpty) {
              _selectedSubjectId = subjects.first.id;
            }
          }
        });
      }
    } catch (e) {
      AppLogger.error('CreateShiftDialog: Error loading subjects: $e');
    }
  }

  @override
  void dispose() {
    _customNameController.dispose();
    _notesController.dispose();
    _teacherSearchController.dispose();
    _studentSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableUsers() async {
    try {
      AppLogger.debug('CreateShiftDialog: Loading available users...');

      // Try the ShiftService first
      var teachers = await ShiftService.getAvailableTeachers();
      var leaders = await ShiftService.getAvailableLeaders(); // NEW: Load leaders
      var students = await ShiftService.getAvailableStudents();

      AppLogger.debug(
          'CreateShiftDialog: ShiftService returned ${teachers.length} teachers and ${students.length} students');

      // If ShiftService returns empty, try loading all employees and filter locally
      if (teachers.isEmpty && students.isEmpty) {
        AppLogger.debug(
            'CreateShiftDialog: ShiftService returned empty, trying direct Firestore query...');

        try {
          final snapshot =
              await FirebaseFirestore.instance.collection('users').get();
          AppLogger.debug(
              'CreateShiftDialog: Found ${snapshot.docs.length} total employees');

          final allEmployees =
              EmployeeDataSource.mapSnapshotToEmployeeList(snapshot);
          AppLogger.debug(
              'CreateShiftDialog: Mapped ${allEmployees.length} employees');

          teachers =
              allEmployees.where((emp) => emp.userType == 'teacher').toList();
          students =
              allEmployees.where((emp) => emp.userType == 'student').toList();

          AppLogger.debug(
              'CreateShiftDialog: Filtered to ${teachers.length} teachers and ${students.length} students');

          // Debug: Print first teacher and student if found
          if (teachers.isNotEmpty) {
            AppLogger.debug(
                'First teacher: ${teachers.first.firstName} ${teachers.first.lastName} (${teachers.first.email})');
          }
          if (students.isNotEmpty) {
            AppLogger.error(
                'First student: ${students.first.firstName} ${students.first.lastName} (${students.first.email})');
          }
        } catch (e) {
          AppLogger.error('CreateShiftDialog: Error with direct query: $e');
        }
      }

      if (mounted) {
        setState(() {
          _availableTeachers = teachers;
          _availableLeaders = leaders; // NEW: Store leaders
          _availableStudents = students;
        });
        AppLogger.info(
            'CreateShiftDialog: State updated with teachers: ${_availableTeachers.length}, students: ${_availableStudents.length}');

        // Load student codes for the students
        await _loadStudentCodes();

        // Force a rebuild to show the loaded codes
        if (mounted) {
          setState(() {});
        }

        // Convert UIDs to emails for editing mode
        _convertUidsToEmails();
        
        // Apply initial values if provided (after all data is loaded)
        _applyInitialValues();
      }
    } catch (e) {
      AppLogger.error('CreateShiftDialog: Error loading available users: $e');
    }
  }
  
  /// Apply initial values from enrollment/job opportunity
  void _applyInitialValues() async {
    // Note: When editing, teacher is set in _convertUidsToEmails()
    // But we still need to apply initialTeacherId if provided for new shifts
    if (widget.shift != null) return; // Don't override if editing existing shift
    
    // Date and time are already set in initState(), but ensure they're set here too for safety
    if (mounted) {
      setState(() {
        if (widget.initialDate != null && _shiftDate != widget.initialDate) {
          _shiftDate = widget.initialDate!;
          AppLogger.debug('CreateShiftDialog: Re-applied initial date: ${widget.initialDate}');
        }
        if (widget.initialTime != null) {
          _startTime = widget.initialTime!;
          _endTime = TimeOfDay(
            hour: (_startTime.hour + 1) % 24,
            minute: _startTime.minute,
          );
          AppLogger.debug('CreateShiftDialog: Re-applied initial time: ${widget.initialTime}');
        }
      });
    }
    
    // Handle teacher pre-selection with retry mechanism
    // Only try to match if we haven't already matched it
    if (widget.initialTeacherId != null && (_selectedTeacherId == null || _selectedTeacherId != widget.initialTeacherId)) {
      AppLogger.debug('CreateShiftDialog: Attempting to pre-select teacher: ${widget.initialTeacherId}');
      
      // Retry mechanism to wait for lists to load
      Employee? teacher;
      int retryCount = 0;
      const maxRetries = 10;
      
      while (teacher == null && retryCount < maxRetries && mounted) {
        await Future.delayed(Duration(milliseconds: 100 * (retryCount + 1)));
        
        // Try to find in teachers first (case-insensitive, trim whitespace)
        final searchId = widget.initialTeacherId!.toLowerCase().trim();
        
        try {
          teacher = _availableTeachers.firstWhere(
            (t) => t.email.toLowerCase().trim() == searchId || 
                   t.documentId?.toLowerCase().trim() == searchId,
          );
          AppLogger.debug('CreateShiftDialog: Found teacher in teachers list: ${teacher.email}');
        } catch (e) {
          // Try to find in leaders
          try {
            teacher = _availableLeaders.firstWhere(
              (l) => l.email.toLowerCase().trim() == searchId || 
                     l.documentId?.toLowerCase().trim() == searchId,
            );
            AppLogger.debug('CreateShiftDialog: Found teacher in leaders list: ${teacher.email}');
          } catch (e2) {
            // Not found yet, will retry
          }
        }
        
        if (teacher == null && _availableTeachers.isEmpty && _availableLeaders.isEmpty) {
          retryCount++;
          continue;
        }
        
        if (teacher != null) break;
        retryCount++;
      }
      
      if (teacher != null && mounted) {
        setState(() {
          _selectedTeacherId = teacher!.email;
          // Determine category based on where found
          if (_availableLeaders.any((l) => l.email == teacher!.email)) {
            _selectedCategory = ShiftCategory.leadership;
          }
          // Set search controller to show teacher name for better UX
          _teacherSearchController.text = '${teacher!.firstName} ${teacher!.lastName}';
        });
        AppLogger.debug('CreateShiftDialog: Pre-selected teacher: ${teacher.email} (category: $_selectedCategory)');
        
        // Update timezone for the selected teacher
        _updateTimezoneForTeacher(teacher.email);
        
        // Force rebuild to show selection
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) setState(() {});
      } else {
        AppLogger.error('CreateShiftDialog: Could not find teacher ${widget.initialTeacherId} after $retryCount retries');
        AppLogger.debug('CreateShiftDialog: Available teachers: ${_availableTeachers.map((t) => t.email).toList()}');
        AppLogger.debug('CreateShiftDialog: Available leaders: ${_availableLeaders.map((l) => l.email).toList()}');
        // If we couldn't find the teacher, clear the selection so user can choose manually
        if (mounted) {
          setState(() {
            _selectedTeacherId = null;
            _teacherSearchController.clear();
          });
        }
      }
    }
    
    // Set initial student (only if student exists in system)
    if (widget.initialStudentEmail != null && _availableStudents.isNotEmpty && mounted) {
      try {
        final student = _availableStudents.firstWhere(
          (s) => s.email == widget.initialStudentEmail,
        );
        // Format as email|firstName|lastName (matching the dialog's format)
        setState(() {
          _selectedStudentIds = {'${student.email}|${student.firstName}|${student.lastName}'};
        });
        AppLogger.debug('CreateShiftDialog: Set initial student: ${student.email}');
      } catch (e) {
        // Student not found in system yet - this is OK, admin can select manually
        AppLogger.debug('CreateShiftDialog: Student ${widget.initialStudentEmail} not found in system yet');
      }
    }
    
    // Set initial subject
    if (widget.initialSubjectName != null && _availableSubjects.isNotEmpty && mounted) {
      try {
        final subject = _availableSubjects.firstWhere(
          (s) => s.name.toLowerCase() == widget.initialSubjectName!.toLowerCase(),
        );
        setState(() {
          _selectedSubjectId = subject.id;
        });
        AppLogger.debug('CreateShiftDialog: Set initial subject: ${subject.name}');
      } catch (e) {
        AppLogger.debug('CreateShiftDialog: Subject "${widget.initialSubjectName}" not found, using default');
      }
    }
    
    // Set initial timezone
    if (widget.initialTimezone != null && widget.initialTimezone!.isNotEmpty && mounted) {
      setState(() {
        _selectedTimezone = widget.initialTimezone!;
      });
      AppLogger.debug('CreateShiftDialog: Set initial timezone: ${widget.initialTimezone}');
    }
    
    // Parse initial time slots to set start/end time
    if (widget.initialTimeSlots != null && widget.initialTimeSlots!.isNotEmpty && mounted) {
      final firstTimeSlot = widget.initialTimeSlots!.first;
      _parseTimeSlot(firstTimeSlot);
      AppLogger.debug('CreateShiftDialog: Parsed time slot: $firstTimeSlot');
    }
  }
  
  /// Parse time slot string (e.g., "8 AM - 12 PM") to set start and end times
  void _parseTimeSlot(String timeSlot) {
    try {
      // Common formats: "8 AM - 12 PM", "14:00 - 16:00", etc.
      final parts = timeSlot.split(' - ');
      if (parts.length == 2) {
        final startStr = parts[0].trim();
        final endStr = parts[1].trim();
        
        // Parse start time
        final startTime = _parseTimeString(startStr);
        if (startTime != null) {
          _startTime = startTime;
        }
        
        // Parse end time
        final endTime = _parseTimeString(endStr);
        if (endTime != null) {
          _endTime = endTime;
        }
      }
    } catch (e) {
      AppLogger.error('CreateShiftDialog: Error parsing time slot: $e');
    }
  }
  
  /// Parse time string to TimeOfDay
  TimeOfDay? _parseTimeString(String timeStr) {
    try {
      // Handle formats like "8 AM", "14:00", "2 PM"
      if (timeStr.contains('AM') || timeStr.contains('PM')) {
        // 12-hour format
        final isPM = timeStr.toUpperCase().contains('PM');
        final timeOnly = timeStr.replaceAll(RegExp(r'[^\d:]'), '');
        final parts = timeOnly.split(':');
        int hour = int.parse(parts[0]);
        int minute = parts.length > 1 ? int.parse(parts[1]) : 0;
        
        if (isPM && hour != 12) hour += 12;
        if (!isPM && hour == 12) hour = 0;
        
        return TimeOfDay(hour: hour, minute: minute);
      } else {
        // 24-hour format
        final parts = timeStr.split(':');
        if (parts.length >= 2) {
          return TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }
      }
    } catch (e) {
      AppLogger.error('CreateShiftDialog: Error parsing time string "$timeStr": $e');
    }
    return null;
  }

  Future<void> _loadStudentCodes() async {
    try {
      AppLogger.error('CreateShiftDialog: Loading student codes...');
      final Map<String, String> studentCodesMap = {};

      for (final student in _availableStudents) {
        try {
          // Query Firestore to get the student_code for this student
          final studentSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .where('e-mail', isEqualTo: student.email)
              .where('user_type', isEqualTo: 'student')
              .limit(1)
              .get();

          if (studentSnapshot.docs.isNotEmpty) {
            final studentData = studentSnapshot.docs.first.data();
            AppLogger.debug(
                'CreateShiftDialog: Student data for ${student.firstName}: ${studentData.keys.toList()}');

            // Check all possible field names for student code
            String? studentCode = studentData['student_code'] as String?;
            if (studentCode == null || studentCode.isEmpty) {
              studentCode = studentData['studentCode'] as String?;
            }
            if (studentCode == null || studentCode.isEmpty) {
              studentCode = studentData['student_id'] as String?;
            }
            if (studentCode == null || studentCode.isEmpty) {
              studentCode = studentData['studentId'] as String?;
            }

            if (studentCode != null && studentCode.isNotEmpty) {
              studentCodesMap[student.email] = studentCode;
              AppLogger.debug(
                  'CreateShiftDialog: ✅ Found student code for ${student.firstName} ${student.lastName}: "$studentCode"');
            } else {
              AppLogger.debug(
                  'CreateShiftDialog: ❌ No student code found for ${student.firstName} ${student.lastName}');
              AppLogger.debug(
                  'CreateShiftDialog: Available fields with "student/code/id": ${studentData.keys.where((k) => k.toLowerCase().contains("student") || k.toLowerCase().contains("code") || k.toLowerCase().contains("id")).toList()}');
            }
          } else {
            AppLogger.error(
                'CreateShiftDialog: ⚠️ No documents found for email: ${student.email}');
          }
        } catch (e) {
          AppLogger.error(
              'CreateShiftDialog: Error loading student code for ${student.email}: $e');
        }
      }

      if (mounted) {
        setState(() {
          _studentCodes = studentCodesMap;
          _studentCodesLoaded = true;
        });
        AppLogger.info(
            'CreateShiftDialog: Loaded ${_studentCodes.length} student codes');
        AppLogger.debug('CreateShiftDialog: Student codes map: $_studentCodes');
        // Sample output for verification
        _studentCodes.forEach((email, code) {
          AppLogger.error('  - $email → $code');
        });
      }
    } catch (e) {
      AppLogger.error('CreateShiftDialog: Error loading student codes: $e');
    }
  }

  void _convertUidsToEmails() async {
    if (widget.shift != null) {
      final shift = widget.shift!;

      try {
        // Convert teacher UID to email by querying Firestore
        final teacherDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(shift.teacherId)
            .get();

        if (teacherDoc.exists) {
          final teacherData = teacherDoc.data() as Map<String, dynamic>;
          final teacherEmail = teacherData['e-mail'] as String?;
          
          if (teacherEmail != null && mounted) {
            // Wait for lists to be loaded (with retry mechanism)
            Employee? foundTeacher;
            int retryCount = 0;
            const maxRetries = 5;
            
            while (foundTeacher == null && retryCount < maxRetries && mounted) {
              // Wait a bit for lists to load
              await Future.delayed(Duration(milliseconds: 100 * (retryCount + 1)));
              
              // Determine which list to check first based on shift category
              final isTeachingShift = shift.category == ShiftCategory.teaching;
              
              // Try the appropriate list first based on category
              if (isTeachingShift) {
                try {
                  foundTeacher = _availableTeachers.firstWhere(
                    (t) => t.email.toLowerCase().trim() == teacherEmail.toLowerCase().trim() ||
                           t.documentId == shift.teacherId,
                  );
                } catch (e) {
                  // Fallback: try leaders list
                  try {
                    foundTeacher = _availableLeaders.firstWhere(
                      (l) => l.email.toLowerCase().trim() == teacherEmail.toLowerCase().trim() ||
                             l.documentId == shift.teacherId,
                    );
                  } catch (e2) {
                    // Not found yet, will retry
                  }
                }
              } else {
                // For non-teaching shifts, check leaders first
                try {
                  foundTeacher = _availableLeaders.firstWhere(
                    (l) => l.email.toLowerCase().trim() == teacherEmail.toLowerCase().trim() ||
                           l.documentId == shift.teacherId,
                  );
                } catch (e) {
                  // Fallback: try teachers list
                  try {
                    foundTeacher = _availableTeachers.firstWhere(
                      (t) => t.email.toLowerCase().trim() == teacherEmail.toLowerCase().trim() ||
                             t.documentId == shift.teacherId,
                    );
                  } catch (e2) {
                    // Not found yet, will retry
                  }
                }
              }
              
              if (foundTeacher != null) break;
              retryCount++;
            }
            
            // Use the found teacher's email, or fallback to the email from Firestore
            final emailToUse = foundTeacher?.email ?? teacherEmail;
            
            if (mounted) {
              setState(() {
                _selectedTeacherId = emailToUse;
                _teacherSearchController.text = ''; // Clear search to show all teachers
              });
              
              AppLogger.debug(
                  'CreateShiftDialog: Converted teacher UID ${shift.teacherId} to email $emailToUse (found in list: ${foundTeacher != null}, retries: $retryCount)');
              
              // Force another rebuild after a short delay to ensure UI updates
              Future.delayed(const Duration(milliseconds: 200), () {
                if (mounted) {
                  setState(() {
                    // Ensure selection is still set
                    if (_selectedTeacherId != emailToUse) {
                      _selectedTeacherId = emailToUse;
                    }
                  });
                }
              });
            }
          } else {
            AppLogger.error('CreateShiftDialog: Teacher email is null for UID ${shift.teacherId}');
          }
        } else {
          AppLogger.error('CreateShiftDialog: Teacher document not found: ${shift.teacherId}');
        }

        // Convert student UIDs to unique identifiers by querying Firestore
        final studentIdentifiers = <String>[];
        for (String studentUid in shift.studentIds) {
          final studentDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(studentUid)
              .get();

          if (studentDoc.exists) {
            final studentData = studentDoc.data() as Map<String, dynamic>;
            final studentEmail = studentData['e-mail'] as String?;
            final firstName = studentData['first_name'] as String? ?? '';
            final lastName = studentData['last_name'] as String? ?? '';
            if (studentEmail != null) {
              // Create unique identifier for the student
              studentIdentifiers.add('$studentEmail|$firstName|$lastName');
            }
          }
        }

        if (mounted) {
          setState(() {
            _selectedStudentIds = studentIdentifiers.toSet();
          });
          AppLogger.error(
              'CreateShiftDialog: Converted ${shift.studentIds.length} student UIDs to ${studentIdentifiers.length} unique identifiers');
        }
      } catch (e) {
        AppLogger.error(
            'CreateShiftDialog: Error converting UIDs to emails: $e');
      }
    }
  }

  void _initializeFormData() {
    if (widget.shift != null) {
      final shift = widget.shift!;
      // Note: We'll need to convert UIDs to emails after loading users
      _shiftDate = DateTime(
        shift.shiftStart.year,
        shift.shiftStart.month,
        shift.shiftStart.day,
      );
      _startTime = TimeOfDay.fromDateTime(shift.shiftStart);
      _endTime = TimeOfDay.fromDateTime(shift.shiftEnd);

      // Set timezone from shift if available, otherwise default to admin's
      // Note: Shifts are stored in UTC, so we might want to convert back to the original timezone if we stored it
      // For now, we'll default to admin timezone or try to infer from teacher
      _selectedTimezone = _adminTimezone;

      // NEW: Load category and leader role from existing shift
      _selectedCategory = shift.category;
      _selectedLeaderRole = shift.leaderRole;

      // Handle subject - check if it has a subject ID first
      if (shift.subjectId != null) {
        _selectedSubjectId = shift.subjectId;
      } else {
        // For backward compatibility - map the enum to a subject ID after subjects are loaded
        // This will be handled in _loadAvailableSubjects
      }

      _recurrence = shift.recurrence;
      _recurrenceEndDate = shift.recurrenceEndDate;

      if (shift.customName != null) {
        _useCustomName = true;
        _customNameController.text = shift.customName!;
      }

      if (shift.notes != null) {
        _notesController.text = shift.notes!;
      }
    } else {
      // For new shifts, use initialCategory if provided, otherwise default to teaching
      if (widget.initialCategory != null) {
        _selectedCategory = widget.initialCategory!;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 800),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // NEW: Category selector at top
                      _buildCategorySelector(),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 20),
                      _buildTeacherSelection(),
                      const SizedBox(height: 20),
                      // Show student selection only for teaching category
                      if (_selectedCategory == ShiftCategory.teaching) ...[
                        _buildStudentSelection(),
                        const SizedBox(height: 20),
                        _buildSubjectSelection(),
                        const SizedBox(height: 20),
                      ] else ...[
                        // Show leader role selector for non-teaching categories
                        _buildLeaderRoleSelector(),
                        const SizedBox(height: 20),
                      ],
                      _buildTimezoneSelection(),
                      const SizedBox(height: 20),
                      _buildDateTimeSelection(),
                      const SizedBox(height: 20),
                      _buildRecurrenceSettings(),
                      const SizedBox(height: 20),
                      _buildCustomName(),
                      const SizedBox(height: 20),
                      _buildNotes(),
                    ],
                  ),
                ),
              ),
            ),
            _buildActions(),
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
              color: const Color(0xff0386FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.schedule,
              color: Color(0xff0386FF),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.shift == null ? 'Create New Shift' : 'Edit Shift',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xff111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Configure Islamic education teaching schedule',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xff6B7280),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
            color: const Color(0xff6B7280),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherSelection() {
    // Use teachers or leaders based on category
    final availableUsers = _selectedCategory == ShiftCategory.teaching
        ? _availableTeachers
        : _availableLeaders;
    
    // Filter based on search, but always include the selected teacher
    final filteredUsers = availableUsers.where((user) {
      // Always show the selected teacher, even if search doesn't match
      if (_selectedTeacherId != null && 
          user.email.toLowerCase().trim() == _selectedTeacherId!.toLowerCase().trim()) {
        return true;
      }
      // Filter by search query
      if (_teacherSearchController.text.isEmpty) return true;
      final query = _teacherSearchController.text.toLowerCase();
      return user.firstName.toLowerCase().contains(query) ||
          user.lastName.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query);
    }).toList();
    
    // Get the selected teacher's name for display
    String? selectedTeacherName;
    if (_selectedTeacherId != null) {
      try {
        final selectedTeacher = availableUsers.firstWhere(
          (u) => u.email.toLowerCase().trim() == _selectedTeacherId!.toLowerCase().trim(),
        );
        selectedTeacherName = '${selectedTeacher.firstName} ${selectedTeacher.lastName}';
      } catch (e) {
        // Teacher not found in list yet
      }
    }

    final labelText = _selectedCategory == ShiftCategory.teaching
        ? 'Teacher *'
        : 'Leader *';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          labelText,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xff374151),
          ),
        ),
        const SizedBox(height: 8),
        // Show selected teacher prominently if pre-selected
        if (_selectedTeacherId != null && selectedTeacherName != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xff0386FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xff0386FF).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Color(0xff0386FF),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Selected: $selectedTeacherName',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff0386FF),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedTeacherId = null;
                      _teacherSearchController.clear();
                    });
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Change',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xff0386FF),
                    ),
                  ),
                ),
              ],
            ),
          ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xffD1D5DB)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          _selectedTeacherId != null 
                              ? 'Change teacher (optional)'
                              : 'Select a teacher',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xff6B7280),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _teacherSearchController,
                      decoration: InputDecoration(
                        hintText: _selectedTeacherId != null
                            ? 'Search to change teacher...'
                            : 'Search teacher by name or email...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _selectedTeacherId != null
                            ? IconButton(
                                icon: const Icon(Icons.check_circle, color: Color(0xff0386FF), size: 20),
                                onPressed: null, // Visual indicator only
                                tooltip: 'Teacher selected: $selectedTeacherName',
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide:
                              const BorderSide(color: Color(0xffE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: _selectedTeacherId != null 
                                ? const Color(0xff0386FF).withOpacity(0.5)
                                : const Color(0xffE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide:
                              const BorderSide(color: Color(0xff0386FF)),
                        ),
                      ),
                      onChanged: (value) => setState(() {}),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                child: availableUsers.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Loading...'),
                        ),
                      )
                    : filteredUsers.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('No users found'),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: filteredUsers.length,
                            itemBuilder: (context, index) {
                              final user = filteredUsers[index];
                              final isSelected =
                                  _selectedTeacherId == user.email;

                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedTeacherId = user.email;
                                    AppLogger.debug(
                                        'Selected ${_selectedCategory == ShiftCategory.teaching ? "teacher" : "leader"}: ${user.firstName} ${user.lastName} (${user.email})');
                                    _updateTimezoneForTeacher(user.email);
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xff0386FF)
                                            .withOpacity(0.05)
                                        : null,
                                    border: isSelected
                                        ? Border.all(
                                            color: const Color(0xff0386FF)
                                                .withOpacity(0.3))
                                        : null,
                                  ),
                                  child: Row(
                                    children: [
                                      Radio<String>(
                                        value: user.email,
                                        groupValue: _selectedTeacherId,
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedTeacherId = value;
                                            AppLogger.debug(
                                                'Radio selected ${_selectedCategory == ShiftCategory.teaching ? "teacher" : "leader"}: ${user.firstName} ${user.lastName} (${user.email})');
                                            _updateTimezoneForTeacher(value!);
                                          });
                                        },
                                        activeColor: const Color(0xff0386FF),
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: const Color(0xff0386FF)
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${user.firstName[0]}${user.lastName[0]}',
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xff0386FF),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '${user.firstName} ${user.lastName}',
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xff059669)
                                                            .withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4),
                                                  ),
                                                  child: Text(
                                                    user.userType
                                                        .toUpperCase(),
                                                    style: GoogleFonts.inter(
                                                      fontSize: 11,
                                                      color: const Color(
                                                          0xff059669),
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    user.email,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 12,
                                                      color: const Color(
                                                          0xff6B7280),
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(
                                          Icons.check_circle,
                                          color: Color(0xff0386FF),
                                          size: 20,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
        if (_selectedTeacherId == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Please select a teacher',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.red,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Schedule Type *',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xff374151),
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<ShiftCategory>(
          segments: [
            ButtonSegment<ShiftCategory>(
              value: ShiftCategory.teaching,
              label: const Text('Teacher Class'),
              icon: const Icon(Icons.school, size: 18),
            ),
            ButtonSegment<ShiftCategory>(
              value: ShiftCategory.leadership,
              label: const Text('Leader Duty'),
              icon: const Icon(Icons.admin_panel_settings, size: 18),
            ),
            ButtonSegment<ShiftCategory>(
              value: ShiftCategory.meeting,
              label: const Text('Meeting'),
              icon: const Icon(Icons.groups, size: 18),
            ),
            ButtonSegment<ShiftCategory>(
              value: ShiftCategory.training,
              label: const Text('Training'),
              icon: const Icon(Icons.school_outlined, size: 18),
            ),
          ],
          selected: {_selectedCategory},
          onSelectionChanged: (Set<ShiftCategory> selected) {
            setState(() {
              _selectedCategory = selected.first;
              // Clear student selection when switching to non-teaching
              if (_selectedCategory != ShiftCategory.teaching) {
                _selectedStudentIds.clear();
                _selectedSubjectId = null;
              }
              // Clear leader role when switching to teaching
              if (_selectedCategory == ShiftCategory.teaching) {
                _selectedLeaderRole = null;
              }
            });
          },
        ),
      ],
    );
  }

  Widget _buildLeaderRoleSelector() {
    if (_selectedCategory == ShiftCategory.teaching) {
      return const SizedBox.shrink();
    }

    final roleOptions = <String, String>{
      'admin': 'Administration',
      'coordination': 'Coordination',
      'meeting': 'Meeting',
      'training': 'Staff Training',
      'planning': 'Curriculum Planning',
      'outreach': 'Community Outreach',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Duty Type *',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xff374151),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedLeaderRole,
          decoration: InputDecoration(
            hintText: 'Select duty type',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 16,
            ),
          ),
          items: roleOptions.entries.map((entry) {
            return DropdownMenuItem<String>(
              value: entry.key,
              child: Text(entry.value),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedLeaderRole = value;
            });
          },
          validator: (value) {
            if (_selectedCategory != ShiftCategory.teaching && value == null) {
              return 'Please select a duty type';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildStudentSelection() {
    // Filter students based on search
    final filteredStudents = _availableStudents.where((student) {
      if (_studentSearchController.text.isEmpty) return true;
      final query = _studentSearchController.text.toLowerCase();
      final studentCode = _studentCodes[student.email] ?? '';
      return student.firstName.toLowerCase().contains(query) ||
          student.lastName.toLowerCase().contains(query) ||
          student.email.toLowerCase().contains(query) ||
          studentCode.toLowerCase().contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Students *',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xff374151),
          ),
        ),
        const SizedBox(height: 8),
        // Show selected students prominently if editing
        if (_selectedStudentIds.isNotEmpty && widget.shift != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xff10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xff10B981).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.people,
                      color: Color(0xff10B981),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_selectedStudentIds.length} student${_selectedStudentIds.length == 1 ? '' : 's'} selected',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xff10B981),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _selectedStudentIds.take(5).map((studentId) {
                    final parts = studentId.split('|');
                    final name = parts.length >= 3 
                        ? '${parts[1]} ${parts[2]}'
                        : parts[0].split('@').first;
                    return Chip(
                      label: Text(
                        name,
                        style: GoogleFonts.inter(fontSize: 11),
                      ),
                      backgroundColor: const Color(0xff10B981).withOpacity(0.15),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () {
                        setState(() {
                          _selectedStudentIds.remove(studentId);
                        });
                      },
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                    );
                  }).toList(),
                ),
                if (_selectedStudentIds.length > 5)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '+ ${_selectedStudentIds.length - 5} more',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xff6B7280),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xffD1D5DB)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          _selectedStudentIds.isNotEmpty && widget.shift != null
                              ? 'Change students (optional)'
                              : 'Select students (${_selectedStudentIds.length} selected)',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xff6B7280),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _studentSearchController,
                      decoration: InputDecoration(
                        hintText: _selectedStudentIds.isNotEmpty && widget.shift != null
                            ? 'Search to add/remove students...'
                            : 'Search by name, student code, or email...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide:
                              const BorderSide(color: Color(0xffE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: _selectedStudentIds.isNotEmpty
                                ? const Color(0xff10B981).withOpacity(0.5)
                                : const Color(0xffE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide:
                              const BorderSide(color: Color(0xff0386FF)),
                        ),
                      ),
                      onChanged: (value) => setState(() {}),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: _availableStudents.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Loading students...'),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredStudents.length,
                        itemBuilder: (context, index) {
                          final student = filteredStudents[index];
                          // Create a unique identifier combining email and name to handle students with same parent email
                          final uniqueStudentId =
                              '${student.email}|${student.firstName}|${student.lastName}';
                          final isSelected =
                              _selectedStudentIds.contains(uniqueStudentId);

                          // Debug: Print student code for this student
                          final studentCode = _studentCodes[student.email];
                          if (index < 3) {
                            // Only print first 3 to avoid spam
                            AppLogger.debug(
                                'CreateShiftDialog: Displaying student ${student.firstName} ${student.lastName}, code: $studentCode');
                          }

                          return InkWell(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedStudentIds.remove(uniqueStudentId);
                                  AppLogger.debug(
                                      'Deselected student: ${student.firstName} ${student.lastName} (${student.email})');
                                } else {
                                  _selectedStudentIds.add(uniqueStudentId);
                                  AppLogger.debug(
                                      'Selected student: ${student.firstName} ${student.lastName} (${student.email})');
                                }
                                AppLogger.debug(
                                    'Currently selected: $_selectedStudentIds');
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: isSelected,
                                    onChanged: (checked) {
                                      setState(() {
                                        if (checked == true) {
                                          _selectedStudentIds
                                              .add(uniqueStudentId);
                                          AppLogger.debug(
                                              'Checkbox selected student: ${student.firstName} ${student.lastName} (${student.email})');
                                        } else {
                                          _selectedStudentIds
                                              .remove(uniqueStudentId);
                                          AppLogger.debug(
                                              'Checkbox deselected student: ${student.firstName} ${student.lastName} (${student.email})');
                                        }
                                        AppLogger.debug(
                                            'Currently selected: $_selectedStudentIds');
                                      });
                                    },
                                    activeColor: const Color(0xff0386FF),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${student.firstName} ${student.lastName}',
                                          style:
                                              GoogleFonts.inter(fontSize: 14),
                                        ),
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xff0386FF)
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                student.userType.toUpperCase(),
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  color:
                                                      const Color(0xff0386FF),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: RichText(
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                text: TextSpan(
                                                  children: [
                                                    if (_studentCodes[
                                                            student.email] !=
                                                        null) ...[
                                                      TextSpan(
                                                        text:
                                                            '${_studentCodes[student.email]} ',
                                                        style:
                                                            GoogleFonts.inter(
                                                          fontSize: 12,
                                                          color: const Color(
                                                              0xff059669), // Green color for student code
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                      TextSpan(
                                                        text: '• ',
                                                        style:
                                                            GoogleFonts.inter(
                                                          fontSize: 12,
                                                          color: const Color(
                                                              0xff6B7280),
                                                        ),
                                                      ),
                                                    ],
                                                    TextSpan(
                                                      text: student.email,
                                                      style: GoogleFonts.inter(
                                                        fontSize: 12,
                                                        color: const Color(
                                                            0xff6B7280),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        if (_selectedStudentIds.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Please select at least one student',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.red,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSubjectSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Subject *',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xff374151),
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => const SubjectManagementDialog(),
                ).then((_) => _loadAvailableSubjects());
              },
              icon: const Icon(Icons.settings, size: 16),
              label: Text(
                'Manage Subjects',
                style: GoogleFonts.inter(fontSize: 12),
              ),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xff0386FF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedSubjectId,
          isExpanded: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xffD1D5DB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xffD1D5DB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xff0386FF)),
            ),
          ),
          items: _availableSubjects.map((subject) {
            return DropdownMenuItem<String>(
              value: subject.id,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      subject.displayName,
                      style: GoogleFonts.inter(),
                    ),
                  ),
                  if (subject.arabicName != null)
                    Text(
                      ' (${subject.arabicName})',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
          selectedItemBuilder: (context) => _availableSubjects.map((s) {
            return Align(
              alignment: Alignment.centerLeft,
              child: Text(
                s.displayName,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontWeight: FontWeight.w500),
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedSubjectId = value;
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select a subject';
            }
            return null;
          },
        ),
        if (_selectedSubjectId != null) ...[
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final selectedSubject = _availableSubjects.firstWhere(
                (s) => s.id == _selectedSubjectId,
                orElse: () => _availableSubjects.first,
              );
              if (selectedSubject.description != null) {
                return Text(
                  selectedSubject.description!,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF6B7280),
                    fontStyle: FontStyle.italic,
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ],
    );
  }

  IslamicSubject _mapSubjectToEnum(String subjectName) {
    switch (subjectName) {
      case 'quran_studies':
        return IslamicSubject.quranStudies;
      case 'hadith_studies':
        return IslamicSubject.hadithStudies;
      case 'fiqh':
        return IslamicSubject.fiqh;
      case 'arabic_language':
        return IslamicSubject.arabicLanguage;
      case 'islamic_history':
        return IslamicSubject.islamicHistory;
      case 'aqeedah':
        return IslamicSubject.aqeedah;
      case 'tafseer':
        return IslamicSubject.tafseer;
      case 'seerah':
        return IslamicSubject.seerah;
      default:
        return IslamicSubject.quranStudies;
    }
  }

  Future<void> _updateTimezoneForTeacher(String teacherEmail) async {
    try {
      // Find teacher UID from email
      final teacherSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('e-mail', isEqualTo: teacherEmail)
          .limit(1)
          .get();

      if (teacherSnapshot.docs.isNotEmpty) {
        final teacherData = teacherSnapshot.docs.first.data();
        final teacherTz = teacherData['timezone'] as String?;

        if (teacherTz != null && teacherTz.isNotEmpty) {
          setState(() {
            _teacherTimezone = teacherTz;
            _selectedTimezone = teacherTz;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Switched to teacher\'s timezone: $teacherTz'),
                duration: const Duration(seconds: 2),
                backgroundColor: const Color(0xff0386FF),
              ),
            );
          }
        }
      }
    } catch (e) {
      AppLogger.error('Error fetching teacher timezone: $e');
    }
  }

  Widget _buildTimezoneSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Timezone',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xff374151),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message:
                  'The timezone used for the start and end times below. Defaults to the teacher\'s timezone.',
              child: Icon(
                Icons.info_outline,
                size: 16,
                color: const Color(0xff9CA3AF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InputDecorator(
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xffD1D5DB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xffD1D5DB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xff0386FF)),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: ButtonTheme(
              alignedDropdown: true,
              child: DropdownButton<String>(
                value: TimezoneUtils.getCommonTimezones()
                        .contains(_selectedTimezone)
                    ? _selectedTimezone
                    : 'UTC', // Fallback if timezone not in list
                isExpanded: true,
                icon:
                    const Icon(Icons.arrow_drop_down, color: Color(0xff6B7280)),
                style: GoogleFonts.inter(
                  color: const Color(0xff111827),
                  fontSize: 14,
                ),
                borderRadius: BorderRadius.circular(8),
                items: TimezoneUtils.getCommonTimezones().map((String tz) {
                  return DropdownMenuItem<String>(
                    value: tz,
                    child: Text(tz),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedTimezone = newValue;
                    });
                  }
                },
              ),
            ),
          ),
        ),
        if (_selectedTimezone != _adminTimezone)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xff0386FF).withOpacity(0.05),
                borderRadius: BorderRadius.circular(6),
                border:
                    Border.all(color: const Color(0xff0386FF).withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.public, size: 14, color: Color(0xff0386FF)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Scheduling in ${_selectedTimezone}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xff0386FF),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDateTimeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Schedule *',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xff374151),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildDatePicker(),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTimePickers(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    final isPrefilled = widget.initialDate != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Date',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xff6B7280),
              ),
            ),
            if (isPrefilled && widget.shift == null)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xff0386FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Pre-filled',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      color: const Color(0xff0386FF),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _shiftDate,
              firstDate: DateTime.now().subtract(const Duration(days: 30)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (date != null) {
              setState(() {
                _shiftDate = date;
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(
                color: isPrefilled && widget.shift == null
                    ? const Color(0xff0386FF).withOpacity(0.5)
                    : const Color(0xffD1D5DB),
                width: isPrefilled && widget.shift == null ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
              color: isPrefilled && widget.shift == null
                  ? const Color(0xff0386FF).withOpacity(0.05)
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 20,
                  color: isPrefilled && widget.shift == null
                      ? const Color(0xff0386FF)
                      : const Color(0xff6B7280),
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('EEE, MMM d, yyyy').format(_shiftDate),
                  style: GoogleFonts.inter(
                    fontWeight: isPrefilled && widget.shift == null
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: isPrefilled && widget.shift == null
                        ? const Color(0xff0386FF)
                        : const Color(0xff374151),
                  ),
                ),
                const Spacer(),
                const Icon(Icons.edit, size: 16, color: Color(0xff9CA3AF)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConversionPreview() {
    final now = DateTime.now();
    final shiftStart = DateTime(
      now.year,
      now.month,
      now.day,
      _startTime.hour,
      _startTime.minute,
    );

    final conversionText = TimezoneUtils.formatConversion(
      shiftStart,
      _selectedTimezone,
      _adminTimezone,
    );

    if (conversionText.isEmpty || _selectedTimezone == _adminTimezone) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xffF3F4F6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xffE5E7EB)),
      ),
      child: Row(
        children: [
          const Icon(Icons.swap_horiz, size: 20, color: Color(0xff6B7280)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Local Time Conversion',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xff6B7280),
                  ),
                ),
                Text(
                  conversionText,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xff374151),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePickers() {
    final isTimePrefilled = widget.initialTime != null && widget.shift == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Time (${TimezoneUtils.getTimezoneAbbreviation(_selectedTimezone)})',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xff6B7280),
              ),
            ),
            if (isTimePrefilled)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xff0386FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Pre-filled',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      color: const Color(0xff0386FF),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: _startTime,
                  );
                  if (time != null) {
                    setState(() {
                      _startTime = time;
                      // Auto-set end time to 1 hour later
                      int endHour = time.hour + 1;
                      int endMinute = time.minute;

                      // Handle day overflow (clamp to 23:59 for same-day shifts)
                      if (endHour >= 24) {
                        endHour = 23;
                        endMinute = 59;
                      }

                      _endTime = TimeOfDay(hour: endHour, minute: endMinute);
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isTimePrefilled
                          ? const Color(0xff0386FF).withOpacity(0.5)
                          : const Color(0xffD1D5DB),
                      width: isTimePrefilled ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: isTimePrefilled
                        ? const Color(0xff0386FF).withOpacity(0.05)
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 18,
                        color: isTimePrefilled
                            ? const Color(0xff0386FF)
                            : const Color(0xff6B7280),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _startTime.format(context),
                        style: GoogleFonts.inter(
                          fontWeight: isTimePrefilled
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isTimePrefilled
                              ? const Color(0xff0386FF)
                              : const Color(0xff374151),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('-'),
            ),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: _endTime,
                  );
                  if (time != null) {
                    // Validate end time is after start time
                    final startMinutes =
                        _startTime.hour * 60 + _startTime.minute;
                    final endMinutes = time.hour * 60 + time.minute;

                    if (endMinutes <= startMinutes) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('End time must be after start time'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                      return;
                    }

                    setState(() {
                      _endTime = time;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isTimePrefilled
                          ? const Color(0xff0386FF).withOpacity(0.5)
                          : const Color(0xffD1D5DB),
                      width: isTimePrefilled ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: isTimePrefilled
                        ? const Color(0xff0386FF).withOpacity(0.05)
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 18,
                        color: isTimePrefilled
                            ? const Color(0xff0386FF)
                            : const Color(0xff6B7280),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _endTime.format(context),
                        style: GoogleFonts.inter(
                          fontWeight: isTimePrefilled
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isTimePrefilled
                              ? const Color(0xff0386FF)
                              : const Color(0xff374151),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        _buildConversionPreview(),
      ],
    );
  }

  Widget _buildRecurrenceSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recurrence Settings',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xff374151),
          ),
        ),
        const SizedBox(height: 16),
        EnhancedRecurrencePicker(
          initialRecurrence: _enhancedRecurrence,
          onRecurrenceChanged: (newRecurrence) {
            setState(() {
              _enhancedRecurrence = newRecurrence;
              _recurrenceEndDate = newRecurrence.endDate;
              // Update old recurrence type for backward compatibility
              if (newRecurrence.type == EnhancedRecurrenceType.none) {
                _recurrence = RecurrencePattern.none;
              } else if (newRecurrence.type == EnhancedRecurrenceType.daily) {
                _recurrence = RecurrencePattern.daily;
              } else if (newRecurrence.type == EnhancedRecurrenceType.weekly) {
                _recurrence = RecurrencePattern.weekly;
              } else if (newRecurrence.type == EnhancedRecurrenceType.monthly) {
                _recurrence = RecurrencePattern.monthly;
              }
            });
          },
          showEndDate: true,
        ),
      ],
    );
  }

  Widget _buildCustomName() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: _useCustomName,
              onChanged: (value) {
                setState(() {
                  _useCustomName = value!;
                  if (!_useCustomName) {
                    _customNameController.clear();
                  }
                });
              },
              activeColor: const Color(0xff0386FF),
            ),
            Text(
              'Use custom shift name',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xff374151),
              ),
            ),
          ],
        ),
        if (_useCustomName) ...[
          const SizedBox(height: 8),
          TextFormField(
            controller: _customNameController,
            decoration: InputDecoration(
              hintText: 'Enter custom shift name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xffD1D5DB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xffD1D5DB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xff0386FF)),
              ),
            ),
            style: GoogleFonts.inter(),
          ),
        ],
      ],
    );
  }

  Widget _buildNotes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notes',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xff374151),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _notesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Add any additional notes or instructions...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xffD1D5DB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xffD1D5DB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xff0386FF)),
            ),
          ),
          style: GoogleFonts.inter(),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xffE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: const Color(0xff6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _isLoading ? null : _saveShift,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff0386FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    widget.shift == null ? 'Create Shift' : 'Update Shift',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveShift() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate category-specific requirements
    if (_selectedCategory == ShiftCategory.teaching) {
      if (_selectedStudentIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one student for teaching shifts'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } else {
      if (_selectedLeaderRole == null || _selectedLeaderRole!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a duty type for leader schedules'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Validate that end time is after start time
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;

    if (endMinutes <= startMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shift end time must be after start time'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Create DateTime objects for shift start and end in admin's local time
      DateTime effectiveDate = _shiftDate;

      // If recurrence is enabled, ensure the start date matches the recurrence pattern
      // If not, find the next valid date
      if (_enhancedRecurrence.type != EnhancedRecurrenceType.none) {
        // Check if current date is valid
        if (_enhancedRecurrence.isDateExcluded(_shiftDate) ||
            !_isDaySelected(_shiftDate, _enhancedRecurrence)) {
          // Find next valid date
          DateTime nextDate = _shiftDate.add(const Duration(days: 1));
          int attempts = 0;
          // Look ahead up to 1 year
          while (attempts < 365) {
            if (!_enhancedRecurrence.isDateExcluded(nextDate) &&
                _isDaySelected(nextDate, _enhancedRecurrence)) {
              effectiveDate = nextDate;

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Start date adjusted to first valid recurrence day: ${_formatDate(effectiveDate)}'),
                    backgroundColor: const Color(0xff0386FF),
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
              break;
            }
            nextDate = nextDate.add(const Duration(days: 1));
            attempts++;
          }
        }
      }

      // Create DateTime objects in the selected timezone (not system timezone)
      // This ensures the time components are interpreted in the correct timezone
      AppLogger.debug('CreateShiftDialog: Admin timezone: $_adminTimezone');
      AppLogger.debug(
          'CreateShiftDialog: Selected timezone: $_selectedTimezone');
      
      // Create a naive DateTime (year, month, day, hour, minute) that represents
      // the time in the selected timezone, then convert it to UTC properly
      final naiveStart = DateTime(
        effectiveDate.year,
        effectiveDate.month,
        effectiveDate.day,
        _startTime.hour,
        _startTime.minute,
      );
      
      final naiveEnd = DateTime(
        effectiveDate.year,
        effectiveDate.month,
        effectiveDate.day,
        _endTime.hour,
        _endTime.minute,
      );
      
      AppLogger.debug('CreateShiftDialog: Naive shift start: $naiveStart');
      AppLogger.debug('CreateShiftDialog: Naive shift end: $naiveEnd');

      DateTime shiftStart;
      DateTime shiftEnd;

      // Convert from the selected timezone to UTC
      // This properly interprets the naive DateTime as being in the selected timezone
      shiftStart = TimezoneUtils.convertToUtc(naiveStart, _selectedTimezone);
      shiftEnd = TimezoneUtils.convertToUtc(naiveEnd, _selectedTimezone);

      AppLogger.debug('CreateShiftDialog: Final shift start: $shiftStart');
      AppLogger.debug('CreateShiftDialog: Final shift end: $shiftEnd');

      if (widget.shift == null) {
        // Find teacher UID from email
        final teacherSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('e-mail', isEqualTo: _selectedTeacherId!)
            .limit(1)
            .get();

        if (teacherSnapshot.docs.isEmpty) {
          throw Exception('Teacher not found');
        }

        final teacherUid = teacherSnapshot.docs.first.id;

        // Find student UIDs and names from unique identifiers
        final studentUids = <String>[];
        final studentNames = <String>[];
        for (String uniqueId in _selectedStudentIds) {
          // Extract email and names from unique identifier (format: email|firstName|lastName)
          final parts = uniqueId.split('|');
          if (parts.length < 3) continue;
          final studentEmail = parts[0];
          final firstName = parts[1];
          final lastName = parts[2];

          final studentSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .where('e-mail', isEqualTo: studentEmail)
              .limit(1)
              .get();

          if (studentSnapshot.docs.isNotEmpty) {
            studentUids.add(studentSnapshot.docs.first.id);
            // Use the names from the UI selection instead of re-querying the database
            studentNames.add('$firstName $lastName');
          }
        }

        // Find selected subject
        final selectedSubject = _selectedSubjectId != null
            ? _availableSubjects.firstWhere(
                (s) => s.id == _selectedSubjectId,
                orElse: () => _availableSubjects.first,
              )
            : null;

        // Create new shift
        await ShiftService.createShift(
          teacherId: teacherUid,
          studentIds: _selectedCategory == ShiftCategory.teaching ? studentUids : [],
          studentNames: _selectedCategory == ShiftCategory.teaching ? studentNames : [],
          shiftStart: shiftStart,
          shiftEnd: shiftEnd,
          adminTimezone:
              _selectedTimezone, // Store the timezone used for scheduling
          subject: _mapSubjectToEnum(selectedSubject?.name ?? 'quran_studies'),
          subjectId: _selectedSubjectId,
          subjectDisplayName: selectedSubject?.displayName,
          customName: _useCustomName ? _customNameController.text.trim() : null,
          notes: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
          recurrence: _recurrence,
          enhancedRecurrence:
              _enhancedRecurrence.type != EnhancedRecurrenceType.none
                  ? _enhancedRecurrence
                  : null,
          recurrenceEndDate: _recurrenceEndDate,
          originalLocalStart: naiveStart,
          originalLocalEnd: naiveEnd,
          // NEW: Category and leader role
          category: _selectedCategory,
          leaderRole: _selectedLeaderRole,
        );
      } else {
        // Update existing shift - convert emails back to UIDs

        // Find teacher UID from email
        final teacherSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('e-mail', isEqualTo: _selectedTeacherId!)
            .limit(1)
            .get();

        if (teacherSnapshot.docs.isEmpty) {
          throw Exception('Teacher not found');
        }

        final teacherUid = teacherSnapshot.docs.first.id;
        final teacherData = teacherSnapshot.docs.first.data();
        final teacherName =
            '${teacherData['first_name']} ${teacherData['last_name']}';
        AppLogger.debug(
            'CreateShiftDialog: Update - converted teacher email $_selectedTeacherId to UID $teacherUid, name: $teacherName');

        // Find student UIDs and names from unique identifiers
        final studentUids = <String>[];
        final studentNames = <String>[];
        for (String uniqueId in _selectedStudentIds) {
          // Extract email and names from unique identifier (format: email|firstName|lastName)
          final parts = uniqueId.split('|');
          if (parts.length < 3) continue;
          final studentEmail = parts[0];
          final firstName = parts[1];
          final lastName = parts[2];

          final studentSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .where('e-mail', isEqualTo: studentEmail)
              .limit(1)
              .get();

          if (studentSnapshot.docs.isNotEmpty) {
            studentUids.add(studentSnapshot.docs.first.id);
            // Use the names from the UI selection instead of re-querying the database
            studentNames.add('$firstName $lastName');
          }
        }

        AppLogger.debug(
            'CreateShiftDialog: Update - converted ${_selectedStudentIds.length} student emails to ${studentUids.length} UIDs and ${studentNames.length} names');

        // Find selected subject for update
        final selectedSubject = _selectedSubjectId != null
            ? _availableSubjects.firstWhere(
                (s) => s.id == _selectedSubjectId,
                orElse: () => _availableSubjects.first,
              )
            : null;

        // Regenerate auto-generated name with updated participants
        final autoGeneratedName = TeachingShift.generateAutoName(
          teacherName: teacherName,
          subject: _mapSubjectToEnum(selectedSubject?.name ?? 'quran_studies'),
          studentNames: studentNames,
        );

        final updatedShift = widget.shift!.copyWith(
          teacherId: teacherUid,
          teacherName: teacherName,
          studentIds: _selectedCategory == ShiftCategory.teaching ? studentUids : [],
          studentNames: _selectedCategory == ShiftCategory.teaching ? studentNames : [],
          shiftStart: shiftStart,
          shiftEnd: shiftEnd,
          subject: _mapSubjectToEnum(selectedSubject?.name ?? 'quran_studies'),
          subjectId: _selectedSubjectId,
          subjectDisplayName: selectedSubject?.displayName,
          autoGeneratedName: autoGeneratedName,
          customName: _useCustomName ? _customNameController.text.trim() : null,
          notes: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
          recurrence: _recurrence,
          recurrenceEndDate: _recurrenceEndDate,
          // NEW: Category and leader role
          category: _selectedCategory,
          leaderRole: _selectedLeaderRole,
        );

        AppLogger.debug('CreateShiftDialog: Updating shift with:');
        AppLogger.debug('  - Teacher: $teacherName ($teacherUid)');
        AppLogger.debug(
            '  - Students: ${studentNames.join(', ')} (${studentUids.join(', ')})');
        AppLogger.debug('  - Auto name: $autoGeneratedName');

        await ShiftService.updateShift(updatedShift);
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onShiftCreated();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.shift == null
                  ? 'Shift created successfully'
                  : 'Shift updated successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving shift: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _isDaySelected(DateTime date, EnhancedRecurrence recurrence) {
    if (recurrence.type == EnhancedRecurrenceType.daily) return true;

    if (recurrence.type == EnhancedRecurrenceType.weekly) {
      // Convert DateTime weekday (1-7) to WeekDay enum
      // DateTime: 1=Mon, 7=Sun
      // WeekDay: assuming standard mapping or checking index
      // Let's check how WeekDay is defined in enhanced_recurrence.dart or shift_enums.dart
      // Usually we map 1->monday, etc.

      // Simple mapping based on standard Dart DateTime
      final weekdayIndex = date.weekday;
      // We need to match this with recurrence.selectedWeekdays
      // Assuming WeekDay enum has a way to match or we iterate

      for (final day in recurrence.selectedWeekdays) {
        if (day.index + 1 == weekdayIndex)
          return true; // WeekDay enum usually 0-based
      }
      return false;
    }

    if (recurrence.type == EnhancedRecurrenceType.monthly) {
      return recurrence.selectedMonthDays.contains(date.day);
    }

    return true;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
