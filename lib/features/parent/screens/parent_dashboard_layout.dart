// ignore_for_file: library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/user_role_service.dart';
import '../../../form_screen.dart';
import '../../../screens/landing_page.dart';
import '../../dashboard/widgets/custom_sidebar.dart';
import 'parent_dashboard_screen.dart';
import 'parent_invoices_screen.dart';
import 'payment_history_screen.dart';
import 'parent_profile_screen.dart';

/// Parent Dashboard Layout with sidebar navigation
class ParentDashboardLayout extends StatefulWidget {
  const ParentDashboardLayout({super.key});

  @override
  State<ParentDashboardLayout> createState() => _ParentDashboardLayoutState();
}

class _ParentDashboardLayoutState extends State<ParentDashboardLayout> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isSideMenuCollapsed = false;
  int _selectedIndex = 0;
  String? _userRole;
  static const int _screenCount = 5; // Dashboard, Invoices, Payments, Forms, Profile

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadSidebarState();
  }

  Future<void> _loadUserData() async {
    try {
      final role = await UserRoleService.getCurrentUserRole();
      if (mounted) {
        setState(() {
          _userRole = role;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _loadSidebarState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isCollapsed = prefs.getBool('parent_sidebar_collapsed') ?? false;
      if (mounted) {
        setState(() {
          _isSideMenuCollapsed = isCollapsed;
        });
      }
    } catch (e) {
      print('Error loading sidebar state: $e');
    }
  }

  Future<void> _saveSidebarState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('parent_sidebar_collapsed', _isSideMenuCollapsed);
    } catch (e) {
      print('Error saving sidebar state: $e');
    }
  }

  Widget _buildScreenForIndex(int index) {
    final parentId = UserRoleService.getCurrentUserId() ?? FirebaseAuth.instance.currentUser?.uid;

    switch (index) {
      case 0:
        return ParentDashboardScreen(parentId: parentId);
      case 1:
        return ParentInvoicesScreen(parentId: parentId ?? '');
      case 2:
        return PaymentHistoryScreen(parentId: parentId ?? '');
      case 3:
        return const FormScreen();
      case 4:
        return const ParentProfileScreen();
      default:
        return const _AccessDeniedScreen();
    }
  }

  void _onItemTapped(int index) {
    if (index < 0 || index >= _screenCount) return;

    // Close drawer on compact layouts
    final isCompact = MediaQuery.of(context).size.width < 900;
    if (isCompact && _scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isCompactLayout = MediaQuery.of(context).size.width < 900;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(isCompact: isCompactLayout),
      drawer: isCompactLayout
          ? Drawer(
              child: SafeArea(
                child: _buildSideMenu(forceExpanded: true),
              ),
            )
          : null,
      body: _buildBody(isCompact: isCompactLayout),
    );
  }

  Widget _buildBody({required bool isCompact}) {
    final content = IndexedStack(
      index: _selectedIndex,
      children: List<Widget>.generate(_screenCount, (i) => _buildScreenForIndex(i)),
    );

    if (isCompact) {
      return content;
    }

    return Row(
      children: [
        _buildSideMenu(),
        Expanded(child: content),
      ],
    );
  }

  AppBar _buildAppBar({required bool isCompact}) {
    if (isCompact) {
      return AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Color(0xFF111827)),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          tooltip: 'Menu',
        ),
        title: _buildLogo(),
        actions: [
          _buildUserProfile(compact: true),
          const SizedBox(width: 16),
        ],
      );
    }

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            _buildLogo(),
            _buildUserProfile(compact: false),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return GestureDetector(
      onTap: () {
        setState(() => _selectedIndex = 0);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/Alluwal_Education_Hub_Logo.png',
            width: 40,
            height: 40,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 12),
          Text(
            'Alluwal Academy',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserProfile({required bool compact}) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: UserRoleService.getCurrentUserData(),
      builder: (context, snapshot) {
        final userData = snapshot.data;
        final firstName = (userData?['first_name'] ?? '').toString().trim();
        final lastName = (userData?['last_name'] ?? '').toString().trim();
        final displayName = '$firstName $lastName'.trim().isNotEmpty
            ? '$firstName $lastName'.trim()
            : 'Parent';

        return PopupMenuButton<String>(
          icon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: compact ? 32 : 40,
                height: compact ? 32 : 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, color: Color(0xFF1D4ED8), size: 20),
              ),
              if (!compact) ...[
                const SizedBox(width: 8),
                Text(
                  displayName,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF111827),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, color: Color(0xFF6B7280)),
            ],
          ),
          itemBuilder: (BuildContext context) => [
            PopupMenuItem<String>(
              value: 'profile',
              child: Row(
                children: [
                  const Icon(Icons.person, size: 20, color: Color(0xFF6B7280)),
                  const SizedBox(width: 12),
                  Text('Profile', style: GoogleFonts.inter()),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'signout',
              child: Row(
                children: [
                  const Icon(Icons.logout, size: 20, color: Color(0xFFDC2626)),
                  const SizedBox(width: 12),
                  Text('Sign Out', style: GoogleFonts.inter(color: const Color(0xFFDC2626))),
                ],
              ),
            ),
          ],
          onSelected: (String value) {
            if (value == 'profile') {
              setState(() => _selectedIndex = 4); // Profile screen index
            } else if (value == 'signout') {
              _handleSignOut();
            }
          },
        );
      },
    );
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sign Out', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: Text(
          'Are you sure you want to sign out?',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: GoogleFonts.inter()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: Text('Sign Out', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      UserRoleService.clearCache();
      // Navigate to root and remove all previous routes BEFORE signing out
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LandingPage()),
        (route) => false,
      );
      // Wait for navigation to complete
      await Future.delayed(const Duration(milliseconds: 100));
      // Now sign out from Firebase Auth
      await FirebaseAuth.instance.signOut();
    }
  }

  Widget _buildSideMenu({bool forceExpanded = false}) {
    return CustomSidebar(
      selectedIndex: _selectedIndex,
      onItemSelected: _onItemTapped,
      isCollapsed: forceExpanded ? false : _isSideMenuCollapsed,
      onToggleCollapse: () {
        if (forceExpanded) return;
        setState(() {
          _isSideMenuCollapsed = !_isSideMenuCollapsed;
        });
        _saveSidebarState();
      },
      userRole: _userRole,
    );
  }
}

class _AccessDeniedScreen extends StatelessWidget {
  const _AccessDeniedScreen();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFF8FAFC),
      child: Center(
        child: Text(
          'Access restricted',
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

