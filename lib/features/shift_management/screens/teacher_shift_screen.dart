import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/teacher_shift_calendar.dart';
import '../../../core/models/teaching_shift.dart';
import '../../../core/services/shift_service.dart';
import '../../../core/services/shift_timesheet_service.dart';
import '../../../core/services/location_service.dart';
import '../widgets/shift_details_dialog.dart';
import 'available_shifts_screen.dart';

class TeacherShiftScreen extends StatefulWidget {
  const TeacherShiftScreen({super.key});

  @override
  State<TeacherShiftScreen> createState() => _TeacherShiftScreenState();
}

class _TeacherShiftScreenState extends State<TeacherShiftScreen> {
  List<TeachingShift> _shifts = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // all, upcoming, active, completed
  final String _teacherTimezone =
      'America/New_York'; // Get from user preferences
  bool _isCalendarView = true; // Calendar/List toggle

  @override
  void initState() {
    super.initState();
    _setupShiftStream();
  }

  void _setupShiftStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('TeacherShiftScreen: No authenticated user found');
      setState(() => _isLoading = false);
      return;
    }

    print(
        'TeacherShiftScreen: Setting up real-time stream for user UID: ${user.uid}');
    print('TeacherShiftScreen: User email: ${user.email}');

    // Listen to real-time shifts stream
    ShiftService.getTeacherShifts(user.uid).listen(
      (shifts) {
        print(
            'TeacherShiftScreen: Stream update - received ${shifts.length} shifts');
        if (mounted) {
          setState(() {
            _shifts = shifts;
            _isLoading = false;
          });
        }
      },
      onError: (error) {
        print('Error in teacher shifts stream: $error');
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading shifts: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }

  Future<void> _loadTeacherShifts() async {
    // This method now just triggers a manual refresh
    // The actual data loading is handled by the stream
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    // The stream will automatically update the UI when data changes
  }

  List<TeachingShift> get _filteredShifts {
    final now = DateTime.now();

    switch (_selectedFilter) {
      case 'upcoming':
        return _shifts
            .where((shift) =>
                shift.shiftStart.isAfter(now) &&
                shift.status == ShiftStatus.scheduled)
            .toList();
      case 'active':
        return _shifts
            .where((shift) =>
                shift.isCurrentlyActive || shift.status == ShiftStatus.active)
            .toList();
      case 'completed':
        return _shifts
            .where((shift) => shift.status == ShiftStatus.completed)
            .toList();
      default:
        return _shifts;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        title: Text(
          'My Teaching Shifts',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xff111827),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xff6B7280)),
        actions: [
          // Available Shifts Button
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AvailableShiftsScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.public, size: 18),
              label: Text(
                'Available Shifts',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff0386FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              // Manual refresh by re-setting up the stream
              _setupShiftStream();
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh shifts',
          ),
          IconButton(
            onPressed: _cleanupDuplicates,
            icon: const Icon(Icons.cleaning_services),
            tooltip: 'Cleanup duplicates',
          ),
        ],
      ),
      // Make the entire page scrollable (filters + stats + content)
      body: Scrollbar(
        thumbVisibility: true,
        interactive: true,
        child: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _buildFilterTabs(),
              _buildViewToggle(),
              _buildShiftStats(),
              // Inline the content; list itself won't scroll
              if (_isLoading)
                _buildLoadingState()
              else if (_filteredShifts.isEmpty)
                _buildEmptyState()
              else
                (_isCalendarView
                    ? _buildCalendarSection()
                    : _buildShiftsList(shrinkWrap: true)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildFilterTab('all', 'All Shifts', Icons.list),
          _buildFilterTab('upcoming', 'Upcoming', Icons.schedule),
          _buildFilterTab('active', 'Active', Icons.play_circle),
          _buildFilterTab('completed', 'Completed', Icons.check_circle),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String filter, String label, IconData icon) {
    final isSelected = _selectedFilter == filter;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedFilter = filter),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xff0386FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : const Color(0xff6B7280),
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xff6B7280),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShiftStats() {
    final totalShifts = _shifts.length;
    final upcomingShifts = _shifts
        .where((s) =>
            s.shiftStart.isAfter(DateTime.now()) &&
            s.status == ShiftStatus.scheduled)
        .length;
    final activeShifts = _shifts
        .where((s) => s.isCurrentlyActive || s.status == ShiftStatus.active)
        .length;
    final completedShifts =
        _shifts.where((s) => s.status == ShiftStatus.completed).length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildStatCard('Total', totalShifts.toString(), Colors.blue),
          const SizedBox(width: 12),
          _buildStatCard('Upcoming', upcomingShifts.toString(), Colors.orange),
          const SizedBox(width: 12),
          _buildStatCard('Active', activeShifts.toString(), Colors.green),
          const SizedBox(width: 12),
          _buildStatCard(
              'Completed', completedShifts.toString(), Colors.purple),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xff6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading your shifts...'),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    String submessage;
    IconData icon;

    // Debug info for testing
    final user = FirebaseAuth.instance.currentUser;

    switch (_selectedFilter) {
      case 'upcoming':
        icon = Icons.schedule;
        message = 'No upcoming shifts';
        submessage = 'You have no scheduled shifts coming up';
        break;
      case 'active':
        icon = Icons.play_circle;
        message = 'No active shifts';
        submessage = 'You don\'t have any shifts currently in progress';
        break;
      case 'completed':
        icon = Icons.check_circle;
        message = 'No completed shifts';
        submessage = 'You haven\'t completed any shifts yet';
        break;
      default:
        icon = Icons.schedule;
        message = 'No shifts assigned';
        submessage = 'You don\'t have any teaching shifts assigned yet';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: const Color(0xff9CA3AF),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xff374151),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            submessage,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xff6B7280),
            ),
            textAlign: TextAlign.center,
          ),
          // Temporary debug info
          if (user != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    'Debug Info:',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'User UID: ${user.uid}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.blue,
                    ),
                  ),
                  Text(
                    'Email: ${user.email}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildShiftsList({bool shrinkWrap = false}) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredShifts.length,
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      itemBuilder: (context, index) {
        final shift = _filteredShifts[index];
        return _buildShiftCard(shift);
      },
    );
  }

  // Calendar section with bounded height so it lays out within page scroll
  Widget _buildCalendarSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
      child: SizedBox(
        height: 700,
        child: TeacherShiftCalendar(
          shifts: _filteredShifts,
          onSelectShift: _showShiftDetails,
        ),
      ),
    );
  }

  Widget _buildViewToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      alignment: Alignment.centerRight,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xffF3F4F6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildViewButton(
              icon: Icons.calendar_view_week,
              label: 'Calendar',
              isSelected: _isCalendarView,
              onTap: () => setState(() => _isCalendarView = true),
            ),
            _buildViewButton(
              icon: Icons.view_list,
              label: 'List',
              isSelected: !_isCalendarView,
              onTap: () => setState(() => _isCalendarView = false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xff0386FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 16,
                color: isSelected ? Colors.white : const Color(0xff6B7280)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xff6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftCard(TeachingShift shift) {
    final now = DateTime.now();
    final canClockIn = shift.canClockIn && !shift.isClockedIn;
    final isActive = shift.isClockedIn;
    final canClockOut = shift.canClockOut;
    final hasExpired = shift.hasExpired;
    final needsAutoLogout = shift.needsAutoLogout;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (needsAutoLogout) {
      statusColor = Colors.red;
      statusText = 'AUTO-LOGOUT PENDING';
      statusIcon = Icons.warning;
    } else if (isActive && canClockOut) {
      statusColor = Colors.green;
      statusText = 'CLOCKED IN';
      statusIcon = Icons.play_circle;
    } else if (canClockIn) {
      statusColor = Colors.orange;
      statusText = 'READY TO CLOCK IN';
      statusIcon = Icons.access_time;
    } else if (hasExpired && shift.status == ShiftStatus.scheduled) {
      statusColor = Colors.red;
      statusText = 'MISSED';
      statusIcon = Icons.cancel;
    } else if (shift.status == ShiftStatus.completed) {
      statusColor = Colors.purple;
      statusText = shift.clockOutTime != null ? 'COMPLETED' : 'AUTO-COMPLETED';
      statusIcon = Icons.check_circle;
    } else {
      statusColor = Colors.blue;
      statusText = 'SCHEDULED';
      statusIcon = Icons.schedule;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showShiftDetails(shift),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                          shift.displayName,
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xff111827),
                          ),
                              ),
                            ),
                            // Published badge
                            if (shift.isPublished) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xff0386FF).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xff0386FF).withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.public,
                                      size: 12,
                                      color: Color(0xff0386FF),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'PUBLISHED',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xff0386FF),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          shift.effectiveSubjectDisplayName,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xff6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status pill — make it flexible to avoid overflow on narrow screens
                  Flexible(
                    fit: FlexFit.loose,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            statusIcon,
                            size: 16,
                            color: statusColor,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              statusText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildInfoChip(
                    Icons.calendar_today,
                    _formatDate(shift.shiftStart),
                  ),
                  const SizedBox(width: 12),
                  _buildInfoChip(
                    Icons.access_time,
                    '${_formatTime(shift.shiftStart)} - ${_formatTime(shift.shiftEnd)}',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildInfoChip(
                    Icons.people,
                    '${shift.studentNames.length} students',
                  ),
                  const SizedBox(width: 12),
                  _buildInfoChip(
                    Icons.schedule,
                    '${shift.shiftDurationHours.toStringAsFixed(1)}h',
                  ),
                  const SizedBox(width: 12),
                  _buildInfoChip(
                    Icons.attach_money,
                    '\$${shift.totalPayment.toStringAsFixed(0)}',
                  ),
                ],
              ),
              if (shift.studentNames.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Students: ${shift.studentNames.join(', ')}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xff6B7280),
                  ),
                ),
              ],
              // Publish button for scheduled, non-expired, non-published shifts
              if (shift.status == ShiftStatus.scheduled && 
                  !shift.hasExpired && 
                  !shift.isPublished) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _handlePublishShift(shift),
                        icon: const Icon(Icons.publish, size: 18),
                        label: Text(
                          'Publish Shift',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xff0386FF),
                          side: const BorderSide(color: Color(0xff0386FF)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (canClockIn || isActive) ...[
                const SizedBox(height: 16),
                // Action buttons - only show details and time clock redirect
                Row(
                  children: [
                    // Show instruction text for clock-in/out
                    if (canClockIn || canClockOut) ...[
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (canClockIn ? Colors.green : Colors.red)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: (canClockIn ? Colors.green : Colors.red)
                                  .withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info,
                                color: canClockIn ? Colors.green : Colors.red,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  canClockIn
                                      ? 'To clock in: Go to Time Clock tab'
                                      : 'To clock out: Go to Time Clock tab',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: canClockIn
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    // Always show details button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showShiftDetails(shift),
                        icon: const Icon(Icons.info_outline, size: 20),
                        label: Text(
                          'View Details',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xffF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: const Color(0xff64748B),
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xff475569),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];

    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  String _formatTime(DateTime time) {
    final hour = time.hour == 0
        ? 12
        : time.hour > 12
            ? time.hour - 12
            : time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  void _showShiftDetails(TeachingShift shift) {
    showDialog(
      context: context,
      builder: (context) => ShiftDetailsDialog(
        shift: shift,
        onPublishShift: () => _handlePublishShift(shift),
        onUnpublishShift: () => _handleUnpublishShift(shift),
      ),
    );
  }

  Future<void> _handlePublishShift(TeachingShift shift) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.publish, color: Color(0xff0386FF)),
            const SizedBox(width: 12),
            Text(
              'Publish Shift',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to publish this shift? Other teachers will be able to see and claim it.',
              style: GoogleFonts.inter(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xffFFF4E6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xffF59E0B)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, 
                    color: Color(0xffF59E0B), 
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You won\'t be responsible for this shift once it\'s claimed by another teacher.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xff92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: const Color(0xff6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff0386FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Publish Shift',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) return;

        // Update shift document with publishing information
        await FirebaseFirestore.instance
            .collection('teaching_shifts')
            .doc(shift.id)
            .update({
          'is_published': true,
          'published_by': currentUser.uid,
          'published_at': FieldValue.serverTimestamp(),
          'original_teacher_id': shift.teacherId,
          'original_teacher_name': shift.teacherName,
          'last_modified': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Shift published! Other teachers can now see and claim it.',
                style: GoogleFonts.inter(),
              ),
              backgroundColor: const Color(0xff10B981),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        print('Error publishing shift: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '❌ Failed to publish shift. Please try again.',
                style: GoogleFonts.inter(),
              ),
              backgroundColor: const Color(0xffEF4444),
            ),
          );
        }
      }
    }
  }

  Future<void> _handleUnpublishShift(TeachingShift shift) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.unpublished, color: Color(0xffF59E0B)),
            const SizedBox(width: 12),
            Text(
              'Unpublish Shift',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to unpublish this shift? It will no longer be visible to other teachers.',
          style: GoogleFonts.inter(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: const Color(0xff6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xffF59E0B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Unpublish',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Update shift document to unpublish
        await FirebaseFirestore.instance
            .collection('teaching_shifts')
            .doc(shift.id)
            .update({
          'is_published': false,
          'published_by': null,
          'published_at': null,
          'last_modified': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Shift unpublished successfully.',
                style: GoogleFonts.inter(),
              ),
              backgroundColor: const Color(0xff0386FF),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        print('Error unpublishing shift: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '❌ Failed to unpublish shift. Please try again.',
                style: GoogleFonts.inter(),
              ),
              backgroundColor: const Color(0xffEF4444),
            ),
          );
        }
      }
    }
  }

  void _clockIn(TeachingShift shift) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Show loading state
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Getting location for clock-in...'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 1),
        ),
      );

      // Get location first
      LocationData? location;
      try {
        location = await LocationService.getCurrentLocation();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Location permission required. Please enable location access: ${e.toString().split(': ').last}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      if (location == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Location temporarily unavailable. Please try again or move to an open area.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Use the integrated shift-timesheet service
      final result = await ShiftTimesheetService.clockInToShift(
        user.uid,
        shift.id,
        location: location,
      );

      if (mounted) {
        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clocking in: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _clockOut(TeachingShift shift) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Clock Out',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          content: Text(
            'Are you sure you want to clock out of "${shift.displayName}"?',
            style: GoogleFonts.inter(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(color: const Color(0xff6B7280)),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Clock Out',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // Show loading state
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Getting location (usually takes 5-10 seconds)...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Get location first
      LocationData? location;
      try {
        location = await LocationService.getCurrentLocation();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Location permission required: ${e.toString().split(': ').last}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      if (location == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Location temporarily unavailable. Please try again or move to an open area.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Use the integrated shift-timesheet service
      final result = await ShiftTimesheetService.clockOutFromShift(
        user.uid,
        shift.id,
        location: location,
      );

      if (mounted) {
        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clocking out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cleanupDuplicates() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cleaning up duplicate shifts...'),
          backgroundColor: Colors.orange,
        ),
      );

      await ShiftService.cleanupDuplicateShifts(user.uid);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cleanup completed! Refreshing...'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadTeacherShifts();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cleanup failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
