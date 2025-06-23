import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  Map<String, int> stats = {};

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
    }
  }

  Future<void> _loadStats() async {
    try {
      print('Loading dashboard statistics...');

      // Load all collections in parallel
      final futures = await Future.wait([
        FirebaseFirestore.instance.collection('users').get(),
        FirebaseFirestore.instance.collection('forms').get(),
        FirebaseFirestore.instance.collection('form_responses').get(),
      ]);

      final usersSnapshot = futures[0];
      final formsSnapshot = futures[1];
      final responsesSnapshot = futures[2];

      print('Users found: ${usersSnapshot.docs.length}');
      print('Forms found: ${formsSnapshot.docs.length}');
      print('Responses found: ${responsesSnapshot.docs.length}');

      // Count users by role
      Map<String, int> roleCount = {};
      for (var doc in usersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final role = data['user_type'] ?? 'unknown';
        roleCount[role] = (roleCount[role] ?? 0) + 1;
        print('User: ${data['first_name']} ${data['last_name']} - Role: $role');
      }

      // Calculate additional stats
      int activeUsers = 0;
      int recentLogins = 0;
      DateTime now = DateTime.now();
      DateTime weekAgo = now.subtract(const Duration(days: 7));

      for (var doc in usersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final isActive = data['is_active'] ?? true;
        if (isActive) activeUsers++;

        // Check for recent logins (if last_login exists and is recent)
        final lastLogin = data['last_login'];
        if (lastLogin != null && lastLogin is Timestamp) {
          if (lastLogin.toDate().isAfter(weekAgo)) {
            recentLogins++;
          }
        }
      }

      // Calculate form completion rate
      double completionRate = 0.0;
      if (formsSnapshot.docs.isNotEmpty) {
        completionRate =
            responsesSnapshot.docs.length / formsSnapshot.docs.length;
      }

      if (mounted) {
        setState(() {
          stats = {
            'total_users': usersSnapshot.docs.length,
            'total_forms': formsSnapshot.docs.length,
            'total_responses': responsesSnapshot.docs.length,
            'admins': roleCount['admin'] ?? 0,
            'teachers': roleCount['teacher'] ?? 0,
            'students': roleCount['student'] ?? 0,
            'parents': roleCount['parent'] ?? 0,
            'active_users': activeUsers,
            'recent_logins': recentLogins,
            'completion_rate': (completionRate * 100).round(),
          };
        });
        print('Stats loaded successfully: $stats');
      }
    } catch (e) {
      print('Error loading stats: $e');
      // Set default values on error
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
            'completion_rate': 0,
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
          // Stats Overview Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'System Statistics',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xff1a1a1a),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  _loadStats();
                  _loadUserData();
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Primary Stats Overview
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
            children: [
              _buildStatCard('Total Users', stats['total_users'] ?? 0,
                  Icons.people, Colors.blue),
              _buildStatCard('Teachers', stats['teachers'] ?? 0, Icons.school,
                  Colors.green),
              _buildStatCard('Students', stats['students'] ?? 0, Icons.person,
                  Colors.orange),
              _buildStatCard('Parents', stats['parents'] ?? 0,
                  Icons.family_restroom, Colors.purple),
            ],
          ),
          const SizedBox(height: 16),

          // Secondary Stats Overview
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
            children: [
              _buildStatCard('Active Forms', stats['total_forms'] ?? 0,
                  Icons.assignment, Colors.indigo),
              _buildStatCard('Form Responses', stats['total_responses'] ?? 0,
                  Icons.assignment_turned_in, Colors.teal),
              _buildStatCard('Active Users', stats['active_users'] ?? 0,
                  Icons.verified_user, Colors.cyan),
              _buildStatCard('Recent Logins', stats['recent_logins'] ?? 0,
                  Icons.login, Colors.amber),
            ],
          ),
          const SizedBox(height: 24),

          // Quick Actions and Recent Activity
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _buildQuickActionsCard(),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: _buildRecentActivityCard(),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // System Overview
          _buildSystemOverviewCard(),
        ],
      ),
    );
  }

  Widget _buildTeacherDashboard() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Teacher Stats
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.3,
            children: [
              _buildStatCard('My Students', 24, Icons.groups, Colors.blue),
              _buildStatCard('Active Forms', stats['total_forms'] ?? 0,
                  Icons.assignment, Colors.green),
              _buildStatCard('Pending Tasks', 7, Icons.task_alt, Colors.orange),
            ],
          ),
          const SizedBox(height: 24),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildMyClassesCard()),
              const SizedBox(width: 16),
              Expanded(child: _buildUpcomingTasksCard()),
            ],
          ),
          const SizedBox(height: 24),

          _buildStudentProgressCard(),
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
            'Quick Actions',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xff1a1a1a),
            ),
          ),
          const SizedBox(height: 16),
          _buildQuickActionButton(
              'Add New User', Icons.person_add, Colors.blue),
          const SizedBox(height: 8),
          _buildQuickActionButton('Create Form', Icons.add_box, Colors.green),
          const SizedBox(height: 8),
          _buildQuickActionButton(
              'View Reports', Icons.analytics, Colors.orange),
          const SizedBox(height: 8),
          _buildQuickActionButton(
              'Export Form Responses', Icons.file_download, Colors.teal),
          const SizedBox(height: 8),
          _buildQuickActionButton(
              'System Settings', Icons.settings, Colors.purple),
        ],
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
            'Recent Activity',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xff1a1a1a),
            ),
          ),
          const SizedBox(height: 16),
          _buildActivityItem('New student registered', '2 minutes ago',
              Icons.person_add, Colors.green),
          _buildActivityItem('Form "Parent Consent" created', '1 hour ago',
              Icons.assignment, Colors.blue),
          _buildActivityItem('Teacher John Smith logged in', '3 hours ago',
              Icons.login, Colors.orange),
          _buildActivityItem('System backup completed', '1 day ago',
              Icons.backup, Colors.purple),
        ],
      ),
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
        return FormResponsesExportDialog();
      },
    );
  }
}

/// Dialog for exporting form responses with date range selection
class FormResponsesExportDialog extends StatefulWidget {
  @override
  State<FormResponsesExportDialog> createState() =>
      _FormResponsesExportDialogState();
}

class _FormResponsesExportDialogState extends State<FormResponsesExportDialog> {
  DateTime? startDate;
  DateTime? endDate;
  String? selectedFormId;
  String selectedFormat = 'csv';
  bool isLoading = false;
  List<Map<String, dynamic>> availableForms = [];

  @override
  void initState() {
    super.initState();
    _loadForms();
    // Set default date range to last 30 days
    endDate = DateTime.now();
    startDate = endDate!.subtract(const Duration(days: 30));
  }

  Future<void> _loadForms() async {
    try {
      final formsSnapshot =
          await FirebaseFirestore.instance.collection('form').get();

      setState(() {
        availableForms = formsSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'title': data['title'] ?? 'Untitled Form',
            'createdAt': data['createdAt'],
          };
        }).toList();

        // Sort by creation date, newest first
        availableForms.sort((a, b) {
          final aTime = a['createdAt'] as Timestamp?;
          final bTime = b['createdAt'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        });
      });
    } catch (e) {
      print('Error loading forms: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildContent()),
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
        gradient: LinearGradient(
          colors: [Color(0xff0d9488), Color(0xff14b8a6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
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
              Icons.file_download,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Export Form Responses',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Download responses as CSV with date filtering',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFormSelection(),
          const SizedBox(height: 24),
          _buildDateRangeSelection(),
          const SizedBox(height: 24),
          _buildFormatSelection(),
          const SizedBox(height: 24),
          _buildExportPreview(),
        ],
      ),
    );
  }

  Widget _buildFormSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.assignment, color: Colors.teal.shade600, size: 20),
            const SizedBox(width: 8),
            Text(
              'Select Form',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xff111827),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xffE2E8F0)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedFormId,
              isExpanded: true,
              hint: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'All Forms (default)',
                  style: GoogleFonts.inter(
                    color: const Color(0xff6B7280),
                    fontSize: 14,
                  ),
                ),
              ),
              items: [
                DropdownMenuItem<String>(
                  value: null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(Icons.select_all,
                            color: Colors.teal.shade600, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'All Forms',
                          style: GoogleFonts.inter(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                ...availableForms.map((form) {
                  return DropdownMenuItem<String>(
                    value: form['id'],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Icon(Icons.assignment,
                              color: Colors.blue.shade600, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              form['title'],
                              style: GoogleFonts.inter(fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ],
              onChanged: (value) {
                setState(() {
                  selectedFormId = value;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateRangeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.date_range, color: Colors.teal.shade600, size: 20),
            const SizedBox(width: 8),
            Text(
              'Date Range',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xff111827),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildDateButton('Start Date', startDate, true)),
            const SizedBox(width: 16),
            Expanded(child: _buildDateButton('End Date', endDate, false)),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            _buildQuickDateButton('Last 7 days', 7),
            _buildQuickDateButton('Last 30 days', 30),
            _buildQuickDateButton('Last 90 days', 90),
            _buildQuickDateButton('This year', 365),
          ],
        ),
      ],
    );
  }

  Widget _buildDateButton(String label, DateTime? date, bool isStart) {
    return InkWell(
      onTap: () => _selectDate(isStart),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xffE2E8F0)),
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xffF8FAFC),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xff6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              date != null
                  ? '${date.day}/${date.month}/${date.year}'
                  : 'Select date',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xff111827),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickDateButton(String label, int days) {
    return InkWell(
      onTap: () => _setQuickDateRange(days),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.teal.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.teal.shade200),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.teal.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildFormatSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.description, color: Colors.teal.shade600, size: 20),
            const SizedBox(width: 8),
            Text(
              'Export Format',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xff111827),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xffF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildFormatOption('CSV', 'csv', Icons.table_chart),
              ),
              Expanded(
                child: _buildFormatOption('JSON', 'json', Icons.code),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFormatOption(String label, String value, IconData icon) {
    final isSelected = selectedFormat == value;
    return InkWell(
      onTap: () => setState(() => selectedFormat = value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color:
                  isSelected ? Colors.teal.shade600 : const Color(0xff6B7280),
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color:
                    isSelected ? Colors.teal.shade600 : const Color(0xff6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportPreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade600, size: 20),
              const SizedBox(width: 8),
              Text(
                'Export Summary',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSummaryRow(
              'Form:',
              selectedFormId == null
                  ? 'All forms'
                  : (availableForms.firstWhere((f) => f['id'] == selectedFormId,
                              orElse: () => {'title': 'Unknown'})['title']
                          as String? ??
                      'Unknown')),
          _buildSummaryRow('Date Range:',
              '${startDate != null ? "${startDate!.day}/${startDate!.month}/${startDate!.year}" : "N/A"} - ${endDate != null ? "${endDate!.day}/${endDate!.month}/${endDate!.year}" : "N/A"}'),
          _buildSummaryRow('Format:', selectedFormat.toUpperCase()),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xff6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xff111827),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xffE2E8F0))),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: isLoading ? null : () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Color(0xffE2E8F0)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff6B7280),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: isLoading || startDate == null || endDate == null
                  ? null
                  : _exportResponses,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: isLoading
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Exporting...',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.download, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Export Responses',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          isStart ? (startDate ?? DateTime.now()) : (endDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.teal.shade600,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          startDate = picked;
          // Ensure end date is not before start date
          if (endDate != null && endDate!.isBefore(startDate!)) {
            endDate = startDate;
          }
        } else {
          endDate = picked;
          // Ensure start date is not after end date
          if (startDate != null && startDate!.isAfter(endDate!)) {
            startDate = endDate;
          }
        }
      });
    }
  }

  void _setQuickDateRange(int days) {
    setState(() {
      endDate = DateTime.now();
      startDate = endDate!.subtract(Duration(days: days));
    });
  }

  Future<void> _exportResponses() async {
    if (startDate == null || endDate == null) return;

    setState(() => isLoading = true);

    try {
      // Use simpler query to avoid composite index requirement
      Query query = FirebaseFirestore.instance
          .collection('form_responses')
          .where('submittedAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate!))
          .where('submittedAt',
              isLessThanOrEqualTo:
                  Timestamp.fromDate(endDate!.add(const Duration(days: 1))))
          .orderBy('submittedAt', descending: true);

      final responsesSnapshot = await query.get();

      // Filter by form ID in memory if specified
      List<QueryDocumentSnapshot> filteredDocs = responsesSnapshot.docs;
      if (selectedFormId != null) {
        filteredDocs = responsesSnapshot.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['formId'] == selectedFormId;
        }).toList();
      }

      if (filteredDocs.isEmpty) {
        _showSnackBar('No responses found for the selected criteria',
            isError: true);
        return;
      }

      // Get all form details for proper column headers
      final formIds = filteredDocs
          .map(
              (doc) => (doc.data() as Map<String, dynamic>)['formId'] as String)
          .toSet();
      final formsData = <String, Map<String, dynamic>>{};

      for (String formId in formIds) {
        final formDoc = await FirebaseFirestore.instance
            .collection('form')
            .doc(formId)
            .get();
        if (formDoc.exists) {
          formsData[formId] = formDoc.data()!;
        }
      }

      if (selectedFormat == 'csv') {
        await _exportAsCSV(filteredDocs, formsData);
      } else {
        await _exportAsJSON(filteredDocs, formsData);
      }

      _showSnackBar(
          'Export completed successfully! ${filteredDocs.length} responses exported.',
          isError: false);
      Navigator.of(context).pop();
    } catch (e) {
      print('Export error: $e');
      _showSnackBar('Export failed: ${e.toString()}', isError: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _exportAsCSV(List<QueryDocumentSnapshot> responses,
      Map<String, Map<String, dynamic>> formsData) async {
    // Build dynamic headers based on all possible fields across all forms
    Set<String> allFieldIds = {};
    for (var response in responses) {
      final data = response.data() as Map<String, dynamic>;
      final responseData = data['responses'] as Map<String, dynamic>? ?? {};
      allFieldIds.addAll(responseData.keys);
    }

    // Create CSV headers
    List<String> headers = [
      'Response ID',
      'Form Title',
      'User Email',
      'Submitted At',
      'Status',
    ];

    // Add field headers with proper labels
    Map<String, String> fieldLabels = {};
    for (String formId in formsData.keys) {
      final fields =
          formsData[formId]!['fields'] as Map<String, dynamic>? ?? {};
      for (String fieldId in fields.keys) {
        final field = fields[fieldId] as Map<String, dynamic>;
        fieldLabels[fieldId] = field['label'] ?? fieldId;
      }
    }

    for (String fieldId in allFieldIds) {
      headers.add(fieldLabels[fieldId] ?? fieldId);
    }

    // Build CSV rows
    List<List<String>> csvData = [headers];

    for (var response in responses) {
      final data = response.data() as Map<String, dynamic>;
      final formId = data['formId'] as String;
      final formTitle = formsData[formId]?['title'] ?? 'Unknown Form';
      final userEmail = data['userEmail'] ?? 'Unknown User';
      final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();
      final status = data['status'] ?? 'completed';
      final responseData = data['responses'] as Map<String, dynamic>? ?? {};

      List<String> row = [
        response.id,
        formTitle,
        userEmail,
        submittedAt?.toString() ?? 'Unknown',
        status,
      ];

      // Add field values
      for (String fieldId in allFieldIds) {
        final value = responseData[fieldId];
        String cellValue = '';

        if (value != null) {
          if (value is List) {
            cellValue = value.join('; ');
          } else if (value is Map) {
            // Handle complex objects like image uploads
            if (value['downloadURL'] != null) {
              cellValue =
                  'File: ${value['fileName'] ?? 'Unknown'} (${value['downloadURL']})';
            } else {
              cellValue = value.toString();
            }
          } else {
            cellValue = value.toString();
          }
        }

        row.add(cellValue);
      }

      csvData.add(row);
    }

    // Convert to CSV and download
    String csvString = const ListToCsvConverter().convert(csvData);
    final bytes = utf8.encode(csvString);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);

    final fileName =
        'form_responses_${startDate!.day}-${startDate!.month}-${startDate!.year}_to_${endDate!.day}-${endDate!.month}-${endDate!.year}.csv';

    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _exportAsJSON(List<QueryDocumentSnapshot> responses,
      Map<String, Map<String, dynamic>> formsData) async {
    List<Map<String, dynamic>> jsonData = [];

    for (var response in responses) {
      final data = response.data() as Map<String, dynamic>;
      final formId = data['formId'] as String;
      final formTitle = formsData[formId]?['title'] ?? 'Unknown Form';

      jsonData.add({
        'responseId': response.id,
        'formId': formId,
        'formTitle': formTitle,
        'userEmail': data['userEmail'],
        'submittedAt':
            (data['submittedAt'] as Timestamp?)?.toDate()?.toIso8601String(),
        'status': data['status'],
        'responses': data['responses'],
      });
    }

    final jsonString = jsonEncode({
      'exportInfo': {
        'exportedAt': DateTime.now().toIso8601String(),
        'dateRange': {
          'startDate': startDate!.toIso8601String(),
          'endDate': endDate!.toIso8601String(),
        },
        'totalResponses': jsonData.length,
        'selectedForm': selectedFormId == null
            ? 'All Forms'
            : formsData[selectedFormId]?['title'],
      },
      'responses': jsonData,
    });

    final bytes = utf8.encode(jsonString);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);

    final fileName =
        'form_responses_${startDate!.day}-${startDate!.month}-${startDate!.year}_to_${endDate!.day}-${endDate!.month}-${endDate!.year}.json';

    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor:
            isError ? const Color(0xffEF4444) : const Color(0xff10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
