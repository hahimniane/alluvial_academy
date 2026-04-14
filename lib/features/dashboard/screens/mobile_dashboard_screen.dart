import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/user_role_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../chat/screens/chat_page.dart';
import '../../chat/services/chat_service.dart';
import '../../chat/models/chat_user.dart';
import './admin_dashboard_screen.dart';
import '../../tasks/screens/quick_tasks_screen.dart';
import '../../shift_management/screens/teacher_shift_screen.dart';
import '../../forms/screens/teacher_forms_screen.dart';
import 'package:alluwalacademyadmin/features/profile/services/profile_picture_service.dart';
import '../../settings/screens/mobile_settings_screen.dart';
import '../../notifications/screens/mobile_notification_screen.dart';
import '../../user_management/screens/mobile_user_management_screen.dart';
import './teacher_home_screen.dart'; // Import the new TeacherHomeScreen
// import './teacher_mobile_home.dart'; // Remove the old one
import './teacher_job_board_screen.dart';
import '../../profile/screens/teacher_profile_screen.dart';
import '../../student/screens/student_classes_screen.dart'; // Student classes screen
import '../../student/screens/student_progress_screen.dart'; // Student progress screen
import '../../shift_management/screens/admin_classes_screen.dart'; // Admin classes screen
import '../../recordings/screens/class_recordings_screen.dart';
import '../../surah_podcast/screens/surah_podcast_screen.dart';
import '../../quiz/screens/quiz_home_screen.dart'; // Quiz feature
import '../../tutor/screens/ai_tutor_screen.dart'; // AI Tutor feature
import '../../curriculum/screens/curriculum_books_screen.dart';
import '../../tontine/screens/tontine_home_screen.dart';
import '../../tontine/screens/circle_member_profile_setup_screen.dart';

// Onboarding imports
import 'package:alluwalacademyadmin/features/onboarding/services/onboarding_service.dart';
import '../../onboarding/screens/student_welcome_screen.dart';
import '../../onboarding/services/student_feature_tour.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

/// Navigation item data
class _NavItemData {
  final IconData icon;
  final String label;
  final int index;
  final bool isChat;

  _NavItemData(this.icon, this.label, this.index, {this.isChat = false});
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
  bool _aiTutorEnabled = false;
  bool _tontineEnabled = false;
  bool _showCircleMemberProfileSetup = false;
  final ChatService _chatService = ChatService();
  StreamSubscription<DocumentSnapshot>? _userDocSubscription;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _userDocSubscription?.cancel();
    super.dispose();
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

      // Check if circle_member needs profile setup (first_name empty)
      bool needsCircleProfileSetup = false;
      if (role?.toLowerCase() == 'circle_member') {
        final firstName = (data?['first_name'] as String? ?? '').trim();
        final profileDone = data?['profile_completed'] as bool? ?? false;
        needsCircleProfileSetup = firstName.isEmpty && !profileDone;
      }

      if (mounted) {
        setState(() {
          _userRole = role;
          _userData = data;
          _profilePictureUrl = profilePicUrl;
          _isLoading = false;
          _showOnboarding = needsOnboarding;
          _showCircleMemberProfileSetup = needsCircleProfileSetup;
          _aiTutorEnabled = data?['ai_tutor_enabled'] as bool? ?? false;
          _tontineEnabled = data?['tontine_enabled'] as bool? ?? false;
        });

        // Set up real-time listener for AI Tutor access changes
        _setupAITutorListener();

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

  /// Set up real-time listener for AI Tutor access changes
  void _setupAITutorListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Cancel existing subscription if any
    _userDocSubscription?.cancel();

    // Listen to user document changes
    _userDocSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      if (snapshot.exists) {
        final data = snapshot.data();
        final newAiTutorEnabled = data?['ai_tutor_enabled'] as bool? ?? false;
        final newTontineEnabled = data?['tontine_enabled'] as bool? ?? false;
        if (newAiTutorEnabled != _aiTutorEnabled ||
            newTontineEnabled != _tontineEnabled) {
          setState(() {
            _aiTutorEnabled = newAiTutorEnabled;
            _tontineEnabled = newTontineEnabled;
          });
        }
      }
    }, onError: (e) {
      AppLogger.error('Error listening to AI Tutor changes: $e');
    });
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
                          ? Border.all(
                              color: Theme.of(context).dividerColor, width: 2)
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
                  AppLocalizations.of(context)!.settingsViewProfile,
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
                  if (_userRole?.toLowerCase() == 'circle_member') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CircleMemberProfileSetupScreen(
                          isEditing: true,
                          onComplete: () {
                            Navigator.pop(context);
                            _loadUserData();
                          },
                        ),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TeacherProfileScreen(),
                      ),
                    );
                  }
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
                  AppLocalizations.of(context)!.settingsTitle,
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
                  AppLocalizations.of(context)!.settingsHelpSupport,
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
                    AppLocalizations.of(context)!.settingsTakeAppTour,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).textTheme.titleMedium?.color,
                    ),
                  ),
                  subtitle: Text(
                    AppLocalizations.of(context)!.settingsLearnApp,
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
                  AppLocalizations.of(context)!.settingsSignOut,
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

    if (role == 'circle_member') {
      return [
        const TontineHomeScreen(),
      ];
    }

    if (role == 'teacher') {
      return [
        const TeacherHomeScreen(),
        const TeacherShiftScreen(),
        const ChatPage(),
        const TeacherFormsScreen(),
        const TeacherJobBoardScreen(),
        const CurriculumBooksScreen(),
        if (_tontineEnabled) const TontineHomeScreen(),
      ];
    }

    if (role == 'admin') {
      return [
        const AdminDashboard(refreshTrigger: 0),
        const ChatPage(),
        const AdminClassesScreen(),
        const QuickTasksScreen(),
        _AdminMoreScreen(onNavigate: _navigateToAdminFeature),
      ];
    }

    if (role == 'student') {
      return [
        const StudentClassesScreen(),
        const QuizHomeScreen(),
        const ChatPage(),
        const QuickTasksScreen(),
        const StudentProgressScreen(),
        const CurriculumBooksScreen(),
        if (_tontineEnabled) const TontineHomeScreen(),
      ];
    }

    // Parents get basic features
    return [
      const AdminDashboard(refreshTrigger: 0),
      const ChatPage(),
      const QuickTasksScreen(),
      const CurriculumBooksScreen(),
      if (_tontineEnabled) const TontineHomeScreen(),
    ];
  }

  // Get navigation items based on role
  List<_NavItemData> get _navItems {
    final l10n = AppLocalizations.of(context)!;
    final role = _userRole?.toLowerCase();

    if (role == 'circle_member') {
      return [
        _NavItemData(Icons.groups_rounded, l10n.tontineCircles, 0),
      ];
    }

    if (role == 'teacher') {
      final items = [
        _NavItemData(Icons.home_rounded, l10n.navHome, 0),
        _NavItemData(Icons.calendar_today_rounded, l10n.navShifts, 1),
        _NavItemData(Icons.chat_bubble_rounded, l10n.navChat, 2, isChat: true),
        _NavItemData(Icons.description_rounded, l10n.navForms, 3),
        _NavItemData(Icons.work_outline_rounded, l10n.navJobs, 4),
        _NavItemData(Icons.menu_book_rounded, 'Books', 5),
      ];
      if (_tontineEnabled) {
        items.add(_NavItemData(Icons.groups_rounded, l10n.tontineCircles, 6));
      }
      return items;
    }

    if (role == 'admin') {
      return [
        _NavItemData(Icons.home_rounded, l10n.navHome, 0),
        _NavItemData(Icons.chat_bubble_rounded, l10n.navChat, 1, isChat: true),
        _NavItemData(Icons.school_rounded, l10n.navClasses, 2),
        _NavItemData(Icons.task_alt_rounded, l10n.navTasks, 3),
        _NavItemData(Icons.grid_view_rounded, 'More', 4),
      ];
    }

    if (role == 'student') {
      final items = [
        _NavItemData(Icons.school_rounded, l10n.navClasses, 0),
        _NavItemData(Icons.quiz_rounded, l10n.navQuiz, 1),
        _NavItemData(Icons.chat_bubble_rounded, l10n.navChat, 2, isChat: true),
        _NavItemData(Icons.task_alt_rounded, l10n.navTasks, 3),
        _NavItemData(Icons.insights_rounded, l10n.progress, 4),
        _NavItemData(Icons.menu_book_rounded, 'Books', 5),
      ];
      if (_tontineEnabled) {
        items.add(_NavItemData(Icons.groups_rounded, l10n.tontineCircles, 6));
      }
      return items;
    }

    // Parents get basic features
    final items = [
      _NavItemData(Icons.home_rounded, l10n.navHome, 0),
      _NavItemData(Icons.chat_bubble_rounded, l10n.navChat, 1, isChat: true),
      _NavItemData(Icons.task_alt_rounded, l10n.navTasks, 2),
      _NavItemData(Icons.menu_book_rounded, 'Books', 3),
    ];
    if (_tontineEnabled) {
      items.add(_NavItemData(Icons.groups_rounded, l10n.tontineCircles, 4));
    }
    return items;
  }

  void _onItemTapped(int index) {
    if (mounted) {
      setState(() => _selectedIndex = index);
    }
  }

  /// Navigate to a full-screen admin feature from the "More" grid.
  void _navigateToAdminFeature(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
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
            AppLocalizations.of(context)!.settingsSignOut,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          content: Text(
            AppLocalizations.of(context)!.settingsSignOutConfirm,
            style: GoogleFonts.inter(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                AppLocalizations.of(context)!.commonCancel,
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
                AppLocalizations.of(context)!.settingsSignOut,
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
                AppLocalizations.of(context)!.commonLoading,
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

    final isCircleMember = _userRole?.toLowerCase() == 'circle_member';

    if (isCircleMember && _showCircleMemberProfileSetup) {
      return CircleMemberProfileSetupScreen(
        onComplete: () {
          setState(() {
            _showCircleMemberProfileSetup = false;
          });
          _loadUserData();
        },
      );
    }

    if (isCircleMember) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
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
                child: Text(
                  'Alluwal',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: GestureDetector(
                onTap: _showProfileMenu,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.person,
                    color: Theme.of(context).primaryColor,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: const TontineHomeScreen(),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // Hide AppBar for Teachers (new home screen has its own header)
      appBar: (_userRole?.toLowerCase() == 'teacher' && _selectedIndex == 0)
          ? null
          : AppBar(
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
                          AppLocalizations.of(context)!.appTitle,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color:
                                Theme.of(context).textTheme.titleLarge?.color,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        if (_userData?['name'] != null)
                          Text(
                            _userData!['name'],
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color:
                                  Theme.of(context).textTheme.bodyMedium?.color,
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
                // Profile Picture Button - Opens profile menu with settings, logout, etc.
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: GestureDetector(
                    key: _userRole?.toLowerCase() == 'student'
                        ? studentFeatureTour.profileButtonKey
                        : null,
                    onTap: _showProfileMenu,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _profilePictureUrl == null
                            ? Theme.of(context).primaryColor.withOpacity(0.1)
                            : Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(10),
                        border: _profilePictureUrl != null
                            ? Border.all(
                                color: Theme.of(context).dividerColor,
                                width: 1.5)
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
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Theme.of(context).primaryColor),
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
      // AI Tutor FAB for students and teachers (only if enabled by admin)
      floatingActionButton: (_aiTutorEnabled &&
              (_userRole?.toLowerCase() == 'student' ||
                  _userRole?.toLowerCase().contains('teacher') == true))
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AITutorScreen(),
                  ),
                );
              },
              backgroundColor: const Color(0xFF0E72ED),
              icon: const Icon(Icons.smart_toy_rounded, color: Colors.white),
              label: Text(
                AppLocalizations.of(context)!.navTutor,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    final navItems = _navItems;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0xE61E293B),
                        const Color(0xD90F172A),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.94),
                        const Color(0xFFF7FBFF).withValues(alpha: 0.92),
                      ],
              ),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.72),
              ),
              boxShadow: [
                BoxShadow(
                  color: (isDark ? Colors.black : const Color(0xFF0F172A))
                      .withValues(alpha: isDark ? 0.34 : 0.10),
                  blurRadius: 30,
                  spreadRadius: -10,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
              child: Row(
                children: navItems.map((item) {
                  // Assign GlobalKeys for student feature tour
                  GlobalKey? itemKey;
                  if (_userRole?.toLowerCase() == 'student') {
                    if (item.index == 0) {
                      itemKey = studentFeatureTour.classesTabKey;
                    } else if (item.index == 2) {
                      itemKey = studentFeatureTour.chatTabKey;
                    } else if (item.index == 3) {
                      itemKey = studentFeatureTour.tasksTabKey;
                    }
                  }

                  return _buildNavItem(item, key: itemKey);
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(_NavItemData item, {GlobalKey? key}) {
    final icon = item.icon;
    final label = item.label;
    final index = item.index;
    final isSelected = _selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accent = Color(0xff0386FF);
    final inactiveColor =
        isDark ? const Color(0xff94A3B8) : const Color(0xff64748B);
    final selectedTextColor = accent;
    final iconWidget = Icon(
      icon,
      color: isSelected ? accent : inactiveColor,
      size: isSelected ? 22 : 21,
    );

    return Expanded(
      key: key,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          scale: isSelected ? 1.02 : 1,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _onItemTapped(index),
              borderRadius: BorderRadius.circular(22),
              splashColor: accent.withValues(alpha: 0.10),
              highlightColor: Colors.transparent,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.fromLTRB(6, isSelected ? 8 : 10, 6, 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      width: isSelected ? 42 : 34,
                      height: isSelected ? 34 : 32,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(17),
                        color: isSelected
                            ? accent.withValues(alpha: isDark ? 0.18 : 0.12)
                            : (isDark ? Colors.white : const Color(0xFF0F172A))
                                .withValues(alpha: isDark ? 0.05 : 0.04),
                        border: Border.all(
                          color: isSelected
                              ? accent.withValues(alpha: isDark ? 0.30 : 0.18)
                              : Colors.transparent,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: accent.withValues(
                                      alpha: isDark ? 0.16 : 0.10),
                                  blurRadius: 16,
                                  spreadRadius: -8,
                                  offset: const Offset(0, 8),
                                ),
                              ]
                            : const [],
                      ),
                      child: Center(
                        child: AnimatedSlide(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          offset: Offset(0, isSelected ? -0.03 : 0),
                          child: item.isChat
                              ? _buildChatBadgeIcon(iconWidget)
                              : iconWidget,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      style: GoogleFonts.inter(
                        fontSize: isSelected ? 11.2 : 10.2,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected ? selectedTextColor : inactiveColor,
                        letterSpacing: isSelected ? 0.15 : 0.05,
                      ),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.only(top: 4),
                      width: isSelected ? 18 : 0,
                      height: 3,
                      decoration: BoxDecoration(
                        color: isSelected ? accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatBadgeIcon(Widget icon) {
    return StreamBuilder<List<ChatUser>>(
      stream: _chatService.getUserChats(),
      builder: (context, snapshot) {
        final chats = snapshot.data ?? const [];
        int totalUnread = 0;
        for (final chat in chats) {
          totalUnread += chat.unreadCount;
        }
        if (totalUnread <= 0) {
          return icon;
        }

        final badgeText = totalUnread > 99 ? '99+' : totalUnread.toString();

        return Stack(
          clipBehavior: Clip.none,
          children: [
            icon,
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xff10B981),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The "More" grid screen shown in the admin bottom nav.
class _AdminMoreScreen extends StatelessWidget {
  final void Function(Widget screen) onNavigate;

  const _AdminMoreScreen({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final items = <_MoreItem>[
      _MoreItem(
        icon: Icons.description_rounded,
        label: l10n.navForms,
        color: const Color(0xff8B5CF6),
        screen: const TeacherFormsScreen(),
      ),
      _MoreItem(
        icon: Icons.notifications_rounded,
        label: l10n.navNotify,
        color: const Color(0xffF59E0B),
        screen: const MobileNotificationScreen(),
      ),
      _MoreItem(
        icon: Icons.people_rounded,
        label: l10n.navUsers,
        color: const Color(0xff0EA5E9),
        screen: const MobileUserManagementScreen(),
      ),
      _MoreItem(
        icon: Icons.menu_book_rounded,
        label: 'Books',
        color: const Color(0xff10B981),
        screen: const CurriculumBooksScreen(),
      ),
      _MoreItem(
        icon: Icons.groups_rounded,
        label: l10n.tontineCircles,
        color: const Color(0xffEC4899),
        screen: const TontineHomeScreen(),
      ),
      _MoreItem(
        icon: Icons.video_library_rounded,
        label: 'Recordings',
        color: const Color(0xffEF4444),
        screen: const ClassRecordingsScreen(),
      ),
      _MoreItem(
        icon: Icons.podcasts_rounded,
        label: 'Podcasts',
        color: const Color(0xff6366F1),
        screen: const SurahPodcastScreen(),
      ),
      _MoreItem(
        icon: Icons.settings_rounded,
        label: l10n.settingsTitle,
        color: const Color(0xff64748B),
        screen: const MobileSettingsScreen(),
      ),
    ];

    return Container(
      color: isDark
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xffF8FAFC),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'More',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Additional tools and features',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? const Color(0xff94A3B8)
                      : const Color(0xff64748B),
                ),
              ),
              const SizedBox(height: 24),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.95,
                ),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _MoreTile(
                    item: item,
                    isDark: isDark,
                    onTap: () => onNavigate(item.screen),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreItem {
  final IconData icon;
  final String label;
  final Color color;
  final Widget screen;

  const _MoreItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.screen,
  });
}

class _MoreTile extends StatelessWidget {
  final _MoreItem item;
  final bool isDark;
  final VoidCallback onTap;

  const _MoreTile({
    required this.item,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? const Color(0xff1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xff334155) : const Color(0xffE2E8F0),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  item.icon,
                  color: item.color,
                  size: 26,
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  item.label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
