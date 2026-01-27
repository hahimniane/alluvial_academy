import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/user_role_service.dart';
import '../../../core/services/profile_picture_service.dart';
import '../../../core/services/theme_service.dart';
import '../../../core/services/onboarding_service.dart';
import '../../onboarding/services/student_feature_tour.dart';
import 'notification_preferences_screen.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

class MobileSettingsScreen extends StatefulWidget {
  const MobileSettingsScreen({super.key});

  @override
  State<MobileSettingsScreen> createState() => _MobileSettingsScreenState();
}

class _MobileSettingsScreenState extends State<MobileSettingsScreen> {
  Map<String, dynamic>? _userData;
  String? _profilePictureUrl;
  String? _userRole;
  bool _isLoading = true;
  bool _isUploadingPicture = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final data = await UserRoleService.getCurrentUserData();
      final profilePicUrl = await ProfilePictureService.getProfilePictureUrl();
      final role = await UserRoleService.getCurrentUserRole();
      if (mounted) {
        setState(() {
          _userData = data;
          _profilePictureUrl = profilePicUrl;
          _userRole = role;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('Error loading user data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  bool get _isStudent => _userRole == 'student';

  Future<void> _uploadProfilePicture(ImageSource source) async {
    setState(() => _isUploadingPicture = true);
    
    try {
      // Pick image
      final XFile? imageFile = await ProfilePictureService.pickImage(source: source);
      if (imageFile == null) {
        setState(() => _isUploadingPicture = false);
        return;
      }

      // Upload to Firebase
      final String? downloadUrl = await ProfilePictureService.uploadProfilePicture(imageFile);
      
      if (downloadUrl != null && mounted) {
        setState(() {
          _profilePictureUrl = downloadUrl;
          _isUploadingPicture = false;
        });
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Profile picture updated successfully!',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: const Color(0xff10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error uploading profile picture: $e');
      if (mounted) {
        setState(() => _isUploadingPicture = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to upload profile picture. Please try again.',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: const Color(0xffEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  Future<void> _removeProfilePicture() async {
    try {
      await ProfilePictureService.removeProfilePicture();
      if (mounted) {
        setState(() => _profilePictureUrl = null);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Profile picture removed successfully!',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: const Color(0xff10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error removing profile picture: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to remove profile picture. Please try again.',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: const Color(0xffEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  void _showProfilePictureOptions() {
    showModalBottomSheet(
      context: context,
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
              
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Change Profile Picture',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Options
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.photo_library,
                    color: Theme.of(context).primaryColor,
                    size: 20,
                  ),
                ),
                title: Text(
                  'Choose from Gallery',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).textTheme.titleMedium?.color,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _uploadProfilePicture(ImageSource.gallery);
                },
              ),
              
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xff10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Color(0xff10B981),
                    size: 20,
                  ),
                ),
                title: Text(
                  'Take a Photo',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).textTheme.titleMedium?.color,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _uploadProfilePicture(ImageSource.camera);
                },
              ),
              
              if (_profilePictureUrl != null)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xffEF4444).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.delete,
                      color: Color(0xffEF4444),
                      size: 20,
                    ),
                  ),
                title: Text(
                  'Remove Picture',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xffEF4444), // Keep red for destructive action
                  ),
                ),
                  onTap: () {
                    Navigator.pop(context);
                    _removeProfilePicture();
                  },
                ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelpDialog() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            Text(
              'Help & Support',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildHelpItem(
              icon: Icons.book_outlined,
              title: 'How to Join a Class',
              description: 'Tap on any upcoming class card and click "Join Class" when it\'s time.',
            ),
            _buildHelpItem(
              icon: Icons.notifications_outlined,
              title: 'Getting Notifications',
              description: 'Enable notifications in Settings to get reminders before your classes.',
            ),
            _buildHelpItem(
              icon: Icons.video_call_outlined,
              title: 'During Class',
              description: 'Use the mic and camera buttons to control your audio and video.',
            ),
            _buildHelpItem(
              icon: Icons.chat_outlined,
              title: 'Chat Feature',
              description: 'Send messages to your teacher using the Chat tab.',
            ),
            
            const SizedBox(height: 20),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _contactSupport,
                icon: const Icon(Icons.mail_outline),
                label: const Text('Contact Support'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff0386FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xff0386FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xff0386FF), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.titleMedium?.color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _startAppTour() async {
    HapticFeedback.lightImpact();
    Navigator.pop(context); // Close settings first
    await OnboardingService.resetFeatureTour();
    if (mounted) {
      // Navigate back to dashboard and start tour
      Navigator.of(context).popUntil((route) => route.isFirst);
      // Small delay to let the dashboard rebuild
      await Future.delayed(const Duration(milliseconds: 300));
      studentFeatureTour.startTour(context, isReplay: true);
    }
  }

  void _showAboutDialog() {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Image.asset(
              'assets/LOGO.png',
              width: 40,
              height: 40,
              errorBuilder: (_, __, ___) => Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xff0386FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.school, color: Color(0xff0386FF)),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alluwal Academy',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Version 1.0.0',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xff6B7280),
                  ),
                ),
              ],
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Alluwal Academy is a Quran education platform that connects students with qualified teachers for online Islamic learning.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xff4B5563),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '© 2024 Alluwal Education Hub',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xff9CA3AF),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Privacy Policy',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).textTheme.titleLarge?.color,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPrivacySection(
                        title: 'Information We Collect',
                        content: 'We collect information you provide directly, including your name, email, and profile information. We also collect data about your class attendance and learning progress.',
                      ),
                      _buildPrivacySection(
                        title: 'How We Use Your Information',
                        content: 'Your information is used to provide our educational services, send class notifications, and improve your learning experience. We never sell your personal data.',
                      ),
                      _buildPrivacySection(
                        title: 'Data Security',
                        content: 'We implement industry-standard security measures to protect your data. All communications are encrypted and we regularly audit our security practices.',
                      ),
                      _buildPrivacySection(
                        title: 'Children\'s Privacy',
                        content: 'We are committed to protecting children\'s privacy. Parent or guardian consent is required for users under 13, and we collect only necessary information.',
                      ),
                      _buildPrivacySection(
                        title: 'Your Rights',
                        content: 'You have the right to access, correct, or delete your personal information. Contact us at support@alluwaleducationhub.org for any privacy-related requests.',
                      ),
                      _buildPrivacySection(
                        title: 'Contact Us',
                        content: 'For privacy questions or concerns, email us at support@alluwaleducationhub.org or contact our support team through the app.',
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Last updated: January 2024',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xff9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacySection({required String title, required String content}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.titleMedium?.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xff4B5563),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _contactSupport() async {
    HapticFeedback.lightImpact();
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@alluwaleducationhub.org',
      query: 'subject=Support Request from ${_userData?['name'] ?? 'User'}',
    );
    
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Email: support@alluwaleducationhub.org',
                style: GoogleFonts.inter(),
              ),
              backgroundColor: const Color(0xff0386FF),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Copy',
                textColor: Colors.white,
                onPressed: () {
                  Clipboard.setData(const ClipboardData(text: 'support@alluwaleducationhub.org'));
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.error('Error launching email: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Theme.of(context).cardColor,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Theme.of(context).iconTheme.color),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Settings',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xff111827),
            ),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xff0386FF)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).cardColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xff111827),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16),
            
            // Profile Section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'PROFILE',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff6B7280),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Profile Picture
                  GestureDetector(
                    onTap: _showProfilePictureOptions,
                    child: Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: _profilePictureUrl == null 
                                ? const Color(0xff0386FF).withOpacity(0.1)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(50),
                            border: _profilePictureUrl != null 
                                ? Border.all(color: const Color(0xffE5E7EB), width: 2)
                                : null,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(50),
                            child: _isUploadingPicture 
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xff0386FF)),
                                    ),
                                  )
                                : _profilePictureUrl != null
                                    ? Image.network(
                                        _profilePictureUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return const Icon(
                                            Icons.person,
                                            color: Color(0xff0386FF),
                                            size: 50,
                                          );
                                        },
                                      )
                                    : const Icon(
                                        Icons.person,
                                        color: Color(0xff0386FF),
                                        size: 50,
                                      ),
                          ),
                        ),
                        // Camera badge
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xff10B981),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  if (_userData?['name'] != null)
                    Text(
                      _userData!['name'],
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xff111827),
                      ),
                    ),
                  const SizedBox(height: 4),
                  if (_userData?['email'] != null)
                    Text(
                      _userData!['email'],
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xff6B7280),
                      ),
                    ),
                  const SizedBox(height: 12),
                  
                  TextButton.icon(
                    onPressed: _showProfilePictureOptions,
                    icon: const Icon(Icons.edit, size: 18),
                    label: Text(
                      'Change Profile Picture',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xff0386FF),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // App Settings Section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
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
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'APP SETTINGS',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xff6B7280),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  _buildSettingsTile(
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    subtitle: 'Manage notification preferences',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationPreferencesScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildSettingsTile(
                    icon: Icons.language_outlined,
                    title: 'Language',
                    subtitle: 'English',
                    onTap: () {
                      // Navigate to language settings
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildDarkModeToggle(),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Support Section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
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
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'SUPPORT',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xff6B7280),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  _buildSettingsTile(
                    icon: Icons.help_outline,
                    title: 'Help & Support',
                    subtitle: 'Get help using the app',
                    onTap: _showHelpDialog,
                  ),
                  const Divider(height: 1, indent: 56),
                  if (_isStudent) ...[
                    _buildSettingsTile(
                      icon: Icons.explore_outlined,
                      title: 'Take App Tour',
                      subtitle: 'Learn how to use the app',
                      onTap: _startAppTour,
                    ),
                    const Divider(height: 1, indent: 56),
                  ],
                  _buildSettingsTile(
                    icon: Icons.info_outline,
                    title: 'About',
                    subtitle: 'Version and app information',
                    onTap: _showAboutDialog,
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildSettingsTile(
                    icon: Icons.policy_outlined,
                    title: 'Privacy Policy',
                    subtitle: 'Read our privacy policy',
                    onTap: _showPrivacyPolicy,
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildSettingsTile(
                    icon: Icons.mail_outline,
                    title: 'Contact Us',
                    subtitle: 'Send us an email',
                    onTap: _contactSupport,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xff0386FF).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: const Color(0xff0386FF),
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(
          fontSize: 13,
          color: Theme.of(context).textTheme.bodySmall?.color,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
      ),
      onTap: onTap,
    );
  }

  Widget _buildDarkModeToggle() {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xff0386FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              themeService.isDarkMode ? Icons.dark_mode : Icons.light_mode,
              color: const Color(0xff0386FF),
              size: 20,
            ),
          ),
          title: Text(
            'Dark Mode',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            themeService.isDarkMode ? 'Enabled' : 'Disabled',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          trailing: Switch(
            value: themeService.isDarkMode,
            onChanged: (value) {
              themeService.toggleTheme();
            },
            activeThumbColor: const Color(0xff0386FF),
          ),
        );
      },
    );
  }
}
