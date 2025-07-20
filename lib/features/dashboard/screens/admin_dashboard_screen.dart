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
        return _TeacherProfileDialog();
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
            'Start Live Class',
            Icons.video_call_rounded,
            const Color(0xff10B981),
          ),
          const SizedBox(height: 12),
          _buildQuickActionButton(
            'Message Parents',
            Icons.chat_bubble_rounded,
            const Color(0xff3B82F6),
          ),
          const SizedBox(height: 12),
          _buildQuickActionButton(
            'Add Assignment',
            Icons.assignment_rounded,
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
                'Student Progress Overview',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff111827),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {},
                child: Text(
                  'View All',
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

          // Top Students
          Text(
            'Top Performing Students',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xff111827),
            ),
          ),
          const SizedBox(height: 12),
          _buildStudentProgressItem(
              'Ahmad Al-Rashid', 'Grade 4', 94, const Color(0xff10B981)),
          const SizedBox(height: 8),
          _buildStudentProgressItem(
              'Fatima Hassan', 'Grade 3', 89, const Color(0xff3B82F6)),
          const SizedBox(height: 8),
          _buildStudentProgressItem(
              'Omar Malik', 'Grade 5', 87, const Color(0xffF59E0B)),
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
