// ignore_for_file: library_private_types_in_public_api
import 'features/dashboard/screens/admin_dashboard_screen.dart';
import 'features/chat/screens/chat_page.dart';
import 'form_screen.dart';
import 'job_scheduling.dart';
import 'features/time_clock/screens/time_clock_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'core/services/user_role_service.dart';
import 'core/constants/app_constants.dart';
import 'features/user_management/screens/user_management_screen.dart';
import 'admin/form_builder.dart';
import 'test_role_system.dart';

/// Constants for the Dashboard
class DashboardConstants {
  // Dimensions
  static const double sideMenuWidth = 250.0;
  static const double logoHoverHeight = 180.0;
  static const double logoNormalHeight = 160.0;
  static const double searchBarWidth = 200.0;
  static const double searchBarHeight = 40.0;

  // Durations
  static const Duration hoverAnimationDuration = Duration(milliseconds: 200);

  // Colors
  static const chatIconColor = Color(0xff2ED9B9);
  static const timeClockIconColor = Color(0xff3786F9);
  static const formsIconColor = Color(0xffBA39A9);
  static const jobSchedulingIconColor = Color(0xffFF9A6C);
}

/// Main Dashboard widget that serves as the app's primary navigation interface
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // State variables
  bool _isHovered = false;
  int _selectedIndex = 0;
  String? _userRole;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final role = await UserRoleService.getCurrentUserRole();
      final data = await UserRoleService.getCurrentUserData();
      if (mounted) {
        setState(() {
          _userRole = role;
          _userData = data;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  // List of screens available in the dashboard
  final List<Widget> _screens = [
    const AdminDashboard(),
    const UserManagementScreen(),
    const ChatScreen(),
    const TimeClockScreen(),
    const FormScreen(),
    const FormBuilder(),
    const TasksScreen(),
    const TimeOffScreen(),
    const TestRoleSystemScreen(), // Test screen for role system
  ];

  /// Updates the selected index when a navigation item is tapped
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  /// Handles user sign out
  Future<void> _handleSignOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      // Navigation will be handled automatically by the AuthenticationWrapper
      // in main.dart which listens to auth state changes
    } catch (e) {
      // Show error dialog if sign out fails
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to sign out: ${e.toString()}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  /// Builds the main body of the dashboard
  Widget _buildBody() {
    return Row(
      children: [
        _buildSideMenu(),
        Expanded(
          child: IndexedStack(
            index: _selectedIndex,
            children: _screens,
          ),
        ),
      ],
    );
  }

  /// Builds the app bar with logo, search, and user profile
  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            _buildLogoAndSearch(),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  /// Builds the logo and search section of the app bar
  Row _buildLogoAndSearch() {
    return Row(
      children: [
        _buildAnimatedLogo(),
        const SizedBox(width: 10),
        _buildSearchBar(),
      ],
    );
  }

  /// Builds the animated logo with hover effect
  Widget _buildAnimatedLogo() {
    return GestureDetector(
      onTap: () => print('Logo clicked'),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: DashboardConstants.hoverAnimationDuration,
          child: Image.asset(
            'assets/logo_navigation_bar.PNG',
            height: _isHovered
                ? DashboardConstants.logoHoverHeight
                : DashboardConstants.logoNormalHeight,
          ),
        ),
      ),
    );
  }

  /// Builds the search bar with custom styling
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.only(bottom: 10),
      margin: const EdgeInsets.only(bottom: 10, top: 20),
      width: DashboardConstants.searchBarWidth,
      height: DashboardConstants.searchBarHeight,
      child: TextField(
        decoration: InputDecoration(
          hintStyle: GoogleFonts.openSans(
            textStyle: const TextStyle(
              fontWeight: FontWeight.w400,
              fontSize: 14,
              color: Color.fromARGB(255, 63, 70, 72),
            ),
          ),
          hintText: 'Search anything',
          suffixIcon: Icon(Icons.search, color: Colors.grey.shade300),
          border: _buildSearchBarBorder(),
          enabledBorder: _buildSearchBarBorder(color: Colors.green),
          focusedBorder: _buildSearchBarBorder(color: Colors.green),
        ),
      ),
    );
  }

  /// Helper method to build consistent search bar borders
  OutlineInputBorder _buildSearchBarBorder({Color color = Colors.grey}) {
    return OutlineInputBorder(
      borderSide: BorderSide(width: 0.4, color: color),
      borderRadius: BorderRadius.circular(10.0),
    );
  }

  /// Builds the actions section of the app bar (notifications and profile)
  Row _buildActions() {
    return Row(
      children: [
        _buildNotificationIcon(),
        const SizedBox(width: 20),
        _buildUserProfile(),
      ],
    );
  }

  /// Builds the user profile section
  Widget _buildUserProfile() {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'logout') {
          _handleSignOut();
        }
      },
      itemBuilder: (BuildContext context) {
        return [
          PopupMenuItem<String>(
            value: 'logout',
            child: Row(
              children: [
                const Icon(Icons.logout, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  'Sign Out',
                  style: openSansHebrewTextStyle.copyWith(color: Colors.red),
                ),
              ],
            ),
          ),
        ];
      },
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _getUserName(),
                style: openSansHebrewTextStyle.copyWith(
                  color: Colors.blueAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_userRole != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getRoleColor(),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _userRole!.toUpperCase(),
                    style: openSansHebrewTextStyle.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            backgroundColor: Colors.teal,
            child: Text(
              _getInitials(),
              style: openSansHebrewTextStyle.copyWith(color: Colors.white),
            ),
          ),
          const Icon(Icons.arrow_drop_down, color: Colors.blueAccent),
        ],
      ),
    );
  }

  /// Get user initials for avatar
  String _getInitials() {
    if (_userData != null) {
      final firstName = _userData!['first_name'] ?? '';
      final lastName = _userData!['last_name'] ?? '';
      if (firstName.isNotEmpty && lastName.isNotEmpty) {
        return '${firstName[0]}${lastName[0]}'.toUpperCase();
      }
    }
    return 'U'; // Default fallback
  }

  /// Get user's full name
  String _getUserName() {
    if (_userData != null) {
      final firstName = _userData!['first_name'] ?? '';
      final lastName = _userData!['last_name'] ?? '';
      if (firstName.isNotEmpty || lastName.isNotEmpty) {
        return '$firstName $lastName'.trim();
      }
    }
    return 'User';
  }

  /// Get role-specific color
  Color _getRoleColor() {
    switch (_userRole?.toLowerCase()) {
      case 'admin':
        return Colors.red;
      case 'teacher':
        return Colors.blue;
      case 'student':
        return Colors.green;
      case 'parent':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  /// Builds the notification icon with badge
  Stack _buildNotificationIcon() {
    return Stack(
      children: <Widget>[
        const Icon(Icons.notifications, color: Colors.grey),
        Positioned(
          right: 0,
          child: _buildNotificationBadge(),
        ),
      ],
    );
  }

  /// Builds the notification badge with count
  Widget _buildNotificationBadge() {
    return Container(
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(6),
      ),
      constraints: const BoxConstraints(
        minWidth: 12,
        minHeight: 12,
      ),
      child: Text(
        '1',
        style:
            openSansHebrewTextStyle.copyWith(fontSize: 10, color: Colors.white),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Builds the side navigation menu
  Container _buildSideMenu() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(width: 0.5, color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 5,
            blurRadius: 7,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      width: DashboardConstants.sideMenuWidth,
      child: ListView(
        children: _buildNavigationItems(),
      ),
    );
  }

  /// Builds the list of navigation items based on user role
  List<Widget> _buildNavigationItems() {
    final availableFeatures = UserRoleService.getAvailableFeatures(_userRole);
    List<Widget> items = [];

    // Dashboard is available to all users
    items.add(_buildCustomListTile(
      "assets/dashboard.svg",
      "Dashboard",
      0,
      Colors.white,
    ));

    // Admin-only features
    if (availableFeatures.contains('user_management')) {
      items.add(_buildCustomListTile(
        'assets/users-sidebar.svg',
        'admin/Users',
        1,
        Colors.white,
      ));
    }

    items.add(const Divider());

    // Chat (available to most roles)
    if (availableFeatures.contains('chat')) {
      items.add(_buildCustomListTile(
        'assets/Icon_chat.png',
        'Chat',
        2,
        DashboardConstants.chatIconColor,
      ));
    }

    // Time Clock (teachers and admins)
    if (availableFeatures.contains('time_clock')) {
      items.add(_buildCustomListTile(
        'assets/Icon_punch_clock.png',
        'Time Clock',
        3,
        DashboardConstants.timeClockIconColor,
      ));
    }

    // Forms (available to most roles)
    if (availableFeatures.contains('forms')) {
      items.add(_buildCustomListTile(
        'assets/Icon_forms.png',
        'Forms',
        4,
        DashboardConstants.formsIconColor,
      ));
    }

    // Form Builder (admin only)
    if (availableFeatures.contains('form_builder')) {
      items.add(_buildCustomListTile(
        'assets/Icon_Scheduler.png',
        'admin/Manage Forms',
        5,
        DashboardConstants.jobSchedulingIconColor,
      ));
    }

    // Tasks (not available to parents)
    if (availableFeatures.contains('tasks')) {
      items.add(_buildCustomListTile(
        'assets/Icon_task_manage.png',
        'Quick Tasks',
        6,
        DashboardConstants.jobSchedulingIconColor,
      ));
    }

    // Test Role System (temporary - admin only)
    if (_userRole?.toLowerCase() == 'admin') {
      items.add(_buildCustomListTile(
        'assets/Icon_task_manage.png',
        'Test Role System',
        8, // Using index 8 for test screen
        Colors.purple,
      ));
    }

    return items;
  }

  /// Builds a custom list tile for navigation items
  ListTile _buildCustomListTile(
    String assetPath,
    String title,
    int index,
    Color color, {
    Widget? trailing,
  }) {
    return ListTile(
      leading: Container(
        height: 30,
        width: 30,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          color: color,
          border: Border.all(color: color),
        ),
        child: _loadImage(assetPath),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight:
              _selectedIndex == index ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: () => _onItemTapped(index),
      selected: _selectedIndex == index,
      trailing: trailing ??
          (_selectedIndex == index
              ? const Icon(Icons.arrow_right, color: Colors.blue)
              : null),
    );
  }

  /// Helper method to load different types of images (SVG or regular)
  Widget _loadImage(String assetPath) {
    if (assetPath.endsWith('.svg')) {
      return SvgPicture.asset(
        assetPath,
        height: 40,
        width: 40,
      );
    } else {
      return Image.asset(
        assetPath,
        color: Colors.white,
        height: 40,
        width: 40,
      );
    }
  }
}
