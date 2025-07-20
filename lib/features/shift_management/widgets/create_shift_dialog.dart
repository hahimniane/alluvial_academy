import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/teaching_shift.dart';
import '../../../core/models/employee_model.dart';
import '../../../core/services/shift_service.dart';

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
  List<String> _selectedStudentIds = [];
  DateTime _shiftDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = const TimeOfDay(hour: 14, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 16, minute: 0);
  IslamicSubject _selectedSubject = IslamicSubject.quranStudies;
  RecurrencePattern _recurrence = RecurrencePattern.none;
  DateTime? _recurrenceEndDate;

  // Data lists
  List<Employee> _availableTeachers = [];
  List<Employee> _availableStudents = [];

  // Timezone (simplified - in production use proper timezone library)
  final String _adminTimezone = 'EST'; // Get from user preferences

  @override
  void initState() {
    super.initState();
    _loadAvailableUsers();
    _initializeFormData();
  }

  @override
  void dispose() {
    _customNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableUsers() async {
    try {
      print('CreateShiftDialog: Loading available users...');

      // Try the ShiftService first
      var teachers = await ShiftService.getAvailableTeachers();
      var students = await ShiftService.getAvailableStudents();

      print(
          'CreateShiftDialog: ShiftService returned ${teachers.length} teachers and ${students.length} students');

      // If ShiftService returns empty, try loading all employees and filter locally
      if (teachers.isEmpty && students.isEmpty) {
        print(
            'CreateShiftDialog: ShiftService returned empty, trying direct Firestore query...');

        try {
          final snapshot =
              await FirebaseFirestore.instance.collection('users').get();
          print(
              'CreateShiftDialog: Found ${snapshot.docs.length} total employees');

          final allEmployees =
              EmployeeDataSource.mapSnapshotToEmployeeList(snapshot);
          print('CreateShiftDialog: Mapped ${allEmployees.length} employees');

          teachers =
              allEmployees.where((emp) => emp.userType == 'teacher').toList();
          students =
              allEmployees.where((emp) => emp.userType == 'student').toList();

          print(
              'CreateShiftDialog: Filtered to ${teachers.length} teachers and ${students.length} students');

          // Debug: Print first teacher and student if found
          if (teachers.isNotEmpty) {
            print(
                'First teacher: ${teachers.first.firstName} ${teachers.first.lastName} (${teachers.first.email})');
          }
          if (students.isNotEmpty) {
            print(
                'First student: ${students.first.firstName} ${students.first.lastName} (${students.first.email})');
          }
        } catch (e) {
          print('CreateShiftDialog: Error with direct query: $e');
        }
      }

      if (mounted) {
        setState(() {
          _availableTeachers = teachers;
          _availableStudents = students;
        });
        print(
            'CreateShiftDialog: State updated with teachers: ${_availableTeachers.length}, students: ${_availableStudents.length}');

        // Convert UIDs to emails for editing mode
        _convertUidsToEmails();
      }
    } catch (e) {
      print('CreateShiftDialog: Error loading available users: $e');
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
            print(
                'CreateShiftDialog: Converted teacher UID ${shift.teacherId} to email $teacherEmail');
          }
        }

        // Convert student UIDs to emails by querying Firestore
        final studentEmails = <String>[];
        for (String studentUid in shift.studentIds) {
          final studentDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(studentUid)
              .get();

          if (studentDoc.exists) {
            final studentData = studentDoc.data() as Map<String, dynamic>;
            final studentEmail = studentData['e-mail'] as String?;
            if (studentEmail != null) {
              studentEmails.add(studentEmail);
            }
          }
        }

        if (mounted) {
          setState(() {
            _selectedStudentIds = studentEmails;
          });
          print(
              'CreateShiftDialog: Converted ${shift.studentIds.length} student UIDs to ${studentEmails.length} emails');
        }
      } catch (e) {
        print('CreateShiftDialog: Error converting UIDs to emails: $e');
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
      _selectedSubject = shift.subject;
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
        _availableTeachers.isEmpty
            ? Container(
                height: 48,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xffD1D5DB)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text('Loading teachers...'),
                ),
              )
            : DropdownButtonFormField<String>(
                value: _selectedTeacherId,
                decoration: InputDecoration(
                  hintText: 'Select a teacher',
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
                items: _availableTeachers.map((teacher) {
                  return DropdownMenuItem<String>(
                    value: teacher.email,
                    child: Text(
                      '${teacher.firstName} ${teacher.lastName}',
                      style: GoogleFonts.inter(),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedTeacherId = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a teacher';
                  }
                  return null;
                },
              ),
      ],
    );
  }

  Widget _buildStudentSelection() {
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
                child: Text(
                  'Select students for this shift',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xff6B7280),
                  ),
                ),
              ),
              const Divider(height: 1),
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                child: _availableStudents.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Loading students...'),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _availableStudents.length,
                        itemBuilder: (context, index) {
                          final student = _availableStudents[index];
                          final isSelected =
                              _selectedStudentIds.contains(student.email);

                          return InkWell(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedStudentIds.remove(student.email);
                                } else {
                                  _selectedStudentIds.add(student.email);
                                }
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
                                              .add(student.email);
                                        } else {
                                          _selectedStudentIds
                                              .remove(student.email);
                                        }
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
                                        Text(
                                          student.email,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: const Color(0xff6B7280),
                                          ),
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
        Text(
          'Subject *',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xff374151),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<IslamicSubject>(
          value: _selectedSubject,
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
          items: IslamicSubject.values.map((subject) {
            return DropdownMenuItem<IslamicSubject>(
              value: subject,
              child: Text(
                _getSubjectDisplayName(subject),
                style: GoogleFonts.inter(),
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedSubject = value!;
            });
          },
        ),
      ],
    );
  }

  String _getSubjectDisplayName(IslamicSubject subject) {
    switch (subject) {
      case IslamicSubject.quranStudies:
        return 'Quran Studies';
      case IslamicSubject.hadithStudies:
        return 'Hadith Studies';
      case IslamicSubject.fiqh:
        return 'Islamic Jurisprudence (Fiqh)';
      case IslamicSubject.arabicLanguage:
        return 'Arabic Language';
      case IslamicSubject.islamicHistory:
        return 'Islamic History';
      case IslamicSubject.aqeedah:
        return 'Islamic Creed (Aqeedah)';
      case IslamicSubject.tafseer:
        return 'Quran Interpretation (Tafseer)';
      case IslamicSubject.seerah:
        return 'Prophet\'s Biography (Seerah)';
    }
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

  Widget _buildTimePickers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Time',
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
      ],
    );
  }

  Widget _buildRecurrenceSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recurrence',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xff374151),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<RecurrencePattern>(
          value: _recurrence,
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
          items: RecurrencePattern.values.map((pattern) {
            return DropdownMenuItem<RecurrencePattern>(
              value: pattern,
              child: Text(
                _getRecurrenceDisplayName(pattern),
                style: GoogleFonts.inter(),
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _recurrence = value!;
              if (_recurrence == RecurrencePattern.none) {
                _recurrenceEndDate = null;
              }
            });
          },
        ),
        if (_recurrence != RecurrencePattern.none) ...[
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _recurrenceEndDate ??
                    DateTime.now().add(const Duration(days: 30)),
                firstDate: _shiftDate.add(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) {
                setState(() {
                  _recurrenceEndDate = date;
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
                  const Icon(Icons.event, size: 20, color: Color(0xff6B7280)),
                  const SizedBox(width: 8),
                  Text(
                    _recurrenceEndDate != null
                        ? 'Repeat until ${_recurrenceEndDate!.day}/${_recurrenceEndDate!.month}/${_recurrenceEndDate!.year}'
                        : 'Select end date for recurrence',
                    style: GoogleFonts.inter(
                      color: _recurrenceEndDate != null
                          ? const Color(0xff374151)
                          : const Color(0xff9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _getRecurrenceDisplayName(RecurrencePattern pattern) {
    switch (pattern) {
      case RecurrencePattern.none:
        return 'No Recurrence';
      case RecurrencePattern.daily:
        return 'Daily';
      case RecurrencePattern.weekly:
        return 'Weekly';
      case RecurrencePattern.monthly:
        return 'Monthly';
    }
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

    setState(() => _isLoading = true);

    try {
      // Create DateTime objects for shift start and end
      final shiftStart = DateTime(
        _shiftDate.year,
        _shiftDate.month,
        _shiftDate.day,
        _startTime.hour,
        _startTime.minute,
      );

      final shiftEnd = DateTime(
        _shiftDate.year,
        _shiftDate.month,
        _shiftDate.day,
        _endTime.hour,
        _endTime.minute,
      );

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

        // Find student UIDs from emails
        final studentUids = <String>[];
        for (String studentEmail in _selectedStudentIds) {
          final studentSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .where('e-mail', isEqualTo: studentEmail)
              .limit(1)
              .get();

          if (studentSnapshot.docs.isNotEmpty) {
            studentUids.add(studentSnapshot.docs.first.id);
          }
        }

        // Create new shift
        await ShiftService.createShift(
          teacherId: teacherUid,
          studentIds: studentUids,
          shiftStart: shiftStart,
          shiftEnd: shiftEnd,
          adminTimezone: _adminTimezone,
          subject: _selectedSubject,
          customName: _useCustomName ? _customNameController.text.trim() : null,
          notes: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
          recurrence: _recurrence,
          recurrenceEndDate: _recurrenceEndDate,
        );
      } else {
        // Update existing shift
        final updatedShift = widget.shift!.copyWith(
          teacherId: _selectedTeacherId,
          studentIds: _selectedStudentIds,
          shiftStart: shiftStart,
          shiftEnd: shiftEnd,
          subject: _selectedSubject,
          customName: _useCustomName ? _customNameController.text.trim() : null,
          notes: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
          recurrence: _recurrence,
          recurrenceEndDate: _recurrenceEndDate,
        );

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
}
