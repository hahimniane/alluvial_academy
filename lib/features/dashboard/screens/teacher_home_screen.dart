// ✅ UNIFIED TEACHER DASHBOARD - SINGLE SOURCE OF TRUTH
// This is the ONLY file for teacher dashboard/home screen
// All other teacher dashboard files should use this:
//   - admin_dashboard_screen.dart → uses TeacherHomeScreen (line 515)
//   - role_based_dashboard.dart → uses TeacherHomeScreen (line 301)
//   - mobile_dashboard_screen.dart → uses TeacherHomeScreen (line 346)
//
// Files that can be DELETED after verification:
//   - teacher_mobile_home.dart (deprecated, functionality merged here)
//   - admin_dashboard_screen.dart methods: _buildTeacherDashboard, _buildMobileTeacherDashboard (deprecated)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../l10n/app_localizations.dart';
import '../../shift_management/widgets/shift_details_dialog.dart';
import '../../shift_management/screens/teacher_shift_screen.dart';
import '../../profile/screens/teacher_profile_screen.dart';
import '../../settings/screens/mobile_settings_screen.dart';
import '../../tasks/screens/quick_tasks_screen.dart';
import '../../tasks/models/task.dart';
import '../../tasks/services/task_service.dart';
import '../../../form_screen.dart';
import '../../forms/screens/my_submissions_screen.dart';
import '../../forms/screens/teacher_forms_screen.dart';
import '../../assignments/screens/teacher_assignments_screen.dart';
import '../screens/admin_dashboard_screen.dart';
import '../../../core/models/teaching_shift.dart';
import '../../../core/enums/shift_enums.dart';
import '../../../core/enums/task_enums.dart';
import '../../../core/services/shift_service.dart';
import '../../../core/services/shift_timesheet_service.dart';
import '../../../core/services/shift_form_service.dart';
import '../../../core/services/shift_repository.dart';
import '../../../core/services/task_repository.dart';
import '../../../core/services/user_role_service.dart';
import '../../../core/services/profile_picture_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/form_template_service.dart';
import '../../../core/models/form_template.dart';
import '../../forms/widgets/form_details_modal.dart';
import '../widgets/pending_form_button.dart';
import '../widgets/date_strip_calendar.dart';
import '../widgets/timeline_shift_card.dart';
import 'package:url_launcher/url_launcher.dart';

class TeacherHomeScreen extends StatefulWidget {
  final bool showScaffold; // If false, returns content only (for use in AdminDashboard)
  
  const TeacherHomeScreen({super.key, this.showScaffold = true});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  String _userName = 'Teacher';
  String? _profilePicUrl;
  bool _isLoading = true;
  List<TeachingShift> _upcomingShifts = [];
  List<TeachingShift> _allShifts = []; // All shifts from stream
  List<TeachingShift> _dailyShifts = []; // Filtered for selected day
  DateTime _selectedDate = DateTime.now(); // Selected date for schedule
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
  
  // Pending forms count and details
  int _pendingFormsCount = 0;
  List<Map<String, dynamic>> _pendingFormShifts = []; // List of shifts needing forms

  // Real-time stream subscriptions
  StreamSubscription? _shiftsSubscription;
  StreamSubscription? _timesheetSubscription;

  // Programmed clock-in state (for early clock-in countdown)
  String? _programmedShiftId;
  Timer? _programTimer;
  String _timeUntilAutoStart = "";
  Timer? _uiRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupRealtimeListeners();
    
    // Refresh UI every second to update countdown and time-based buttons
    _uiRefreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          // Just trigger rebuild for time-based UI updates
        });
      }
    });
  }

  @override
  void dispose() {
    _shiftsSubscription?.cancel();
    _timesheetSubscription?.cancel();
    _programTimer?.cancel();
    _uiRefreshTimer?.cancel();
    super.dispose();
  }

  /// Setup real-time listeners for automatic refresh
  void _setupRealtimeListeners() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Use ShiftService stream for real-time updates
    _shiftsSubscription = ShiftService.getTeacherShifts(user.uid).listen(
      (shifts) {
        if (!mounted) return;
        setState(() {
          _allShifts = shifts;
          _filterShiftsForDate(_selectedDate);
          // Update active shift
          try {
            _activeShift = shifts.firstWhere((s) => s.isClockedIn);
          } catch (e) {
            _activeShift = null;
          }
          // Update upcoming shifts - get ALL future shifts, sorted, then take first for "next session"
          final now = DateTime.now();
          final futureShifts = shifts
              .where((s) {
                final shiftEnd = s.shiftEnd.toLocal();
                return shiftEnd.isAfter(now) && !s.isClockedIn;
              })
              .toList();
          futureShifts.sort((a, b) => a.shiftStart.compareTo(b.shiftStart));
          _upcomingShifts = futureShifts; // Keep all for potential future use, but display only first
        });
        debugPrint('🔄 Home: Shifts updated via stream');
      },
      onError: (e) {
        debugPrint('❌ Home: Shift stream error: $e');
      },
    );

    // Listen for timesheet changes (clock-in/out, status changes)
    _timesheetSubscription = FirebaseFirestore.instance
        .collection('timesheet_entries')
        .where('teacher_id', isEqualTo: user.uid)
        .orderBy('created_at', descending: true)
        .limit(10) // Only listen to recent entries
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      
      // Reload stats when timesheets change
      debugPrint('🔄 Home: Timesheets updated - reloading stats');
      _loadStats(user.uid);
    }, onError: (e) {
      debugPrint('❌ Home: Timesheet stream error: $e');
    });
  }

  /// Filter shifts for the selected date - EXCLUDE PAST SHIFTS
  void _filterShiftsForDate(DateTime date) {
    final now = DateTime.now();
    setState(() {
      _dailyShifts = _allShifts.where((shift) {
        // Match selected date
        final matchesDate = shift.shiftStart.year == date.year &&
            shift.shiftStart.month == date.month &&
            shift.shiftStart.day == date.day;
        
        // EXCLUDE past shifts (shift has ended)
        final shiftEnd = shift.shiftEnd.toLocal();
        final isPast = shiftEnd.isBefore(now);
        
        return matchesDate && !isPast;
      }).toList();

      // Sort by start time
      _dailyShifts.sort((a, b) => a.shiftStart.compareTo(b.shiftStart));
    });
  }

  /// Handle date selection from calendar
  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
    _filterShiftsForDate(date);
  }

  String _getGreeting(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hour = DateTime.now().hour;
    if (l10n == null) {
      if (hour < 12) return 'Good Morning';
      if (hour < 17) return 'Good Afternoon';
      return 'Good Evening';
    }
    if (hour < 12) return l10n.greetingMorning;
    if (hour < 17) return l10n.greetingAfternoon;
    return l10n.greetingEvening;
  }

  Future<void> _loadData() async {
    // OPTIMIZATION: Show cached data immediately for instant UI
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Try to get cached shifts immediately (synchronous)
      final cachedShifts = ShiftRepository.getCachedTeacherShifts(user.uid);
      if (cachedShifts != null && cachedShifts.isNotEmpty) {
        final now = DateTime.now();
        final cachedUpcoming = cachedShifts
            .where((shift) => shift.shiftEnd.toLocal().isAfter(now))
            .toList()
          ..sort((a, b) => a.shiftStart.compareTo(b.shiftStart));
        
        if (mounted) {
          setState(() {
            _upcomingShifts = cachedUpcoming;
            _allShifts = cachedShifts;
            _isLoading = false; // Show UI immediately with cached data
          });
        }
      } else {
        setState(() => _isLoading = true);
      }
    } else {
      setState(() => _isLoading = true);
    }
    
    try {
      if (user != null) {
        // Load user name and profile picture
        final userData = await UserRoleService.getCurrentUserData();
        final profilePicUrl = await ProfilePictureService.getProfilePictureUrl();
        
        if (userData != null && mounted) {
          setState(() {
            _userName = userData['first_name'] ?? 'Teacher';
            _profilePicUrl = profilePicUrl;
          });
        }

        // Load active shift (currently clocked in)
        final active = await ShiftService.getCurrentActiveShift(user.uid);

        // Load ALL teacher shifts (including past for calendar navigation)
        // Use cached repository for better performance
        final allShifts = await ShiftRepository.getTeacherShiftsCached(user.uid);
        
        // Filter for upcoming shifts (for the "upcoming" section)
        final now = DateTime.now();
        final futureShifts = allShifts.where((shift) {
          final localEnd = shift.shiftEnd.toLocal();
          // Keep if shift hasn't ended OR if it's the active shift
          return localEnd.isAfter(now) || (active != null && shift.id == active.id);
        }).toList();
        
        futureShifts.sort((a, b) => a.shiftStart.compareTo(b.shiftStart));

        // Load recent tasks assigned to teacher
        await _loadRecentTasks();
        
        // Load stats
        await _loadStats(user.uid);
        
        // Load pending forms count
        await _loadPendingFormsCount(user.uid);

        if (mounted) {
          setState(() {
            _activeShift = active;
            // Store ALL shifts (including past) for calendar, but filter in display
            _allShifts = allShifts;
            // Sort and store upcoming shifts (for "next session" display)
            futureShifts.sort((a, b) => a.shiftStart.compareTo(b.shiftStart));
            _upcomingShifts = futureShifts; // All upcoming, sorted by time
            _filterShiftsForDate(_selectedDate); // This filters out past shifts
            _isLoading = false;
          });
          debugPrint('📅 Loaded ${_allShifts.length} total shifts, ${_dailyShifts.length} for selected date');
        }
      }
    } catch (e) {
      debugPrint('Error loading teacher home data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Check for pending Readiness Forms from completed AND missed shifts
  /// Uses ShiftFormService which handles both cases
  Future<void> _loadPendingFormsCount(String teacherId) async {
    try {
      // Use the service method that handles both completed and missed shifts
      final pendingForms = await ShiftFormService.getPendingFormsForTeacher();
      
      if (mounted) {
        setState(() {
          _pendingFormsCount = pendingForms.length;
          _pendingFormShifts = pendingForms;
        });
      }

      debugPrint('📋 Pending forms count: ${pendingForms.length}');
      debugPrint('   - Completed shifts: ${pendingForms.where((f) => f['type'] == 'completed').length}');
      debugPrint('   - Missed shifts: ${pendingForms.where((f) => f['type'] == 'missed').length}');
    } catch (e) {
      debugPrint('Error loading pending forms count: $e');
    }
  }

  Future<void> _loadRecentTasks() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Use cached repository for better performance
      final recentTasks = await TaskRepository.getRecentTasksCached(user.uid, limit: 3);

      if (mounted) {
        setState(() {
          _recentTasks = recentTasks;
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
        
        // Calculate hours worked (using seconds for precision)
        double hoursWorked = 0;
        if (clockOut != null) {
          final duration = clockOut.toDate().difference(clockInDate);
          hoursWorked = duration.inSeconds / 3600.0; // Use seconds for accurate sub-minute tracking
        }
        
        // IMPORTANT: Verify shift still exists before counting stats
        final shiftId = data['shift_id'] as String? ?? data['shiftId'] as String?;
        bool shiftExists = false;
        
        if (shiftId != null && shiftId.isNotEmpty) {
          try {
            final shiftDoc = await FirebaseFirestore.instance
                .collection('teaching_shifts')
                .doc(shiftId)
                .get();
            shiftExists = shiftDoc.exists;
          } catch (e) {
            debugPrint('Error checking shift existence: $e');
            shiftExists = false;
          }
        }
        
        // Skip this timesheet if shift doesn't exist (orphaned entry)
        if (!shiftExists) {
          debugPrint('⚠️ Skipping orphaned timesheet entry ${doc.id} - shift $shiftId does not exist');
          continue;
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
        
        // Calculate earnings - PREFER payment_amount from timesheet (saved during clock-out)
        // This ensures consistency with what was actually paid
        double shiftEarnings = (data['payment_amount'] as num?)?.toDouble() ??
                               (data['total_pay'] as num?)?.toDouble() ??
                               (hoursWorked * hourlyRate); // Fallback to calculation
        
        // If edited and approved, verify against total_hours if available or recalculate
        if (isEdited && editApproved) {
           // The hoursWorked calculated above uses the clock_in/out from the document
           // Since the document is updated upon edit, hoursWorked should already be correct
           // However, if there's a total_hours string override or specific earnings override, check here
           shiftEarnings = (data['payment_amount'] as num?)?.toDouble() ??
                          (data['total_pay'] as num?)?.toDouble() ??
                          (hoursWorked * hourlyRate);
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
        if (shiftId != null && isThisWeek && shiftExists) {
          try {
            final shiftDoc = await FirebaseFirestore.instance
                .collection('teaching_shifts')
                .doc(shiftId)
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
                content: Text(AppLocalizations.of(context)!.couldNotOpenUrl),
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
                content: Text(AppLocalizations.of(context)!.couldNotOpenUrl),
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
            content: Text(AppLocalizations.of(context)!
                .dashboardErrorOpeningLink(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                // Only show header if standalone (not embedded in AdminDashboard)
                if (widget.showScaffold) ...[
                  _buildHeader(),
                  const SizedBox(height: 8),
                ],
                // PAYMENT SECTION - Comes FIRST
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildStatsRow(context),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildCompactEarningsCard(),
                ),
                const SizedBox(height: 16),
                if (_pendingFormsCount > 0) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildPendingFormsBanner(),
                  ),
                  const SizedBox(height: 16),
                ],
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
                  child: _buildUpcomingSection(context),
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
                  child: _buildQuickAccessSection(context),
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
        );
    
    // If showScaffold is false, return content only (for use in AdminDashboard with navigation)
    if (!widget.showScaffold) {
      return content;
    }
    
    // Otherwise, return full Scaffold (for mobile_dashboard_screen)
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      body: SafeArea(
        child: content,
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
                  _getGreeting(context),
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
          // Profile Picture and Settings
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Settings Icon
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white, size: 24),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MobileSettingsScreen(),
                    ),
                  ).then((_) {
                    // Refresh profile picture after returning from settings
                    _refreshProfilePicture();
                  });
                },
                tooltip: 'Settings',
              ),
              const SizedBox(width: 8),
              // Profile Picture Button
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TeacherProfileScreen(),
                    ),
                  ).then((_) {
                    // Refresh profile picture after returning from profile
                    _refreshProfilePicture();
                  });
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _profilePicUrl == null 
                        ? Colors.white.withOpacity(0.2)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: _profilePicUrl != null
                        ? Image.network(
                            _profilePicUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.person,
                                color: const Color(0xFF0386FF),
                                size: 24,
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                              );
                            },
                          )
                        : Icon(
                            Icons.person,
                            color: const Color(0xFF0386FF),
                            size: 24,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  /// Refresh profile picture after returning from profile/settings
  Future<void> _refreshProfilePicture() async {
    final profilePicUrl = await ProfilePictureService.getProfilePictureUrl();
    if (mounted) {
      setState(() {
        _profilePicUrl = profilePicUrl;
      });
    }
  }

  Widget _buildStatsRow(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
        children: [
          _buildStatCard(
            icon: Icons.access_time_filled,
            value: '${_hoursThisWeek.toStringAsFixed(1)}h',
            label: l10n?.dashboardThisWeek ?? 'This Week',
            color: const Color(0xFF10B981),
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            icon: Icons.school,
            value: '$_classesThisWeek',
            label: l10n?.dashboardClasses ?? 'Classes',
            color: const Color(0xFF8B5CF6),
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            icon: Icons.attach_money,
            value: '\$${_earningsThisWeek.toStringAsFixed(2)}',
            label: l10n?.dashboardApproved ?? 'Approved',
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
                    AppLocalizations.of(context)!.pendingapprovals,
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

  /// Builds a banner/card alerting the teacher to pending Readiness Forms
  Widget _buildPendingFormsBanner() {
    return GestureDetector(
      onTap: () {
        // Show dialog with list of shifts that need forms
        _showPendingFormsDialog();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.assignment_late,
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
                    _pendingFormsCount == 1
                        ? '1 Readiness Form Required'
                        : '$_pendingFormsCount Readiness Forms Required',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppLocalizations.of(context)!.readinessFormComplete,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Colors.white,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  /// Shows a dialog with list of shifts that need Readiness Forms
  void _showPendingFormsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.assignment_late,
                      color: Color(0xFFF59E0B),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.readinessFormPending,
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          AppLocalizations.of(context)!.readinessFormSelectShift,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // List of pending shifts
            Flexible(
              child: _pendingFormShifts.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              size: 48,
                              color: Color(0xFF10B981),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              AppLocalizations.of(context)!.readinessFormAllComplete,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _pendingFormShifts.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                      itemBuilder: (context, index) {
                        final shift = _pendingFormShifts[index];
                        final shiftType = shift['type'] as String?;
                        final isMissed = shiftType == 'missed';
                        
                        // Handle different data structures
                        final shiftTitle = shift['shiftTitle'] ?? 
                                         shift['displayName'] ?? 
                                         AppLocalizations.of(context)!.commonUnknownShift;
                        
                        // Safely handle shiftDate - can be DateTime, Timestamp, or null
                        // Check multiple possible field names: shiftDate, shiftStart, clockInTime
                        // Note: getPendingFormsForTeacher already converts Timestamps to DateTime
                        DateTime? shiftDate;
                        final shiftDateValue = shift['shiftDate'] ?? 
                                              shift['shiftStart'] ?? 
                                              shift['clockInTime'];
                        if (shiftDateValue != null) {
                          if (shiftDateValue is DateTime) {
                            shiftDate = shiftDateValue;
                          } else if (shiftDateValue is Timestamp) {
                            shiftDate = shiftDateValue.toDate();
                          }
                        }
                        
                        // Safely handle shiftEnd - can be DateTime, Timestamp, or null
                        // Check multiple possible field names: shiftEnd, clockOutTime
                        // Note: getPendingFormsForTeacher already converts Timestamps to DateTime
                        DateTime? shiftEnd;
                        final shiftEndValue = shift['shiftEnd'] ?? shift['clockOutTime'];
                        if (shiftEndValue != null) {
                          if (shiftEndValue is DateTime) {
                            shiftEnd = shiftEndValue;
                          } else if (shiftEndValue is Timestamp) {
                            shiftEnd = shiftEndValue.toDate();
                          }
                        }
                        
                        final subject = shift['subject'] as String? ?? '';
                        final studentNamesRaw = shift['studentNames'];
                        List<String> studentNames = [];
                        if (studentNamesRaw != null) {
                          if (studentNamesRaw is List) {
                            studentNames = studentNamesRaw
                                .map((e) => e?.toString() ?? '')
                                .where((e) => e.isNotEmpty)
                                .toList()
                                .cast<String>();
                          }
                        }
                        final studentDisplay = studentNames.isNotEmpty 
                            ? studentNames.join(', ') 
                            : 'Student';
                        final missedReason = shift['missedReason'] as String?;
                        final currentShiftId = shift['shiftId'] as String?;
                        
                        return InkWell(
                          onTap: null, // Disable tap on row, button handles action
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: isMissed ? BoxDecoration(
                              color: Colors.orange.withOpacity(0.05),
                              border: Border(
                                left: BorderSide(color: Colors.orange, width: 3),
                              ),
                            ) : null,
                            child: Row(
                              children: [
                                // Left side - shift info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Title with missed badge
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              isMissed ? shiftTitle : '$studentDisplay - $subject',
                                              style: GoogleFonts.inter(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF1E293B),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isMissed)
                                            Container(
                                              margin: const EdgeInsets.only(left: 8),
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                AppLocalizations.of(context)!.shiftMissed,
                                                style: GoogleFonts.inter(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.orange.shade700,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      // Time: Start - End
                                      if (shiftDate != null && shiftEnd != null)
                                        Row(
                                          children: [
                                            Icon(
                                              isMissed ? Icons.error_outline : Icons.access_time,
                                              size: 14,
                                              color: isMissed ? Colors.orange : const Color(0xFF64748B),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${DateFormat('h:mm a').format(shiftDate)} - ${DateFormat('h:mm a').format(shiftEnd)}',
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                color: const Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        )
                                      else if (isMissed && missedReason != null)
                                        Row(
                                          children: [
                                            const Icon(Icons.info_outline, size: 14, color: Colors.orange),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                missedReason,
                                                style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  color: Colors.orange.shade700,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      const SizedBox(height: 2),
                                      // Date
                                      Row(
                                        children: [
                                          const Icon(Icons.calendar_today, size: 14, color: Color(0xFF94A3B8)),
                                          const SizedBox(width: 4),
                                          Text(
                                            shiftDate != null
                                                ? DateFormat('EEEE, MMMM d, yyyy').format(shiftDate)
                                                : shiftEnd != null
                                                    ? DateFormat('EEEE, MMMM d, yyyy').format(shiftEnd)
                                                    : 'Date not available',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: const Color(0xFF94A3B8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Fill Form or View Form button (check if form exists)
                                PendingFormButton(
                                  shiftId: currentShiftId ?? '',
                                  onFill: () {
                                    Navigator.pop(context);
                                    _navigateToFormForShift(shift);
                                  },
                                  onView: (formId, responses) {
                                    Navigator.pop(context);
                                    FormDetailsModal.show(
                                      context,
                                      formId: formId,
                                      shiftId: currentShiftId ?? '',
                                      responses: responses,
                                    );
                                  },
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
    );
  }

  /// Navigate to FormScreen for a specific shift
  /// Handles both completed shifts (with timesheet) and missed shifts (without timesheet)
  /// FIXED: Now fetches template directly (like Quick Access) instead of passing ID
  Future<void> _navigateToFormForShift(Map<String, dynamic> shift) async {
    final timesheetId = shift['timesheetId'] as String?;
    final shiftId = shift['shiftId'] as String?;
    final shiftType = shift['type'] as String?; // 'completed' or 'missed'
    
    // Shift ID is required, but timesheetId is optional (for missed shifts)
    if (shiftId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.errorMissingShiftInformation),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    debugPrint('📋 Navigating to form for shift: $shiftId');
    debugPrint('   - Type: ${shiftType ?? "unknown"}');
    debugPrint('   - TimesheetId: $timesheetId');
    
    // FIXED: Use same approach as Quick Access - get ALL templates and filter to latest version
    // This ensures we get the latest version even if config points to an old template ID
    try {
      // Get all templates (same as Quick Access)
      final allTemplates = await FormTemplateService.getAllTemplates(forceRefresh: true);
      
      // Filter to keep only the latest version of each template by name (same logic as Quick Access)
      final Map<String, FormTemplate> latestTemplatesByName = {};
      for (var template in allTemplates) {
        if (!template.isActive) continue;
        
        // Normalize template name for comparison
        final normalizedName = template.name
            .trim()
            .toLowerCase()
            .replaceAll(RegExp(r'\s+'), ' ');
        
        if (!latestTemplatesByName.containsKey(normalizedName)) {
          latestTemplatesByName[normalizedName] = template;
        } else {
          final existing = latestTemplatesByName[normalizedName]!;
          // Keep the one with higher version, or if same version, keep the one with later updatedAt
          if (template.version > existing.version) {
            latestTemplatesByName[normalizedName] = template;
          } else if (template.version == existing.version) {
            if (template.updatedAt.isAfter(existing.updatedAt)) {
              latestTemplatesByName[normalizedName] = template;
            }
          }
        }
      }
      
      // Find the daily class report template (same as Quick Access)
      FormTemplate? template;
      for (var t in latestTemplatesByName.values) {
        if (t.frequency == FormFrequency.perSession &&
            t.name.toLowerCase().contains('daily') &&
            (t.name.toLowerCase().contains('class') || t.name.toLowerCase().contains('report'))) {
          template = t;
          break;
        }
      }
      
      // If not found, use first perSession template
      if (template == null) {
        template = latestTemplatesByName.values.firstWhere(
          (t) => t.frequency == FormFrequency.perSession,
          orElse: () => latestTemplatesByName.values.first,
        );
      }
      
      
      if (template == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.errorCouldNotLoadFormTemplate),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      if (!mounted) return;
      
      // Pass template directly (same as Quick Access) - ensures latest version
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FormScreen(
            timesheetId: timesheetId, // Can be null for missed shifts
            shiftId: shiftId, // Always required
            template: template, // Pass template directly - uses latest version
          ),
        ),
      ).then((_) {
        // Refresh data after returning from form
        _loadData();
      });
    } catch (e) {
      debugPrint('Error fetching template: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorLoadingFormE),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
                  AppLocalizations.of(context)!.dashboardActiveSession,
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
                  AppLocalizations.of(context)!.dashboardInProgress,
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showShiftDetails(_activeShift!),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.dashboardViewSession,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _handleClockOut(_activeShift!),
                  icon: const Icon(Icons.logout, size: 18),
                  label: Text(
                    'Clock Out',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFEF4444),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
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
                  AppLocalizations.of(context)!.dashboardMyTasks,
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
                AppLocalizations.of(context)!.dashboardSeeAll,
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

  Widget _buildUpcomingSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n?.dashboardNextClass ?? 'Next Class',
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
                l10n?.dashboardSeeAll ?? 'See All',
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
                ? _buildEmptyUpcoming(context)
                : _buildUpcomingCard(_upcomingShifts.first),
      ],
    );
  }

  Widget _buildEmptyNextSession() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Icon(Icons.event_available, size: 32, color: Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          Text(
            'No upcoming sessions',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySchedule() {
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
            'No classes scheduled',
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
            // Clock-in action buttons based on time
            const SizedBox(height: 12),
            _buildClockInActionButtons(shift),
          ],
        ),
      ),
    );
  }

  /// Build clock-in action buttons based on current time and shift state
  Widget _buildClockInActionButtons(TeachingShift shift) {
    // Use local time for both to ensure consistent comparison
    final now = DateTime.now();
    final shiftStart = shift.shiftStart.toLocal();
    final shiftEnd = shift.shiftEnd.toLocal();
    
    // Programming window: 1 minute before shift start
    final programmingWindowStart = shiftStart.subtract(const Duration(minutes: 1));
    
    // Debug logging to help diagnose
    debugPrint('🕐 Clock-in buttons: now=$now, shiftStart=$shiftStart, programWindow=$programmingWindowStart');
    
    // Check states
    final isInProgramWindow = now.isAfter(programmingWindowStart) && now.isBefore(shiftStart);
    final shiftHasStarted = now.isAfter(shiftStart) || now.isAtSameMomentAs(shiftStart);
    final shiftHasEnded = now.isAfter(shiftEnd);
    final isThisShiftProgrammed = _programmedShiftId == shift.id;
    
    debugPrint('🕐 States: inProgramWindow=$isInProgramWindow, started=$shiftHasStarted, ended=$shiftHasEnded, programmed=$isThisShiftProgrammed');
    
    // If shift has ended, don't show any buttons
    if (shiftHasEnded) {
      return const SizedBox.shrink();
    }
    
    // If this shift is programmed - show countdown and cancel button
    if (isThisShiftProgrammed) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _timeUntilAutoStart.isNotEmpty ? _timeUntilAutoStart : 'Programmed...',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF3B82F6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _cancelProgrammedClockIn,
                icon: const Icon(Icons.close, size: 16),
                label: Text(AppLocalizations.of(context)!.clockInCancelProgramming, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    // If shift has started but not ended - show Clock In button
    if (shiftHasStarted && !shiftHasEnded) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _handleClockIn(shift),
          icon: const Icon(Icons.login, size: 18),
          label: Text(AppLocalizations.of(context)!.clockInNow, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        ),
      );
    }
    
    // If in programming window (1 minute before shift) - show Program button
    // This programs automatic clock-in when shift starts
    if (isInProgramWindow) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _startProgrammedClockIn(shift),
          icon: const Icon(Icons.schedule, size: 18),
          label: Text(AppLocalizations.of(context)!.clockInProgram, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        ),
      );
    }
    
    // Otherwise, just show the time until clock-in is available
    final timeUntilProgramWindow = programmingWindowStart.difference(now);
    if (timeUntilProgramWindow.inSeconds > 0) {
      final totalSeconds = timeUntilProgramWindow.inSeconds;
      final mins = timeUntilProgramWindow.inMinutes;
      final hrs = timeUntilProgramWindow.inHours;
      final secs = totalSeconds % 60;
      String timeText;
      if (hrs > 0) {
        timeText = 'Clock-in available in ${hrs}h ${mins % 60}m';
      } else if (mins > 0) {
        timeText = 'Clock-in available in ${mins}m ${secs}s';
      } else {
        timeText = 'Clock-in available in ${secs}s';
      }
      
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.access_time, size: 16, color: Color(0xFF64748B)),
            const SizedBox(width: 8),
            Text(
              timeText,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }
    
    return const SizedBox.shrink();
  }

  /// Handle clock-in button press
  Future<void> _handleClockIn(TeachingShift shift) async {
    final now = DateTime.now();
    final shiftStart = shift.shiftStart.toLocal();
    final programmingWindowStart = shiftStart.subtract(const Duration(minutes: 1));
    
    final isInProgramWindow = now.isAfter(programmingWindowStart) && now.isBefore(shiftStart);
    final shiftHasStarted = !now.isBefore(shiftStart);
    
    // Only allow clock-in if shift has started (not during programming window)
    if (shiftHasStarted) {
      await _performClockIn(shift);
    } else if (isInProgramWindow) {
      // During programming window, use program function instead
      _startProgrammedClockIn(shift);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.clockInTooEarly),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  /// Handle clock-out button press
  Future<void> _handleClockOut(TeachingShift shift) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not authenticated'), backgroundColor: Colors.red),
        );
        return;
      }

      // Get location for clock-out
      LocationData? location;
      try {
        location = await LocationService.getCurrentLocation().timeout(
          const Duration(seconds: 15),
        );
      } catch (e) {
        debugPrint('❌ Home: Location error during clock-out: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to get location. Please enable location services.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (location == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to get location. Please enable location services.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Perform clock-out via service
      final result = await ShiftTimesheetService.clockOutFromShift(
        user.uid,
        shift.id,
        location: location,
        platform: 'mobile',
      );

      if (result['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Clocked out successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh data to update UI
        _loadData();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to clock out'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Home: Error clocking out: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// Start programmed clock-in
  void _startProgrammedClockIn(TeachingShift shift) async {
    debugPrint('🕐 Home: Starting programmed clock-in for shift ${shift.id}');
    
    final nowUtc = DateTime.now().toUtc();
    final shiftStartUtc = shift.shiftStart.toUtc();
    
    // If shift has already started, clock in immediately
    if (!nowUtc.isBefore(shiftStartUtc)) {
      debugPrint('🕐 Home: Shift already started - clocking in immediately');
      await _performClockIn(shift, isAutoStart: true);
      return;
    }
    
    // Calculate initial countdown
    final timeLeft = shiftStartUtc.difference(nowUtc);
    final initialSeconds = timeLeft.inSeconds;
    final initialMinutes = timeLeft.inMinutes;
    final remainingSeconds = initialSeconds % 60;
    
    // Persist programmed state
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('programmed_start_${shift.id}', true);
    } catch (e) {
      debugPrint('❌ Home: Failed to save programmed state: $e');
    }
    
    if (!mounted) return;
    
    // Format countdown
    final countdownText = initialMinutes > 0 
        ? 'Starting in ${initialMinutes}m ${remainingSeconds.toString().padLeft(2, '0')}s'
        : 'Starting in ${initialSeconds}s';
    
    setState(() {
      _programmedShiftId = shift.id;
      _timeUntilAutoStart = countdownText;
    });
    
    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.dashboardClockInProgrammed(
            DateFormat('HH:mm').format(shift.shiftStart))),
        backgroundColor: const Color(0xFF3B82F6),
        duration: const Duration(seconds: 2),
      ),
    );
    
    // Cancel any existing timer
    _programTimer?.cancel();
    
    // Start countdown timer
    _programTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      final nowUtc = DateTime.now().toUtc();
      final shiftStartUtc = shift.shiftStart.toUtc();
      
      if (!nowUtc.isBefore(shiftStartUtc)) {
        // Time to clock in!
        debugPrint('🕐 Home: Auto-start time reached! Clocking in...');
        timer.cancel();
        
        // Clear persisted state
        SharedPreferences.getInstance().then((prefs) {
          prefs.remove('programmed_start_${shift.id}');
        });
        
        if (mounted) {
          setState(() {
            _timeUntilAutoStart = "Clocking In...";
          });
          _performClockIn(shift, isAutoStart: true);
        }
        return;
      }
      
      final timeLeft = shiftStartUtc.difference(nowUtc);
      final seconds = timeLeft.inSeconds;
      final minutes = timeLeft.inMinutes;
      final remainingSeconds = seconds % 60;
      
      final countdownText = minutes > 0 
          ? 'Starting in ${minutes}m ${remainingSeconds.toString().padLeft(2, '0')}s'
          : 'Starting in ${seconds}s';
      
      if (mounted) {
        setState(() {
          _timeUntilAutoStart = countdownText;
        });
      }
    });
  }

  /// Cancel programmed clock-in
  void _cancelProgrammedClockIn() async {
    debugPrint('🕐 Home: Cancelling programmed clock-in');
    _programTimer?.cancel();
    _programTimer = null;
    
    // Clear persisted state
    if (_programmedShiftId != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('programmed_start_$_programmedShiftId');
      } catch (e) {
        debugPrint('❌ Home: Failed to clear programmed state: $e');
      }
    }
    
    if (mounted) {
      setState(() {
        _programmedShiftId = null;
        _timeUntilAutoStart = "";
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.clockInCancelled),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Perform the actual clock-in
  Future<void> _performClockIn(TeachingShift shift, {bool isAutoStart = false}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.clockInNotAuthenticated), backgroundColor: Colors.red),
        );
        return;
      }

      // Get location with timeout
      LocationData? location;
      try {
        final timeoutDuration = Duration(seconds: isAutoStart ? 5 : 15);
        location = await LocationService.getCurrentLocation().timeout(timeoutDuration);
      } catch (e) {
        debugPrint('❌ Home: Location error: $e');
        if (isAutoStart) {
          // For auto-start, use fallback location
          location = LocationData(
            latitude: 0.0,
            longitude: 0.0,
            address: 'Auto clock-in - location unavailable',
            neighborhood: 'Programmed start',
          );
        }
      }
      
      // Check location - if null and not auto-start, return early
      if (location == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.clockInLocationError),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // At this point, location is guaranteed to be non-null
      final locationData = location!;

      // Perform clock-in via service (user is already checked at the beginning of the method)
      final result = await ShiftTimesheetService.clockInToShift(
        user.uid,
        shift.id,
        location: locationData,
        platform: 'mobile',
      );

      if (result['success'] == true) {
        // Clear programmed state on success
        if (mounted) {
          setState(() {
            _programmedShiftId = null;
            _timeUntilAutoStart = "";
          });
        }
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isAutoStart ? 'Auto clock-in successful!' : 'Clocked in successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh data
        _loadData();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to clock in'),
            backgroundColor: Colors.red,
          ),
        );
        
        // Clear programmed state on failure too
        if (mounted) {
          setState(() {
            _programmedShiftId = null;
            _timeUntilAutoStart = "";
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Home: Error clocking in: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.errorE), backgroundColor: Colors.red),
      );
      
      // Clear programmed state on error
      if (mounted) {
        setState(() {
          _programmedShiftId = null;
          _timeUntilAutoStart = "";
        });
      }
    }
  }

  Widget _buildEmptyUpcoming(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
            l10n?.dashboardNoUpcomingClasses ?? 'No Upcoming Classes',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n?.dashboardEnjoyFreeTime ?? 'Enjoy your free time!',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n?.dashboardQuickAccess ?? 'Quick Access',
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
                icon: Icons.article_outlined,
                label: l10n?.navForms ?? 'Forms',
                color: const Color(0xFFEC4899),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TeacherFormsScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              _buildCompactQuickAccessCard(
                icon: Icons.assignment_outlined,
                label: l10n?.dashboardAssignments ?? 'Assignments',
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
                label: l10n?.dashboardMyForms ?? 'My Forms',
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
                AppLocalizations.of(context)!.dashboardIslamicResources,
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
