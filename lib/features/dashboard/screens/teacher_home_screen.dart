import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../shift_management/widgets/shift_details_dialog.dart';
import '../../shift_management/screens/teacher_shift_screen.dart';
import '../../profile/screens/teacher_profile_screen.dart';
import '../../tasks/screens/quick_tasks_screen.dart';
import '../../tasks/models/task.dart';
import '../../tasks/services/task_service.dart';
import '../../../form_screen.dart';
import '../../forms/screens/my_submissions_screen.dart';
import '../../assignments/screens/teacher_assignments_screen.dart';
import '../screens/admin_dashboard_screen.dart';
import '../../../core/models/teaching_shift.dart';
import '../../../core/enums/shift_enums.dart';
import '../../../core/enums/task_enums.dart';
import '../../../core/services/shift_service.dart';
import '../../../core/services/user_role_service.dart';
import '../../../core/services/profile_picture_service.dart';
import 'package:url_launcher/url_launcher.dart';

class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({super.key});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  String _userName = 'Teacher';
  String? _profilePicUrl;
  bool _isLoading = true;
  List<TeachingShift> _upcomingShifts = [];
  TeachingShift? _activeShift;
  List<Task> _recentTasks = [];
  
  // Stats
  double _hoursThisWeek = 0;
  int _classesThisWeek = 0;
  int _totalStudents = 0;
  
  // Earnings and Approval Stats
  double _earningsThisWeek = 0;
  double _earningsThisMonth = 0;
  double _earningsToday = 0;
  int _pendingApprovals = 0;
  int _approvedThisWeek = 0;
  double _defaultHourlyRate = 15.0; // Default hourly rate if not specified

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Load user name and profile picture
        final userData = await UserRoleService.getCurrentUserData();
        final profilePic = await ProfilePictureService.getProfilePictureUrl();
        
        if (userData != null && mounted) {
          setState(() {
            _userName = userData['first_name'] ?? 'Teacher';
            _profilePicUrl = profilePic;
          });
        }

        // Load active shift (currently clocked in)
        final active = await ShiftService.getCurrentActiveShift(user.uid);

        // Load ALL teacher shifts and filter STRICTLY for future only
        final now = DateTime.now();
        final allShifts = await ShiftService.getShiftsForTeacher(user.uid);
        
        final futureShifts = allShifts.where((shift) {
          final localStart = shift.shiftStart.toLocal();
          final localEnd = shift.shiftEnd.toLocal();
          
          if (active != null && shift.id == active.id) return false;
          if (localEnd.isBefore(now)) return false;
          if (localStart.isBefore(now)) return false;
          return localStart.isAfter(now);
        }).toList();
        
        futureShifts.sort((a, b) => a.shiftStart.compareTo(b.shiftStart));

        // Load recent tasks assigned to teacher
        await _loadRecentTasks();
        
        // Load stats
        await _loadStats(user.uid);

        if (mounted) {
          setState(() {
            _activeShift = active;
            _upcomingShifts = futureShifts.take(1).toList();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading teacher home data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadRecentTasks() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Fetch all tasks for this teacher and filter in memory
      // This avoids complex index requirements
      final allTasksSnapshot = await FirebaseFirestore.instance
          .collection('tasks')
          .where('assignedTo', arrayContains: user.uid)
          .get();

      final allTasks = allTasksSnapshot.docs
          .map((doc) {
            try {
              return Task.fromFirestore(doc);
            } catch (e) {
              debugPrint('Error parsing task ${doc.id}: $e');
              return null;
            }
          })
          .where((task) => task != null && task.status != TaskStatus.done)
          .cast<Task>()
          .toList();

      // Sort by creation date (most recent first)
      allTasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (mounted) {
        setState(() {
          _recentTasks = allTasks.take(3).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading tasks: $e');
    }
  }

  Future<void> _loadStats(String teacherId) async {
    try {
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final startOfWeekDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day, 0, 0, 0);
      final endOfWeekDate = startOfWeekDate.add(const Duration(days: 7));
      
      // Start of month
      final startOfMonth = DateTime(now.year, now.month, 1, 0, 0, 0);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      
      // Start of today
      final startOfToday = DateTime(now.year, now.month, now.day, 0, 0, 0);
      final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
      
      debugPrint('📊 Loading stats for teacher: $teacherId');
      debugPrint('📅 Week range: ${startOfWeekDate.toIso8601String()} to ${endOfWeekDate.toIso8601String()}');
      
      // Fetch this teacher's timesheet entries
      final timesheetQuery = await FirebaseFirestore.instance
          .collection('timesheet_entries')
          .where('teacher_id', isEqualTo: teacherId)
          .get();

      double totalHours = 0;
      int classCount = 0;
      Set<String> uniqueStudents = {};
      
      // Earnings tracking
      double weeklyEarnings = 0;
      double monthlyEarnings = 0;
      double dailyEarnings = 0;
      int pendingCount = 0;
      int approvedThisWeekCount = 0;

      for (var doc in timesheetQuery.docs) {
        final data = doc.data();
        // Support both naming conventions
        final clockIn = (data['clock_in_time'] ?? data['clock_in_timestamp']) as Timestamp?;
        final clockOut = (data['clock_out_time'] ?? data['clock_out_timestamp']) as Timestamp?;
        final status = data['status'] as String? ?? 'pending';
        final hourlyRate = (data['hourly_rate'] as num?)?.toDouble() ?? _defaultHourlyRate;
        
        if (clockIn == null) continue;
        
        final clockInDate = clockIn.toDate();
        
        // Check if this is an edited timesheet
        final isEdited = data['is_edited'] as bool? ?? false;
        final editApproved = data['edit_approved'] as bool? ?? false;
        
        // Calculate hours worked
        double hoursWorked = 0;
        if (clockOut != null) {
          final duration = clockOut.toDate().difference(clockInDate);
          hoursWorked = duration.inMinutes / 60.0;
        }
        
        // Check timesheet status
        if (status == 'pending') {
          pendingCount++;
        }
        
        // Check if this week for weekly stats
        final isThisWeek = clockInDate.isAfter(startOfWeekDate.subtract(const Duration(seconds: 1))) && 
                           clockInDate.isBefore(endOfWeekDate);
        
        // Check if this month
        final isThisMonth = clockInDate.isAfter(startOfMonth.subtract(const Duration(seconds: 1))) && 
                            clockInDate.isBefore(endOfMonth);
        
        // Check if today
        final isToday = clockInDate.isAfter(startOfToday.subtract(const Duration(seconds: 1))) && 
                        clockInDate.isBefore(endOfToday);
        
        // Determine correct earnings value
        double shiftEarnings = hoursWorked * hourlyRate;
        
        // If edited and approved, verify against total_hours if available or recalculate
        if (isEdited && editApproved) {
           // The hoursWorked calculated above uses the clock_in/out from the document
           // Since the document is updated upon edit, hoursWorked should already be correct
           // However, if there's a total_hours string override or specific earnings override, check here
           shiftEarnings = hoursWorked * hourlyRate;
        }
        
        if (isThisWeek && clockOut != null) {
          totalHours += hoursWorked;
          classCount++;
          
          // Calculate earnings for approved timesheets
          if (status == 'approved' || status == 'paid') {
            weeklyEarnings += shiftEarnings;
            approvedThisWeekCount++;
          }
        }
        
        if (isThisMonth && clockOut != null && (status == 'approved' || status == 'paid')) {
          monthlyEarnings += shiftEarnings;
        }
        
        if (isToday && clockOut != null && (status == 'approved' || status == 'paid')) {
          dailyEarnings += shiftEarnings;
        }
        
        // Get unique students from shift
        if (data['shift_id'] != null && isThisWeek) {
          try {
            final shiftDoc = await FirebaseFirestore.instance
                .collection('teaching_shifts')
                .doc(data['shift_id'])
                .get();
            
            if (shiftDoc.exists) {
              final shiftData = shiftDoc.data();
              if (shiftData != null) {
                // Get student IDs or names
                if (shiftData['student_ids'] is List) {
                  uniqueStudents.addAll((shiftData['student_ids'] as List).cast<String>());
                } else if (shiftData['student_names'] is List) {
                  uniqueStudents.addAll((shiftData['student_names'] as List).cast<String>());
                }
              }
            }
          } catch (e) {
            debugPrint('Error fetching shift for stats: $e');
          }
        }
      }

      debugPrint('📊 Stats calculated: Hours: $totalHours, Classes: $classCount, Students: ${uniqueStudents.length}');
      debugPrint('💰 Earnings: Weekly: \$${weeklyEarnings.toStringAsFixed(2)}, Monthly: \$${monthlyEarnings.toStringAsFixed(2)}');
      debugPrint('📋 Approvals: Pending: $pendingCount, Approved this week: $approvedThisWeekCount');

      if (mounted) {
        setState(() {
          _hoursThisWeek = totalHours;
          _classesThisWeek = classCount;
          _earningsThisWeek = weeklyEarnings;
          _earningsThisMonth = monthlyEarnings;
          _earningsToday = dailyEarnings;
          _pendingApprovals = pendingCount;
          _approvedThisWeek = approvedThisWeekCount;
          _totalStudents = uniqueStudents.length;
        });
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  Future<void> _launchURL(String url) async {
    try {
      debugPrint('🌐 Attempting to open URL: $url');
      final uri = Uri.parse(url);
      
      // Don't use canLaunchUrl on mobile - it often returns false incorrectly
      // Just try to launch directly and catch errors
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!launched && mounted) {
          // Try with inAppWebView as fallback
          final fallbackLaunched = await launchUrl(
            uri,
            mode: LaunchMode.inAppWebView,
          );
          if (!fallbackLaunched && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Could not open $url'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (launchError) {
        debugPrint('❌ Launch error, trying fallback: $launchError');
        // Try inAppWebView as fallback
        try {
          await launchUrl(uri, mode: LaunchMode.inAppWebView);
        } catch (fallbackError) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Could not open $url'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error launching URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening link: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildStatsRow(),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildCompactEarningsCard(),
                ),
                const SizedBox(height: 16),
                if (_activeShift != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildActiveSessionCard(),
                  ),
                  const SizedBox(height: 24),
                ],
                // ORDER: Next Class → My Tasks → Quick Access
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildUpcomingSection(),
                ),
                const SizedBox(height: 24),
                if (_recentTasks.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildRecentTasksSection(),
                  ),
                  const SizedBox(height: 24),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildQuickAccessSection(),
                ),
                const SizedBox(height: 24),
                // Islamic Resources Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildIslamicResourcesSection(),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0386FF), Color(0xFF0066CC)],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getGreeting(),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.9),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _userName,
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  DateFormat('EEEE, MMMM d').format(DateTime.now()),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withOpacity(0.8),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TeacherProfileScreen()),
              );
            },
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                image: _profilePicUrl != null
                    ? DecorationImage(
                        image: NetworkImage(_profilePicUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _profilePicUrl == null
                  ? const Icon(Icons.person, color: Color(0xFF0386FF), size: 28)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
        children: [
          _buildStatCard(
            icon: Icons.access_time_filled,
            value: '${_hoursThisWeek.toStringAsFixed(1)}h',
            label: 'This Week',
            color: const Color(0xFF10B981),
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            icon: Icons.school,
            value: '$_classesThisWeek',
            label: 'Classes',
            color: const Color(0xFF8B5CF6),
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            icon: Icons.attach_money,
            value: '\$${_earningsThisWeek.toStringAsFixed(2)}',
            label: 'Approved',
            color: const Color(0xFF10B981),
          ),
        ],
      );
  }
  
  // Compact Earnings Card - much smaller and professional
  Widget _buildCompactEarningsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0386FF), Color(0xFF0066CC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0386FF).withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Earnings values
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCompactEarningItem('Today', _earningsToday),
                Container(width: 1, height: 30, color: Colors.white.withOpacity(0.2)),
                _buildCompactEarningItem('Week', _earningsThisWeek),
                Container(width: 1, height: 30, color: Colors.white.withOpacity(0.2)),
                _buildCompactEarningItem('Month', _earningsThisMonth),
              ],
            ),
          ),
          // Approval badge
          if (_pendingApprovals > 0)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFBBF24),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.pending, size: 12, color: Color(0xFF78350F)),
                  const SizedBox(width: 4),
                  Text(
                    '$_pendingApprovals',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF78350F),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildCompactEarningItem(String label, double amount) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '\$${amount.toStringAsFixed(0)}',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 9,
                color: const Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSessionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.play_circle_fill, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Active Session',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'IN PROGRESS',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _activeShift!.displayName,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            '${DateFormat('h:mm a').format(_activeShift!.shiftStart)} - ${DateFormat('h:mm a').format(_activeShift!.shiftEnd)}',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showShiftDetails(_activeShift!),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(
                'View Session',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTasksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.task_alt, color: Color(0xFFEF4444), size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'My Tasks',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const QuickTasksScreen()),
                );
              },
              child: Text(
                'See All',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0386FF),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._recentTasks.map((task) => _buildTaskCard(task)),
      ],
    );
  }

  Widget _buildTaskCard(Task task) {
    Color statusColor;
    IconData statusIcon;
    
    switch (task.status) {
      case TaskStatus.inProgress:
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.pending;
        break;
      case TaskStatus.done:
        statusColor = const Color(0xFF10B981);
        statusIcon = Icons.check_circle;
        break;
      default:
        statusColor = const Color(0xFF0386FF);
        statusIcon = Icons.circle_outlined;
    }

    final isOverdue = task.dueDate.isBefore(DateTime.now()) && task.status != TaskStatus.done;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const QuickTasksScreen()),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOverdue ? Colors.red.withOpacity(0.3) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(statusIcon, color: statusColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 12, color: isOverdue ? Colors.red : const Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(
                        'Due ${DateFormat('MMM d').format(task.dueDate)}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isOverdue ? Colors.red : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: const Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Next Class',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TeacherShiftScreen()),
                );
              },
              child: Text(
                'See All',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0386FF),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _upcomingShifts.isEmpty
                ? _buildEmptyUpcoming()
                : _buildUpcomingCard(_upcomingShifts.first),
      ],
    );
  }

  Widget _buildUpcomingCard(TeachingShift shift) {
    final isToday = shift.shiftStart.day == DateTime.now().day &&
        shift.shiftStart.month == DateTime.now().month &&
        shift.shiftStart.year == DateTime.now().year;
    
    final isTomorrow = shift.shiftStart.day == DateTime.now().add(const Duration(days: 1)).day &&
        shift.shiftStart.month == DateTime.now().add(const Duration(days: 1)).month;

    String dateLabel;
    if (isToday) {
      dateLabel = 'Today';
    } else if (isTomorrow) {
      dateLabel = 'Tomorrow';
    } else {
      dateLabel = DateFormat('EEE, MMM d').format(shift.shiftStart);
    }

    return GestureDetector(
      onTap: () => _showShiftDetails(shift),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isToday 
                    ? const Color(0xFF0386FF).withOpacity(0.1)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('d').format(shift.shiftStart),
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isToday ? const Color(0xFF0386FF) : const Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    DateFormat('MMM').format(shift.shiftStart).toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isToday ? const Color(0xFF0386FF) : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          shift.displayName,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isToday 
                              ? const Color(0xFF0386FF).withOpacity(0.1)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          dateLabel,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isToday ? const Color(0xFF0386FF) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 14, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Text(
                        '${DateFormat('h:mm a').format(shift.shiftStart)} - ${DateFormat('h:mm a').format(shift.shiftEnd)}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyUpcoming() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_available, size: 32, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 16),
          Text(
            'No Upcoming Classes',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Enjoy your free time!',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Access',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildCompactQuickAccessCard(
                icon: Icons.assignment_outlined,
                label: 'Assignments',
                color: const Color(0xFF8B5CF6),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TeacherAssignmentsScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              _buildCompactQuickAccessCard(
                icon: Icons.description_outlined,
                label: 'My Forms',
                color: const Color(0xFF10B981),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MySubmissionsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactQuickAccessCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIslamicResourcesSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEC4899).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.mosque,
                  color: Color(0xFFEC4899),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Islamic Resources',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildResourceItem(
            'Quran.com - Recitation & Translation',
            Icons.menu_book_rounded,
            const Color(0xff10B981),
            'https://quran.com',
          ),
          _buildResourceItem(
            'Sunnah.com - Hadith Collections',
            Icons.book_rounded,
            const Color(0xff3B82F6),
            'https://sunnah.com',
          ),
          _buildResourceItem(
            'Islamic Finder - Prayer Times',
            Icons.access_time_rounded,
            const Color(0xffEF4444),
            'https://www.islamicfinder.org',
          ),
          _buildResourceItem(
            'IslamQA.info - Q&A',
            Icons.question_answer_rounded,
            const Color(0xff8B5CF6),
            'https://islamqa.info',
          ),
          _buildResourceItem(
            'Bayyinah Institute',
            Icons.school_rounded,
            const Color(0xffF59E0B),
            'https://bayyinah.com',
          ),
          _buildResourceItem(
            'SeekersGuidance - Courses',
            Icons.play_circle_outline,
            const Color(0xff06B6D4),
            'https://seekersguidance.org',
          ),
        ],
      ),
    );
  }

  Widget _buildResourceItem(
    String title,
    IconData icon,
    Color color,
    String url,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _launchURL(url),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xff374151),
                  ),
                ),
              ),
              Icon(
                Icons.open_in_new,
                size: 16,
                color: color.withOpacity(0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showShiftDetails(TeachingShift shift) {
    showDialog(
      context: context,
      builder: (context) => ShiftDetailsDialog(
        shift: shift,
        onRefresh: _loadData,
      ),
    );
  }
}
