import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart' as constants;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/timesheet_table.dart' show TimesheetTable;

class TimeClockScreen extends StatefulWidget {
  const TimeClockScreen({super.key});

  @override
  _TimeClockScreenState createState() => _TimeClockScreenState();
}

class _TimeClockScreenState extends State<TimeClockScreen> {
  List<Map<String, dynamic>> _students = [];
  bool _isLoadingStudents = false;

  bool _isClockingIn = false;
  String _selectedStudentName = '';
  DateTime? _clockInTime;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  String _totalHoursWorked = "00:00:00";

  final List<dynamic> _timesheetEntries = [];

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    if (!mounted) return;
    setState(() {
      _isLoadingStudents = true;
    });

    try {
      final QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('user_type', isEqualTo: 'student')
          .get();

      List<Map<String, dynamic>> students = [];

      for (QueryDocumentSnapshot doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        String displayName = 'Unknown Student';
        if (data['first_name'] != null && data['last_name'] != null) {
          displayName = '${data['first_name']} ${data['last_name']}';
        } else if (data['first_name'] != null) {
          displayName = data['first_name'];
        } else if (data['last_name'] != null) {
          displayName = data['last_name'];
        } else if (data['email'] != null) {
          displayName = data['email'].split('@')[0];
        }

        students.add({
          'id': doc.id,
          'name': displayName,
          'email': data['email'] ?? '',
          'grade': data['title'] ?? 'Student',
          'kiosk_code': data['kiosk_code'] ?? '',
        });
      }

      students
          .sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));

      if (!mounted) return;
      setState(() {
        _students = students;
        _isLoadingStudents = false;
      });
    } catch (e) {
      print('Error loading students: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingStudents = false;
      });
    }
  }

  void _handleStudentSelection(Map<String, dynamic> student) {
    Navigator.of(context).pop();
    _startTeachingSession(student);
  }

  void _startTeachingSession(Map<String, dynamic> student) {
    if (!mounted) return;
    setState(() {
      _isClockingIn = true;
      _selectedStudentName = student['name'];
      _clockInTime = DateTime.now();
      _totalHoursWorked = "00:00:00"; // Reset timer display
      _stopwatch.reset(); // Make sure stopwatch is reset
      _stopwatch.start();
      _startTimer();
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _updateTotalHours();
      });
    });
  }

  void _updateTotalHours() {
    final elapsed = _stopwatch.elapsed;
    final hours = elapsed.inHours.toString().padLeft(2, '0');
    final minutes = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    _totalHoursWorked = '$hours:$minutes:$seconds';
    print(
        'Timer update: $_totalHoursWorked (elapsed: ${elapsed.inSeconds}s)'); // Debug
  }

  void _clockOut() async {
    if (!_isClockingIn || _clockInTime == null) return;

    final now = DateTime.now();
    final startTime = DateFormat('h:mm a').format(_clockInTime!);
    final endTime = DateFormat('h:mm a').format(now);

    // Calculate final hours without seconds for storage
    final elapsed = _stopwatch.elapsed;
    final hours = elapsed.inHours.toString().padLeft(2, '0');
    final minutes = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final totalHours = '$hours:$minutes';

    // Create a simple entry for the clock-in entries list
    final clockInEntry = {
      'date': DateFormat('EEE MM/dd').format(now),
      'type': _selectedStudentName,
      'start': startTime,
      'end': endTime,
      'totalHours': totalHours,
    };

    if (!mounted) return;
    setState(() {
      _timesheetEntries.insert(0, clockInEntry);
      _isClockingIn = false;
      _stopwatch.stop();
      _timer?.cancel();
      _stopwatch.reset();
      _clockInTime = null;
      _selectedStudentName = '';
    });

    // Save to Firebase
    bool savedSuccessfully = await _saveToFirebase(clockInEntry);

    // If saved successfully, remove from local list to avoid duplicates
    if (savedSuccessfully && mounted) {
      setState(() {
        _timesheetEntries.removeWhere((entry) =>
            entry is Map<String, dynamic> &&
            entry['date'] == clockInEntry['date'] &&
            entry['type'] == clockInEntry['type'] &&
            entry['start'] == clockInEntry['start'] &&
            entry['end'] == clockInEntry['end']);
      });
    }

    // Show confirmation
    _showClockOutConfirmation(clockInEntry);
  }

  Future<bool> _saveToFirebase(Map<String, dynamic> entry) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('User not authenticated, cannot save timesheet entry');
        return false;
      }

      await FirebaseFirestore.instance.collection('timesheet_entries').add({
        'teacher_id': user.uid,
        'teacher_email': user.email,
        'date': entry['date'],
        'student_name': entry['type'],
        'start_time': entry['start'],
        'end_time': entry['end'],
        'break_duration': '15 min',
        'total_hours': entry['totalHours'],
        'description': 'Teaching session with ${entry['type']}',
        'status': 'draft',
        'source': 'clock_in',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      print('Clock-in entry saved to Firebase successfully');
      return true;
    } catch (e) {
      print('Error saving clock-in entry to Firebase: $e');
      return false;
    }
  }

  void _showClockOutConfirmation(Map<String, dynamic> entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Session Completed',
              style: constants.openSansHebrewTextStyle.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your teaching session has been recorded:',
              style: constants.openSansHebrewTextStyle.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Student:', entry['type']),
                  _buildInfoRow('Date:', entry['date']),
                  _buildInfoRow('Time:', '${entry['start']} - ${entry['end']}'),
                  _buildInfoRow('Total Hours:', entry['totalHours']),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'This entry has been saved as a draft. You can review and submit it for approval in the timesheet below.',
              style: constants.openSansHebrewTextStyle.copyWith(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff0386FF),
              foregroundColor: Colors.white,
            ),
            child: const Text('View Timesheet'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: constants.openSansHebrewTextStyle.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: constants.openSansHebrewTextStyle.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showStudentSelectionPopup(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) {
        String localSearchQuery = '';
        List<Map<String, dynamic>> localFilteredStudents = List.from(_students);
        TextEditingController localSearchController = TextEditingController();

        return StatefulBuilder(
          builder: (context, dialogSetState) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(
                maxWidth: 500,
                maxHeight: 600,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      color: Color(0xffF8FAFC),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xff0386FF).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.school,
                            color: Color(0xff0386FF),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Select Student',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xff111827),
                                ),
                              ),
                              Text(
                                'Choose a student to clock in',
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
                          icon: const Icon(
                            Icons.close,
                            color: Color(0xff6B7280),
                            size: 20,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Search field
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xffF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xffE5E7EB)),
                      ),
                      child: TextField(
                        controller: localSearchController,
                        onChanged: (value) {
                          dialogSetState(() {
                            localSearchQuery = value.toLowerCase();
                            if (localSearchQuery.isEmpty) {
                              localFilteredStudents = _students;
                            } else {
                              localFilteredStudents =
                                  _students.where((student) {
                                return student['name']
                                        .toLowerCase()
                                        .contains(localSearchQuery) ||
                                    student['email']
                                        .toLowerCase()
                                        .contains(localSearchQuery) ||
                                    student['grade']
                                        .toLowerCase()
                                        .contains(localSearchQuery) ||
                                    student['kiosk_code']
                                        .toLowerCase()
                                        .contains(localSearchQuery);
                              }).toList();
                            }
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search students...',
                          hintStyle: GoogleFonts.inter(
                            color: const Color(0xff9CA3AF),
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Color(0xff9CA3AF),
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Students list
                  Flexible(
                    child: _isLoadingStudents
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: CircularProgressIndicator(
                                color: Color(0xff0386FF),
                              ),
                            ),
                          )
                        : localFilteredStudents.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.search_off,
                                        size: 48,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        localSearchQuery.isEmpty
                                            ? 'No students found'
                                            : 'No students match your search',
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          color: const Color(0xff6B7280),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                itemCount: localFilteredStudents.length,
                                separatorBuilder: (context, index) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final student = localFilteredStudents[index];
                                  return InkWell(
                                    onTap: () =>
                                        _handleStudentSelection(student),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 20,
                                            backgroundColor:
                                                const Color(0xff0386FF)
                                                    .withOpacity(0.1),
                                            child: Text(
                                              student['name'][0].toUpperCase(),
                                              style: GoogleFonts.inter(
                                                color: const Color(0xff0386FF),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  student['name'],
                                                  style: GoogleFonts.inter(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                    color:
                                                        const Color(0xff111827),
                                                  ),
                                                ),
                                                if (student['email'].isNotEmpty)
                                                  Text(
                                                    student['email'],
                                                    style: GoogleFonts.inter(
                                                      fontSize: 12,
                                                      color: const Color(
                                                          0xff6B7280),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          if (student['kiosk_code'].isNotEmpty)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xff0386FF)
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                student['kiosk_code'],
                                                style: GoogleFonts.inter(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w500,
                                                  color:
                                                      const Color(0xff0386FF),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                  // Footer
                  if (!_isLoadingStudents && localFilteredStudents.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xffF9FAFB),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${localFilteredStudents.length} student${localFilteredStudents.length == 1 ? '' : 's'} found',
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
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Clock-in section
          Container(
            height: 250,
            padding: const EdgeInsets.all(16),
            child: Card(
              color: Colors.white,
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's Clock",
                      style: constants.openSansHebrewTextStyle.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Center(
                        child: _isClockingIn
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Teaching: $_selectedStudentName',
                                      style: constants.openSansHebrewTextStyle
                                          .copyWith(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xff0386FF),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _totalHoursWorked,
                                    style: constants.openSansHebrewTextStyle
                                        .copyWith(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _clockOut,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(100, 40),
                                    ),
                                    child: const Text('Stop'),
                                  ),
                                ],
                              )
                            : ElevatedButton(
                                onPressed: () =>
                                    _showStudentSelectionPopup(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xff0386FF),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(100, 40),
                                ),
                                child: const Text('Clock In'),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Timesheet section
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TimesheetTable(
                clockInEntries: _timesheetEntries,
                key: ValueKey(_timesheetEntries.length),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
