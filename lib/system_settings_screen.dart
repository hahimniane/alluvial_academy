import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
                  'System Settings ⚙️',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Configure and manage your education platform',
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
                'General Settings',
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
                'Security Settings',
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
                'Notification Settings',
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
                'Backup Settings',
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
                'Maintenance',
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
                'System Information',
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
          activeColor: Colors.blue,
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
            'Reset to Defaults',
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
            'Save Settings',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // Action methods
  void _saveSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Settings saved successfully!',
          style: GoogleFonts.inter(fontWeight: FontWeight.w500),
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showResetPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset All Passwords'),
        content: const Text(
            'Are you sure you want to force all users to reset their passwords? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Implement password reset logic
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Password reset initiated for all users')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reset All'),
          ),
        ],
      ),
    );
  }

  void _showLoginLogs() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login Logs'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView(
            children: const [
              ListTile(
                leading: Icon(Icons.login, color: Colors.green),
                title: Text('john.doe@email.com'),
                subtitle: Text('Successful login - 2 minutes ago'),
              ),
              ListTile(
                leading: Icon(Icons.error, color: Colors.red),
                title: Text('jane.smith@email.com'),
                subtitle: Text('Failed login attempt - 15 minutes ago'),
              ),
              ListTile(
                leading: Icon(Icons.login, color: Colors.green),
                title: Text('admin@school.edu'),
                subtitle: Text('Successful login - 1 hour ago'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPermissionsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Role Permissions'),
        content: const Text(
            'Role-based permissions are configured automatically. Contact support for custom permission modifications.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _testNotifications() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Test notification sent successfully!')),
    );
  }

  void _createBackup() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Backup created successfully!')),
    );
  }

  void _restoreBackup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Backup'),
        content: const Text('Select a backup to restore from:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _clearCache() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cache cleared successfully!')),
    );
  }

  void _runDiagnostics() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('System Diagnostics'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.check_circle, color: Colors.green),
              title: Text('Database Connection'),
              subtitle: Text('Healthy'),
            ),
            ListTile(
              leading: Icon(Icons.check_circle, color: Colors.green),
              title: Text('Storage Service'),
              subtitle: Text('Operational'),
            ),
            ListTile(
              leading: Icon(Icons.check_circle, color: Colors.green),
              title: Text('Authentication Service'),
              subtitle: Text('Active'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
