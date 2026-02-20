import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/build_info.dart';
import '../../../core/services/mobile_classes_access_service.dart';
import '../../../core/services/user_role_service.dart';
import '../../admin/screens/mobile_classes_access_screen.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notificationEmailController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _updatingMobileClasses = false;
  bool _hasAccess = true;

  @override
  void initState() {
    super.initState();
    _checkAccessAndLoad();
  }

  @override
  void dispose() {
    _notificationEmailController.dispose();
    super.dispose();
  }

  Future<void> _checkAccessAndLoad({int retryCount = 0}) async {
    const maxRetries = 15;
    const retryDelay = Duration(milliseconds: 600);
    const initialDelay = Duration(milliseconds: 400);

    try {
      // Give dashboard/listener time to prime role cache on first run.
      if (retryCount == 0) {
        await Future.delayed(initialDelay);
        if (!mounted) return;
      }

      final role = await UserRoleService.getCurrentUserRole();
      final availableRoles = await UserRoleService.getAvailableRoles();
      final lower = role?.toLowerCase();
      final isAdminByRole = lower == 'admin' || lower == 'super_admin';
      final hasAdminAvailable = availableRoles
          .any((r) => r.toLowerCase() == 'admin' || r.toLowerCase() == 'super_admin');
      final isAdmin = isAdminByRole || hasAdminAvailable;

      if (!mounted) return;

      // Role/data may not be loaded yet (e.g. just after login or dual admin+teacher). Retry before showing Access Restricted.
      if (role == null &&
          availableRoles.isEmpty &&
          FirebaseAuth.instance.currentUser != null &&
          retryCount < maxRetries) {
        await Future.delayed(retryDelay);
        if (mounted) _checkAccessAndLoad(retryCount: retryCount + 1);
        return;
      }

      // Before showing Access Restricted, force one fresh read (bypass cache) in case cache was stale.
      if (!isAdmin && role == null && availableRoles.isEmpty) {
        UserRoleService.clearCache();
        final freshRole = await UserRoleService.getCurrentUserRole();
        final freshRoles = await UserRoleService.getAvailableRoles();
        final freshAdmin = freshRole?.toLowerCase() == 'admin' ||
            freshRole?.toLowerCase() == 'super_admin' ||
            freshRoles.any((r) => r.toLowerCase() == 'admin' || r.toLowerCase() == 'super_admin');
        if (freshAdmin && mounted) {
          setState(() => _hasAccess = true);
          await _loadSettings();
          return;
        }
      }

      if (!isAdmin) {
        setState(() {
          _hasAccess = false;
          _isLoading = false;
        });
        return;
      }

      await _loadSettings();
    } catch (e) {
      AppLogger.error('AdminSettings: error checking access: $e');
      if (!mounted) return;
      setState(() {
        _hasAccess = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('admin')
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        _notificationEmailController.text = data['notification_email'] ?? '';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorLoadingSettingsE)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveSettings() async {
    if (!_hasAccess) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('settings')
          .doc('admin')
          .set({
        'notification_email': _notificationEmailController.text.trim(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.settingsSavedSuccessfully2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorSavingSettingsE),
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

  Future<void> _setAllowAllTeachers(bool allowAll) async {
    if (!_hasAccess) return;
    if (_updatingMobileClasses) return;

    setState(() => _updatingMobileClasses = true);
    try {
      await MobileClassesAccessService.setAllowAllTeachers(allowAll);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            allowAll
                ? 'All teachers can now teach from the mobile app.'
                : 'Mobile app classes are now restricted to selected teachers.',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update mobile classes setting: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingMobileClasses = false);
      }
    }
  }

  void _openMobileClassesManager() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MobileClassesAccessScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasAccess) {
      return Scaffold(
        backgroundColor: Color(0xffF8FAFC),
        body: Center(
          child: Text(
            AppLocalizations.of(context)!.accessRestricted,
            style: TextStyle(
              fontSize: 16,
              color: Color(0xff6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('Notification Settings'),
                          const SizedBox(height: 16),
                          _buildTextField(
                            label: AppLocalizations.of(context)!.adminSettingsNotificationemail,
                            hint: 'email@example.com',
                            controller: _notificationEmailController,
                            helperText: AppLocalizations.of(context)!.thisEmailWillReceiveNotificationsFor,
                            validator: (value) {
                              if (value != null && value.isNotEmpty) {
                                final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                                if (!emailRegex.hasMatch(value)) {
                                  return 'Please enter a valid email address';
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: 200,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _saveSettings,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xff0386FF),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Text(
                                      AppLocalizations.of(context)!.timesheetSaveChanges,
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 48),
                          _buildSectionTitle('Mobile Classes'),
                          const SizedBox(height: 16),
                          _buildMobileClassesCard(),
                          const SizedBox(height: 48),
                          _buildSectionTitle('About'),
                          const SizedBox(height: 16),
                          _buildVersionCard(),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileClassesCard() {
    return StreamBuilder<bool>(
      stream: MobileClassesAccessService.watchAllowAllTeachers(),
      builder: (context, snapshot) {
        final allowAll = snapshot.data == true;
        final loading = snapshot.connectionState == ConnectionState.waiting;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xff0EA5E9).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.tablet_mac,
                      color: Color(0xff0EA5E9),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Allow teachers to teach from mobile',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xff111827),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Enable for all teachers, or restrict to selected teachers.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xff6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: allowAll,
                    onChanged: (loading || _updatingMobileClasses)
                        ? null
                        : _setAllowAllTeachers,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _openMobileClassesManager,
                    icon: const Icon(Icons.manage_accounts),
                    label: Text(
                      'Manage teachers',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xff0386FF),
                      side: const BorderSide(color: Color(0xff0386FF)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      allowAll
                          ? 'Currently enabled for all teachers.'
                          : 'Currently enabled only for selected teachers.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xff6B7280),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          const Icon(Icons.settings, color: Color(0xff6B7280), size: 32),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.adminSettings,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xff111827),
                ),
              ),
              Text(
                AppLocalizations.of(context)!.configureApplicationSettings,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xff6B7280),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: const Color(0xff111827),
      ),
    );
  }

  Widget _buildVersionCard() {
    final textStyle = GoogleFonts.inter(
      fontSize: 13,
      color: const Color(0xff374151),
    );

    final labelStyle = GoogleFonts.inter(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: const Color(0xff111827),
    );

    final webVersion = BuildInfo.webBuildVersion.trim();
    final versionText = webVersion.isEmpty ? 'Not set' : webVersion;

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
          _buildVersionRow('New version', versionText, labelStyle, textStyle),
        ],
      ),
    );
  }

  Widget _buildVersionRow(
    String label,
    String value,
    TextStyle labelStyle,
    TextStyle valueStyle,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 110, child: Text(label, style: labelStyle)),
        Expanded(child: Text(value, style: valueStyle)),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    String? helperText,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xff374151),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            helperText: helperText,
            helperMaxLines: 3,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xffD1D5DB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xffD1D5DB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xff0386FF), width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
