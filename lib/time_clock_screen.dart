import 'dart:async';

import 'package:alluwalacademyadmin/widgets/export_widget.dart';
import 'package:flutter/material.dart';
import 'package:alluwalacademyadmin/const.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart'; // Assuming you have this package for the text style

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';

import 'add_new_user_screen.dart';
import 'model/employee_model_class.dart';
import 'package:intl/intl.dart';

class TimeClockScreen extends StatefulWidget {
  const TimeClockScreen({super.key});

  @override
  _TimeClockScreenState createState() => _TimeClockScreenState();
}

class _TimeClockScreenState extends State<TimeClockScreen> {
  OverlayEntry? _overlayEntry;
  bool _isHovered = false;
  PickerDateRange? _selectedDateRange;
  final GlobalKey _totalHoursKey = GlobalKey();
  final GlobalKey _clockCardKey = GlobalKey();

  final List<Map<String, dynamic>> _jobs = [
    {'title': 'Front Desk', 'color': Colors.blue},
    {'title': 'Customer Service', 'color': Colors.green},
    {'title': 'Project A', 'color': Colors.orange},
    {'title': 'Staff Manager', 'color': Colors.purple},
  ];

  final List<Map<String, dynamic>> _students = [
    {'name': 'John Doe', 'grade': '10th'},
    {'name': 'Jane Smith', 'grade': '11th'},
    {'name': 'Mike Johnson', 'grade': '9th'},
    // Add more students as needed
  ];

  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredStudents = [];

  bool _isClockingIn = false;
  String _selectedStudentName = '';
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  String _totalHoursWorked = "00:00";

  final TextEditingController _studentSearchController =
      TextEditingController();

  String selectedStudent = 'Select student';

  final List<TimesheetEntry> _timesheetEntries = [];

  @override
  void initState() {
    super.initState();
    _filteredStudents = _students;
    _searchController.addListener(_filterStudents);
  }

  void _filterStudents() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredStudents = _students.where((student) {
        return student['name'].toLowerCase().contains(query) ||
            student['grade'].toLowerCase().contains(query);
      }).toList();
    });
  }

  void _handleStudentSelection(Map<String, dynamic> student) {
    _overlayEntry?.remove();
    setState(() {
      _isClockingIn = true;
      _selectedStudentName = student['name'];
      _stopwatch.start();
      _startTimer();
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {});
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  Future<void> _selectDateRange(BuildContext context) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Create a default date range if none is selected
        DateTimeRange defaultRange = DateTimeRange(
          start: DateTime.now(),
          end: DateTime.now().add(const Duration(days: 14)),
        );

        // Use the existing range or default range
        DateTimeRange initialRange = _selectedDateRange != null
            ? DateTimeRange(
                start: _selectedDateRange!.startDate!,
                end: _selectedDateRange!.endDate ??
                    _selectedDateRange!.startDate!,
              )
            : defaultRange;

        return Dialog(
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.4,
            height: MediaQuery.of(context).size.height * 0.6,
            child: Theme(
              data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context).colorScheme.copyWith(
                      primary: Colors.blue,
                      onPrimary: Colors.white,
                      onSurface: Colors.black,
                    ),
              ),
              child: DateRangePickerDialog(
                switchToInputEntryModeIcon: const Icon(Icons.calendar_month),
                firstDate: DateTime(2020),
                lastDate: DateTime(2025),
                initialDateRange: initialRange,
                cancelText: null,
                confirmText: 'Save',
                helpText: 'Select Date Range',
              ),
            ),
          ),
        );
      },
    ).then((value) {
      if (value != null && value is DateTimeRange) {
        setState(() {
          _selectedDateRange = PickerDateRange(value.start, value.end);
        });
      }
    });
  }

  void _updateTotalHours(Duration sessionDuration) {
    setState(() {
      // Convert current total to minutes
      List<String> parts = _totalHoursWorked.split(':');
      int totalMinutes = (int.parse(parts[0]) * 60) + int.parse(parts[1]);

      // Calculate total seconds and convert to minutes
      int sessionSeconds = sessionDuration.inSeconds;
      int remainderSeconds =
          sessionSeconds % 60; // Get remaining seconds after full minutes
      int fullMinutes = sessionSeconds ~/ 60; // Get complete minutes

      // Add an extra minute if more than 30 seconds
      int additionalMinutes = fullMinutes + (remainderSeconds >= 30 ? 1 : 0);

      // Add new session minutes
      totalMinutes += additionalMinutes;

      // Convert back to hours and minutes
      int hours = totalMinutes ~/ 60;
      int minutes = totalMinutes % 60;

      // Format the string
      _totalHoursWorked = '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}';

      print('Session seconds: $sessionSeconds');
      print('Remainder seconds: $remainderSeconds');
      print('Full minutes: $fullMinutes');
      print('Additional minutes: $additionalMinutes');
      print('Updated total hours: $_totalHoursWorked');
    });
  }

  void _handleClockOut() {
    final elapsed = _stopwatch.elapsed;
    final now = DateTime.now();

    // Format times
    final startTime = DateFormat('hh:mm a').format(now.subtract(elapsed));
    final endTime = DateFormat('hh:mm a').format(now);
    final totalHours =
        _formatDuration(elapsed).substring(0, 5); // Get HH:mm only

    // Calculate daily total
    final todayEntries = _timesheetEntries
        .where((entry) => entry.date == DateFormat('EEE M/d').format(now))
        .toList();

    Duration dailyTotalDuration = elapsed;
    for (var entry in todayEntries) {
      final parts = entry.totalHours.split(':');
      dailyTotalDuration += Duration(
        hours: int.parse(parts[0]),
        minutes: int.parse(parts[1]),
      );
    }

    final dailyTotal = _formatDuration(dailyTotalDuration).substring(0, 5);

    // Create new entry
    final newEntry = TimesheetEntry(
      date: DateFormat('EEE M/d').format(now),
      type: _selectedStudentName,
      start: startTime,
      end: endTime,
      totalHours: totalHours,
      dailyTotal: dailyTotal,
      typeColor: Colors.purple, // You can adjust this based on the type
    );

    setState(() {
      _timesheetEntries.insert(0, newEntry);
      _isClockingIn = false;
      _stopwatch.stop();
      _timer?.cancel();
      _stopwatch.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      // const Color(0xffF6F6F6),
      body: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
                _buildTopSection(context, constraints),
                BuildTimeSheetSection(entries: _timesheetEntries)
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopSection(BuildContext context, BoxConstraints constraints) {
    double containerHeight = constraints.maxHeight * 0.30;

    return SizedBox(
      height: containerHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildClockCard(context, containerHeight),
          _buildRequestsCard(context, containerHeight),
        ],
      ),
    );
  }

  Widget _buildClockCard(BuildContext context, double height) {
    return Expanded(
      flex: 2,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SizedBox(
          key: _clockCardKey,
          height: height,
          child: Card(
            color: Colors.white,
            elevation: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildClockHeader(),
                    _buildTotalWorkHours(),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: _buildClockButton(context, height),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClockHeader() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Text(
        "Today's clock",
        style: openSansHebrewTextStyle.copyWith(
          fontWeight: FontWeight.w700,
          color: Colors.black,
          fontSize: 20,
        ),
      ),
    );
  }

  Widget _buildClockButton(BuildContext context, double height) {
    double iconSize = height * 0.1;

    if (_isClockingIn) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
              child: Column(
                children: [
                  Text(
                    _formatDuration(_stopwatch.elapsed),
                    style: openSansHebrewTextStyle.copyWith(
                      fontSize: 36,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xff31C5DA),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedStudentName,
                    style: openSansHebrewTextStyle.copyWith(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _handleClockOut,
              style: TextButton.styleFrom(
                backgroundColor: Colors.red[400],
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                'Stop',
                style: openSansHebrewTextStyle.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      alignment: Alignment.center,
      child: TextButton(
        style: TextButton.styleFrom(overlayColor: Colors.white),
        onPressed: () {
          final RenderBox box = context.findRenderObject() as RenderBox;
          final Offset position = box.localToGlobal(Offset.zero);

          showDialog(
            context: context,
            barrierColor: Colors.transparent,
            builder: (context) => Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(color: Colors.transparent),
                  ),
                ),
                Positioned(
                  right: 16, // Position from right edge
                  top: 120, // Position below the header
                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 300,
                      constraints: const BoxConstraints(maxHeight: 400),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(8),
                                topRight: Radius.circular(8),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Select Student',
                                  style: openSansHebrewTextStyle.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.close, size: 20),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search students...',
                                prefixIcon: const Icon(Icons.search,
                                    color: Colors.grey),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _students.length,
                              itemBuilder: (context, index) {
                                final student = _students[index];
                                return ListTile(
                                  title: Text(student['name']),
                                  subtitle: Text(student['grade']),
                                  onTap: () {
                                    setState(() {
                                      selectedStudent = student['name'];
                                    });
                                    Navigator.pop(context);
                                    _handleStudentSelection(student);
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          padding: const EdgeInsets.all(20),
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: Transform.scale(
                scale: _isHovered ? 1.2 : 1.0,
                child: Container(
                  width: iconSize * 3.0,
                  height: iconSize * 3.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Colors.blue, Color(0xff31C5DA)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        spreadRadius: _isHovered ? 4 : 2,
                        blurRadius: _isHovered ? 10 : 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        color: Colors.white,
                        size: iconSize,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Clock in',
                        style: openSansHebrewTextStyle.copyWith(
                          color: Colors.white,
                          fontSize: iconSize * 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTotalWorkHours() {
    return Padding(
      key: _totalHoursKey,
      padding: const EdgeInsets.all(12.0),
      child: Card(
        elevation: 2,
        color: const Color(0xffF5F5F5),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Text(
                "Total Work hours today:",
                style: openSansHebrewTextStyle.copyWith(
                  fontWeight: FontWeight.w400,
                  color: const Color(0xff3f4648),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3.0),
                child: Text(
                  _totalHoursWorked,
                  style: openSansHebrewTextStyle.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStudentSelectionDialog(BuildContext context, Offset position) {
    final RenderBox? clockCardBox =
        _clockCardKey.currentContext?.findRenderObject() as RenderBox?;
    if (clockCardBox != null) {
      final containerWidth = clockCardBox.size.width;
      final containerHeight = clockCardBox.size.height;
      final Offset clockCardPosition = clockCardBox.localToGlobal(Offset.zero);

      _overlayEntry = OverlayEntry(
        builder: (context) => Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => _overlayEntry?.remove(),
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ),
            Positioned(
              left: clockCardPosition.dx +
                  containerWidth -
                  (containerWidth * 0.3),
              top: clockCardPosition.dy,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: containerWidth * 0.3,
                  height: containerHeight,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Select Student',
                              style: openSansHebrewTextStyle.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () => _overlayEntry?.remove(),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8.0),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search...',
                            prefixIcon:
                                const Icon(Icons.search, color: Colors.grey),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _filteredStudents.length,
                          itemBuilder: (context, index) {
                            final student = _filteredStudents[index];
                            return MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[200]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ListTile(
                                  title: Text(
                                    student['name'],
                                    style: openSansHebrewTextStyle.copyWith(
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Text(
                                    student['grade'],
                                    style: openSansHebrewTextStyle.copyWith(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                  onTap: () => _handleStudentSelection(student),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );

      Overlay.of(context).insert(_overlayEntry!);
    }
  }

  Widget _buildRequestsCard(BuildContext context, double height) {
    return Expanded(
      flex: 1,
      child: Container(
        padding: const EdgeInsets.all(8),
        height: height,
        child: Card(
          elevation: 4,
          color: Colors.white,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRequestsHeader(),
                const Divider(),
                _buildRequestItem(
                  "Add a shift request",
                  const LinearGradient(
                    colors: [Colors.blue, Color(0xff31C5DA)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  Icons.add,
                ),
                _buildRequestItem(
                  "Add an absence request",
                  const LinearGradient(
                    colors: [Color(0xff44d9b8), Color(0xff44d9b8)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  Icons.light_mode,
                  onTap: () {
                    showDialog(
                      context: context,
                      barrierColor: Colors.transparent,
                      builder: (context) => StatefulBuilder(
                        builder: (context, setState) {
                          String selectedTimeOffType = 'Time Off';
                          return Stack(
                            children: [
                              Positioned.fill(
                                child: GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Container(color: Colors.transparent),
                                ),
                              ),
                              Positioned(
                                right: 16,
                                top: 60,
                                child: Material(
                                  elevation: 8,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 400,
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            GestureDetector(
                                              onTap: () =>
                                                  Navigator.pop(context),
                                              child: Icon(Icons.close,
                                                  size: 20,
                                                  color: Colors.grey[600]),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              'New time off request',
                                              style: openSansHebrewTextStyle
                                                  .copyWith(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 24),
                                        Text(
                                          'Time off type',
                                          style:
                                              openSansHebrewTextStyle.copyWith(
                                            fontSize: 14,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 8),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                                color: Colors.grey[300]!),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              isExpanded: true,
                                              value: selectedTimeOffType,
                                              items: [
                                                'Time Off',
                                                'Sick leave',
                                                'Unpaid Leave'
                                              ]
                                                  .map((type) =>
                                                      DropdownMenuItem(
                                                        value: type,
                                                        child: Text(type),
                                                      ))
                                                  .toList(),
                                              onChanged: (value) {
                                                setState(() =>
                                                    selectedTimeOffType =
                                                        value!);
                                              },
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        Text(
                                          'Date and time of time off',
                                          style:
                                              openSansHebrewTextStyle.copyWith(
                                            fontSize: 14,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 8),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                                color: Colors.grey[300]!),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('12/25'),
                                              Icon(Icons.calendar_today,
                                                  size: 20),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Total time off days',
                                              style: openSansHebrewTextStyle
                                                  .copyWith(
                                                fontSize: 14,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                            Text(
                                              '1.00 work days',
                                              style: openSansHebrewTextStyle
                                                  .copyWith(
                                                fontSize: 14,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 24),
                                        TextField(
                                          decoration: InputDecoration(
                                            hintText:
                                                'Attach a note to your request',
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          maxLines: 3,
                                        ),
                                        const SizedBox(height: 24),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.blue,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 16),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: Text(
                                              'Send for approval',
                                              style: openSansHebrewTextStyle
                                                  .copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Center(
                                          child: Text(
                                            'All requests will be sent for a manager\'s approval',
                                            style: openSansHebrewTextStyle
                                                .copyWith(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestsHeader() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        "Requests",
        style: openSansHebrewTextStyle.copyWith(
          fontWeight: FontWeight.w700,
          color: Colors.black,
          fontSize: 20,
        ),
      ),
    );
  }

  Widget _buildRequestItem(String title, LinearGradient gradient, IconData icon,
      {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        color: Colors.white,
        elevation: 4,
        child: ListTile(
          leading: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: gradient,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          title: Text(
            title,
            style: openSansHebrewTextStyle,
          ),
          onTap: onTap ??
              () {
                if (title == "Add a shift request") {
                  _showShiftRequestDialog(context);
                } else if (title == "Add an absence request") {
                  _showAbsenceRequestDialog(context);
                }
              },
        ),
      ),
    );
  }

  Widget _buildViewRequestsButton() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(8.0),
        child: Card(
          color: const Color(0xffEAF5FF),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Text(
                "View your requests",
                style: openSansHebrewTextStyle.copyWith(
                  color: Colors.blue,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimesheetHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                "Timesheet",
                style: openSansHebrewTextStyle.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 16),
              InkWell(
                onTap: () => _selectDateRange(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _selectedDateRange != null
                            ? '${DateFormat('MM/dd').format(_selectedDateRange!.startDate!)} - ${DateFormat('MM/dd').format(_selectedDateRange!.endDate ?? _selectedDateRange!.startDate!)}'
                            : 'Select date range',
                        style: openSansHebrewTextStyle,
                      ),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('Export'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: Text('Submit timesheet'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimesheetTable(BuildContext context) {
    return Expanded(
      child: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text("Date")),
            DataColumn(label: Text("Type")),
            DataColumn(label: Text("Sub job")),
            DataColumn(label: Text("Start")),
            DataColumn(label: Text("End")),
            DataColumn(label: Text("Total hours")),
            DataColumn(label: Text("Daily total")),
            DataColumn(label: Text("Weekly total")),
            DataColumn(label: Text("Total regular")),
          ],
          rows: _generateRows(),
        ),
      ),
    );
  }

  List<DataRow> _generateRows() {
    return [
      const DataRow(cells: [
        DataCell(Text("Tue 8/6")),
        DataCell(Text("--")),
        DataCell(Text("--")),
        DataCell(Text("--")),
        DataCell(Text("--")),
        DataCell(Text("--")),
        DataCell(Text("--")),
        DataCell(Text("--")),
        DataCell(Text("--")),
      ]),
      DataRow(cells: [
        const DataCell(Text("Mon 8/5")),
        const DataCell(Text("Front Desk")),
        const DataCell(Text("--")),
        const DataCell(Text("07:02 PM")),
        const DataCell(Text("07:02 PM")),
        const DataCell(Text("--")),
        const DataCell(Text("--")),
        const DataCell(Text("--")),
        DataCell(IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () {},
        )),
      ]),
      // Add more rows as needed
    ];
  }

  void _onSelectionChanged(
      DateRangePickerSelectionChangedArgs dateRangePickerSelectionChangedArgs) {
    final PickerDateRange range = dateRangePickerSelectionChangedArgs.value;
    setState(() {
      _selectedDateRange = range;
    });
  }

  void _showShiftRequestDialog(BuildContext context) {
    DateTime now = DateTime.now();
    DateTime startDate = DateTime(now.year, now.month, now.day, 9, 0);
    DateTime endDate = DateTime(now.year, now.month, now.day, 17, 0);
    String selectedStudent = 'Customer 1';
    String totalHours = '08:00';

    void updateTotalHours() {
      Duration difference = endDate.difference(startDate);
      int hours = difference.inHours;
      int minutes = (difference.inMinutes % 60);
      totalHours = '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}';
    }

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    color: Colors.transparent,
                  ),
                ),
              ),
              Positioned(
                right: 16,
                top: 60,
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 400,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Icon(Icons.close,
                                  size: 20, color: Colors.grey[600]),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Add a shift request',
                              style: openSansHebrewTextStyle.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Text(
                              'Student',
                              style: openSansHebrewTextStyle.copyWith(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  final RenderBox box =
                                      context.findRenderObject() as RenderBox;
                                  final Offset position =
                                      box.localToGlobal(Offset.zero);

                                  showDialog(
                                    context: context,
                                    barrierColor: Colors.transparent,
                                    builder: (context) => Stack(
                                      children: [
                                        Positioned.fill(
                                          child: GestureDetector(
                                            onTap: () => Navigator.pop(context),
                                            child: Container(
                                                color: Colors.transparent),
                                          ),
                                        ),
                                        Positioned(
                                          right: 16, // Position from right edge
                                          top: 120, // Position below the header
                                          child: Material(
                                            elevation: 8,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: Container(
                                              width: 300,
                                              constraints: const BoxConstraints(
                                                  maxHeight: 400),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            16),
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey[50],
                                                      borderRadius:
                                                          const BorderRadius
                                                              .only(
                                                        topLeft:
                                                            Radius.circular(8),
                                                        topRight:
                                                            Radius.circular(8),
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Text(
                                                          'Select Student',
                                                          style:
                                                              openSansHebrewTextStyle
                                                                  .copyWith(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontSize: 16,
                                                          ),
                                                        ),
                                                        IconButton(
                                                          padding:
                                                              EdgeInsets.zero,
                                                          icon: const Icon(
                                                              Icons.close,
                                                              size: 20),
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                  context),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            16),
                                                    child: TextField(
                                                      controller:
                                                          _searchController,
                                                      decoration:
                                                          InputDecoration(
                                                        hintText:
                                                            'Search students...',
                                                        prefixIcon: const Icon(
                                                            Icons.search,
                                                            color: Colors.grey),
                                                        border:
                                                            OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: ListView.builder(
                                                      itemCount:
                                                          _students.length,
                                                      itemBuilder:
                                                          (context, index) {
                                                        final student =
                                                            _students[index];
                                                        return ListTile(
                                                          title: Text(
                                                              student['name']),
                                                          subtitle: Text(
                                                              student['grade']),
                                                          onTap: () {
                                                            setState(() {
                                                              selectedStudent =
                                                                  student[
                                                                      'name'];
                                                            });
                                                            Navigator.pop(
                                                                context);
                                                            _handleStudentSelection(
                                                                student);
                                                          },
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        selectedStudent,
                                        style: openSansHebrewTextStyle.copyWith(
                                          color: Colors.blue,
                                        ),
                                      ),
                                      const Icon(Icons.arrow_drop_down,
                                          color: Colors.blue),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Starts',
                                    style: openSansHebrewTextStyle.copyWith(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          onTap: () async {
                                            final date = await showDatePicker(
                                              context: context,
                                              initialDate: startDate,
                                              firstDate: DateTime.now(),
                                              lastDate: DateTime.now().add(
                                                  const Duration(days: 365)),
                                            );
                                            if (date != null) {
                                              setState(() {
                                                startDate = DateTime(
                                                  date.year,
                                                  date.month,
                                                  date.day,
                                                  startDate.hour,
                                                  startDate.minute,
                                                );
                                                updateTotalHours();
                                              });
                                            }
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                  color: Colors.grey[300]!),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              DateFormat('MM/dd/yyyy')
                                                  .format(startDate),
                                              style: openSansHebrewTextStyle,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () async {
                                          final time = await showTimePicker(
                                            context: context,
                                            initialTime: TimeOfDay.fromDateTime(
                                                startDate),
                                          );
                                          if (time != null) {
                                            setState(() {
                                              startDate = DateTime(
                                                startDate.year,
                                                startDate.month,
                                                startDate.day,
                                                time.hour,
                                                time.minute,
                                              );
                                              updateTotalHours();
                                            });
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                                color: Colors.grey[300]!),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            DateFormat('h:mm a')
                                                .format(startDate),
                                            style: openSansHebrewTextStyle,
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
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Ends',
                                    style: openSansHebrewTextStyle.copyWith(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          onTap: () async {
                                            final date = await showDatePicker(
                                              context: context,
                                              initialDate: endDate,
                                              firstDate: startDate,
                                              lastDate: DateTime.now().add(
                                                  const Duration(days: 365)),
                                            );
                                            if (date != null) {
                                              setState(() {
                                                endDate = DateTime(
                                                  date.year,
                                                  date.month,
                                                  date.day,
                                                  endDate.hour,
                                                  endDate.minute,
                                                );
                                                updateTotalHours();
                                              });
                                            }
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                  color: Colors.grey[300]!),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              DateFormat('MM/dd/yyyy')
                                                  .format(endDate),
                                              style: openSansHebrewTextStyle,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () async {
                                          final time = await showTimePicker(
                                            context: context,
                                            initialTime:
                                                TimeOfDay.fromDateTime(endDate),
                                          );
                                          if (time != null) {
                                            setState(() {
                                              endDate = DateTime(
                                                endDate.year,
                                                endDate.month,
                                                endDate.day,
                                                time.hour,
                                                time.minute,
                                              );
                                              updateTotalHours();
                                            });
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                                color: Colors.grey[300]!),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            DateFormat('h:mm a')
                                                .format(endDate),
                                            style: openSansHebrewTextStyle,
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
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Total hours',
                                style: openSansHebrewTextStyle.copyWith(
                                  color: Colors.blue[700],
                                ),
                              ),
                              const Spacer(),
                              Text(
                                totalHours,
                                style: openSansHebrewTextStyle.copyWith(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Shift attachments',
                          style: openSansHebrewTextStyle.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(Icons.note_outlined,
                                size: 20, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Text(
                              'Note',
                              style: openSansHebrewTextStyle.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '(Blank)',
                            style: openSansHebrewTextStyle.copyWith(
                              color: Colors.grey[500],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          decoration: InputDecoration(
                            hintText: 'Attach a note to your request',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: Text(
                              'Send for approval',
                              style: openSansHebrewTextStyle.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            'All requests will be sent for a manager\'s approval',
                            style: openSansHebrewTextStyle.copyWith(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAbsenceRequestDialog(BuildContext context) {
    String selectedTimeOffType = 'Time Off';
    DateTime selectedDate = DateTime.now();
    double workDays = 1.00;

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(color: Colors.transparent),
              ),
            ),
            Positioned(
              right: 16,
              top: 60,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 400,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Icon(Icons.close,
                                size: 20, color: Colors.grey[600]),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'New time off request',
                            style: openSansHebrewTextStyle.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Time off type',
                        style: openSansHebrewTextStyle.copyWith(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(selectedTimeOffType),
                                const Icon(Icons.arrow_drop_down),
                              ],
                            ),
                          ),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                                value: 'Time Off', child: Text('Time Off')),
                            const PopupMenuItem(
                                value: 'Sick leave', child: Text('Sick leave')),
                            const PopupMenuItem(
                                value: 'Unpaid Leave',
                                child: Text('Unpaid Leave')),
                          ],
                          onSelected: (value) {
                            setState(() => selectedTimeOffType = value);
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Date and time of time off',
                        style: openSansHebrewTextStyle.copyWith(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setState(() => selectedDate = date);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(DateFormat('MM/dd').format(selectedDate)),
                              const Icon(Icons.calendar_today, size: 20),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total time off days',
                            style: openSansHebrewTextStyle.copyWith(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            '${workDays.toStringAsFixed(2)} work days',
                            style: openSansHebrewTextStyle.copyWith(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Attach a note to your request',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Send for approval',
                            style: openSansHebrewTextStyle.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          'All requests will be sent for a manager\'s approval',
                          style: openSansHebrewTextStyle.copyWith(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _studentSearchController.dispose();
    _searchController.dispose();
    _overlayEntry?.remove();
    _timer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }
}

class BuildTimeSheetSection extends StatefulWidget {
  final List<TimesheetEntry> entries;

  const BuildTimeSheetSection({
    super.key,
    required this.entries,
  });

  @override
  State<BuildTimeSheetSection> createState() => _BuildTimeSheetSectionState();
}

class _BuildTimeSheetSectionState extends State<BuildTimeSheetSection> {
  PickerDateRange? _selectedDateRange;
  List<TimesheetEntry> timesheetData = [];
  late TimesheetDataSource _timesheetDataSource;

  @override
  void initState() {
    super.initState();
    // Initialize with sample data
    timesheetData = [
      TimesheetEntry(
        date: 'Tue 12/24',
        type: 'John Doe',
        subJob: 'Front Desk',
        start: '07:27 PM',
        end: '07:28 PM',
        totalHours: '00:01',
        dailyTotal: '00:09',
        weeklyTotal: '00:09',
        totalRegular: '00:09',
      ),
      // Add more sample entries as needed
    ];
    _timesheetDataSource = TimesheetDataSource(timesheetData: timesheetData);
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Card(
          elevation: 4,
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const Divider(height: 1),
              Expanded(
                child: SfDataGridTheme(
                  data: SfDataGridThemeData(
                    headerColor: Colors.grey[50],
                    gridLineColor: Colors.grey[300]!,
                    gridLineStrokeWidth: 1,
                  ),
                  child: SfDataGrid(
                    source: _timesheetDataSource,
                    columnWidthMode: ColumnWidthMode.fill,
                    columns: [
                      GridColumn(
                        columnName: 'date',
                        label: Container(
                          padding: const EdgeInsets.all(8.0),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Date',
                            style: openSansHebrewTextStyle.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      GridColumn(
                        columnName: 'type',
                        label: Container(
                          padding: const EdgeInsets.all(8.0),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Type',
                            style: openSansHebrewTextStyle.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      GridColumn(
                        columnName: 'subJob',
                        label: Container(
                          padding: const EdgeInsets.all(8.0),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Sub job',
                            style: openSansHebrewTextStyle.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      GridColumn(
                        columnName: 'start',
                        label: Container(
                          padding: const EdgeInsets.all(8.0),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Start',
                            style: openSansHebrewTextStyle.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      GridColumn(
                        columnName: 'end',
                        label: Container(
                          padding: const EdgeInsets.all(8.0),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'End',
                            style: openSansHebrewTextStyle.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      GridColumn(
                        columnName: 'totalHours',
                        label: Container(
                          padding: const EdgeInsets.all(8.0),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Total hours',
                            style: openSansHebrewTextStyle.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      GridColumn(
                        columnName: 'dailyTotal',
                        label: Container(
                          padding: const EdgeInsets.all(8.0),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Daily total',
                            style: openSansHebrewTextStyle.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      GridColumn(
                        columnName: 'weeklyTotal',
                        label: Container(
                          padding: const EdgeInsets.all(8.0),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Weekly total',
                            style: openSansHebrewTextStyle.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      GridColumn(
                        columnName: 'totalRegular',
                        label: Container(
                          padding: const EdgeInsets.all(8.0),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Total regular',
                            style: openSansHebrewTextStyle.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                'Timesheet',
                style: openSansHebrewTextStyle.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 16),
              InkWell(
                onTap: () => _selectDateRange(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _selectedDateRange != null
                            ? '${DateFormat('MM/dd').format(_selectedDateRange!.startDate!)} - ${DateFormat('MM/dd').format(_selectedDateRange!.endDate ?? _selectedDateRange!.startDate!)}'
                            : 'Select date range',
                        style: openSansHebrewTextStyle,
                      ),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('Export'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: Text('Submit timesheet'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _selectDateRange(BuildContext context) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Create a default date range if none is selected
        DateTimeRange defaultRange = DateTimeRange(
          start: DateTime.now(),
          end: DateTime.now().add(const Duration(days: 7)),
        );

        // Use the existing range or default range
        DateTimeRange initialRange = _selectedDateRange != null
            ? DateTimeRange(
                start: _selectedDateRange!.startDate!,
                end: _selectedDateRange!.endDate ??
                    _selectedDateRange!.startDate!,
              )
            : defaultRange;

        return Dialog(
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.4,
            height: MediaQuery.of(context).size.height * 0.6,
            child: Theme(
              data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context).colorScheme.copyWith(
                      primary: Colors.blue,
                      onPrimary: Colors.white,
                      onSurface: Colors.black,
                    ),
              ),
              child: DateRangePickerDialog(
                firstDate: DateTime(2020),
                lastDate: DateTime(2025),
                initialDateRange: initialRange,
                cancelText: null,
                confirmText: 'Save',
                helpText: 'Select Date Range',
              ),
            ),
          ),
        );
      },
    ).then((value) {
      if (value != null && value is DateTimeRange) {
        setState(() {
          _selectedDateRange = PickerDateRange(value.start, value.end);
        });
      }
    });
  }
}

// Add these new classes to handle the data source
class TimesheetEntry {
  final String date;
  final String type; // This will store the student name or type
  final String subJob; // This can be empty as shown with "-"
  final String start; // Time format like "12:17 PM"
  final String end; // Time format like "12:17 PM"
  final String totalHours; // Format like "00:01"
  final String dailyTotal; // Format like "00:09"
  final String weeklyTotal; // Format like "00:09"
  final String totalRegular; // Format like "00:09"
  final Color? typeColor; // For the background color of the type field

  TimesheetEntry({
    required this.date,
    required this.type,
    this.subJob = '-',
    required this.start,
    required this.end,
    required this.totalHours,
    required this.dailyTotal,
    this.weeklyTotal = '-',
    this.totalRegular = '-',
    this.typeColor,
  });
}

class TimesheetDataSource extends DataGridSource {
  List<DataGridRow> _timesheetData = [];

  TimesheetDataSource({required List<TimesheetEntry> timesheetData}) {
    _timesheetData = timesheetData
        .map<DataGridRow>((entry) => DataGridRow(
              cells: [
                DataGridCell(columnName: 'date', value: entry),
                DataGridCell(columnName: 'type', value: entry),
                DataGridCell(columnName: 'subJob', value: entry),
                DataGridCell(columnName: 'start', value: entry),
                DataGridCell(columnName: 'end', value: entry),
                DataGridCell(columnName: 'totalHours', value: entry),
                DataGridCell(columnName: 'dailyTotal', value: entry),
                DataGridCell(columnName: 'weeklyTotal', value: entry),
                DataGridCell(columnName: 'totalRegular', value: entry),
              ],
            ))
        .toList();
  }

  @override
  List<DataGridRow> get rows => _timesheetData;

  @override
  DataGridRowAdapter? buildRow(DataGridRow row) {
    final entry = row.getCells().first.value as TimesheetEntry;

    return DataGridRowAdapter(
      cells: [
        Container(
          padding: const EdgeInsets.all(8.0),
          alignment: Alignment.centerLeft,
          child: Text(entry.date),
        ),
        Container(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: entry.typeColor ?? Colors.grey,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              entry.type,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8.0),
          alignment: Alignment.centerLeft,
          child: Text(entry.subJob),
        ),
        Container(
          padding: const EdgeInsets.all(8.0),
          alignment: Alignment.centerLeft,
          child: Text(entry.start),
        ),
        Container(
          padding: const EdgeInsets.all(8.0),
          alignment: Alignment.centerLeft,
          child: Text(entry.end),
        ),
        Container(
          padding: const EdgeInsets.all(8.0),
          alignment: Alignment.centerLeft,
          child: Text(entry.totalHours),
        ),
        Container(
          padding: const EdgeInsets.all(8.0),
          alignment: Alignment.centerLeft,
          child: Text(entry.dailyTotal),
        ),
        Container(
          padding: const EdgeInsets.all(8.0),
          alignment: Alignment.centerLeft,
          child: Text(entry.weeklyTotal),
        ),
        Container(
          padding: const EdgeInsets.all(8.0),
          alignment: Alignment.centerLeft,
          child: Text(entry.totalRegular),
        ),
      ],
    );
  }
}
