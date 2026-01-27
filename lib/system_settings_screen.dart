import 'package:flutter/material.dart';
import 'core/enums/wage_enums.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/services/wage_management_service.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SystemSettingsScreen extends StatefulWidget {
  const SystemSettingsScreen({super.key});

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> {
  bool _emailNotifications = true;
  bool _pushNotifications = false;
  bool _maintenanceMode = false;
  bool _autoBackup = true;
  bool _userRegistration = true;
  bool _guestAccess = false;

  String _selectedTheme = 'Light';
  String _selectedLanguage = 'English';
  String _backupFrequency = 'Daily';
  String _sessionTimeout = '30 minutes';

  final List<String> _themes = ['Light', 'Dark', 'Auto'];
  final List<String> _languages = ['English', 'Spanish', 'French'];
  final List<String> _backupOptions = ['Daily', 'Weekly', 'Monthly'];
  final List<String> _timeoutOptions = [
    '15 minutes',
    '30 minutes',
    '1 hour',
    '2 hours'
  ];

  // Wage management variables
  double _globalWage = 4.0;
  Map<String, double> _roleWages = {};
  Map<String, double> _individualWages = {};
  bool _isLoadingWages = true;

  @override
  void initState() {
    super.initState();
    _loadWageSettings();
  }

  Future<void> _loadWageSettings() async {
    setState(() => _isLoadingWages = true);
    try {
      _globalWage = await WageManagementService.getGlobalWage();
      _roleWages = await WageManagementService.getRoleWages();
      _individualWages = await WageManagementService.getIndividualWages();
    } catch (e) {
      AppLogger.error('Error loading wage settings: $e');
    }
    setState(() => _isLoadingWages = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            _buildGeneralSettingsCard(),
                            const SizedBox(height: 24),
                            _buildSecuritySettingsCard(),
                            const SizedBox(height: 24),
                            _buildMaintenanceCard(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          children: [
                            _buildWageManagementCard(),
                            const SizedBox(height: 24),
                            _buildNotificationSettingsCard(),
                            const SizedBox(height: 24),
                            _buildBackupSettingsCard(),
                            const SizedBox(height: 24),
                            _buildSystemInfoCard(),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff667eea), Color(0xff764ba2)],
        ),
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
                  AppLocalizations.of(context)!.systemSettings,
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.configureAndManageYourEducationPlatform,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
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
            child: const Icon(
              Icons.settings,
              size: 48,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralSettingsCard() {
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tune, color: Colors.blue),
              ),
              const SizedBox(width: 12),
              Text(
                AppLocalizations.of(context)!.generalSettings,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xff1a1a1a),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildDropdownSetting('Theme', _selectedTheme, _themes, (value) {
            setState(() => _selectedTheme = value!);
          }),
          const SizedBox(height: 16),
          _buildDropdownSetting('Language', _selectedLanguage, _languages,
              (value) {
            setState(() => _selectedLanguage = value!);
          }),
          const SizedBox(height: 16),
          _buildDropdownSetting(
              'Session Timeout', _sessionTimeout, _timeoutOptions, (value) {
            setState(() => _sessionTimeout = value!);
          }),
          const SizedBox(height: 16),
          _buildSwitchSetting(
            'Allow User Registration',
            'Enable new users to register accounts',
            _userRegistration,
            (value) => setState(() => _userRegistration = value),
          ),
          const SizedBox(height: 12),
          _buildSwitchSetting(
            'Guest Access',
            'Allow limited access without registration',
            _guestAccess,
            (value) => setState(() => _guestAccess = value),
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySettingsCard() {
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.security, color: Colors.red),
              ),
              const SizedBox(width: 12),
              Text(
                AppLocalizations.of(context)!.securitySettings,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xff1a1a1a),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildActionButton(
            'Reset All Passwords',
            'Force all users to reset their passwords',
            Icons.lock_reset,
            Colors.orange,
            () => _showResetPasswordDialog(),
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            'View Login Logs',
            'Monitor user authentication activity',
            Icons.history,
            Colors.blue,
            () => _showLoginLogs(),
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            'Manage Permissions',
            'Configure role-based access control',
            Icons.admin_panel_settings,
            Colors.purple,
            () => _showPermissionsDialog(),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationSettingsCard() {
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.notifications, color: Colors.green),
              ),
              const SizedBox(width: 12),
              Text(
                AppLocalizations.of(context)!.notificationSettings,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xff1a1a1a),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSwitchSetting(
            'Email Notifications',
            'Send system notifications via email',
            _emailNotifications,
            (value) => setState(() => _emailNotifications = value),
          ),
          const SizedBox(height: 12),
          _buildSwitchSetting(
            'Push Notifications',
            'Send real-time push notifications',
            _pushNotifications,
            (value) => setState(() => _pushNotifications = value),
          ),
          const SizedBox(height: 16),
          _buildActionButton(
            'Test Notifications',
            'Send a test notification to verify setup',
            Icons.send,
            Colors.blue,
            () => _testNotifications(),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupSettingsCard() {
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.backup, color: Colors.purple),
              ),
              const SizedBox(width: 12),
              Text(
                AppLocalizations.of(context)!.backupSettings,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xff1a1a1a),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSwitchSetting(
            'Automatic Backup',
            'Enable scheduled database backups',
            _autoBackup,
            (value) => setState(() => _autoBackup = value),
          ),
          const SizedBox(height: 16),
          _buildDropdownSetting(
              'Backup Frequency', _backupFrequency, _backupOptions, (value) {
            setState(() => _backupFrequency = value!);
          }),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'Backup Now',
                  'Create immediate backup',
                  Icons.save,
                  Colors.green,
                  () => _createBackup(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  'Restore',
                  'Restore from backup',
                  Icons.restore,
                  Colors.orange,
                  () => _restoreBackup(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceCard() {
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.build, color: Colors.orange),
              ),
              const SizedBox(width: 12),
              Text(
                AppLocalizations.of(context)!.maintenance,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xff1a1a1a),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSwitchSetting(
            'Maintenance Mode',
            'Temporarily disable access for maintenance',
            _maintenanceMode,
            (value) => setState(() => _maintenanceMode = value),
          ),
          const SizedBox(height: 16),
          _buildActionButton(
            'Clear Cache',
            'Clear system cache and temporary files',
            Icons.clear_all,
            Colors.blue,
            () => _clearCache(),
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            'System Diagnostics',
            'Run comprehensive system health check',
            Icons.health_and_safety,
            Colors.green,
            () => _runDiagnostics(),
          ),
        ],
      ),
    );
  }

  Widget _buildWageManagementCard() {
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.payments, color: Colors.green),
              ),
              const SizedBox(width: 12),
              Text(
                AppLocalizations.of(context)!.wageManagement,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xff1a1a1a),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_isLoadingWages)
            const Center(child: CircularProgressIndicator())
          else ...[
            // Global wage setting
            _buildWageInputField(
              'Global Hourly Rate',
              'Default rate for all teachers',
              _globalWage,
              (value) => _globalWage = value,
            ),
            const SizedBox(height: 16),
            _buildActionButton(
              'Manage Role-Based Wages',
              'Set different wages for different roles',
              Icons.group,
              Colors.blue,
              () => _showRoleWageDialog(),
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              'Manage Individual Wages',
              'Override wages for specific teachers',
              Icons.person,
              Colors.purple,
              () => _showIndividualWageDialog(),
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              'Apply Wage Changes',
              'Update all existing records with new wages',
              Icons.update,
              Colors.orange,
              () => _showApplyWagesDialog(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWageInputField(
      String title, String subtitle, double value, Function(double) onChanged) {
    final controller = TextEditingController(text: value.toStringAsFixed(2));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xff374151),
          ),
        ),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xff6b7280),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            prefixText: '\$ ',
            suffixText: ' /hour',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xffe5e7eb)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xffe5e7eb)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          onChanged: (text) {
            final value = double.tryParse(text);
            if (value != null) {
              onChanged(value);
            }
          },
        ),
      ],
    );
  }

  Widget _buildSystemInfoCard() {
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.cyan.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.info, color: Colors.cyan),
              ),
              const SizedBox(width: 12),
              Text(
                AppLocalizations.of(context)!.systemInformation,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xff1a1a1a),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildInfoRow('Version', '1.0.0'),
          _buildInfoRow('Database', 'Firebase Firestore'),
          _buildInfoRow('Storage', 'Firebase Storage'),
          _buildInfoRow('Authentication', 'Firebase Auth'),
          _buildInfoRow('Last Backup', '2 hours ago'),
          _buildInfoRow('Uptime', '99.9%'),
        ],
      ),
    );
  }

  Widget _buildDropdownSetting(String title, String value, List<String> options,
      ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xff374151),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xffe5e7eb)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              onChanged: onChanged,
              items: options.map((String option) {
                return DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchSetting(
      String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xff374151),
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xff6b7280),
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Colors.blue,
        ),
      ],
    );
  }

  Widget _buildActionButton(String title, String subtitle, IconData icon,
      Color color, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                  Text(
                    subtitle,
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
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xff6b7280),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xff374151),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () {
            // Reset to defaults
            setState(() {
              _emailNotifications = true;
              _pushNotifications = false;
              _maintenanceMode = false;
              _autoBackup = true;
              _userRegistration = true;
              _guestAccess = false;
              _selectedTheme = 'Light';
              _selectedLanguage = 'English';
              _backupFrequency = 'Daily';
              _sessionTimeout = '30 minutes';
            });
          },
          child: Text(
            AppLocalizations.of(context)!.resetToDefaults,
            style: GoogleFonts.inter(
              color: const Color(0xff6b7280),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton(
          onPressed: _saveSettings,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          ),
          child: Text(
            AppLocalizations.of(context)!.saveSettings,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // Action methods
  void _saveSettings() async {
    // Save wage settings
    try {
      await WageManagementService.setGlobalWage(_globalWage);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.settingsSavedSuccessfully,
            style: GoogleFonts.inter(fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.errorSavingSettingsE,
            style: GoogleFonts.inter(fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  void _showResetPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.resetAllPasswords),
        content: Text(
            AppLocalizations.of(context)!.areYouSureYouWantTo3),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.commonCancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Implement password reset logic
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(AppLocalizations.of(context)!.passwordResetInitiatedForAllUsers)),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.resetAll),
          ),
        ],
      ),
    );
  }

  void _showLoginLogs() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.loginLogs),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView(
            children: const [
              ListTile(
                leading: Icon(Icons.login, color: Colors.green),
                title: Text(AppLocalizations.of(context)!.johnDoeEmailCom),
                subtitle: Text(AppLocalizations.of(context)!.successfulLogin2MinutesAgo),
              ),
              ListTile(
                leading: Icon(Icons.error, color: Colors.red),
                title: Text(AppLocalizations.of(context)!.janeSmithEmailCom),
                subtitle: Text(AppLocalizations.of(context)!.failedLoginAttempt15MinutesAgo),
              ),
              ListTile(
                leading: Icon(Icons.login, color: Colors.green),
                title: Text(AppLocalizations.of(context)!.adminSchoolEdu),
                subtitle: Text(AppLocalizations.of(context)!.successfulLogin1HourAgo),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.commonClose),
          ),
        ],
      ),
    );
  }

  void _showPermissionsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.rolePermissions),
        content: Text(
            AppLocalizations.of(context)!.roleBasedPermissionsAreConfiguredAutomatically),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.commonOk),
          ),
        ],
      ),
    );
  }

  void _testNotifications() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppLocalizations.of(context)!.testNotificationSentSuccessfully)),
    );
  }

  void _createBackup() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppLocalizations.of(context)!.backupCreatedSuccessfully)),
    );
  }

  void _restoreBackup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.restoreBackup),
        content: Text(AppLocalizations.of(context)!.selectABackupToRestoreFrom),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.commonCancel),
          ),
        ],
      ),
    );
  }

  void _clearCache() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppLocalizations.of(context)!.cacheClearedSuccessfully)),
    );
  }

  void _runDiagnostics() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.systemDiagnostics),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.check_circle, color: Colors.green),
              title: Text(AppLocalizations.of(context)!.databaseConnection),
              subtitle: Text(AppLocalizations.of(context)!.healthy),
            ),
            ListTile(
              leading: Icon(Icons.check_circle, color: Colors.green),
              title: Text(AppLocalizations.of(context)!.storageService),
              subtitle: Text(AppLocalizations.of(context)!.operational),
            ),
            ListTile(
              leading: Icon(Icons.check_circle, color: Colors.green),
              title: Text(AppLocalizations.of(context)!.authenticationService),
              subtitle: Text(AppLocalizations.of(context)!.shiftActive),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.commonClose),
          ),
        ],
      ),
    );
  }

  // Wage management dialogs
  void _showRoleWageDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _EnhancedRoleWageDialog(
        onApply: (role, wage) async {
          // Apply wage to all users in this role
          await WageManagementService.setRoleWage(role, wage);

          // Get all users in this role and update their wages
          final allUsers = await WageManagementService.getAllUsers();
          final usersInRole = allUsers
              .where((user) =>
                  user['role'].toString().toLowerCase() == role.toLowerCase())
              .toList();

          // Update each user's wage
          for (var user in usersInRole) {
            await WageManagementService.setIndividualWage(user['id'], wage);
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Applied wage of \$${wage.toStringAsFixed(2)}/hour to ${usersInRole.length} users in $role role'),
              backgroundColor: Colors.green,
            ),
          );

          await _loadWageSettings();
        },
      ),
    );
  }

  void _showIndividualWageDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _EnhancedIndividualWageDialog(
        onSave: (userWages) async {
          await WageManagementService.setMultipleIndividualWages(userWages);
          await _loadWageSettings();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Updated wages for ${userWages.length} users'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  void _showApplyWagesDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ApplyWageChangesDialog(
        globalWage: _globalWage,
        onApply: (updateType, role, userIds, wage) async {
          Navigator.of(context).pop();
          _applyWageChangesWithOptions(updateType, role, userIds, wage);
        },
      ),
    );
  }

  void _applyWageChangesWithOptions(WageType updateType, String? role,
      List<String>? userIds, double wage) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(AppLocalizations.of(context)!.applyingWageChangesToAllRecords),
          ],
        ),
      ),
    );

    try {
      Map<String, int> results;

      if (updateType == WageType.individual && userIds != null) {
        // Apply to specific users
        results = {'shifts': 0, 'timesheets': 0};
        for (String userId in userIds) {
          final userResults = await WageManagementService.applyWageUpdates(
            updateType: WageType.individual,
            userId: userId,
            newWage: wage,
          );
          results['shifts'] = results['shifts']! + userResults['shifts']!;
          results['timesheets'] =
              results['timesheets']! + userResults['timesheets']!;
        }
      } else {
        // Apply by role or globally
        results = await WageManagementService.applyWageUpdates(
          updateType: updateType,
          role: role,
          newWage: wage,
        );
      }

      Navigator.of(context).pop(); // Close loading dialog

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.wageChangesApplied),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('✅ Updated ${results['shifts']} shifts'),
              Text('✅ Updated ${results['timesheets']} timesheet entries'),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.allRecordsNowReflectTheNew,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppLocalizations.of(context)!.commonDone),
            ),
          ],
        ),
      );
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.errorApplyingWageChangesE),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// Role wage dialog
class _RoleWageDialog extends StatefulWidget {
  final Map<String, double> roleWages;
  final Function(Map<String, double>) onSave;

  const _RoleWageDialog({
    required this.roleWages,
    required this.onSave,
  });

  @override
  State<_RoleWageDialog> createState() => _RoleWageDialogState();
}

class _RoleWageDialogState extends State<_RoleWageDialog> {
  late Map<String, double> _roleWages;
  List<String> _availableRoles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _roleWages = Map<String, double>.from(widget.roleWages);
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    final roles = await WageManagementService.getAvailableRoles();
    final globalWage = await WageManagementService.getGlobalWage();
    setState(() {
      _availableRoles = roles;
      // Add default wage for roles that don't have one
      for (var role in roles) {
        _roleWages[role] ??= globalWage;
      }
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.manageRoleBasedWages),
      content: SizedBox(
        width: 400,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppLocalizations.of(context)!.setDifferentHourlyRatesForEach,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ..._availableRoles.map((role) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                role,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: TextEditingController(
                                  text: _roleWages[role]?.toStringAsFixed(2) ??
                                      '',
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: InputDecoration(
                                  prefixText: '\$ ',
                                  suffixText: ' /hour',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                onChanged: (value) {
                                  final wage = double.tryParse(value);
                                  if (wage != null) {
                                    setState(() => _roleWages[role] = wage);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context)!.commonCancel),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onSave(_roleWages);
            Navigator.of(context).pop();
          },
          child: Text(AppLocalizations.of(context)!.commonSave),
        ),
      ],
    );
  }
}

// Individual wage dialog
class _IndividualWageDialog extends StatefulWidget {
  final Function(String userId, double? wage) onSave;

  const _IndividualWageDialog({required this.onSave});

  @override
  State<_IndividualWageDialog> createState() => _IndividualWageDialogState();
}

class _IndividualWageDialogState extends State<_IndividualWageDialog> {
  List<Map<String, dynamic>> _teachers = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  Future<void> _loadTeachers() async {
    final teachers = await WageManagementService.getAllUsers();
    setState(() {
      _teachers = teachers;
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> get _filteredTeachers {
    if (_searchQuery.isEmpty) return _teachers;

    final query = _searchQuery.toLowerCase();
    return _teachers.where((teacher) {
      final name = teacher['name'].toString().toLowerCase();
      final email = teacher['email'].toString().toLowerCase();
      return name.contains(query) || email.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.manageIndividualWages),
      content: SizedBox(
        width: 600,
        height: 400,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.searchTeachers,
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _filteredTeachers.length,
                      itemBuilder: (context, index) {
                        final teacher = _filteredTeachers[index];
                        final hasOverride = teacher['has_override'] as bool;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(teacher['name']),
                            subtitle: Text(teacher['email']),
                            trailing: SizedBox(
                              width: 150,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: TextEditingController(
                                        text: teacher['current_wage']
                                            .toStringAsFixed(2),
                                      ),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      decoration: InputDecoration(
                                        prefixText: '\$',
                                        suffixIcon: hasOverride
                                            ? IconButton(
                                                icon: const Icon(Icons.clear,
                                                    size: 16),
                                                onPressed: () {
                                                  widget.onSave(
                                                      teacher['id'], null);
                                                  _loadTeachers();
                                                },
                                                tooltip: AppLocalizations.of(context)!.removeOverride,
                                              )
                                            : null,
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                      ),
                                      onSubmitted: (value) {
                                        final wage = double.tryParse(value);
                                        if (wage != null) {
                                          widget.onSave(teacher['id'], wage);
                                          _loadTeachers();
                                        }
                                      },
                                    ),
                                  ),
                                  if (hasOverride)
                                    Container(
                                      margin: const EdgeInsets.only(left: 4),
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Icon(
                                        Icons.edit,
                                        size: 16,
                                        color: Colors.orange,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context)!.commonClose),
        ),
      ],
    );
  }
}

// Enhanced Role Wage Dialog
class _EnhancedRoleWageDialog extends StatefulWidget {
  final Function(String role, double wage) onApply;

  const _EnhancedRoleWageDialog({required this.onApply});

  @override
  State<_EnhancedRoleWageDialog> createState() =>
      _EnhancedRoleWageDialogState();
}

class _EnhancedRoleWageDialogState extends State<_EnhancedRoleWageDialog> {
  List<String> _availableRoles = [];
  String? _selectedRole;
  double _wage = 4.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    final roles = await WageManagementService.getAvailableRoles();
    setState(() {
      _availableRoles = roles;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.applyWageToRole),
      content: SizedBox(
        width: 400,
        child: _isLoading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.selectARoleAndSetThe,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ..._availableRoles.map((role) {
                    return RadioListTile<String>(
                      title: Text(role),
                      value: role,
                      groupValue: _selectedRole,
                      onChanged: (value) {
                        setState(() => _selectedRole = value);
                      },
                    );
                  }).toList(),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  TextField(
                    controller:
                        TextEditingController(text: _wage.toStringAsFixed(2)),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.hourlyWage,
                      prefixText: '\$ ',
                      suffixText: ' /hour',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (value) {
                      final wage = double.tryParse(value);
                      if (wage != null) {
                        setState(() => _wage = wage);
                      }
                    },
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context)!.commonCancel),
        ),
        ElevatedButton(
          onPressed: _selectedRole == null
              ? null
              : () {
                  Navigator.of(context).pop();
                  widget.onApply(_selectedRole!, _wage);
                },
          child: Text(AppLocalizations.of(context)!.applyToRole),
        ),
      ],
    );
  }
}

// Enhanced Individual Wage Dialog
class _EnhancedIndividualWageDialog extends StatefulWidget {
  final Function(Map<String, double>) onSave;

  const _EnhancedIndividualWageDialog({required this.onSave});

  @override
  State<_EnhancedIndividualWageDialog> createState() =>
      _EnhancedIndividualWageDialogState();
}

class _EnhancedIndividualWageDialogState
    extends State<_EnhancedIndividualWageDialog> {
  List<Map<String, dynamic>> _allUsers = [];
  List<String> _selectedUserIds = [];
  Map<String, double> _userWages = {};
  bool _isLoading = true;
  String _searchQuery = '';
  double _bulkWage = 4.0;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final users = await WageManagementService.getAllUsers();
    setState(() {
      _allUsers = users;
      for (var user in users) {
        _userWages[user['id']] = user['current_wage'];
      }
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.isEmpty) return _allUsers;

    final query = _searchQuery.toLowerCase();
    return _allUsers.where((user) {
      final name = user['name'].toString().toLowerCase();
      final email = user['email'].toString().toLowerCase();
      final role = user['role'].toString().toLowerCase();
      return name.contains(query) ||
          email.contains(query) ||
          role.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Text(AppLocalizations.of(context)!.manageIndividualWages),
          const Spacer(),
          Text(
            '${_selectedUserIds.length} selected',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
          ),
        ],
      ),
      content: SizedBox(
        width: 700,
        height: 500,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Search bar
                  TextField(
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.searchByNameEmailOrRole,
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                  const SizedBox(height: 16),
                  // Bulk actions
                  if (_selectedUserIds.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Set wage for ${_selectedUserIds.length} selected users:',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                          SizedBox(
                            width: 150,
                            child: TextField(
                              controller: TextEditingController(
                                text: _bulkWage.toStringAsFixed(2),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: InputDecoration(
                                prefixText: '\$ ',
                                suffixText: ' /hour',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                              ),
                              onChanged: (value) {
                                final wage = double.tryParse(value);
                                if (wage != null) {
                                  setState(() => _bulkWage = wage);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                for (var userId in _selectedUserIds) {
                                  _userWages[userId] = _bulkWage;
                                }
                              });
                            },
                            child: Text(AppLocalizations.of(context)!.commonApply),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  // User list
                  Expanded(
                    child: ListView.builder(
                      itemCount: _filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = _filteredUsers[index];
                        final isSelected =
                            _selectedUserIds.contains(user['id']);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color:
                              isSelected ? Colors.blue.withOpacity(0.1) : null,
                          child: ListTile(
                            leading: Checkbox(
                              value: isSelected,
                              onChanged: (value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedUserIds.add(user['id']);
                                  } else {
                                    _selectedUserIds.remove(user['id']);
                                  }
                                });
                              },
                            ),
                            title: Text(user['name']),
                            subtitle:
                                Text('${user['email']} • ${user['role']}'),
                            trailing: SizedBox(
                              width: 150,
                              child: TextField(
                                controller: TextEditingController(
                                  text: _userWages[user['id']]
                                          ?.toStringAsFixed(2) ??
                                      '',
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: InputDecoration(
                                  prefixText: '\$',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                ),
                                onChanged: (value) {
                                  final wage = double.tryParse(value);
                                  if (wage != null) {
                                    setState(() {
                                      _userWages[user['id']] = wage;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context)!.commonCancel),
        ),
        ElevatedButton(
          onPressed: () {
            // Only save changed wages
            final changedWages = <String, double>{};
            for (var user in _allUsers) {
              if (_userWages[user['id']] != user['current_wage']) {
                changedWages[user['id']] = _userWages[user['id']]!;
              }
            }
            if (changedWages.isNotEmpty) {
              Navigator.of(context).pop();
              widget.onSave(changedWages);
            }
          },
          child: Text(AppLocalizations.of(context)!.timesheetSaveChanges),
        ),
      ],
    );
  }
}

// Apply Wage Changes Dialog
class _ApplyWageChangesDialog extends StatefulWidget {
  final double globalWage;
  final Function(
      WageType type, String? role, List<String>? userIds, double wage) onApply;

  const _ApplyWageChangesDialog({
    required this.globalWage,
    required this.onApply,
  });

  @override
  State<_ApplyWageChangesDialog> createState() =>
      _ApplyWageChangesDialogState();
}

class _ApplyWageChangesDialogState extends State<_ApplyWageChangesDialog> {
  WageType _selectedType = WageType.global;
  String? _selectedRole;
  List<String> _selectedUserIds = [];
  double _wage = 4.0;
  List<String> _availableRoles = [];
  List<Map<String, dynamic>> _allUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _wage = widget.globalWage;
    _loadData();
  }

  Future<void> _loadData() async {
    final roles = await WageManagementService.getAvailableRoles();
    final users = await WageManagementService.getAllUsers();
    setState(() {
      _availableRoles = roles;
      _allUsers = users;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.applyWageChangesToRecords),
      content: SizedBox(
        width: 500,
        height: 400,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.thisWillUpdateAllExistingShifts,
                    style: TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  // Wage input
                  TextField(
                    controller:
                        TextEditingController(text: _wage.toStringAsFixed(2)),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.newHourlyWage,
                      prefixText: '\$ ',
                      suffixText: ' /hour',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (value) {
                      final wage = double.tryParse(value);
                      if (wage != null) {
                        setState(() => _wage = wage);
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    AppLocalizations.of(context)!.applyTo,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  RadioListTile<WageType>(
                    title: Text(AppLocalizations.of(context)!.allUsersGlobal),
                    value: WageType.global,
                    groupValue: _selectedType,
                    onChanged: (value) =>
                        setState(() => _selectedType = value!),
                  ),
                  RadioListTile<WageType>(
                    title: Text(AppLocalizations.of(context)!.specificRole),
                    value: WageType.role,
                    groupValue: _selectedType,
                    onChanged: (value) =>
                        setState(() => _selectedType = value!),
                  ),
                  if (_selectedType == WageType.role)
                    Padding(
                      padding: const EdgeInsets.only(left: 48, right: 16),
                      child: DropdownButtonFormField<String>(
                        value: _selectedRole,
                        hint: Text(AppLocalizations.of(context)!.selectRole),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: _availableRoles.map((role) {
                          return DropdownMenuItem(
                            value: role,
                            child: Text(role),
                          );
                        }).toList(),
                        onChanged: (value) =>
                            setState(() => _selectedRole = value),
                      ),
                    ),
                  RadioListTile<WageType>(
                    title: Text(AppLocalizations.of(context)!.specificUsers),
                    value: WageType.individual,
                    groupValue: _selectedType,
                    onChanged: (value) =>
                        setState(() => _selectedType = value!),
                  ),
                  if (_selectedType == WageType.individual)
                    Expanded(
                      child: Container(
                        margin:
                            const EdgeInsets.only(left: 48, right: 16, top: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _allUsers.length,
                          itemBuilder: (context, index) {
                            final user = _allUsers[index];
                            final isSelected =
                                _selectedUserIds.contains(user['id']);
                            return CheckboxListTile(
                              value: isSelected,
                              onChanged: (value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedUserIds.add(user['id']);
                                  } else {
                                    _selectedUserIds.remove(user['id']);
                                  }
                                });
                              },
                              title: Text(user['name']),
                              subtitle:
                                  Text('${user['email']} • ${user['role']}'),
                              dense: true,
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context)!.commonCancel),
        ),
        ElevatedButton(
          onPressed: _canApply()
              ? () {
                  widget.onApply(
                    _selectedType,
                    _selectedRole,
                    _selectedUserIds,
                    _wage,
                  );
                }
              : null,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          child: Text(AppLocalizations.of(context)!.applyChanges),
        ),
      ],
    );
  }

  bool _canApply() {
    switch (_selectedType) {
      case WageType.global:
        return true;
      case WageType.role:
        return _selectedRole != null;
      case WageType.individual:
        return _selectedUserIds.isNotEmpty;
    }
  }
}
