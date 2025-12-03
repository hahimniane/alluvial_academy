import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/user_role_service.dart';
import '../../../core/services/profile_picture_service.dart';
import '../widgets/teacher_profile_edit_dialog.dart';
import '../../settings/screens/mobile_settings_screen.dart';

class TeacherProfileScreen extends StatefulWidget {
  const TeacherProfileScreen({super.key});

  @override
  State<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen> {
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _teacherProfileData; // Data from 'teacher_profiles' collection
  String? _profilePicUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final data = await UserRoleService.getCurrentUserData();
    final pic = await ProfilePictureService.getProfilePictureUrl();
    
    // Fetch additional teacher profile data
    final teacherProfileDoc = await FirebaseFirestore.instance
        .collection('teacher_profiles')
        .doc(user.uid)
        .get();
    final teacherProfileData = teacherProfileDoc.data();

    if (mounted) {
      setState(() {
        _userData = data;
        _teacherProfileData = teacherProfileData;
        _profilePicUrl = pic;
        _isLoading = false;
      });
    }
  }

  void _showEditProfileDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return TeacherProfileEditDialog(
          onProfileUpdated: _loadData, // Refresh data after edit
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : CustomScrollView(
            slivers: [
              _buildSliverAppBar(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildStatsRow(),
                      const SizedBox(height: 24),
                      _buildProfileDetails(), // New section for detailed profile info
                      const SizedBox(height: 24),
                      _buildMenuSection(),
                      const SizedBox(height: 24),
                      _buildLogoutButton(),
                    ],
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: const Color(0xFF0386FF),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0386FF), Color(0xFF2563EB)],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  image: _profilePicUrl != null 
                    ? DecorationImage(image: NetworkImage(_profilePicUrl!), fit: BoxFit.cover)
                    : null,
                ),
                child: _profilePicUrl == null 
                  ? const Icon(Icons.person, size: 40, color: Color(0xFFCBD5E1)) 
                  : null,
              ),
              const SizedBox(height: 12),
              Text(
                _teacherProfileData?['full_name'] ?? "${_userData?['first_name'] ?? "Teacher"} ${_userData?['last_name'] ?? ""}",
                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              Text(
                _userData?['email'] ?? "",
                style: GoogleFonts.inter(fontSize: 14, color: Colors.white.withOpacity(0.8)),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _showEditProfileDialog,
                icon: const Icon(Icons.edit, size: 18),
                label: Text('Edit Profile', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatCard("Total Hours", "124.5", Icons.access_time),
        const SizedBox(width: 12),
        _buildStatCard("Classes", "48", Icons.school),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF3B82F6), size: 20),
            const SizedBox(height: 8),
            Text(value, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
            Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileDetails() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About Me',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          _detailRow(Icons.work_outline, 'Professional Title', _teacherProfileData?['professional_title']),
          _detailRow(Icons.description_outlined, 'Biography', _teacherProfileData?['biography']),
          _detailRow(Icons.timeline_outlined, 'Years of Experience', _teacherProfileData?['years_of_experience']),
          _detailRow(Icons.star_outline, 'Specialties', _teacherProfileData?['specialties']),
          _detailRow(Icons.school_outlined, 'Education & Certifications', _teacherProfileData?['education_certifications']),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF64748B)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          _buildMenuItem(
            Icons.settings_outlined, 
            "Settings", 
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MobileSettingsScreen(),
                ),
              );
            },
          ),
          const Divider(height: 1, indent: 56),
          _buildMenuItem(
            Icons.help_outline, 
            "Help & Support", 
            () {
              _showHelpDialog();
            },
          ),
          const Divider(height: 1, indent: 56),
          _buildMenuItem(
            Icons.privacy_tip_outlined, 
            "Privacy Policy", 
            () {
              _showPrivacyPolicy();
            },
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Help & Support',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Need help? Contact us:',
              style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            _helpItem(Icons.email_outlined, 'Email', 'support@alluwalacademy.com'),
            const SizedBox(height: 12),
            _helpItem(Icons.phone_outlined, 'Phone', '+1 (555) 123-4567'),
            const SizedBox(height: 12),
            _helpItem(Icons.chat_bubble_outline, 'Live Chat', 'Available 9 AM - 5 PM'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );
  }

  Widget _helpItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF64748B)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF94A3B8),
                ),
              ),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Privacy Policy',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: Text(
            'Your privacy is important to us. This Privacy Policy explains how we collect, use, and protect your personal information.\n\n'
            '• We collect information you provide directly to us\n'
            '• We use your information to provide and improve our services\n'
            '• We do not sell your personal information to third parties\n'
            '• You can update or delete your information at any time\n\n'
            'For more details, please visit our website or contact support.',
            style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 20, color: const Color(0xFF475569)),
      ),
      title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, size: 20, color: Color(0xFFCBD5E1)),
      onTap: onTap,
    );
  }

  Widget _buildLogoutButton() {
    return TextButton(
      onPressed: () async {
        await FirebaseAuth.instance.signOut();
        // Navigation handled by stream in main
      },
      child: Text("Sign Out", style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontWeight: FontWeight.w600)),
    );
  }
}

