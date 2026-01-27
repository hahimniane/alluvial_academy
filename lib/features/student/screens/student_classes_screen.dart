import 'dart:async';
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
import '../../../core/services/onboarding_service.dart';
import '../../onboarding/services/student_feature_tour.dart';

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
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
    // Refresh every 30 seconds to update countdown timers
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
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

      // Sort both lists by start time (soonest first)
      todayClasses.sort((a, b) => a.shiftStart.compareTo(b.shiftStart));
      futureClasses.sort((a, b) => a.shiftStart.compareTo(b.shiftStart));

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
                          ..._todayClasses.asMap().entries.map((entry) {
                            final index = entry.key;
                            final shift = entry.value;
                            // Assign GlobalKey to first class card for feature tour
                            final isFirstCard = index == 0;
                            return _buildClassCard(
                              shift,
                              isToday: true,
                              key: isFirstCard ? studentFeatureTour.firstClassCardKey : null,
                            );
                          }),

                        const SizedBox(height: 24),

                        // Upcoming Classes
                        _buildSectionTitle(
                            'Upcoming Classes', Icons.calendar_month_rounded),
                        const SizedBox(height: 12),
                        if (_upcomingClasses.isEmpty)
                          _buildEmptyState('No upcoming classes',
                              'Check back later for your schedule')
                        else
                          ..._upcomingClasses.asMap().entries.map((entry) {
                            final index = entry.key;
                            final shift = entry.value;
                            // Assign GlobalKey to first card if no today classes
                            final isFirstCard = index == 0 && _todayClasses.isEmpty;
                            return _buildClassCard(
                              shift,
                              isToday: false,
                              key: isFirstCard ? studentFeatureTour.firstClassCardKey : null,
                            );
                          }),

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
              // Help/Tour button
              IconButton(
                onPressed: () => _startAppTour(),
                icon: const Icon(Icons.help_outline_rounded),
                color: Colors.white70,
                tooltip: 'App Tour',
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

  /// Format time until class in a professional way
  String _formatTimeUntil(Duration? timeUntil) {
    if (timeUntil == null) return '';
    
    final totalMinutes = timeUntil.inMinutes;
    final totalHours = timeUntil.inHours;
    final days = timeUntil.inDays;
    
    if (totalMinutes <= 0) {
      return 'Starting now';
    } else if (totalMinutes < 2) {
      return 'Starting in 1 min';
    } else if (totalMinutes < 60) {
      return 'Starting in $totalMinutes min';
    } else if (totalHours < 24) {
      final hours = totalHours;
      final mins = totalMinutes % 60;
      if (mins == 0) {
        return 'Starting in ${hours}h';
      } else if (mins < 10) {
        return 'Starting in ${hours}h ${mins}m';
      } else {
        return 'Starting in ${hours}h ${mins}m';
      }
    } else if (days == 1) {
      return 'Tomorrow';
    } else if (days < 7) {
      return 'In $days days';
    } else {
      return 'In ${(days / 7).floor()} week${days >= 14 ? 's' : ''}';
    }
  }

  Widget _buildClassCard(TeachingShift shift, {required bool isToday, GlobalKey? key}) {
    final canJoin = VideoCallService.canJoinClass(shift);
    final now = DateTime.now();
    final timeUntil = shift.shiftStart.isAfter(now) 
        ? shift.shiftStart.difference(now)
        : null;

    // Format time
    final startTime = DateFormat('h:mm a').format(shift.shiftStart.toLocal());
    final endTime = DateFormat('h:mm a').format(shift.shiftEnd.toLocal());

    // Determine status and styling
    final bool isActive = shift.status == ShiftStatus.active || shift.isClockedIn;
    final bool isStartingSoon = timeUntil != null && timeUntil.inMinutes <= 15;
    final bool isStartingVerySoon = timeUntil != null && timeUntil.inMinutes <= 5;
    
    // Status configuration
    _ClassStatus status;
    
    if (isActive) {
      status = _ClassStatus(
        text: 'LIVE',
        color: const Color(0xFF10B981),
        bgColor: const Color(0xFFD1FAE5),
        icon: Icons.sensors,
        showPulse: true,
      );
    } else if (canJoin) {
      status = _ClassStatus(
        text: 'JOIN NOW',
        color: const Color(0xFF0E72ED),
        bgColor: const Color(0xFFDBEAFE),
        icon: Icons.videocam_rounded,
        showPulse: false,
      );
    } else if (isStartingVerySoon) {
      status = _ClassStatus(
        text: _formatTimeUntil(timeUntil),
        color: const Color(0xFFDC2626),
        bgColor: const Color(0xFFFEE2E2),
        icon: Icons.schedule,
        showPulse: true,
      );
    } else if (isStartingSoon) {
      status = _ClassStatus(
        text: _formatTimeUntil(timeUntil),
        color: const Color(0xFFF59E0B),
        bgColor: const Color(0xFFFEF3C7),
        icon: Icons.schedule,
        showPulse: false,
      );
    } else if (timeUntil != null) {
      status = _ClassStatus(
        text: _formatTimeUntil(timeUntil),
        color: const Color(0xFF6B7280),
        bgColor: const Color(0xFFF3F4F6),
        icon: Icons.access_time,
        showPulse: false,
      );
    } else {
      status = _ClassStatus(
        text: DateFormat('EEE, MMM d').format(shift.shiftStart.toLocal()),
        color: const Color(0xFF6B7280),
        bgColor: const Color(0xFFF3F4F6),
        icon: Icons.calendar_today,
        showPulse: false,
      );
    }

    return GestureDetector(
      key: key,
      onTap: canJoin || isActive ? () => _joinClass(shift) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (canJoin || isActive) 
                  ? status.color.withOpacity(0.15)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: (canJoin || isActive || isStartingVerySoon)
              ? Border.all(color: status.color.withOpacity(0.5), width: 1.5)
              : Border.all(color: const Color(0xFFE5E7EB), width: 1),
        ),
        child: Column(
          children: [
            // Main content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: Time display
                  Container(
                    width: 56,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: status.bgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat('h:mm').format(shift.shiftStart.toLocal()),
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: status.color,
                          ),
                        ),
                        Text(
                          DateFormat('a').format(shift.shiftStart.toLocal()).toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: status.color.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  
                  // Middle: Class info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shift.effectiveSubjectDisplayName,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF111827),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 14,
                              color: const Color(0xFF9CA3AF),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                shift.teacherName,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(0xFF6B7280),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text.rich(
                          TextSpan(
                            children: [
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Icon(
                                  Icons.schedule,
                                  size: 14,
                                  color: const Color(0xFF9CA3AF),
                                ),
                              ),
                              const WidgetSpan(child: SizedBox(width: 4)),
                              TextSpan(text: '$startTime - $endTime'),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Right: Status badge
                  Flexible(
                    fit: FlexFit.loose,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: status.bgColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (status.showPulse) ...[
                              _PulsingDot(color: status.color),
                              const SizedBox(width: 6),
                            ],
                            Icon(
                              status.icon,
                              size: 14,
                              color: status.color,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                status.text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: status.color,
                                  letterSpacing: 0.3,
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
            
            // Join button for active/joinable classes
            if (canJoin || isActive)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: ElevatedButton.icon(
                  onPressed: () => _joinClass(shift),
                  icon: Icon(
                    isActive ? Icons.sensors : Icons.videocam_rounded,
                    size: 18,
                  ),
                  label: Text(
                    isActive ? 'Join Live Class' : 'Join Class',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: status.color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Start the app tour for the student
  void _startAppTour() async {
    await OnboardingService.resetFeatureTour();
    if (mounted) {
      studentFeatureTour.startTour(context, isReplay: true);
    }
  }

  Future<void> _joinClass(TeachingShift shift) async {
    await VideoCallService.joinClass(
      context,
      shift,
      isTeacher: false, // Student joining
    );
  }
}

/// Status configuration for a class card
class _ClassStatus {
  final String text;
  final Color color;
  final Color bgColor;
  final IconData icon;
  final bool showPulse;

  const _ClassStatus({
    required this.text,
    required this.color,
    required this.bgColor,
    required this.icon,
    required this.showPulse,
  });
}

/// Animated pulsing dot for live/urgent indicators
class _PulsingDot extends StatefulWidget {
  final Color color;
  
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color.withOpacity(_animation.value),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(_animation.value * 0.5),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }
}
