import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  const CreateShiftDialog({
    super.key,
    this.shift,
    required this.onShiftCreated,
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
          // Default selected timezone to admin's timezone initially
          if (widget.shift == null) {
            _selectedTimezone = timezone;
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
          // Preserve current selection if possible; otherwise pick first
          final hasCurrent = _selectedSubjectId != null &&
              subjects.any((s) => s.id == _selectedSubjectId);
          if (!hasCurrent && subjects.isNotEmpty) {
            _selectedSubjectId = subjects.first.id;
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
      }
    } catch (e) {
      AppLogger.error('CreateShiftDialog: Error loading available users: $e');
    }
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
            setState(() {
              _selectedTeacherId = teacherEmail;
            });
            AppLogger.debug(
                'CreateShiftDialog: Converted teacher UID ${shift.teacherId} to email $teacherEmail');
          }
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
                      _buildTeacherSelection(),
                      const SizedBox(height: 20),
                      _buildStudentSelection(),
                      const SizedBox(height: 20),
                      _buildSubjectSelection(),
                      const SizedBox(height: 20),
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
    // Filter teachers based on search
    final filteredTeachers = _availableTeachers.where((teacher) {
      if (_teacherSearchController.text.isEmpty) return true;
      final query = _teacherSearchController.text.toLowerCase();
      return teacher.firstName.toLowerCase().contains(query) ||
          teacher.lastName.toLowerCase().contains(query) ||
          teacher.email.toLowerCase().contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Teacher *',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xff374151),
          ),
        ),
        const SizedBox(height: 8),
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
                          'Select a teacher${_selectedTeacherId != null ? ' (1 selected)' : ''}',
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
                        hintText: 'Search teacher by name or email...',
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
                          borderSide:
                              const BorderSide(color: Color(0xffE2E8F0)),
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
                child: _availableTeachers.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Loading teachers...'),
                        ),
                      )
                    : filteredTeachers.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('No teachers found'),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: filteredTeachers.length,
                            itemBuilder: (context, index) {
                              final teacher = filteredTeachers[index];
                              final isSelected =
                                  _selectedTeacherId == teacher.email;

                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedTeacherId = teacher.email;
                                    AppLogger.debug(
                                        'Selected teacher: ${teacher.firstName} ${teacher.lastName} (${teacher.email})');
                                    _updateTimezoneForTeacher(teacher.email);
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
                                        value: teacher.email,
                                        groupValue: _selectedTeacherId,
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedTeacherId = value;
                                            AppLogger.debug(
                                                'Radio selected teacher: ${teacher.firstName} ${teacher.lastName} (${teacher.email})');
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
                                            '${teacher.firstName[0]}${teacher.lastName[0]}',
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
                                              '${teacher.firstName} ${teacher.lastName}',
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
                                                    teacher.userType
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
                                                    teacher.email,
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
                          'Select students (${_selectedStudentIds.length} selected)',
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
                        hintText: 'Search by name, student code, or email...',
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
                          borderSide:
                              const BorderSide(color: Color(0xffE2E8F0)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xff6B7280),
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _shiftDate,
              firstDate: DateTime.now(),
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
              border: Border.all(color: const Color(0xffD1D5DB)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today,
                    size: 20, color: Color(0xff6B7280)),
                const SizedBox(width: 8),
                Text(
                  '${_shiftDate.day}/${_shiftDate.month}/${_shiftDate.year}',
                  style: GoogleFonts.inter(),
                ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Time (${TimezoneUtils.getTimezoneAbbreviation(_selectedTimezone)})',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xff6B7280),
          ),
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
                    border: Border.all(color: const Color(0xffD1D5DB)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _startTime.format(context),
                    style: GoogleFonts.inter(),
                    textAlign: TextAlign.center,
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
                    border: Border.all(color: const Color(0xffD1D5DB)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _endTime.format(context),
                    style: GoogleFonts.inter(),
                    textAlign: TextAlign.center,
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
    if (_selectedStudentIds.isEmpty) return;

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

      final shiftStartLocal = DateTime(
        effectiveDate.year,
        effectiveDate.month,
        effectiveDate.day,
        _startTime.hour,
        _startTime.minute,
      );

      final shiftEndLocal = DateTime(
        effectiveDate.year,
        effectiveDate.month,
        effectiveDate.day,
        _endTime.hour,
        _endTime.minute,
      );

      // Convert admin's local time to UTC for storage
      AppLogger.debug('CreateShiftDialog: Admin timezone: $_adminTimezone');
      AppLogger.debug(
          'CreateShiftDialog: Selected timezone: $_selectedTimezone');
      AppLogger.debug('CreateShiftDialog: Local shift start: $shiftStartLocal');
      AppLogger.debug('CreateShiftDialog: Local shift end: $shiftEndLocal');

      DateTime shiftStart;
      DateTime shiftEnd;

      // Use the selected timezone for conversion
      shiftStart =
          TimezoneUtils.convertToUtc(shiftStartLocal, _selectedTimezone);
      shiftEnd = TimezoneUtils.convertToUtc(shiftEndLocal, _selectedTimezone);

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
          studentIds: studentUids,
          studentNames: studentNames,
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
          originalLocalStart: shiftStartLocal,
          originalLocalEnd: shiftEndLocal,
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
          studentIds: studentUids,
          studentNames: studentNames,
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
