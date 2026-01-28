import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/services/user_role_service.dart';
import '../../../core/services/profile_picture_service.dart';
import '../../../core/services/language_service.dart';
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

  String _languageLabel(AppLocalizations l10n, Locale locale) {
    switch (locale.languageCode) {
      case 'fr':
        return l10n.languageFrench;
      case 'ar':
        return l10n.languageArabic;
      case 'en':
      default:
        return l10n.languageEnglish;
    }
  }

  void _showLanguagePicker(
    BuildContext context,
    LanguageService languageService,
  ) {
    try {
      final l10n = AppLocalizations.of(context)!;
      final currentLocale =
          languageService.locale ?? Localizations.localeOf(context);

      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetContext) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.selectLanguageTitle,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildLanguageOption(
                    context: sheetContext,
                    label: l10n.languageEnglish,
                    value: const Locale('en'),
                    groupValue: currentLocale,
                    onSelected: (locale) =>
                        _applyLocale(sheetContext, languageService, locale),
                  ),
                  _buildLanguageOption(
                    context: sheetContext,
                    label: l10n.languageFrench,
                    value: const Locale('fr'),
                    groupValue: currentLocale,
                    onSelected: (locale) =>
                        _applyLocale(sheetContext, languageService, locale),
                  ),
                  // Arabic disabled for now - RTL support needed
                  // _buildLanguageOption(
                  //   context: sheetContext,
                  //   label: l10n.languageArabic,
                  //   value: const Locale('ar'),
                  //   groupValue: currentLocale,
                  //   onSelected: (locale) =>
                  //       _applyLocale(sheetContext, languageService, locale),
                  // ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      debugPrint('Error showing language picker: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.errorLoadingLanguageSettingsPleaseRestart)),
      );
    }
  }

  void _applyLocale(
    BuildContext context,
    LanguageService languageService,
    Locale locale,
  ) {
    languageService.setLocale(locale);
    Navigator.pop(context);
  }

  Widget _buildLanguageOption({
    required BuildContext context,
    required String label,
    required Locale value,
    required Locale groupValue,
    required ValueChanged<Locale> onSelected,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF111827),
        ),
      ),
      trailing: Radio<Locale>(
        value: value,
        groupValue: groupValue,
        onChanged: (locale) {
          if (locale != null) onSelected(locale);
        },
      ),
      onTap: () => onSelected(value),
    );
  }

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
              AppLocalizations.of(context)!.profilePictureUpdatedSuccessfully,
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
              AppLocalizations.of(context)!.failedToUploadProfilePicturePlease,
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
              AppLocalizations.of(context)!.profilePictureRemovedSuccessfully,
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
              AppLocalizations.of(context)!.failedToRemoveProfilePicturePlease,
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
                  AppLocalizations.of(context)!.changeProfilePicture,
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
                  AppLocalizations.of(context)!.chooseFromGallery,
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
                  AppLocalizations.of(context)!.takeAPhoto,
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
                  AppLocalizations.of(context)!.removePicture,
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
              AppLocalizations.of(context)!.settingsHelpSupport,
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildHelpItem(
              icon: Icons.book_outlined,
              title: AppLocalizations.of(context)!.howToJoinAClass,
              description: AppLocalizations.of(context)!.settingsTourJoinClassDescription,
            ),
            _buildHelpItem(
              icon: Icons.notifications_outlined,
              title: AppLocalizations.of(context)!.gettingNotifications,
              description: AppLocalizations.of(context)!.settingsTourEnableNotificationsDescription,
            ),
            _buildHelpItem(
              icon: Icons.video_call_outlined,
              title: AppLocalizations.of(context)!.duringClass,
              description: AppLocalizations.of(context)!.settingsTourMediaControlsDescription,
            ),
            _buildHelpItem(
              icon: Icons.chat_outlined,
              title: AppLocalizations.of(context)!.chatFeature,
              description: AppLocalizations.of(context)!.settingsTourChatDescription,
            ),
            
            const SizedBox(height: 20),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _contactSupport,
                icon: const Icon(Icons.mail_outline),
                label: Text(AppLocalizations.of(context)!.contactSupport),
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
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.appTitle,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  AppLocalizations.of(context)!.version100,
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
              AppLocalizations.of(context)!.alluwalAcademyIsAQuranEducation,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xff4B5563),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '© 2024 Alluvial Education Hub',
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
            child: Text(AppLocalizations.of(context)!.commonClose),
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
                      AppLocalizations.of(context)!.settingsPrivacyPolicy,
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
                        title: AppLocalizations.of(context)!.informationWeCollect,
                        content: AppLocalizations.of(context)!.weCollectInformationYouProvideDirectly,
                      ),
                      _buildPrivacySection(
                        title: AppLocalizations.of(context)!.howWeUseYourInformation,
                        content: AppLocalizations.of(context)!.yourInformationIsUsedToProvide,
                      ),
                      _buildPrivacySection(
                        title: AppLocalizations.of(context)!.dataSecurity,
                        content: AppLocalizations.of(context)!.weImplementIndustryStandardSecurityMeasures,
                      ),
                      _buildPrivacySection(
                        title: AppLocalizations.of(context)!.childrenSPrivacy,
                        content: AppLocalizations.of(context)!.weAreCommittedToProtectingChildren,
                      ),
                      _buildPrivacySection(
                        title: AppLocalizations.of(context)!.yourRights,
                        content: AppLocalizations.of(context)!.youHaveTheRightToAccess,
                      ),
                      _buildPrivacySection(
                        title: AppLocalizations.of(context)!.contactUs,
                        content: AppLocalizations.of(context)!.forPrivacyQuestionsOrConcernsEmail,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        AppLocalizations.of(context)!.lastUpdatedJanuary2024,
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
                AppLocalizations.of(context)!.emailSupportAlluwaleducationhubOrg,
                style: GoogleFonts.inter(),
              ),
              backgroundColor: const Color(0xff0386FF),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: AppLocalizations.of(context)!.commonCopy,
                textColor: Colors.white,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: AppLocalizations.of(context)!.supportAlluwaleducationhubOrg));
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
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      // Localization not ready yet - show loading
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final languageService = context.watch<LanguageService>();
    final currentLocale =
        languageService.locale ?? Localizations.localeOf(context);
    final languageSubtitle = _languageLabel(l10n, currentLocale);

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
            l10n.settingsTitle,
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
          l10n.settingsTitle,
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
                    l10n.profileHeader,
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
                      AppLocalizations.of(context)!.changeProfilePicture,
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
                      l10n.appSettingsHeader,
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
                    title: l10n.notificationsTitle,
                    subtitle: l10n.notificationsSubtitle,
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
                    title: l10n.languageTitle,
                    subtitle: languageSubtitle,
                    onTap: () {
                      _showLanguagePicker(context, languageService);
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
                      l10n.supportHeader,
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
                    title: AppLocalizations.of(context)!.settingsHelpSupport,
                    subtitle: AppLocalizations.of(context)!.getHelpUsingTheApp,
                    onTap: _showHelpDialog,
                  ),
                  const Divider(height: 1, indent: 56),
                  if (_isStudent) ...[
                    _buildSettingsTile(
                      icon: Icons.explore_outlined,
                      title: AppLocalizations.of(context)!.settingsTakeAppTour,
                      subtitle: AppLocalizations.of(context)!.settingsLearnApp,
                      onTap: _startAppTour,
                    ),
                    const Divider(height: 1, indent: 56),
                  ],
                  _buildSettingsTile(
                    icon: Icons.info_outline,
                    title: AppLocalizations.of(context)!.profileAbout,
                    subtitle: AppLocalizations.of(context)!.versionAndAppInformation,
                    onTap: _showAboutDialog,
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildSettingsTile(
                    icon: Icons.policy_outlined,
                    title: AppLocalizations.of(context)!.settingsPrivacyPolicy,
                    subtitle: AppLocalizations.of(context)!.readOurPrivacyPolicy,
                    onTap: _showPrivacyPolicy,
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildSettingsTile(
                    icon: Icons.mail_outline,
                    title: AppLocalizations.of(context)!.contactUs,
                    subtitle: AppLocalizations.of(context)!.sendUsAnEmail,
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
            AppLocalizations.of(context)!.settingsDarkMode,
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
