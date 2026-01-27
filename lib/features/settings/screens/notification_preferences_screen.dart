import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/notification_preferences_service.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  bool _shiftNotificationsEnabled = true;
  int _shiftNotificationMinutes = 15;

  bool _taskNotificationsEnabled = true;
  int _taskNotificationDays = 1;

  bool _chatNotificationsEnabled = true;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final shiftEnabled =
          await NotificationPreferencesService.isShiftNotificationEnabled();
      final shiftMinutes =
          await NotificationPreferencesService.getShiftNotificationMinutes();
      final taskEnabled =
          await NotificationPreferencesService.isTaskNotificationEnabled();
      final taskDays =
          await NotificationPreferencesService.getTaskNotificationDays();
      final chatEnabled =
          await NotificationPreferencesService.isChatNotificationEnabled();

      if (mounted) {
        setState(() {
          _shiftNotificationsEnabled = shiftEnabled;
          _shiftNotificationMinutes = shiftMinutes;
          _taskNotificationsEnabled = taskEnabled;
          _taskNotificationDays = taskDays;
          _chatNotificationsEnabled = chatEnabled;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('Error loading notification preferences: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _savePreferences() async {
    try {
      await NotificationPreferencesService.setShiftNotificationEnabled(
          _shiftNotificationsEnabled);
      await NotificationPreferencesService.setShiftNotificationMinutes(
          _shiftNotificationMinutes);
      await NotificationPreferencesService.setTaskNotificationEnabled(
          _taskNotificationsEnabled);
      await NotificationPreferencesService.setTaskNotificationDays(
          _taskNotificationDays);
      await NotificationPreferencesService.setChatNotificationEnabled(
          _chatNotificationsEnabled);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Notification preferences saved!',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: const Color(0xff10B981),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error saving notification preferences: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save preferences. Please try again.',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: const Color(0xffEF4444),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
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
            icon: Icon(Icons.arrow_back,
                color: Theme.of(context).iconTheme.color),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Notification Preferences',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.titleLarge?.color,
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
          icon:
              Icon(Icons.arrow_back, color: Theme.of(context).iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notification Preferences',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16),

            // Shift Notifications Section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
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
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xff0386FF).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.schedule,
                            color: Color(0xff0386FF),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SHIFT REMINDERS',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xff6B7280),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Get notified before your shift starts',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _shiftNotificationsEnabled,
                          onChanged: (value) {
                            setState(() => _shiftNotificationsEnabled = value);
                            _savePreferences();
                          },
                          activeThumbColor: const Color(0xff0386FF),
                        ),
                      ],
                    ),
                  ),

                  if (_shiftNotificationsEnabled) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notify me before shift',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.color,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: NotificationPreferencesService
                                .shiftNotificationOptions
                                .map(
                              (minutes) => _buildTimeChip(
                                label: '$minutes min',
                                value: minutes,
                                isSelected:
                                    _shiftNotificationMinutes == minutes,
                                onTap: () {
                                  setState(() =>
                                      _shiftNotificationMinutes = minutes);
                                  _savePreferences();
                                },
                              ),
                            ).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Task Notifications Section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
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
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xff10B981).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.task_alt,
                            color: Color(0xff10B981),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TASK REMINDERS',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xff6B7280),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Get notified before task due date',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _taskNotificationsEnabled,
                          onChanged: (value) {
                            setState(() => _taskNotificationsEnabled = value);
                            _savePreferences();
                          },
                          activeThumbColor: const Color(0xff10B981),
                        ),
                      ],
                    ),
                  ),

                  if (_taskNotificationsEnabled) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notify me before due date',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.color,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: NotificationPreferencesService
                                .taskNotificationOptions
                                .map(
                              (days) => _buildTimeChip(
                                label: '$days ${days == 1 ? 'day' : 'days'}',
                                value: days,
                                isSelected: _taskNotificationDays == days,
                                onTap: () {
                                  setState(() => _taskNotificationDays = days);
                                  _savePreferences();
                                },
                                color: const Color(0xff10B981),
                              ),
                            ).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Chat Notifications Section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xffF59E0B).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.chat_bubble_outline,
                        color: Color(0xffF59E0B),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CHAT MESSAGES',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xff6B7280),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Get notified when you receive messages',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _chatNotificationsEnabled,
                      onChanged: (value) {
                        setState(() => _chatNotificationsEnabled = value);
                        _savePreferences();
                      },
                      activeThumbColor: const Color(0xffF59E0B),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Info Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xffF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xff6B7280),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Notifications help you stay on top of your shifts and tasks. You can adjust these settings anytime.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xff6B7280),
                        height: 1.5,
                      ),
                    ),
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

  Widget _buildTimeChip({
    required String label,
    required int value,
    required bool isSelected,
    required VoidCallback onTap,
    Color color = const Color(0xff0386FF),
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}

