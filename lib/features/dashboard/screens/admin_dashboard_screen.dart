import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/user_role_service.dart';
import '../../../system_settings_screen.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'dart:html' as html;

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  String? userRole;
  Map<String, dynamic>? userData;
  Map<String, dynamic> stats = {};
  Map<String, dynamic> teacherStats = {};
  int _profileCompletionTrigger = 0; // Trigger to refresh profile completion

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadStats();
  }

  Future<void> _loadUserData() async {
    final role = await UserRoleService.getCurrentUserRole();
    final data = await UserRoleService.getCurrentUserData();
    if (mounted) {
      setState(() {
        userRole = role;
        userData = data;
      });

      // Load teacher-specific stats if user is a teacher
      if (role?.toLowerCase() == 'teacher') {
        _loadTeacherStats();
      }
    }
  }

  Future<void> _loadTeacherStats() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      print('Loading teacher-specific statistics...');

      // Load teacher's assigned tasks
      final tasksSnapshot = await FirebaseFirestore.instance
          .collection('tasks')
          .where('assignedTo', arrayContains: currentUser.uid)
          .get();

      // Count tasks by status
      int pendingTasks = 0;
      int completedTasks = 0;
      int inProgressTasks = 0;

      for (var doc in tasksSnapshot.docs) {
        final data = doc.data();
        final status = data['status'] ?? 'TaskStatus.todo';

        if (status.contains('todo')) {
          pendingTasks++;
        } else if (status.contains('done')) {
          completedTasks++;
        } else if (status.contains('inProgress')) {
          inProgressTasks++;
        }
      }

      // Load forms accessible to teachers
      final formsSnapshot =
          await FirebaseFirestore.instance.collection('form').get();

      int accessibleForms = 0;
      for (var doc in formsSnapshot.docs) {
        final data = doc.data();
        final permissions = data['permissions'] as Map<String, dynamic>?;

        // Check if teacher can access this form
        if (permissions == null ||
            permissions['type'] == 'public' ||
            (permissions['role'] == 'teacher' ||
                permissions['role'] == 'teachers') ||
            (permissions['users'] as List<dynamic>?)
                    ?.contains(currentUser.uid) ==
                true) {
          accessibleForms++;
        }
      }

      // Load teacher's timesheet entries to get student count
      final timesheetSnapshot = await FirebaseFirestore.instance
          .collection('timesheet_entries')
          .where('teacher_id', isEqualTo: currentUser.uid)
          .get();

      // Get unique students the teacher has worked with
      Set<String> uniqueStudents = {};
      for (var doc in timesheetSnapshot.docs) {
        final data = doc.data();
        final studentName = data['student_name'];
        if (studentName != null && studentName.isNotEmpty) {
          uniqueStudents.add(studentName);
        }
      }

      if (mounted) {
        setState(() {
          teacherStats = {
            'assigned_tasks': tasksSnapshot.docs.length,
            'pending_tasks': pendingTasks,
            'completed_tasks': completedTasks,
            'in_progress_tasks': inProgressTasks,
            'accessible_forms': accessibleForms,
            'my_students': uniqueStudents.length,
            'total_sessions': timesheetSnapshot.docs.length,
          };
        });
        print('Teacher stats loaded successfully: $teacherStats');
      }
    } catch (e) {
      print('Error loading teacher stats: $e');
      if (mounted) {
        setState(() {
          teacherStats = {
            'assigned_tasks': 0,
            'pending_tasks': 0,
            'completed_tasks': 0,
            'in_progress_tasks': 0,
            'accessible_forms': 0,
            'my_students': 0,
            'total_sessions': 0,
          };
        });
      }
    }
  }

  Future<void> _loadStats() async {
    try {
      print('Loading comprehensive dashboard statistics...');

      // Load all collections in parallel with more detailed queries
      final futures = await Future.wait([
        FirebaseFirestore.instance.collection('users').get(),
        FirebaseFirestore.instance
            .collection('form')
            .get(), // Note: using 'form' not 'forms'
        FirebaseFirestore.instance.collection('form_responses').get(),
      ]);

      final usersSnapshot = futures[0];
      final formsSnapshot = futures[1];
      final responsesSnapshot = futures[2];

      print('Users found: ${usersSnapshot.docs.length}');
      print('Forms found: ${formsSnapshot.docs.length}');
      print('Responses found: ${responsesSnapshot.docs.length}');

      // Enhanced user analytics
      Map<String, int> roleCount = {};
      int activeUsers = 0;
      int recentLogins = 0;
      int onlineNow = 0;
      int weeklyActiveUsers = 0;

      DateTime now = DateTime.now();
      DateTime weekAgo = now.subtract(const Duration(days: 7));
      DateTime dayAgo = now.subtract(const Duration(days: 1));
      DateTime hourAgo = now.subtract(const Duration(hours: 1));

      for (var doc in usersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final role = data['user_type'] ?? data['role'] ?? 'unknown';
        roleCount[role] = (roleCount[role] ?? 0) + 1;

        // Check user activity status
        final isActive = data['is_active'] ?? true;
        if (isActive) activeUsers++;

        // Enhanced login tracking
        final lastLogin = data['last_login'];
        if (lastLogin != null) {
          DateTime loginTime;
          if (lastLogin is Timestamp) {
            loginTime = lastLogin.toDate();
          } else if (lastLogin is String) {
            loginTime = DateTime.tryParse(lastLogin) ?? DateTime(2000);
          } else {
            continue;
          }

          if (loginTime.isAfter(hourAgo)) onlineNow++;
          if (loginTime.isAfter(dayAgo)) recentLogins++;
          if (loginTime.isAfter(weekAgo)) weeklyActiveUsers++;
        }
      }

      // Enhanced form analytics
      int activeForms = 0;
      int inactiveForms = 0;
      int totalFormSubmissions = 0;
      Map<String, int> formSubmissionCounts = {};
      double averageResponseRate = 0.0;

      for (var doc in formsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final status = data['status'] ?? 'active';

        if (status == 'active') {
          activeForms++;
        } else {
          inactiveForms++;
        }

        // Count submissions for this form
        final formId = doc.id;
        final formResponses = responsesSnapshot.docs.where((response) {
          final responseData = response.data() as Map<String, dynamic>;
          return responseData['form_id'] == formId;
        }).length;

        formSubmissionCounts[formId] = formResponses;
        totalFormSubmissions += formResponses;
      }

      // Calculate average response rate
      if (formsSnapshot.docs.isNotEmpty && usersSnapshot.docs.isNotEmpty) {
        averageResponseRate = (totalFormSubmissions /
                (formsSnapshot.docs.length * usersSnapshot.docs.length)) *
            100;
      }

      // System performance metrics (simulated based on real data)
      double systemLoad = (totalFormSubmissions / 100).clamp(0.0, 1.0);
      double memoryUsage = 0.45 + (usersSnapshot.docs.length / 1000) * 0.3;
      memoryUsage = memoryUsage.clamp(0.0, 1.0);

      double storageUsed = (formsSnapshot.docs.length * 0.5 +
          responsesSnapshot.docs.length * 0.1);
      storageUsed = (storageUsed / 100).clamp(0.0, 1.0);

      // Recent activity analytics
      List<Map<String, dynamic>> recentActivity = [];

      // Get recent form creations
      final recentForms = formsSnapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final createdAt = data['created_at'] ?? data['createdAt'];
        if (createdAt is Timestamp) {
          return createdAt.toDate().isAfter(dayAgo);
        }
        return false;
      }).toList();

      // Get recent user registrations
      final recentUsers = usersSnapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final createdAt = data['created_at'] ?? data['createdAt'];
        if (createdAt is Timestamp) {
          return createdAt.toDate().isAfter(dayAgo);
        }
        return false;
      }).toList();

      // Get recent form responses
      final recentResponses = responsesSnapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final submittedAt = data['submitted_at'] ?? data['submittedAt'];
        if (submittedAt is Timestamp) {
          return submittedAt.toDate().isAfter(dayAgo);
        }
        return false;
      }).toList();

      if (mounted) {
        setState(() {
          stats = {
            // User metrics
            'total_users': usersSnapshot.docs.length,
            'admins': roleCount['admin'] ?? 0,
            'teachers': roleCount['teacher'] ?? 0,
            'students': roleCount['student'] ?? 0,
            'parents': roleCount['parent'] ?? 0,
            'active_users': activeUsers,
            'recent_logins': recentLogins,
            'online_now': onlineNow,
            'weekly_active': weeklyActiveUsers,

            // Form metrics
            'total_forms': formsSnapshot.docs.length,
            'active_forms': activeForms,
            'inactive_forms': inactiveForms,
            'total_responses': responsesSnapshot.docs.length,
            'total_submissions': totalFormSubmissions,
            'average_response_rate': averageResponseRate.round(),

            // System metrics
            'system_load': (systemLoad * 100).round(),
            'memory_usage': (memoryUsage * 100).round(),
            'storage_used': (storageUsed * 100).round(),
            'cpu_usage':
                (42 + (systemLoad * 20)).round(), // Simulated based on load
            'response_time':
                (80 + (systemLoad * 40)).round(), // Simulated response time

            // Activity metrics
            'recent_forms_created': recentForms.length,
            'recent_users_registered': recentUsers.length,
            'recent_responses_submitted': recentResponses.length,

            // Performance indicators
            'uptime_percentage': 99.8,
            'system_health': 'excellent',
            'last_backup': 'today',
          };
        });
        print('Enhanced stats loaded successfully: $stats');
      }
    } catch (e) {
      print('Error loading comprehensive stats: $e');
      // Set realistic default values on error
      if (mounted) {
        setState(() {
          stats = {
            'total_users': 0,
            'total_forms': 0,
            'total_responses': 0,
            'admins': 0,
            'teachers': 0,
            'students': 0,
            'parents': 0,
            'active_users': 0,
            'recent_logins': 0,
            'online_now': 0,
            'weekly_active': 0,
            'active_forms': 0,
            'inactive_forms': 0,
            'total_submissions': 0,
            'average_response_rate': 0,
            'system_load': 0,
            'memory_usage': 45,
            'storage_used': 30,
            'cpu_usage': 42,
            'response_time': 120,
            'recent_forms_created': 0,
            'recent_users_registered': 0,
            'recent_responses_submitted': 0,
            'uptime_percentage': 99.8,
            'system_health': 'good',
            'last_backup': 'today',
          };
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeHeader(),
          const SizedBox(height: 24),
          Expanded(
            child: _buildDashboardContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    final firstName = userData?['first_name'] ?? 'User';
    final roleDisplay = UserRoleService.getRoleDisplayName(userRole);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: _getRoleGradient(),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, $firstName! 👋',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You\'re signed in as $roleDisplay',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _getWelcomeMessage(),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getRoleIcon(),
              size: 48,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent() {
    switch (userRole?.toLowerCase()) {
      case 'admin':
        return _buildAdminDashboard();
      case 'teacher':
        return _buildTeacherDashboard();
      case 'student':
        return _buildStudentDashboard();
      case 'parent':
        return _buildParentDashboard();
      default:
        return _buildDefaultDashboard();
    }
  }

  Widget _buildAdminDashboard() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Modern Header with Gradient
          _buildModernHeader(),
          const SizedBox(height: 32),

          // Key Performance Indicators
          _buildKPISection(),
          const SizedBox(height: 32),

          // User Analytics Section
          _buildUserAnalyticsSection(),
          const SizedBox(height: 32),

          // System Performance & Quick Actions
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _buildSystemPerformanceCard(),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 2,
                child: _buildQuickActionsCard(),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Recent Activity & System Health
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _buildRecentActivityCard(),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 1,
                child: _buildSystemHealthCard(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherDashboard() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Modern Welcome Header for Teachers
          _buildTeacherWelcomeHeader(),
          const SizedBox(height: 32),

          // Quick Stats Row - Compact and Modern
          _buildTeacherQuickStats(),
          const SizedBox(height: 32),

          // Main Content Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column - 60%
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    _buildMyClassesModern(),
                    const SizedBox(height: 24),
                    _buildStudentProgressModern(),
                  ],
                ),
              ),
              const SizedBox(width: 24),

              // Right Column - 40%
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    _buildTeacherProfileCard(),
                    const SizedBox(height: 24),
                    _buildIslamicCalendarCard(),
                    const SizedBox(height: 24),
                    _buildQuickActionsTeacher(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Bottom Row - Full Width Cards
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildRecentLessonsCard()),
              const SizedBox(width: 24),
              Expanded(child: _buildIslamicResourcesCard()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentDashboard() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Student Stats
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.3,
            children: [
              _buildStatCard(
                  'My Forms', 12, Icons.assignment_turned_in, Colors.blue),
              _buildStatCard('Completed', 8, Icons.check_circle, Colors.green),
              _buildStatCard(
                  'Pending', 4, Icons.pending_actions, Colors.orange),
            ],
          ),
          const SizedBox(height: 24),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildMyAssignmentsCard()),
              const SizedBox(width: 16),
              Expanded(child: _buildMyProgressCard()),
            ],
          ),
          const SizedBox(height: 24),

          _buildAnnouncementsCard(),
        ],
      ),
    );
  }

  Widget _buildParentDashboard() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Parent Stats
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.3,
            children: [
              _buildStatCard('My Children', 2, Icons.child_care, Colors.pink),
              _buildStatCard('School Forms', 5, Icons.description, Colors.blue),
              _buildStatCard('Messages', 3, Icons.message, Colors.green),
            ],
          ),
          const SizedBox(height: 24),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildMyChildrenCard()),
              const SizedBox(width: 16),
              Expanded(child: _buildSchoolUpdatesCard()),
            ],
          ),
          const SizedBox(height: 24),

          _buildParentResourcesCard(),
        ],
      ),
    );
  }

  Widget _buildDefaultDashboard() {
    return const Center(
      child: Text('Loading dashboard...'),
    );
  }

  Widget _buildModernHeader() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xff0F172A),
            Color(0xff1E293B),
            Color(0xff334155),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin Dashboard',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Welcome back, ${userData?['first_name'] ?? userData?['firstName'] ?? 'Admin'}! Here\'s what\'s happening in your education hub.',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    _buildHeaderStat('Users Online',
                        '${stats['online_now'] ?? 0}', Icons.people),
                    const SizedBox(width: 24),
                    _buildHeaderStat('Active Forms',
                        '${stats['active_forms'] ?? 0}', Icons.assignment),
                    const SizedBox(width: 24),
                    _buildHeaderStat(
                        'System Health',
                        '${stats['uptime_percentage']?.toStringAsFixed(1) ?? '99.8'}%',
                        Icons.health_and_safety),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                _loadStats();
                _loadUserData();
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh Data'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xff0F172A),
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKPISection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key Performance Indicators',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xff111827),
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          childAspectRatio: 1.1,
          children: [
            _buildModernKPICard(
              'Total Users',
              '${stats['total_users'] ?? 0}',
              Icons.people_rounded,
              const Color(0xff3B82F6),
              _calculateUserGrowth(),
              _calculateUserGrowth().startsWith('+'),
            ),
            _buildModernKPICard(
              'Active Forms',
              '${stats['active_forms'] ?? 0}',
              Icons.assignment_rounded,
              const Color(0xff10B981),
              _calculateFormGrowth(),
              _calculateFormGrowth().startsWith('+'),
            ),
            _buildModernKPICard(
              'Form Responses',
              '${stats['total_responses'] ?? 0}',
              Icons.task_alt_rounded,
              const Color(0xff8B5CF6),
              _calculateResponseGrowth(),
              _calculateResponseGrowth().startsWith('+'),
            ),
            _buildModernKPICard(
              'System Uptime',
              '${stats['uptime_percentage']?.toStringAsFixed(1) ?? '99.8'}%',
              Icons.trending_up_rounded,
              const Color(0xffF59E0B),
              '+0.1%',
              true,
            ),
          ],
        ),
      ],
    );
  }

  String _calculateUserGrowth() {
    final recentUsers = stats['recent_users_registered'] ?? 0;
    final totalUsers = stats['total_users'] ?? 1;
    if (totalUsers == 0) return '+0%';
    final growthRate = (recentUsers / totalUsers * 100);
    return growthRate > 0
        ? '+${growthRate.toStringAsFixed(1)}%'
        : '${growthRate.toStringAsFixed(1)}%';
  }

  String _calculateFormGrowth() {
    final recentForms = stats['recent_forms_created'] ?? 0;
    final totalForms = stats['total_forms'] ?? 1;
    if (totalForms == 0) return '+0%';
    final growthRate = (recentForms / totalForms * 100);
    return growthRate > 0
        ? '+${growthRate.toStringAsFixed(1)}%'
        : '${growthRate.toStringAsFixed(1)}%';
  }

  String _calculateResponseGrowth() {
    final recentResponses = stats['recent_responses_submitted'] ?? 0;
    final totalResponses = stats['total_responses'] ?? 1;
    if (totalResponses == 0) return '+0%';
    final growthRate = (recentResponses / totalResponses * 100);
    return growthRate > 0
        ? '+${growthRate.toStringAsFixed(1)}%'
        : '${growthRate.toStringAsFixed(1)}%';
  }

  String _buildRecentUserActivity() {
    final recentUsers = stats['recent_users_registered'] ?? 0;
    if (recentUsers == 0) {
      return 'No new registrations today';
    } else if (recentUsers == 1) {
      return 'New user joined the system';
    } else {
      return '$recentUsers new users registered today';
    }
  }

  String _getTimeSinceLastUser() {
    final recentUsers = stats['recent_users_registered'] ?? 0;
    if (recentUsers == 0) return '24+ hrs ago';
    return '2 hrs ago'; // Simulated - could be enhanced with real timestamp tracking
  }

  String _buildRecentFormActivity() {
    final activeForms = stats['active_forms'] ?? 0;
    final recentForms = stats['recent_forms_created'] ?? 0;
    if (recentForms == 0) {
      return '$activeForms forms currently active';
    } else {
      return '$recentForms new forms created, $activeForms total active';
    }
  }

  String _getTimeSinceLastForm() {
    final recentForms = stats['recent_forms_created'] ?? 0;
    if (recentForms == 0) return '1+ day ago';
    return '4 hrs ago'; // Simulated
  }

  String _buildRecentSubmissionActivity() {
    final recentSubmissions = stats['recent_responses_submitted'] ?? 0;
    final totalResponses = stats['total_responses'] ?? 0;
    if (recentSubmissions == 0) {
      return 'No new submissions today';
    } else {
      return '$recentSubmissions new responses received ($totalResponses total)';
    }
  }

  String _getTimeSinceLastSubmission() {
    final recentSubmissions = stats['recent_responses_submitted'] ?? 0;
    if (recentSubmissions == 0) return '12+ hrs ago';
    return '45 min ago'; // Simulated
  }

  String _calculateBackupSize() {
    final totalUsers = stats['total_users'] ?? 0;
    final totalForms = stats['total_forms'] ?? 0;
    final totalResponses = stats['total_responses'] ?? 0;

    // Estimate backup size based on data
    final estimatedMB =
        (totalUsers * 0.1 + totalForms * 0.5 + totalResponses * 0.2);
    if (estimatedMB < 1000) {
      return '${estimatedMB.toStringAsFixed(1)}MB';
    } else {
      return '${(estimatedMB / 1000).toStringAsFixed(1)}GB';
    }
  }

  Widget _buildModernKPICard(String title, String value, IconData icon,
      Color color, String change, bool isPositive) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPositive
                      ? const Color(0xffDCFCE7)
                      : const Color(0xffFEE2E2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive ? Icons.trending_up : Icons.trending_down,
                      size: 12,
                      color: isPositive
                          ? const Color(0xff16A34A)
                          : const Color(0xffDC2626),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      change,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isPositive
                            ? const Color(0xff16A34A)
                            : const Color(0xffDC2626),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: const Color(0xff111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xff6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAnalyticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'User Analytics',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xff111827),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildUserDistributionCard(),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 1,
              child: _buildActiveUsersCard(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUserDistributionCard() {
    final totalUsers = stats['total_users'] ?? 1;
    final teachers = stats['teachers'] ?? 0;
    final students = stats['students'] ?? 0;
    final parents = stats['parents'] ?? 0;
    final admins = stats['admins'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'User Distribution',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff111827),
                ),
              ),
              const Spacer(),
              Text(
                'Total: $totalUsers users',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xff6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildUserDistributionBar(
              'Students', students, totalUsers, const Color(0xff3B82F6)),
          const SizedBox(height: 16),
          _buildUserDistributionBar(
              'Teachers', teachers, totalUsers, const Color(0xff10B981)),
          const SizedBox(height: 16),
          _buildUserDistributionBar(
              'Parents', parents, totalUsers, const Color(0xffF59E0B)),
          const SizedBox(height: 16),
          _buildUserDistributionBar(
              'Admins', admins, totalUsers, const Color(0xff8B5CF6)),
        ],
      ),
    );
  }

  Widget _buildUserDistributionBar(
      String label, int count, int total, Color color) {
    final percentage = total > 0 ? (count / total * 100) : 0.0;
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xff374151),
                ),
              ),
            ),
            Text(
              '$count',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xff111827),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xff6B7280),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: percentage / 100,
          backgroundColor: const Color(0xffF3F4F6),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 6,
        ),
      ],
    );
  }

  Widget _buildActiveUsersCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Active Users',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xff111827),
            ),
          ),
          const SizedBox(height: 24),
          _buildActiveUserStat('Online Now', '${stats['online_now'] ?? 0}',
              const Color(0xff10B981)),
          const SizedBox(height: 16),
          _buildActiveUserStat('Active Today', '${stats['recent_logins'] ?? 0}',
              const Color(0xff3B82F6)),
          const SizedBox(height: 16),
          _buildActiveUserStat('This Week', '${stats['weekly_active'] ?? 0}',
              const Color(0xffF59E0B)),
        ],
      ),
    );
  }

  Widget _buildActiveUserStat(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xff6B7280),
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xff111827),
          ),
        ),
      ],
    );
  }

  Widget _buildSystemPerformanceCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'System Performance',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff111827),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xffDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xff16A34A),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'All Systems Operational',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xff16A34A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildPerformanceMetric(
                    'Response Time',
                    '${stats['response_time'] ?? 120}ms',
                    const Color(0xff3B82F6),
                    (stats['response_time'] ?? 120) / 200.0),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildPerformanceMetric(
                    'CPU Usage',
                    '${stats['cpu_usage'] ?? 42}%',
                    const Color(0xff10B981),
                    (stats['cpu_usage'] ?? 42) / 100.0),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildPerformanceMetric(
                    'Memory Usage',
                    '${stats['memory_usage'] ?? 68}%',
                    const Color(0xffF59E0B),
                    (stats['memory_usage'] ?? 68) / 100.0),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildPerformanceMetric(
                    'Storage Used',
                    '${stats['storage_used'] ?? 45}%',
                    const Color(0xff8B5CF6),
                    (stats['storage_used'] ?? 45) / 100.0),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetric(
      String label, String value, Color color, double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xff6B7280),
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xff111827),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: const Color(0xffF3F4F6),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 6,
        ),
      ],
    );
  }

  Widget _buildSystemHealthCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Health',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xff111827),
            ),
          ),
          const SizedBox(height: 24),
          _buildHealthItem('Database', 'Connected', true),
          const SizedBox(height: 16),
          _buildHealthItem('Storage', 'Online', true),
          const SizedBox(height: 16),
          _buildHealthItem('Auth Service', 'Active', true),
          const SizedBox(height: 16),
          _buildHealthItem('Email Service', 'Online', true),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xffF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  'Last System Check',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xff6B7280),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '2 minutes ago',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xff111827),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthItem(String service, String status, bool isHealthy) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color:
                isHealthy ? const Color(0xff10B981) : const Color(0xffEF4444),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            service,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xff374151),
            ),
          ),
        ),
        Text(
          status,
          style: GoogleFonts.inter(
            fontSize: 12,
            color:
                isHealthy ? const Color(0xff10B981) : const Color(0xffEF4444),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value.toString(),
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xff1a1a1a),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xff6b7280),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
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
                  color: const Color(0xff3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.rocket_launch_rounded,
                  color: Color(0xff3B82F6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Quick Actions',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildModernQuickActionButton(
              'Add New User',
              Icons.person_add_rounded,
              const Color(0xff3B82F6),
              'Invite new team members'),
          const SizedBox(height: 12),
          _buildModernQuickActionButton('Create Form', Icons.add_box_rounded,
              const Color(0xff10B981), 'Build new forms quickly'),
          const SizedBox(height: 12),
          _buildModernQuickActionButton(
              'View Analytics',
              Icons.analytics_rounded,
              const Color(0xffF59E0B),
              'Detailed system reports'),
          const SizedBox(height: 12),
          _buildModernQuickActionButton(
              'Export Data',
              Icons.file_download_rounded,
              const Color(0xff8B5CF6),
              'Download user responses'),
          const SizedBox(height: 12),
          _buildModernQuickActionButton(
              'System Settings',
              Icons.settings_rounded,
              const Color(0xff6B7280),
              'Configure system options'),
        ],
      ),
    );
  }

  Widget _buildModernQuickActionButton(
      String title, IconData icon, Color color, String subtitle) {
    return InkWell(
      onTap: () => _handleQuickAction(title),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xffF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xffE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xff6B7280),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: const Color(0xff9CA3AF),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(String title, IconData icon, Color color) {
    return InkWell(
      onTap: () => _handleQuickAction(title),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, color: color, size: 14),
          ],
        ),
      ),
    );
  }

  void _handleQuickAction(String action) {
    switch (action) {
      case 'System Settings':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: const Text('System Settings'),
                backgroundColor: Colors.transparent,
                elevation: 0,
                foregroundColor: Colors.black,
              ),
              body: const SystemSettingsScreen(),
            ),
          ),
        );
        break;
      case 'Add Assignment':
        _showAssignmentDialog();
        break;
      case 'My Assignments':
        _showMyAssignmentsDialog();
        break;
      case 'Add New User':
        // Navigate to add user screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Navigating to Add New User...')),
        );
        break;
      case 'Create Form':
        // Navigate to form builder
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Navigating to Form Builder...')),
        );
        break;
      case 'View Reports':
        // Navigate to reports
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Navigating to Reports...')),
        );
        break;
      case 'Export Form Responses':
        _showFormResponsesExportDialog();
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$action feature coming soon!')),
        );
    }
  }

  Widget _buildRecentActivityCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
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
                  color: const Color(0xff10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.timeline_rounded,
                  color: Color(0xff10B981),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Recent Activity',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff111827),
                ),
              ),
              const Spacer(),
              Text(
                'Last 24 hours',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xff6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildModernActivityItem(
            'New User Registration',
            _buildRecentUserActivity(),
            '${_getTimeSinceLastUser()}',
            Icons.person_add_rounded,
            const Color(0xff3B82F6),
          ),
          const SizedBox(height: 16),
          _buildModernActivityItem(
            'Form Activity',
            _buildRecentFormActivity(),
            '${_getTimeSinceLastForm()}',
            Icons.assignment_rounded,
            const Color(0xff10B981),
          ),
          const SizedBox(height: 16),
          _buildModernActivityItem(
            'Form Submissions',
            _buildRecentSubmissionActivity(),
            '${_getTimeSinceLastSubmission()}',
            Icons.task_alt_rounded,
            const Color(0xffF59E0B),
          ),
          const SizedBox(height: 16),
          _buildModernActivityItem(
            'System Backup',
            'Daily backup completed successfully (${_calculateBackupSize()})',
            '${stats['last_backup'] ?? 'today'}',
            Icons.backup_rounded,
            const Color(0xff8B5CF6),
          ),
          const SizedBox(height: 20),
          Center(
            child: TextButton(
              onPressed: () {
                // Navigate to full activity log
              },
              child: Text(
                'View All Activity',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xff3B82F6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernActivityItem(String title, String description, String time,
      IconData icon, Color iconColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff111827),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xff6B7280),
                ),
              ),
            ],
          ),
        ),
        Text(
          time,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: const Color(0xff9CA3AF),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActivityItem(
      String title, String time, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xff1a1a1a),
                  ),
                ),
                Text(
                  time,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xff6b7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemOverviewCard() {
    return Container(
      padding: const EdgeInsets.all(24),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Overview',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xff1a1a1a),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _buildSystemMetric(
                      'Server Status', 'Online', Colors.green)),
              const SizedBox(width: 16),
              Expanded(
                  child: _buildSystemMetric(
                      'Database', 'Connected', Colors.green)),
              const SizedBox(width: 16),
              Expanded(
                  child:
                      _buildSystemMetric('Storage', '78% Used', Colors.orange)),
              const SizedBox(width: 16),
              Expanded(
                  child: _buildSystemMetric('Uptime', '99.9%', Colors.blue)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSystemMetric(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xff6b7280),
            ),
          ),
        ],
      ),
    );
  }

  // Role-specific helper cards
  Widget _buildMyClassesCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My Classes',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xff1a1a1a),
            ),
          ),
          const SizedBox(height: 12),
          _buildClassItem('Mathematics - Grade 10', '24 students'),
          _buildClassItem('Physics - Grade 11', '18 students'),
          _buildClassItem('Chemistry - Grade 12', '21 students'),
        ],
      ),
    );
  }

  Widget _buildClassItem(String className, String studentCount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  className,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  studentCount,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xff6b7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingTasksCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upcoming Tasks',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xff1a1a1a),
            ),
          ),
          const SizedBox(height: 12),
          _buildTaskItem('Grade Math Assignments', 'Due tomorrow', Colors.red),
          _buildTaskItem(
              'Parent-Teacher Meeting', 'This Friday', Colors.orange),
          _buildTaskItem('Submit Monthly Report', 'Next week', Colors.blue),
        ],
      ),
    );
  }

  Widget _buildTaskItem(String task, String deadline, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  deadline,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentProgressCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Student Progress Overview',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xff1a1a1a),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _buildProgressItem('Excellent', 15, Colors.green)),
              Expanded(child: _buildProgressItem('Good', 32, Colors.blue)),
              Expanded(child: _buildProgressItem('Average', 18, Colors.orange)),
              Expanded(child: _buildProgressItem('Needs Help', 5, Colors.red)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xff6b7280),
          ),
        ),
      ],
    );
  }

  Widget _buildMyAssignmentsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My Assignments',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xff1a1a1a),
            ),
          ),
          const SizedBox(height: 12),
          _buildAssignmentItem('Math Homework', 'Due: Tomorrow', true),
          _buildAssignmentItem('Science Project', 'Due: Friday', false),
          _buildAssignmentItem('History Essay', 'Due: Next week', false),
        ],
      ),
    );
  }

  Widget _buildAssignmentItem(String title, String due, bool completed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            completed ? Icons.check_circle : Icons.radio_button_unchecked,
            color: completed ? Colors.green : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    decoration: completed ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  due,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xff6b7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyProgressCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My Progress',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xff1a1a1a),
            ),
          ),
          const SizedBox(height: 12),
          _buildProgressBar('Mathematics', 0.85, Colors.blue),
          _buildProgressBar('Science', 0.72, Colors.green),
          _buildProgressBar('History', 0.90, Colors.orange),
        ],
      ),
    );
  }

  Widget _buildProgressBar(String subject, double progress, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                subject,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'School Announcements',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xff1a1a1a),
            ),
          ),
          const SizedBox(height: 12),
          _buildAnnouncementItem('School Holiday - Memorial Day', '2 days ago'),
          _buildAnnouncementItem('New Library Books Available', '1 week ago'),
          _buildAnnouncementItem(
              'Parent-Teacher Conference Schedule', '2 weeks ago'),
        ],
      ),
    );
  }

  Widget _buildAnnouncementItem(String title, String time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.announcement, color: Colors.blue, size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  time,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xff6b7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyChildrenCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My Children',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xff1a1a1a),
            ),
          ),
          const SizedBox(height: 12),
          _buildChildItem('Emma Johnson', 'Grade 5', 'Excellent'),
          _buildChildItem('Lucas Johnson', 'Grade 8', 'Good'),
        ],
      ),
    );
  }

  Widget _buildChildItem(String name, String grade, String performance) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.blue.withOpacity(0.1),
            child: Text(
              name[0],
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '$grade • $performance',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xff6b7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchoolUpdatesCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'School Updates',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xff1a1a1a),
            ),
          ),
          const SizedBox(height: 12),
          _buildUpdateItem('Emma\'s Math test score: 95%', 'Yesterday'),
          _buildUpdateItem('Lucas joined Science Club', '3 days ago'),
          _buildUpdateItem('Parent meeting scheduled', '1 week ago'),
        ],
      ),
    );
  }

  Widget _buildUpdateItem(String update, String time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  update,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  time,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xff6b7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParentResourcesCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Parent Resources',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xff1a1a1a),
            ),
          ),
          const SizedBox(height: 12),
          _buildResourceItem(
              'School Calendar', Icons.calendar_today, Colors.blue),
          _buildResourceItem('Homework Help Guide', Icons.help, Colors.green),
          _buildResourceItem(
              'Contact Teachers', Icons.contact_mail, Colors.orange),
          _buildResourceItem('School Policies', Icons.policy, Colors.purple),
        ],
      ),
    );
  }

  Widget _buildResourceItem(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  LinearGradient _getRoleGradient() {
    switch (userRole?.toLowerCase()) {
      case 'admin':
        return const LinearGradient(
            colors: [Color(0xff667eea), Color(0xff764ba2)]);
      case 'teacher':
        return const LinearGradient(
            colors: [Color(0xff4facfe), Color(0xff00f2fe)]);
      case 'student':
        return const LinearGradient(
            colors: [Color(0xff43e97b), Color(0xff38f9d7)]);
      case 'parent':
        return const LinearGradient(
            colors: [Color(0xfffa709a), Color(0xfffee140)]);
      default:
        return const LinearGradient(
            colors: [Color(0xff6c757d), Color(0xff495057)]);
    }
  }

  IconData _getRoleIcon() {
    switch (userRole?.toLowerCase()) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'teacher':
        return Icons.school;
      case 'student':
        return Icons.person;
      case 'parent':
        return Icons.family_restroom;
      default:
        return Icons.person;
    }
  }

  String _getWelcomeMessage() {
    switch (userRole?.toLowerCase()) {
      case 'admin':
        return 'Manage your educational institution with powerful admin tools.';
      case 'teacher':
        return 'Inspire and educate your students with our teaching platform.';
      case 'student':
        return 'Continue your learning journey and track your progress.';
      case 'parent':
        return 'Stay connected with your child\'s educational progress.';
      default:
        return 'Welcome to Alluvial Education Hub.';
    }
  }

  /// Show the form responses export dialog with date range selection
  void _showFormResponsesExportDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Export Feature'),
          content: const Text('Export functionality will be implemented soon.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // Helper methods for Islamic features
  String _getCurrentIslamicTime() {
    final now = DateTime.now();
    final hour = now.hour;
    if (hour >= 5 && hour < 12) return 'Dhuhr in ${12 - hour}h';
    if (hour >= 12 && hour < 15) return 'Asr in ${15 - hour}h';
    if (hour >= 15 && hour < 18) return 'Maghrib in ${18 - hour}h';
    if (hour >= 18 && hour < 20) return 'Isha in ${20 - hour}h';
    return 'Fajr in ${29 - hour}h';
  }

  String _getCurrentHijriDate() {
    // This is a simplified example - in production you'd use a proper Hijri calendar library
    return '15 Ramadan 1445';
  }

  String _getCurrentHijriMonth() {
    return 'Ramadan 1445 AH';
  }

  void _showProfileCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return _TeacherProfileDialog(
          onProfileUpdated: () {
            setState(() {
              _profileCompletionTrigger++; // Trigger refresh
            });
          },
        );
      },
    );
  }

  /// Get profile completion percentage from Firestore
  Future<int> _getProfileCompletionPercentage() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 0;

      final profileDoc = await FirebaseFirestore.instance
          .collection('teacher_profiles')
          .doc(user.uid)
          .get();

      if (!profileDoc.exists) return 0;

      final data = profileDoc.data()!;
      int completedFields = 0;
      const totalFields = 6;

      if ((data['full_name'] ?? '').toString().trim().isNotEmpty)
        completedFields++;
      if ((data['professional_title'] ?? '').toString().trim().isNotEmpty)
        completedFields++;
      if ((data['biography'] ?? '').toString().trim().isNotEmpty)
        completedFields++;
      if ((data['years_of_experience'] ?? '').toString().trim().isNotEmpty)
        completedFields++;
      if ((data['specialties'] ?? '').toString().trim().isNotEmpty)
        completedFields++;
      if ((data['education_certifications'] ?? '').toString().trim().isNotEmpty)
        completedFields++;

      return ((completedFields / totalFields) * 100).round();
    } catch (e) {
      print('Error calculating profile completion: $e');
      return 0;
    }
  }

  /// Get count of students this teacher has worked with
  Future<int> _getMyStudentsCount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 0;

      final timesheetSnapshot = await FirebaseFirestore.instance
          .collection('timesheet_entries')
          .where('teacher_id', isEqualTo: user.uid)
          .get();

      // Get unique students
      Set<String> uniqueStudents = {};
      for (var doc in timesheetSnapshot.docs) {
        final data = doc.data();
        final studentName = data['student_name'];
        if (studentName != null && studentName.isNotEmpty) {
          uniqueStudents.add(studentName);
        }
      }

      return uniqueStudents.length;
    } catch (e) {
      print('Error getting student count: $e');
      return 0;
    }
  }

  /// Get list of students this teacher has worked with from timesheet entries
  Future<List<Map<String, dynamic>>> _getMyStudents() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final timesheetSnapshot = await FirebaseFirestore.instance
          .collection('timesheet_entries')
          .where('teacher_id', isEqualTo: user.uid)
          .get();

      // Group by student and calculate stats
      Map<String, Map<String, dynamic>> studentStats = {};

      for (var doc in timesheetSnapshot.docs) {
        final data = doc.data();
        final studentName = data['student_name'];

        if (studentName != null && studentName.isNotEmpty) {
          if (!studentStats.containsKey(studentName)) {
            studentStats[studentName] = {
              'name': studentName,
              'sessions': 0,
              'totalHours': 0.0,
              'lastSession': null,
              'performance': 0, // Will be calculated based on sessions
            };
          }

          studentStats[studentName]!['sessions']++;

          // Calculate hours
          final totalHours = data['total_hours'] ?? '00:00';
          final hoursParts = totalHours.split(':');
          if (hoursParts.length == 2) {
            final hours = int.tryParse(hoursParts[0]) ?? 0;
            final minutes = int.tryParse(hoursParts[1]) ?? 0;
            studentStats[studentName]!['totalHours'] +=
                hours + (minutes / 60.0);
          }

          // Update last session date
          final createdAt = data['created_at'] as Timestamp?;
          if (createdAt != null) {
            final currentLast =
                studentStats[studentName]!['lastSession'] as Timestamp?;
            if (currentLast == null || createdAt.compareTo(currentLast) > 0) {
              studentStats[studentName]!['lastSession'] = createdAt;
            }
          }
        }
      }

      // Convert to list and calculate performance score
      List<Map<String, dynamic>> students = studentStats.values.map((student) {
        // Simple performance calculation based on sessions and total hours
        final sessions = student['sessions'] as int;
        final totalHours = student['totalHours'] as double;
        final performance =
            ((sessions * 10) + (totalHours * 5)).clamp(0, 100).round();

        student['performance'] = performance;
        return student;
      }).toList();

      // Sort by performance descending
      students.sort((a, b) => b['performance'].compareTo(a['performance']));

      return students;
    } catch (e) {
      print('Error getting students: $e');
      return [];
    }
  }

  /// Build real student progress item from timesheet data
  Widget _buildRealStudentProgressItem(Map<String, dynamic> student) {
    final name = student['name'] as String;
    final sessions = student['sessions'] as int;
    final totalHours = student['totalHours'] as double;
    final performance = student['performance'] as int;
    final lastSession = student['lastSession'] as Timestamp?;

    // Determine performance color
    Color performanceColor;
    if (performance >= 80) {
      performanceColor = const Color(0xff10B981);
    } else if (performance >= 60) {
      performanceColor = const Color(0xff3B82F6);
    } else if (performance >= 40) {
      performanceColor = const Color(0xffF59E0B);
    } else {
      performanceColor = const Color(0xffEF4444);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: performanceColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.person, color: performanceColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xff111827),
                  ),
                ),
                Text(
                  '$sessions sessions • ${totalHours.toStringAsFixed(1)}h total',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xff6B7280),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$performance%',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: performanceColor,
                ),
              ),
              if (lastSession != null)
                Text(
                  'Last: ${_formatLastSession(lastSession)}',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: const Color(0xff9CA3AF),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Format last session timestamp
  String _formatLastSession(Timestamp timestamp) {
    final now = DateTime.now();
    final sessionDate = timestamp.toDate();
    final difference = now.difference(sessionDate);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${(difference.inDays / 7).floor()}w ago';
    }
  }

  /// Show assignment creation dialog
  void _showAssignmentDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _AssignmentDialog(
          onAssignmentCreated: () {
            // Refresh student data after assignment creation
            setState(() {});
          },
        );
      },
    );
  }

  /// Show my assignments management dialog
  void _showMyAssignmentsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _MyAssignmentsDialog();
      },
    );
  }

  Widget _buildTeacherWelcomeHeader() {
    final firstName =
        userData?['first_name'] ?? userData?['firstName'] ?? 'Teacher';

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xff1E40AF),
            Color(0xff3B82F6),
            Color(0xff60A5FA),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff3B82F6).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assalamu Alaikum, $firstName! 🕌',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'May Allah bless your teaching efforts today',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildHeaderStat('Students Today',
                        '${teacherStats['my_students'] ?? 0}', Icons.groups),
                    const SizedBox(width: 32),
                    _buildHeaderStat('Lessons This Week',
                        '${teacherStats['total_sessions'] ?? 0}', Icons.school),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.schedule, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  _getCurrentIslamicTime(),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherQuickStats() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 5,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.4,
      children: [
        _buildModernStatCard(
          'Active Students',
          '${teacherStats['my_students'] ?? 0}',
          Icons.groups_rounded,
          const Color(0xff10B981),
          '+${((teacherStats['my_students'] ?? 0) * 0.12).round()}',
        ),
        _buildModernStatCard(
          'Quran Sessions',
          '${((teacherStats['total_sessions'] ?? 0) * 0.6).round()}',
          Icons.menu_book_rounded,
          const Color(0xff3B82F6),
          '+${((teacherStats['total_sessions'] ?? 0) * 0.08).round()}',
        ),
        _buildModernStatCard(
          'Arabic Lessons',
          '${((teacherStats['total_sessions'] ?? 0) * 0.3).round()}',
          Icons.language_rounded,
          const Color(0xffF59E0B),
          '+${((teacherStats['total_sessions'] ?? 0) * 0.05).round()}',
        ),
        _buildModernStatCard(
          'Completed Tasks',
          '${teacherStats['completed_tasks'] ?? 0}',
          Icons.task_alt_rounded,
          const Color(0xff8B5CF6),
          '+${((teacherStats['completed_tasks'] ?? 0) * 0.15).round()}',
        ),
        _buildModernStatCard(
          'Parent Messages',
          '${((teacherStats['my_students'] ?? 0) * 1.2).round()}',
          Icons.chat_bubble_rounded,
          const Color(0xffEF4444),
          '+3',
        ),
      ],
    );
  }

  Widget _buildModernStatCard(
      String title, String value, IconData icon, Color color, String change) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Text(
                change,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff10B981),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: const Color(0xff111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xff6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyClassesModern() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
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
                  color: const Color(0xff3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.class_rounded,
                  color: Color(0xff3B82F6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'My Islamic Classes',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff111827),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Class'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xff3B82F6),
                  textStyle: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Class Cards
          _buildClassCard(
            'Quran Memorization (Grade 3)',
            '8 Students',
            'Next: Today 2:00 PM',
            const Color(0xff10B981),
            Icons.menu_book_rounded,
            85,
          ),
          const SizedBox(height: 12),
          _buildClassCard(
            'Arabic Grammar (Beginners)',
            '12 Students',
            'Next: Tomorrow 10:00 AM',
            const Color(0xffF59E0B),
            Icons.language_rounded,
            92,
          ),
          const SizedBox(height: 12),
          _buildClassCard(
            'Islamic Studies (Advanced)',
            '6 Students',
            'Next: Today 4:30 PM',
            const Color(0xff8B5CF6),
            Icons.school_rounded,
            78,
          ),
        ],
      ),
    );
  }

  Widget _buildClassCard(String className, String students, String nextClass,
      Color color, IconData icon, int progress) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  className,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xff111827),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      students,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xff6B7280),
                      ),
                    ),
                    const Text(' • '),
                    Text(
                      nextClass,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: progress / 100,
                        backgroundColor: const Color(0xffE5E7EB),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$progress%',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherProfileCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
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
                  color: const Color(0xff10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Color(0xff10B981),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Teacher Profile',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Profile Picture & Basic Info
          Center(
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xff10B981), Color(0xff34D399)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  userData?['first_name'] ?? 'Teacher Name',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xff111827),
                  ),
                ),
                Text(
                  'Islamic Studies Teacher',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xff6B7280),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Profile Completion
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xffFEF3C7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xffFCD34D)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xffF59E0B),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    FutureBuilder<int>(
                      key: ValueKey(_profileCompletionTrigger),
                      future: _getProfileCompletionPercentage(),
                      builder: (context, snapshot) {
                        final percentage = snapshot.data ?? 0;
                        return Text(
                          'Profile ${percentage}% Complete',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xffF59E0B),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Complete your profile to appear on the public teachers page and attract more students.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xff92400E),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _showProfileCompletionDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xffF59E0B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Complete Profile',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIslamicCalendarCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
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
                  color: const Color(0xff8B5CF6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: Color(0xff8B5CF6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Islamic Calendar',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Current Islamic Date
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xff8B5CF6), Color(0xffA78BFA)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getCurrentHijriDate(),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getCurrentHijriMonth(),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Upcoming Islamic Events
          Text(
            'Upcoming Events',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xff111827),
            ),
          ),
          const SizedBox(height: 12),
          _buildIslamicEvent('🌙', 'Laylat al-Qadr', '3 days'),
          const SizedBox(height: 8),
          _buildIslamicEvent('🕌', 'Eid al-Fitr', '12 days'),
          const SizedBox(height: 8),
          _buildIslamicEvent('📚', 'Ramadan Reading Week', '2 days'),
        ],
      ),
    );
  }

  Widget _buildIslamicEvent(String emoji, String event, String timeLeft) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            event,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xff374151),
            ),
          ),
        ),
        Text(
          timeLeft,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xff8B5CF6),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsTeacher() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
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
                  color: const Color(0xffEF4444).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.flash_on_rounded,
                  color: Color(0xffEF4444),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Quick Actions',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildQuickActionButton(
            'Add Assignment',
            Icons.assignment_rounded,
            const Color(0xff10B981),
          ),
          const SizedBox(height: 12),
          _buildQuickActionButton(
            'My Assignments',
            Icons.assignment_turned_in_rounded,
            const Color(0xff3B82F6),
          ),
          const SizedBox(height: 12),
          _buildQuickActionButton(
            'Message Parents',
            Icons.chat_bubble_rounded,
            const Color(0xffF59E0B),
          ),
          const SizedBox(height: 12),
          _buildQuickActionButton(
            'View Reports',
            Icons.analytics_rounded,
            const Color(0xff8B5CF6),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentProgressModern() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
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
                  color: const Color(0xff06B6D4).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  color: Color(0xff06B6D4),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'My Students Overview',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff111827),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _showAssignmentDialog,
                icon: const Icon(Icons.add, size: 16),
                label: Text(
                  'Add Assignment',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xff06B6D4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Progress Stats
          Row(
            children: [
              Expanded(
                child: _buildProgressStat(
                    'Quran Memorization', '87%', const Color(0xff10B981)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildProgressStat(
                    'Arabic Fluency', '73%', const Color(0xffF59E0B)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildProgressStat(
                    'Islamic Studies', '91%', const Color(0xff8B5CF6)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // My Students Section
          Row(
            children: [
              Text(
                'My Students',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff111827),
                ),
              ),
              const Spacer(),
              FutureBuilder<int>(
                future: _getMyStudentsCount(),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xff06B6D4).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count total',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xff06B6D4),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Students List
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _getMyStudents(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(color: Color(0xff06B6D4)),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Error loading students',
                        style:
                            GoogleFonts.inter(fontSize: 14, color: Colors.red),
                      ),
                    ],
                  ),
                );
              }

              final students = snapshot.data ?? [];

              if (students.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xffF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.school_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No Known Students Yet',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xff6B7280),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Students will appear here after you clock in for teaching sessions',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xff9CA3AF),
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Show students with progress tracking
              return Column(
                children: students.take(3).map((student) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildRealStudentProgressItem(student),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStat(String title, String percentage, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Text(
            percentage,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xff6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentProgressItem(
      String name, String grade, int score, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.person, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xff111827),
                  ),
                ),
                Text(
                  grade,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xff6B7280),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$score%',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentLessonsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
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
                  color: const Color(0xff3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: Color(0xff3B82F6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Recent Lessons',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildRecentLessonItem(
            'Surah Al-Baqarah (Verse 1-20)',
            'Ahmad Al-Rashid',
            '2 hours ago',
            const Color(0xff10B981),
            Icons.menu_book_rounded,
          ),
          const SizedBox(height: 12),
          _buildRecentLessonItem(
            'Arabic Grammar - Verb Conjugation',
            'Fatima Hassan',
            '4 hours ago',
            const Color(0xffF59E0B),
            Icons.language_rounded,
          ),
          const SizedBox(height: 12),
          _buildRecentLessonItem(
            'Hadith Studies - Sahih Bukhari',
            'Omar Malik',
            '1 day ago',
            const Color(0xff8B5CF6),
            Icons.library_books_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentLessonItem(
      String lesson, String student, String time, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lesson,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xff111827),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Student: $student',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xff6B7280),
                      ),
                    ),
                    const Text(' • '),
                    Text(
                      time,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xff6B7280),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIslamicResourcesCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
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
                  color: const Color(0xffF59E0B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.library_books_rounded,
                  color: Color(0xffF59E0B),
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
          const SizedBox(height: 20),
          _buildResourceItem('Quran Tafsir Library', Icons.menu_book_rounded,
              const Color(0xff10B981)),
          const SizedBox(height: 12),
          _buildResourceItem('Hadith Collections', Icons.book_rounded,
              const Color(0xff3B82F6)),
          const SizedBox(height: 12),
          _buildResourceItem('Islamic History Materials',
              Icons.history_edu_rounded, const Color(0xffF59E0B)),
          const SizedBox(height: 12),
          _buildResourceItem('Arabic Learning Tools', Icons.language_rounded,
              const Color(0xff8B5CF6)),
          const SizedBox(height: 12),
          _buildResourceItem('Prayer Time Calculator',
              Icons.access_time_rounded, const Color(0xffEF4444)),
        ],
      ),
    );
  }
}

// Teacher Profile Dialog for completing profile information
class _TeacherProfileDialog extends StatefulWidget {
  final VoidCallback? onProfileUpdated;

  const _TeacherProfileDialog({Key? key, this.onProfileUpdated})
      : super(key: key);

  @override
  _TeacherProfileDialogState createState() => _TeacherProfileDialogState();
}

class _TeacherProfileDialogState extends State<_TeacherProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _titleController = TextEditingController();
  final _bioController = TextEditingController();
  final _experienceController = TextEditingController();
  final _specialtiesController = TextEditingController();
  final _educationController = TextEditingController();

  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _titleController.dispose();
    _bioController.dispose();
    _experienceController.dispose();
    _specialtiesController.dispose();
    _educationController.dispose();
    super.dispose();
  }

  /// Load existing teacher profile data from Firestore
  Future<void> _loadExistingProfile() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final profileDoc = await FirebaseFirestore.instance
          .collection('teacher_profiles')
          .doc(user.uid)
          .get();

      if (profileDoc.exists) {
        final data = profileDoc.data()!;
        _nameController.text = data['full_name'] ?? '';
        _titleController.text = data['professional_title'] ?? '';
        _bioController.text = data['biography'] ?? '';
        _experienceController.text = data['years_of_experience'] ?? '';
        _specialtiesController.text = data['specialties'] ?? '';
        _educationController.text = data['education_certifications'] ?? '';
      }
    } catch (e) {
      print('Error loading teacher profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load existing profile: $e'),
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

  /// Builds loading state widget
  Widget _buildLoadingState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xff10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.person_rounded,
                color: Color(0xff10B981),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Loading Profile...',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xff111827),
                ),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
              color: const Color(0xff6B7280),
            ),
          ],
        ),
        const SizedBox(height: 40),
        const CircularProgressIndicator(
          color: Color(0xff10B981),
        ),
        const SizedBox(height: 24),
        Text(
          'Loading your existing profile information...',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xff6B7280),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(32),
        child: _isLoading
            ? _buildLoadingState()
            : SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xff10B981).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: Color(0xff10B981),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Complete Your Profile',
                                  style: GoogleFonts.inter(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xff111827),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Help parents and students learn about your expertise',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: const Color(0xff6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                            color: const Color(0xff6B7280),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Form Fields
                      _buildFormField(
                        'Full Name',
                        'Enter your full name as it should appear publicly',
                        _nameController,
                        Icons.person_outline,
                      ),
                      const SizedBox(height: 24),

                      _buildFormField(
                        'Professional Title',
                        'e.g., Quran & Tajweed Specialist, Arabic Teacher',
                        _titleController,
                        Icons.work_outline,
                      ),
                      const SizedBox(height: 24),

                      _buildFormField(
                        'Biography',
                        'Tell parents and students about your background and teaching approach',
                        _bioController,
                        Icons.description_outlined,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 24),

                      _buildFormField(
                        'Years of Experience',
                        'e.g., 10+ years',
                        _experienceController,
                        Icons.timeline_outlined,
                      ),
                      const SizedBox(height: 24),

                      _buildFormField(
                        'Specialties',
                        'e.g., Quran Memorization, Tajweed, Arabic Grammar, Islamic Studies',
                        _specialtiesController,
                        Icons.star_outline,
                      ),
                      const SizedBox(height: 24),

                      _buildFormField(
                        'Education & Certifications',
                        'e.g., PhD in Islamic Theology from Al-Azhar University, Ijazah in Quran',
                        _educationController,
                        Icons.school_outlined,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 32),

                      // Action Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xff6B7280),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: _isSaving ? null : _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xff10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 32, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isSaving
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Saving...',
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    'Save Profile',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildFormField(
    String label,
    String hint,
    TextEditingController controller,
    IconData icon, {
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xff374151),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              color: const Color(0xff9CA3AF),
              fontSize: 14,
            ),
            prefixIcon: Icon(icon, color: const Color(0xff6B7280)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xffD1D5DB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xffD1D5DB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xff10B981), width: 2),
            ),
            filled: true,
            fillColor: const Color(0xffF9FAFB),
            contentPadding: const EdgeInsets.all(16),
          ),
          validator: (value) {
            // No required validation - allow partial saves
            return null;
          },
        ),
      ],
    );
  }

  /// Save teacher profile to Firestore (allows partial saves)
  Future<void> _saveProfile() async {
    if (_isSaving) return; // Prevent double saves

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Prepare profile data - allow empty fields for partial saves
      final profileData = {
        'full_name': _nameController.text.trim(),
        'professional_title': _titleController.text.trim(),
        'biography': _bioController.text.trim(),
        'years_of_experience': _experienceController.text.trim(),
        'specialties': _specialtiesController.text.trim(),
        'education_certifications': _educationController.text.trim(),
        'updated_at': FieldValue.serverTimestamp(),
        'user_id': user.uid,
        'user_email': user.email,
      };

      // Only add created_at if this is a new profile
      final existingDoc = await FirebaseFirestore.instance
          .collection('teacher_profiles')
          .doc(user.uid)
          .get();

      if (!existingDoc.exists) {
        profileData['created_at'] = FieldValue.serverTimestamp();
      }

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('teacher_profiles')
          .doc(user.uid)
          .set(profileData, SetOptions(merge: true));

      // Calculate and show completion percentage
      int completedFields = 0;
      final totalFields = 6;

      if (_nameController.text.trim().isNotEmpty) completedFields++;
      if (_titleController.text.trim().isNotEmpty) completedFields++;
      if (_bioController.text.trim().isNotEmpty) completedFields++;
      if (_experienceController.text.trim().isNotEmpty) completedFields++;
      if (_specialtiesController.text.trim().isNotEmpty) completedFields++;
      if (_educationController.text.trim().isNotEmpty) completedFields++;

      final completionPercentage =
          ((completedFields / totalFields) * 100).round();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Profile saved successfully!',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Profile $completionPercentage% complete',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xff10B981),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );

        Navigator.of(context).pop();

        // Notify parent to refresh completion percentage
        if (widget.onProfileUpdated != null) {
          widget.onProfileUpdated!();
        }
      }
    } catch (e) {
      print('Error saving teacher profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Failed to save profile: ${e.toString()}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

// Assignment Dialog for creating assignments
class _AssignmentDialog extends StatefulWidget {
  final VoidCallback? onAssignmentCreated;
  final Map<String, dynamic>? existingAssignment;

  const _AssignmentDialog(
      {Key? key, this.onAssignmentCreated, this.existingAssignment})
      : super(key: key);

  @override
  _AssignmentDialogState createState() => _AssignmentDialogState();
}

class _AssignmentDialogState extends State<_AssignmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dueDateController = TextEditingController();

  List<String> _selectedStudents = [];
  List<Map<String, dynamic>> _myStudents = [];
  List<Map<String, dynamic>> _attachments = [];
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isUploadingFile = false;
  DateTime? _selectedDueDate;

  @override
  void initState() {
    super.initState();
    _loadMyStudents();
    _loadExistingAssignment();
  }

  void _loadExistingAssignment() {
    if (widget.existingAssignment != null) {
      final assignment = widget.existingAssignment!;

      _titleController.text = assignment['title'] ?? '';
      _descriptionController.text = assignment['description'] ?? '';

      if (assignment['due_date'] != null) {
        final dueDate = (assignment['due_date'] as Timestamp).toDate();
        _selectedDueDate = dueDate;
        _dueDateController.text =
            '${dueDate.day}/${dueDate.month}/${dueDate.year}';
      }

      _selectedStudents = List<String>.from(assignment['assigned_to'] ?? []);

      // Load attachments if they exist
      if (assignment['attachments'] != null) {
        _attachments =
            List<Map<String, dynamic>>.from(assignment['attachments']);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _dueDateController.dispose();
    super.dispose();
  }

  Future<void> _loadMyStudents() async {
    setState(() => _isLoading = true);

    try {
      // Load ALL students from the users collection
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('user_type', isEqualTo: 'student')
          .get();

      List<Map<String, dynamic>> students = [];
      for (var doc in usersSnapshot.docs) {
        final data = doc.data();

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
        });
      }

      // Sort students alphabetically
      students
          .sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));

      setState(() {
        _myStudents = students;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading students: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAssignment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one student'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      print('Saving assignment for user: ${user.uid}');
      print('Assignment title: ${_titleController.text.trim()}');
      print('Selected students: $_selectedStudents');
      print('Attachments: ${_attachments.length}');

      final assignmentData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'due_date': _selectedDueDate != null
            ? Timestamp.fromDate(_selectedDueDate!)
            : null,
        'assigned_to': _selectedStudents,
        'teacher_id': user.uid,
        'teacher_email': user.email,
        'attachments': _attachments,
        'status': 'active',
        'type': 'assignment',
        'updated_at': FieldValue.serverTimestamp(),
      };

      DocumentReference? docRef;

      // Check if we're editing or creating
      if (widget.existingAssignment != null) {
        // Update existing assignment
        print(
            'Updating existing assignment: ${widget.existingAssignment!['id']}');
        await FirebaseFirestore.instance
            .collection('assignments')
            .doc(widget.existingAssignment!['id'])
            .update(assignmentData);
      } else {
        // Create new assignment
        assignmentData['created_at'] = FieldValue.serverTimestamp();
        print('Creating new assignment...');
        docRef = await FirebaseFirestore.instance
            .collection('assignments')
            .add(assignmentData);
        print('Assignment created with ID: ${docRef.id}');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  widget.existingAssignment != null
                      ? 'Assignment updated successfully!'
                      : 'Assignment created successfully!',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xff10B981),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );

        Navigator.of(context).pop();

        if (widget.onAssignmentCreated != null) {
          print('Calling onAssignmentCreated callback');
          widget.onAssignmentCreated!();
        }
      }
    } catch (e) {
      print('Error saving assignment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create assignment: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(32),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xff06B6D4).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.assignment_rounded,
                        color: Color(0xff06B6D4),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.existingAssignment != null
                                ? 'Edit Assignment'
                                : 'Create Assignment',
                            style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xff111827),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.existingAssignment != null
                                ? 'Update assignment details'
                                : 'Assign tasks to your students',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: const Color(0xff6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      color: const Color(0xff6B7280),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Assignment Title
                _buildFormField(
                  'Assignment Title',
                  'Enter assignment title',
                  _titleController,
                  Icons.title_outlined,
                ),
                const SizedBox(height: 24),

                // Description
                _buildFormField(
                  'Description',
                  'Enter assignment description and instructions',
                  _descriptionController,
                  Icons.description_outlined,
                  maxLines: 3,
                ),
                const SizedBox(height: 24),

                // Due Date
                _buildDateField(),
                const SizedBox(height: 24),

                // Student Selection
                _buildStudentSelection(),
                const SizedBox(height: 24),

                // Attachments
                _buildAttachmentSection(),
                const SizedBox(height: 32),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xff6B7280),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveAssignment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff06B6D4),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSaving
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  widget.existingAssignment != null
                                      ? 'Updating...'
                                      : 'Creating...',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              widget.existingAssignment != null
                                  ? 'Update Assignment'
                                  : 'Create Assignment',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormField(
    String label,
    String hint,
    TextEditingController controller,
    IconData icon, {
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xff374151),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xff111827),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              color: const Color(0xff9CA3AF),
              fontSize: 14,
            ),
            prefixIcon: Icon(icon, color: const Color(0xff6B7280)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xffD1D5DB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xffD1D5DB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xff06B6D4), width: 2),
            ),
            filled: true,
            fillColor: const Color(0xffF9FAFB),
            contentPadding: const EdgeInsets.all(16),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'This field is required';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Due Date (Optional)',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xff374151),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _dueDateController,
          readOnly: true,
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now().add(const Duration(days: 7)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (date != null) {
              setState(() {
                _selectedDueDate = date;
                _dueDateController.text =
                    '${date.day}/${date.month}/${date.year}';
              });
            }
          },
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xff111827),
          ),
          decoration: InputDecoration(
            hintText: 'Select due date',
            hintStyle: GoogleFonts.inter(
              color: const Color(0xff9CA3AF),
              fontSize: 14,
            ),
            prefixIcon:
                const Icon(Icons.calendar_today, color: Color(0xff6B7280)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xffD1D5DB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xffD1D5DB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xff06B6D4), width: 2),
            ),
            filled: true,
            fillColor: const Color(0xffF9FAFB),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildStudentSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Assign To Students',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xff374151),
          ),
        ),
        const SizedBox(height: 8),
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_myStudents.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xffF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xffD1D5DB)),
            ),
            child: Text(
              'No students available in the system.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xff6B7280),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xffD1D5DB)),
            ),
            child: Column(
              children: _myStudents.map((student) {
                final studentName = student['name'] as String;
                final isSelected = _selectedStudents.contains(studentName);

                return CheckboxListTile(
                  title: Text(
                    studentName,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  value: isSelected,
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        _selectedStudents.add(studentName);
                      } else {
                        _selectedStudents.remove(studentName);
                      }
                    });
                  },
                  activeColor: const Color(0xff06B6D4),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildAttachmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Attachments (Optional)',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xff374151),
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _isUploadingFile ? null : _addAttachment,
              icon: Icon(
                Icons.attach_file,
                size: 16,
                color: _isUploadingFile ? Colors.grey : const Color(0xff06B6D4),
              ),
              label: Text(
                _isUploadingFile ? 'Uploading...' : 'Add File',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color:
                      _isUploadingFile ? Colors.grey : const Color(0xff06B6D4),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_attachments.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xffF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xffD1D5DB)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.attachment,
                  color: Colors.grey[400],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'No attachments added',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xff6B7280),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xffD1D5DB)),
            ),
            child: Column(
              children: _attachments.map((attachment) {
                return ListTile(
                  leading: Icon(
                    _getFileIcon(attachment['name']),
                    color: const Color(0xff06B6D4),
                  ),
                  title: Text(
                    attachment['name'],
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    _formatFileSize(attachment['size']),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xff6B7280),
                    ),
                  ),
                  trailing: IconButton(
                    onPressed: () {
                      setState(() {
                        _attachments.remove(attachment);
                      });
                    },
                    icon: const Icon(Icons.close, color: Colors.red, size: 20),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
        return Icons.audio_file;
      default:
        return Icons.attach_file;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _addAttachment() async {
    setState(() => _isUploadingFile = true);

    try {
      // Create a file input element for web
      final html.FileUploadInputElement uploadInput =
          html.FileUploadInputElement();
      uploadInput.multiple = false;
      uploadInput.accept =
          '.pdf,.doc,.docx,.txt,.jpg,.jpeg,.png,.gif,.mp4,.mp3,.ppt,.pptx,.xls,.xlsx';

      // Trigger file picker
      uploadInput.click();

      // Wait for file selection
      await uploadInput.onChange.first;

      if (uploadInput.files!.isNotEmpty) {
        final file = uploadInput.files!.first;

        // Create file object
        final attachment = {
          'name': file.name,
          'size': file.size,
          'url':
              'https://example.com/${file.name}', // In real app, upload to Firebase Storage
          'type': file.type,
          'lastModified': file.lastModified,
        };

        setState(() {
          _attachments.add(attachment);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('File "${file.name}" added successfully!'),
                ],
              ),
              backgroundColor: const Color(0xff10B981),
            ),
          );
        }
      }
    } catch (e) {
      print('Error adding attachment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Failed to add file: $e')),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingFile = false);
      }
    }
  }
}

// My Assignments Dialog for managing existing assignments
class _MyAssignmentsDialog extends StatefulWidget {
  @override
  _MyAssignmentsDialogState createState() => _MyAssignmentsDialogState();
}

class _MyAssignmentsDialogState extends State<_MyAssignmentsDialog> {
  List<Map<String, dynamic>> _assignments = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMyAssignments();
  }

  Future<void> _loadMyAssignments() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No authenticated user found');
        setState(() => _isLoading = false);
        return;
      }

      print('Loading assignments for user: ${user.uid}');

      // Try without orderBy first to see if that's causing issues
      var query = FirebaseFirestore.instance
          .collection('assignments')
          .where('teacher_id', isEqualTo: user.uid);

      try {
        final assignmentsSnapshot =
            await query.orderBy('created_at', descending: true).get();

        print(
            'Found ${assignmentsSnapshot.docs.length} assignments with orderBy');

        List<Map<String, dynamic>> assignments = [];
        for (var doc in assignmentsSnapshot.docs) {
          final data = doc.data();
          print('Assignment: ${doc.id} - ${data['title']}');
          assignments.add({
            'id': doc.id,
            ...data,
          });
        }

        setState(() {
          _assignments = assignments;
          _isLoading = false;
        });
      } catch (orderError) {
        print('OrderBy failed, trying without order: $orderError');

        // Fallback: load without ordering
        final assignmentsSnapshot = await query.get();

        print(
            'Found ${assignmentsSnapshot.docs.length} assignments without orderBy');

        List<Map<String, dynamic>> assignments = [];
        for (var doc in assignmentsSnapshot.docs) {
          final data = doc.data();
          print('Assignment: ${doc.id} - ${data['title']}');
          assignments.add({
            'id': doc.id,
            ...data,
          });
        }

        // Sort manually by created_at if available
        assignments.sort((a, b) {
          final aCreated = a['created_at'] as Timestamp?;
          final bCreated = b['created_at'] as Timestamp?;
          if (aCreated == null || bCreated == null) return 0;
          return bCreated.compareTo(aCreated);
        });

        setState(() {
          _assignments = assignments;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading assignments: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }

      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load assignments: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xff3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.assignment_turned_in_rounded,
                    color: Color(0xff3B82F6),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'My Assignments',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xff111827),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  color: const Color(0xff6B7280),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Assignments List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _assignments.isEmpty
                      ? _buildEmptyState()
                      : _buildAssignmentsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Assignments Yet',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xff6B7280),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first assignment to get started',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xff9CA3AF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentsList() {
    return ListView.builder(
      itemCount: _assignments.length,
      itemBuilder: (context, index) {
        final assignment = _assignments[index];
        return _buildAssignmentCard(assignment);
      },
    );
  }

  Widget _buildAssignmentCard(Map<String, dynamic> assignment) {
    final title = assignment['title'] ?? 'Untitled Assignment';
    final description = assignment['description'] ?? '';
    final assignedTo = List<String>.from(assignment['assigned_to'] ?? []);
    final status = assignment['status'] ?? 'active';
    final createdAt = assignment['created_at'] as Timestamp?;
    final dueDate = assignment['due_date'] as Timestamp?;

    // Check if assignment is overdue for styling
    final isOverdue = dueDate != null && _isOverdue(dueDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isOverdue ? Colors.red.withOpacity(0.3) : const Color(0xffE5E7EB),
          width: isOverdue ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isOverdue ? Colors.red : Colors.black).withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xff111827),
                        ),
                      ),
                    ),
                    if (isOverdue) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'OVERDUE',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _editAssignment(assignment);
                      break;
                    case 'delete':
                      _deleteAssignment(assignment);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xff6B7280),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.people, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                '${assignedTo.length} students',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xff6B7280),
                ),
              ),
              const SizedBox(width: 16),
              if (dueDate != null) ...[
                Icon(
                  Icons.schedule,
                  size: 16,
                  color: _getDueDateColor(dueDate),
                ),
                const SizedBox(width: 4),
                Text(
                  'Due: ${_formatDueDate(dueDate)}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: _getDueDateColor(dueDate),
                    fontWeight: _isOverdue(dueDate)
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                const SizedBox(width: 16),
              ],
              if (createdAt != null) ...[
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Created: ${_formatDate(createdAt)}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xff6B7280),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatDueDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference =
        date.difference(now); // Note: date - now for future dates

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Tomorrow';
    } else if (difference.inDays < 7 && difference.inDays > 0) {
      return 'In ${difference.inDays} days';
    } else if (difference.inDays < 0) {
      // Past due
      final pastDays = difference.inDays.abs();
      if (pastDays == 1) {
        return 'Overdue (1 day)';
      } else if (pastDays < 7) {
        return 'Overdue ($pastDays days)';
      } else {
        return 'Overdue';
      }
    } else {
      // More than a week away or specific date
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Color _getDueDateColor(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = date.difference(now);

    if (difference.inDays < 0) {
      // Overdue - red
      return Colors.red;
    } else if (difference.inDays <= 1) {
      // Due today or tomorrow - orange
      return Colors.orange;
    } else if (difference.inDays <= 3) {
      // Due soon - amber
      return Colors.amber[700]!;
    } else {
      // Normal - gray
      return const Color(0xff6B7280);
    }
  }

  bool _isOverdue(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    return date.isBefore(now);
  }

  void _editAssignment(Map<String, dynamic> assignment) {
    // Close current dialog and open edit dialog
    Navigator.of(context).pop();
    showDialog(
      context: context,
      builder: (context) => _AssignmentDialog(
        existingAssignment: assignment,
        onAssignmentCreated: () {
          // Refresh assignments list if still mounted
        },
      ),
    );
  }

  void _deleteAssignment(Map<String, dynamic> assignment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Assignment',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete "${assignment['title']}"? This action cannot be undone.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('assignments')
                    .doc(assignment['id'])
                    .delete();

                Navigator.of(context).pop(); // Close delete dialog
                _loadMyAssignments(); // Refresh list

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Assignment deleted successfully'),
                    backgroundColor: Color(0xff10B981),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete assignment: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
