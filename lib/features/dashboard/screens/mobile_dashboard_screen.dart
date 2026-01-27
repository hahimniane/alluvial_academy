import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/user_role_service.dart';
import '../../chat/screens/chat_page.dart';
import '../../time_clock/screens/time_clock_screen.dart';
import './admin_dashboard_screen.dart';
import '../../tasks/screens/quick_tasks_screen.dart';
import '../../../form_screen.dart';
import '../../forms/screens/my_submissions_screen.dart';
import '../../shift_management/screens/teacher_shift_screen.dart';
import '../../forms/screens/teacher_forms_screen.dart';
import '../../../core/services/profile_picture_service.dart';
import '../../settings/screens/mobile_settings_screen.dart';
import '../../notifications/screens/mobile_notification_screen.dart';
import '../../user_management/screens/mobile_user_management_screen.dart';
import './teacher_home_screen.dart'; // Import the new TeacherHomeScreen
// import './teacher_mobile_home.dart'; // Remove the old one
import './teacher_job_board_screen.dart';
import '../../profile/screens/teacher_profile_screen.dart';
import '../../student/screens/student_classes_screen.dart'; // Student classes screen
import '../../admin/screens/admin_classes_screen.dart'; // Admin classes screen

// Onboarding imports
import '../../../core/services/onboarding_service.dart';
import '../../onboarding/screens/student_welcome_screen.dart';
import '../../onboarding/services/student_feature_tour.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

/// Navigation item data
class _NavItemData {
  final IconData icon;
  final String label;
  final int index;
  
  _NavItemData(this.icon, this.label, this.index);
}

/// Beautiful mobile-optimized dashboard with bottom navigation
class MobileDashboardScreen extends StatefulWidget {
  const MobileDashboardScreen({super.key});

  @override
  State<MobileDashboardScreen> createState() => _MobileDashboardScreenState();
}

class _MobileDashboardScreenState extends State<MobileDashboardScreen> {
  int _selectedIndex = 0;
  String? _userRole;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _profilePictureUrl;
  bool _showOnboarding = false;
  bool _onboardingChecked = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final role = await UserRoleService.getCurrentUserRole();
      final data = await UserRoleService.getCurrentUserData();
      final profilePicUrl = await ProfilePictureService.getProfilePictureUrl();
      
      // Check if student needs onboarding
      bool needsOnboarding = false;
      if (role?.toLowerCase() == 'student' && !_onboardingChecked) {
        needsOnboarding = !(await OnboardingService.hasCompletedOnboarding());
        _onboardingChecked = true;
      }
      
      if (mounted) {
        setState(() {
          _userRole = role;
          _userData = data;
          _profilePictureUrl = profilePicUrl;
          _isLoading = false;
          _showOnboarding = needsOnboarding;
        });
        
        // Start feature tour after a delay if student has completed onboarding
        // but hasn't done the feature tour yet
        if (role?.toLowerCase() == 'student' && !needsOnboarding) {
          _checkAndStartFeatureTour();
        }
      }
    } catch (e) {
      AppLogger.error('Error loading user data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkAndStartFeatureTour() async {
    final hasCompletedTour = await OnboardingService.hasCompletedFeatureTour();
    if (!hasCompletedTour && mounted) {
      // Wait for UI to be fully built
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        // Assign keys to the tour
        studentFeatureTour.profileButtonKey.currentState;
        studentFeatureTour.startTour(context);
      }
    }
  }

  void _startFeatureTour() async {
    await OnboardingService.resetFeatureTour();
    if (mounted) {
      studentFeatureTour.startTour(context, isReplay: true);
    }
  }

  Future<void> _refreshProfilePicture() async {
    final profilePicUrl = await ProfilePictureService.getProfilePictureUrl();
    if (mounted) {
      setState(() {
        _profilePictureUrl = profilePicUrl;
      });
    }
  }

  void _showProfileMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Profile Info Section
              Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _profilePictureUrl == null
                          ? Theme.of(context).primaryColor.withOpacity(0.1)
                          : Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: _profilePictureUrl != null 
                          ? Border.all(color: Theme.of(context).dividerColor, width: 2)
                          : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: _profilePictureUrl != null
                          ? Image.network(
                              _profilePictureUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.person,
                                  color: Theme.of(context).primaryColor,
                                  size: 40,
                                );
                              },
                            )
                          : Icon(
                              Icons.person,
                              color: Theme.of(context).primaryColor,
                              size: 40,
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_userData?['name'] != null)
                    Text(
                      _userData!['name'],
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).textTheme.titleLarge?.color,
                      ),
                    ),
                  const SizedBox(height: 4),
                  if (_userData?['email'] != null)
                    Text(
                      _userData!['email'],
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  if (_userRole != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _userRole!.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).primaryColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              
              // Menu Options
              // View Profile option
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    color: Theme.of(context).primaryColor,
                    size: 20,
                  ),
                ),
                title: Text(
                  'View Profile',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).textTheme.titleMedium?.color,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).iconTheme.color,
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TeacherProfileScreen(),
                    ),
                  );
                },
              ),
              
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.settings_rounded,
                    color: Theme.of(context).primaryColor,
                    size: 20,
                  ),
                ),
                title: Text(
                  'Settings',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).textTheme.titleMedium?.color,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).iconTheme.color,
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MobileSettingsScreen(),
                    ),
                  );
                  // Refresh profile picture after returning from settings
                  _refreshProfilePicture();
                },
              ),
              
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).iconTheme.color?.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.help_rounded,
                    color: Theme.of(context).iconTheme.color,
                    size: 20,
                  ),
                ),
                title: Text(
                  'Help & Support',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).textTheme.titleMedium?.color,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).iconTheme.color,
                ),
                onTap: () {
                  Navigator.pop(context);
                  // Navigate to help
                },
              ),
              
              // App Tour option for students
              if (_userRole?.toLowerCase() == 'student')
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E72ED).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.tour_rounded,
                      color: Color(0xFF0E72ED),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Take App Tour',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).textTheme.titleMedium?.color,
                    ),
                  ),
                  subtitle: Text(
                    'Learn how to use the app',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Color(0xFF0E72ED),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _startFeatureTour();
                  },
                ),
              
              const Divider(height: 1),
              
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xffEF4444).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Color(0xffEF4444),
                    size: 20,
                  ),
                ),
                title: Text(
                  'Sign Out',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xffEF4444),
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Color(0xffEF4444),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _handleSignOut();
                },
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Build screens based on user role
  List<Widget> get _screens {
    final role = _userRole?.toLowerCase();

    // ONLY Teachers get time clock, shifts, forms, job board
    if (role == 'teacher') {
      return [
        const TeacherHomeScreen(), // Use the new screen
        const TeacherShiftScreen(),
        const ChatPage(),
        const TeacherFormsScreen(), // Replaced ZoomScreen with Forms
        const TeacherJobBoardScreen(),
      ];
    }

    // Admins get additional admin features
    if (role == 'admin') {
      return [
        const AdminDashboard(refreshTrigger: 0),
        const AdminClassesScreen(), // All classes view for admins
        const FormScreen(),
        const MobileNotificationScreen(),
        const MobileUserManagementScreen(),
        const ChatPage(),
        const QuickTasksScreen(),
      ];
    }

    // Students get classes as their main screen
    if (role == 'student') {
      return [
        const StudentClassesScreen(), // Main screen for students
        const ChatPage(),
        const QuickTasksScreen(),
      ];
    }

    // Parents get basic features
    return [
      const AdminDashboard(refreshTrigger: 0),
      const ChatPage(),
      const QuickTasksScreen(),
    ];
  }
  
  // Get navigation items based on role
  List<_NavItemData> get _navItems {
    final role = _userRole?.toLowerCase();

    // ONLY Teachers get Clock, Shifts, Forms, and Job Board tabs
    if (role == 'teacher') {
      return [
        _NavItemData(Icons.home_rounded, 'Home', 0),
        _NavItemData(Icons.calendar_today_rounded, 'Shifts', 1),
        _NavItemData(Icons.chat_bubble_rounded, 'Chat', 2),
        _NavItemData(Icons.description_rounded, 'Forms', 3),
        _NavItemData(Icons.work_outline_rounded, 'Jobs', 4),
      ];
    }

    // Admins get admin features
    if (role == 'admin') {
      return [
        _NavItemData(Icons.home_rounded, 'Home', 0),
        _NavItemData(Icons.school_rounded, 'Classes', 1), // All classes view
        _NavItemData(Icons.description_rounded, 'Forms', 2),
        _NavItemData(Icons.notifications_rounded, 'Notify', 3),
        _NavItemData(Icons.people_rounded, 'Users', 4),
        _NavItemData(Icons.chat_bubble_rounded, 'Chat', 5),
        _NavItemData(Icons.task_alt_rounded, 'Tasks', 6),
      ];
    }

    // Students get classes-focused navigation
    if (role == 'student') {
      return [
        _NavItemData(Icons.school_rounded, 'Classes', 0),
        _NavItemData(Icons.chat_bubble_rounded, 'Chat', 1),
        _NavItemData(Icons.task_alt_rounded, 'Tasks', 2),
      ];
    }

    // Parents get basic features
    return [
      _NavItemData(Icons.home_rounded, 'Home', 0),
      _NavItemData(Icons.chat_bubble_rounded, 'Chat', 1),
      _NavItemData(Icons.task_alt_rounded, 'Tasks', 2),
    ];
  }

  void _onItemTapped(int index) {
    if (mounted) {
      setState(() => _selectedIndex = index);
    }
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Sign Out',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          content: Text(
            'Are you sure you want to sign out?',
            style: GoogleFonts.inter(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: const Color(0xff6B7280),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xffEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Sign Out',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        // Navigate to root and clear all routes - AuthenticationWrapper will show login
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/Alluwal_Education_Hub_Logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xff0386FF)),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading...',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: const Color(0xff6B7280),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show onboarding for new students
    if (_showOnboarding && _userRole?.toLowerCase() == 'student') {
      return StudentWelcomeScreen(
        onComplete: () {
          setState(() {
            _showOnboarding = false;
          });
          // Start feature tour after onboarding
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              studentFeatureTour.startTour(context);
            }
          });
        },
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // Hide AppBar for Teachers (new home screen has its own header)
      appBar: (_userRole?.toLowerCase() == 'teacher' && _selectedIndex == 0) ? null : AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).cardColor,
        toolbarHeight: 70,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xffF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/Alluwal_Education_Hub_Logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Alluwal Academy',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).textTheme.titleLarge?.color,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  if (_userData?['name'] != null)
                    Text(
                      _userData!['name'],
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Profile Picture Button - Navigate directly to TeacherProfileScreen for consistency
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              key: _userRole?.toLowerCase() == 'student' 
                  ? studentFeatureTour.profileButtonKey 
                  : null,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TeacherProfileScreen(),
                  ),
                );
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _profilePictureUrl == null 
                      ? Theme.of(context).primaryColor.withOpacity(0.1)
                      : Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(10),
                  border: _profilePictureUrl != null 
                      ? Border.all(color: Theme.of(context).dividerColor, width: 1.5)
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _profilePictureUrl != null
                      ? Image.network(
                          _profilePictureUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.person,
                              color: Theme.of(context).primaryColor,
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
                                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                                ),
                              ),
                            );
                          },
                        )
                      : Icon(
                          Icons.person,
                          color: Theme.of(context).primaryColor,
                          size: 24,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _navItems.map((item) {
                // Assign GlobalKeys for student feature tour
                GlobalKey? itemKey;
                if (_userRole?.toLowerCase() == 'student') {
                  if (item.index == 0) {
                    itemKey = studentFeatureTour.classesTabKey;
                  } else if (item.index == 1) {
                    itemKey = studentFeatureTour.chatTabKey;
                  } else if (item.index == 2) {
                    itemKey = studentFeatureTour.tasksTabKey;
                  }
                }
                return _buildNavItem(item.icon, item.label, item.index, key: itemKey);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, {GlobalKey? key}) {
    final isSelected = _selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Expanded(
      key: key,
      child: GestureDetector(
        onTap: () => _onItemTapped(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).primaryColor.withOpacity(isDark ? 0.2 : 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).iconTheme.color,
                size: 26,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Theme.of(context).iconTheme.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

