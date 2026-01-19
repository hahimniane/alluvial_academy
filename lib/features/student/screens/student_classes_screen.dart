import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../../core/models/teaching_shift.dart';
import '../../../core/services/shift_service.dart';
import '../../../core/services/video_call_service.dart';
import '../../../core/services/user_role_service.dart';
import '../../../core/enums/shift_enums.dart';
import '../../../core/utils/app_logger.dart';

/// Student Classes Screen - Shows upcoming classes and allows students to join
class StudentClassesScreen extends StatefulWidget {
  /// User ID passed from parent widget to avoid web auth race conditions
  final String? userId;

  const StudentClassesScreen({super.key, this.userId});

  @override
  State<StudentClassesScreen> createState() => _StudentClassesScreenState();
}

class _StudentClassesScreenState extends State<StudentClassesScreen> {
  List<TeachingShift> _todayClasses = [];
  List<TeachingShift> _upcomingClasses = [];
  bool _isLoading = true;
  String? _studentName;
  String? _error;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    if (!mounted) return;
    AppLogger.debug('=== StudentClassesScreen._initializeAuth() ===');

    // First, use the userId passed from parent widget (most reliable)
    String? userId = widget.userId;
    AppLogger.debug('  widget.userId: $userId');

    // If not provided, try UserRoleService cache
    if (userId == null) {
      userId = UserRoleService.getCurrentUserId();
      AppLogger.debug('  UserRoleService.getCurrentUserId(): $userId');
    }

    // If still null, try FirebaseAuth directly
    if (userId == null) {
      final user = FirebaseAuth.instance.currentUser;
      userId = user?.uid;
      AppLogger.debug('  FirebaseAuth.instance.currentUser?.uid: $userId');
    }

    // If still null, wait briefly and try again (web issue)
    if (userId == null) {
      AppLogger.debug('  userId is null, waiting for auth state...');
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      userId = UserRoleService.getCurrentUserId() ??
          FirebaseAuth.instance.currentUser?.uid;
      AppLogger.debug('  After delay, userId: $userId');
    }

    if (!mounted) return;

    if (userId != null) {
      AppLogger.debug('  ✅ Auth initialized, userId: $userId');
      setState(() {
        _userId = userId;
      });
      _loadClasses();
    } else {
      AppLogger.debug('  ❌ Auth failed to initialize - no userId found');
      setState(() {
        _error = 'Unable to authenticate. Please try logging in again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadClasses() async {
    AppLogger.debug('=== StudentClassesScreen._loadClasses() starting ===');
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = _userId ?? FirebaseAuth.instance.currentUser?.uid;
      AppLogger.debug('  Using userId: ${userId ?? "null"}');
      if (userId == null) {
        setState(() {
          _error = 'Please log in to see your classes';
          _isLoading = false;
        });
        return;
      }

      // Load student name
      final userData = await UserRoleService.getCurrentUserData();
      if (userData != null && mounted) {
        setState(() {
          _studentName = userData['first_name'] ?? 'Student';
        });
      }

      // Load today's classes
      final todayClasses = (await ShiftService.getTodayShiftsForStudent(userId))
          .where((shift) => shift.studentIds.contains(userId))
          .toList();

      // Load upcoming classes (all future shifts, excluding today)
      final upcomingClasses =
          (await ShiftService.getUpcomingShiftsForStudent(userId, daysAhead: null))
              .where((shift) => shift.studentIds.contains(userId))
              .toList();

      // Filter out today's classes from upcoming
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      final futureClasses = upcomingClasses.where((shift) {
        final shiftDate = DateTime(
          shift.shiftStart.year,
          shift.shiftStart.month,
          shift.shiftStart.day,
        );
        return shiftDate.isAfter(todayDate);
      }).toList();

      if (mounted) {
        setState(() {
          _todayClasses = todayClasses;
          _upcomingClasses = futureClasses;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load classes: $e';
          _isLoading = false;
        });
      }
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    AppLogger.debug('=== StudentClassesScreen.build() called ===');
    AppLogger.debug('  isLoading: $_isLoading, error: $_error');
    AppLogger.debug(
        '  todayClasses: ${_todayClasses.length}, upcomingClasses: ${_upcomingClasses.length}');
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadClasses,
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: _buildHeader(),
              ),

              // Content
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                SliverFillRemaining(
                  child: _buildErrorState(),
                )
              else
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Today's Classes
                        _buildSectionTitle(
                            'Today\'s Classes', Icons.today_rounded),
                        const SizedBox(height: 12),
                        if (_todayClasses.isEmpty)
                          _buildEmptyState(
                              'No classes today', 'Enjoy your free time!')
                        else
                          ..._todayClasses.map(
                              (shift) => _buildClassCard(shift, isToday: true)),

                        const SizedBox(height: 24),

                        // Upcoming Classes
                        _buildSectionTitle(
                            'Upcoming Classes', Icons.calendar_month_rounded),
                        const SizedBox(height: 12),
                        if (_upcomingClasses.isEmpty)
                          _buildEmptyState('No upcoming classes',
                              'Check back later for your schedule')
                        else
                          ..._upcomingClasses.map((shift) =>
                              _buildClassCard(shift, isToday: false)),

                        const SizedBox(height: 100), // Bottom padding
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
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E3A5F),
            const Color(0xFF2E5A8F),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A5F).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getGreeting(),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      _studentName ?? 'Student',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _loadClasses,
                icon: const Icon(Icons.refresh_rounded),
                color: Colors.white70,
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Stats row
          Row(
            children: [
              _buildStatBadge(
                '${_todayClasses.length}',
                'Today',
                Icons.today_rounded,
              ),
              const SizedBox(width: 12),
              _buildStatBadge(
                '${_upcomingClasses.length}',
                'Upcoming',
                Icons.calendar_month_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String count, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          Text(
            count,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A5F).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF1E3A5F), size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E3A5F),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.event_available_rounded,
              color: Color(0xFF1E3A5F),
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Colors.red,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Oops! Something went wrong',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Please try again',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadClasses,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassCard(TeachingShift shift, {required bool isToday}) {
    final canJoin = VideoCallService.canJoinClass(shift);
    final timeUntil = VideoCallService.getTimeUntilCanJoin(shift);
    final isLiveKit = shift.usesLiveKit;

    // Format time
    final startTime = DateFormat('h:mm a').format(shift.shiftStart.toLocal());
    final endTime = DateFormat('h:mm a').format(shift.shiftEnd.toLocal());
    final dateStr = isToday
        ? 'Today'
        : DateFormat('EEEE, MMM d').format(shift.shiftStart.toLocal());

    // Determine status color
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (shift.status == ShiftStatus.active) {
      statusColor = Colors.green;
      statusText = 'In Progress';
      statusIcon = Icons.play_circle_rounded;
    } else if (canJoin) {
      statusColor = const Color(0xFF10B981);
      statusText = 'Ready to Join';
      statusIcon = Icons.video_call_rounded;
    } else if (timeUntil != null) {
      final minutes = timeUntil.inMinutes;
      if (minutes < 60) {
        statusColor = Colors.orange;
        statusText = 'Opens in $minutes min';
        statusIcon = Icons.schedule_rounded;
      } else {
        final hours = minutes ~/ 60;
        statusColor = const Color(0xFF6B7280);
        statusText = 'Opens in ${hours}h';
        statusIcon = Icons.schedule_rounded;
      }
    } else {
      statusColor = const Color(0xFF6B7280);
      statusText = 'Scheduled';
      statusIcon = Icons.event_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: canJoin
                ? const Color(0xFF10B981).withOpacity(0.15)
                : Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: canJoin
            ? Border.all(
                color: const Color(0xFF10B981).withOpacity(0.3), width: 2)
            : null,
      ),
      child: Column(
        children: [
          // Class info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    // Subject icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF1E3A5F),
                            const Color(0xFF2E5A8F),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Class details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shift.effectiveSubjectDisplayName,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'with ${shift.teacherName}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, color: statusColor, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Time and date
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        color: Color(0xFF6B7280),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$startTime - $endTime',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF374151),
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.calendar_today_rounded,
                        color: Color(0xFF6B7280),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        dateStr,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),

                // LiveKit badge
                if (isLiveKit)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.videocam_rounded,
                            color: Colors.purple.shade600,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'In-App Video Call',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.purple.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Join button
          if (canJoin ||
              (isToday && timeUntil != null && timeUntil.inMinutes <= 30))
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ElevatedButton.icon(
                onPressed: canJoin ? () => _joinClass(shift) : null,
                icon: Icon(
                  canJoin ? Icons.video_call_rounded : Icons.schedule_rounded,
                ),
                label: Text(
                  canJoin ? 'Join Class Now' : 'Opens Soon',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: canJoin
                      ? const Color(0xFF10B981)
                      : const Color(0xFFE5E7EB),
                  foregroundColor:
                      canJoin ? Colors.white : const Color(0xFF9CA3AF),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: canJoin ? 2 : 0,
                ),
              ),
            ),
          if (VideoCallService.hasVideoCall(shift))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      VideoCallService.copyJoinLink(context, shift),
                  icon: const Icon(Icons.link),
                  label: Text(
                    'Copy class link',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF0E72ED),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _joinClass(TeachingShift shift) async {
    await VideoCallService.joinClass(
      context,
      shift,
      isTeacher: false, // Student joining
    );
  }
}
