import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/employee_model.dart';

import 'package:alluwalacademyadmin/core/utils/app_search.dart';
import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class SendNotificationScreen extends StatefulWidget {
  const SendNotificationScreen({super.key});

  @override
  State<SendNotificationScreen> createState() => _SendNotificationScreenState();
}

class _SendNotificationScreenState extends State<SendNotificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  String _recipientType = 'individual'; // 'individual', 'role', 'selected'
  String? _selectedRole; // 'teacher', 'student', 'parent', 'admin'
  List<String> _selectedUserIds = [];
  bool _sendEmail = false;
  bool _isSending = false;

  // For user selection
  List<Employee> _allUsers = [];
  List<Employee> _filteredUsers = [];
  String _searchQuery = '';
  bool _isLoadingUsers = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    if (!mounted) return;
    setState(() => _isLoadingUsers = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('is_active', isEqualTo: true)
          .get();

      final users = snapshot.docs.map((doc) {
        final data = doc.data();
        return Employee(
          documentId: doc.id,
          email: data['e-mail'] ?? data['email'] ?? '',
          firstName: data['first_name'] ?? '',
          lastName: data['last_name'] ?? '',
          countryCode: data['country_code'] ?? '+1',
          mobilePhone: data['phone_number'] ?? '',
          userType: data['user_type'] ?? '',
          title: data['title'] ?? '',
          employmentStartDate: data['employment_start_date']?.toString() ?? '',
          kioskCode: data['kiosk_code'] ?? '',
          dateAdded: data['date_added']?.toString() ?? '',
          lastLogin: data['last_login']?.toString() ?? '',
          isActive: data['is_active'] ?? true,
        );
      }).toList();

      users.sort((a, b) => '${a.firstName} ${a.lastName}'
          .compareTo('${b.firstName} ${b.lastName}'));

      if (!mounted) return;
      setState(() {
        _allUsers = users;
        _filteredUsers = users;
        _isLoadingUsers = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingUsers = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!.errorLoadingUsersE)),
      );
    }
  }

  void _filterUsers(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      if (_searchQuery.isEmpty && _selectedRole == null) {
        _filteredUsers = _allUsers;
      } else {
        _filteredUsers = _allUsers.where((user) {
          final matchesSearch = AppSearch.matches(
            query: _searchQuery,
            names: [
              '${user.firstName} ${user.lastName}',
              '${user.lastName} ${user.firstName}',
            ],
            emails: [user.email],
            phones: [
              user.mobilePhone,
              '${user.countryCode}${user.mobilePhone}',
            ],
            ids: [user.documentId, user.studentCode, user.kioskCode],
          );

          final matchesRole =
              _selectedRole == null || user.userType == _selectedRole;

          return matchesSearch && matchesRole;
        }).toList();
      }
    });
  }

  Future<void> _sendNotification() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate recipients
    if (_recipientType == 'individual' || _recipientType == 'selected') {
      if (_selectedUserIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)!
                  .pleaseSelectAtLeastOneRecipient)),
        );
        return;
      }
    } else if (_recipientType == 'role' && _selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!.pleaseSelectARole)),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isSending = true);

    try {
      // Check if user is authenticated
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      AppLogger.debug('Sending notification as user: ${currentUser.uid}');

      // Debug: Show FCM tokens for selected recipients
      if (_recipientType == 'individual' || _recipientType == 'selected') {
        AppLogger.debug('=== FCM Token Debug ===');
        AppLogger.debug('Selected user IDs: $_selectedUserIds');

        for (final userId in _selectedUserIds) {
          try {
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .get();

            if (userDoc.exists) {
              final userData = userDoc.data()!;
              final fcmTokens = userData['fcmTokens'] as List?;
              final userName =
                  '${userData['first_name']} ${userData['last_name']}';
              final userEmail = userData['e-mail'] ?? userData['email'];

              AppLogger.debug('User: $userName ($userEmail)');
              AppLogger.debug('  User ID: $userId');
              AppLogger.debug('  FCM Tokens: ${fcmTokens?.length ?? 0} tokens');

              if (fcmTokens != null && fcmTokens.isNotEmpty) {
                for (var i = 0; i < fcmTokens.length; i++) {
                  final tokenData = fcmTokens[i] as Map<String, dynamic>;
                  final token = tokenData['token'] as String?;
                  final platform = tokenData['platform'] ?? 'unknown';
                  final lastUpdated = tokenData['lastUpdated'];

                  AppLogger.info(
                      '  Token $i: ${token?.substring(0, 20)}... (platform: $platform, updated: $lastUpdated)');
                }
              } else {
                AppLogger.error('  ⚠️ No FCM tokens found for this user!');
              }
            }
          } catch (e) {
            AppLogger.error('Error fetching FCM token info for $userId: $e');
          }
        }
        AppLogger.error('=== End FCM Token Debug ===');
      }

      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('sendAdminNotification');

      final result = await callable.call({
        'recipientType': _recipientType,
        'recipientRole': _selectedRole,
        'recipientIds': _selectedUserIds,
        'notificationTitle': _titleController.text.trim(),
        'notificationBody': _bodyController.text.trim(),
        'sendEmail': _sendEmail,
        'adminId': currentUser.uid,
      });

      final data = result.data as Map<String, dynamic>;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['message'] ??
                  AppLocalizations.of(context)!.notificationSentSuccess,
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Show detailed results
        if (data['results'] != null) {
          final results = data['results'] as Map<String, dynamic>;
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(AppLocalizations.of(context)!.notificationResults),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.of(context)!
                      .notificationTotalRecipients(results['totalRecipients'])),
                  SizedBox(height: 8),
                  Text(AppLocalizations.of(context)!.pushNotifications),
                  Text(AppLocalizations.of(context)!
                      .notificationSuccessCount(results['fcmSuccess'])),
                  Text(AppLocalizations.of(context)!
                      .notificationFailedCount(results['fcmFailed'])),
                  if (_sendEmail) ...[
                    const SizedBox(height: 8),
                    Text(AppLocalizations.of(context)!.emailNotifications),
                    Text(AppLocalizations.of(context)!
                        .notificationEmailsSentCount(results['emailsSent'])),
                    Text(AppLocalizations.of(context)!
                        .notificationEmailsFailedCount(
                            results['emailsFailed'])),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(AppLocalizations.of(context)!.commonOk),
                ),
              ],
            ),
          );
        }

        // Clear form
        _titleController.clear();
        _bodyController.clear();
        setState(() {
          _selectedUserIds.clear();
          _sendEmail = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(AppLocalizations.of(context)!.errorSendingNotificationE),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.sendNotification,
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: const Color(0xff111827),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.1),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildZoomCapacityForecastPanel(),
            _buildZoomGuardrailAttemptsPanel(),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left side - Notification form
                  Expanded(
                    flex: 3,
                    child: Container(
                      margin: const EdgeInsets.all(24),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.composeNotification,
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xff111827),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Recipient Type Selection
                            Text(
                              AppLocalizations.of(context)!.sendTo,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xff374151),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                border:
                                    Border.all(color: const Color(0xffE5E7EB)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  RadioListTile<String>(
                                    title: Text(
                                      AppLocalizations.of(context)!
                                          .individualUser,
                                      style: GoogleFonts.inter(fontSize: 14),
                                    ),
                                    value: 'individual',
                                    groupValue: _recipientType,
                                    onChanged: (value) {
                                      setState(() {
                                        _recipientType = value!;
                                        _selectedRole = null;
                                        _filterUsers(_searchQuery);
                                      });
                                    },
                                  ),
                                  const Divider(height: 1),
                                  RadioListTile<String>(
                                    title: Text(
                                      AppLocalizations.of(context)!
                                          .allUsersInRole,
                                      style: GoogleFonts.inter(fontSize: 14),
                                    ),
                                    value: 'role',
                                    groupValue: _recipientType,
                                    onChanged: (value) {
                                      setState(() {
                                        _recipientType = value!;
                                        _selectedUserIds.clear();
                                      });
                                    },
                                  ),
                                  const Divider(height: 1),
                                  RadioListTile<String>(
                                    title: Text(
                                      AppLocalizations.of(context)!
                                          .selectedUsers,
                                      style: GoogleFonts.inter(fontSize: 14),
                                    ),
                                    value: 'selected',
                                    groupValue: _recipientType,
                                    onChanged: (value) {
                                      setState(() {
                                        _recipientType = value!;
                                        _selectedRole = null;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),

                            // Role Selection (when sending to role)
                            if (_recipientType == 'role') ...[
                              SizedBox(height: 16),
                              Text(
                                AppLocalizations.of(context)!.selectRole,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xff374151),
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: _selectedRole,
                                decoration: InputDecoration(
                                  hintText:
                                      AppLocalizations.of(context)!.chooseARole,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: Color(0xffE5E7EB)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: Color(0xffE5E7EB)),
                                  ),
                                ),
                                items: [
                                  DropdownMenuItem(
                                      value: 'teacher',
                                      child: Text(AppLocalizations.of(context)!
                                          .teachers)),
                                  DropdownMenuItem(
                                      value: 'student',
                                      child: Text(AppLocalizations.of(context)!
                                          .shiftStudents)),
                                  DropdownMenuItem(
                                      value: 'parent',
                                      child: Text(AppLocalizations.of(context)!
                                          .parents)),
                                  DropdownMenuItem(
                                      value: 'admin',
                                      child: Text(AppLocalizations.of(context)!
                                          .admins)),
                                ],
                                onChanged: (value) {
                                  setState(() => _selectedRole = value);
                                },
                                validator: (value) {
                                  if (_recipientType == 'role' &&
                                      value == null) {
                                    return 'Please select a role';
                                  }
                                  return null;
                                },
                              ),
                            ],

                            const SizedBox(height: 24),

                            // Notification Title
                            Text(
                              AppLocalizations.of(context)!.notificationTitle,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xff374151),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _titleController,
                              decoration: InputDecoration(
                                hintText: AppLocalizations.of(context)!
                                    .enterNotificationTitle,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                      color: Color(0xffE5E7EB)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                      color: Color(0xffE5E7EB)),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter a title';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            // Notification Body
                            Text(
                              AppLocalizations.of(context)!.notificationMessage,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xff374151),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _bodyController,
                              maxLines: 6,
                              decoration: InputDecoration(
                                hintText: AppLocalizations.of(context)!
                                    .enterNotificationMessage,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                      color: Color(0xffE5E7EB)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                      color: Color(0xffE5E7EB)),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter a message';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            // Send Email Option
                            CheckboxListTile(
                              title: Text(
                                AppLocalizations.of(context)!
                                    .alsoSendAsEmailNotification,
                                style: GoogleFonts.inter(fontSize: 14),
                              ),
                              subtitle: Text(
                                AppLocalizations.of(context)!
                                    .recipientsWillReceiveBothPushNotification,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xff6B7280),
                                ),
                              ),
                              value: _sendEmail,
                              onChanged: (value) {
                                setState(() => _sendEmail = value ?? false);
                              },
                              controlAffinity: ListTileControlAffinity.leading,
                            ),

                            SizedBox(height: 24),

                            // Send Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed:
                                    _isSending ? null : _sendNotification,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xff3B82F6),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: _isSending
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      )
                                    : Text(
                                        AppLocalizations.of(context)!
                                            .sendNotification,
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Right side - User selection (for individual/selected)
                  if (_recipientType != 'role')
                    Expanded(
                      flex: 2,
                      child: Container(
                        margin: const EdgeInsets.only(
                            top: 24, right: 24, bottom: 24),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _recipientType == 'individual'
                                  ? AppLocalizations.of(context)!.selectUser
                                  : AppLocalizations.of(context)!.selectUsers,
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xff111827),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Search and Filter
                            TextField(
                              decoration: InputDecoration(
                                hintText: AppLocalizations.of(context)!
                                    .userSearchUsers,
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                      color: Color(0xffE5E7EB)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                      color: Color(0xffE5E7EB)),
                                ),
                              ),
                              onChanged: _filterUsers,
                            ),
                            const SizedBox(height: 12),

                            // Role Filter
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                border:
                                    Border.all(color: const Color(0xffE5E7EB)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButton<String?>(
                                value: _selectedRole,
                                hint: Text(
                                    AppLocalizations.of(context)!.filterByRole),
                                isExpanded: true,
                                underline: const SizedBox(),
                                items: [
                                  DropdownMenuItem(
                                      value: null,
                                      child: Text(AppLocalizations.of(context)!
                                          .allRoles)),
                                  DropdownMenuItem(
                                      value: 'teacher',
                                      child: Text(AppLocalizations.of(context)!
                                          .teachers)),
                                  DropdownMenuItem(
                                      value: 'student',
                                      child: Text(AppLocalizations.of(context)!
                                          .shiftStudents)),
                                  DropdownMenuItem(
                                      value: 'parent',
                                      child: Text(AppLocalizations.of(context)!
                                          .parents)),
                                  DropdownMenuItem(
                                      value: 'admin',
                                      child: Text(AppLocalizations.of(context)!
                                          .admins)),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedRole = value;
                                    _filterUsers(_searchQuery);
                                  });
                                },
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Selected count
                            if (_recipientType == 'selected')
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xffF3F4F6),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${_selectedUserIds.length} users selected',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xff374151),
                                  ),
                                ),
                              ),

                            const SizedBox(height: 16),

                            // User List
                            Expanded(
                              child: _isLoadingUsers
                                  ? const Center(
                                      child: CircularProgressIndicator())
                                  : ListView.builder(
                                      itemCount: _filteredUsers.length,
                                      itemBuilder: (context, index) {
                                        final user = _filteredUsers[index];
                                        final isSelected = _selectedUserIds
                                            .contains(user.documentId);

                                        return ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor:
                                                _getRoleColor(user.userType),
                                            child: Text(
                                              user.firstName.isNotEmpty
                                                  ? user.firstName[0]
                                                      .toUpperCase()
                                                  : '?',
                                              style: const TextStyle(
                                                  color: Colors.white),
                                            ),
                                          ),
                                          title: SelectableText(
                                            '${user.firstName} ${user.lastName}'
                                                .trim(),
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          subtitle: SelectableText(
                                            '${user.email} • ${_getRoleName(user.userType)}',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: const Color(0xff6B7280),
                                            ),
                                          ),
                                          trailing: _recipientType ==
                                                  'individual'
                                              ? Radio<String>(
                                                  value: user.documentId,
                                                  groupValue: _selectedUserIds
                                                          .isNotEmpty
                                                      ? _selectedUserIds.first
                                                      : null,
                                                  onChanged: (value) {
                                                    setState(() {
                                                      _selectedUserIds = [
                                                        value!
                                                      ];
                                                    });
                                                  },
                                                )
                                              : Checkbox(
                                                  value: isSelected,
                                                  onChanged: (value) {
                                                    setState(() {
                                                      if (value ?? false) {
                                                        _selectedUserIds.add(
                                                            user.documentId);
                                                      } else {
                                                        _selectedUserIds.remove(
                                                            user.documentId);
                                                      }
                                                    });
                                                  },
                                                ),
                                          onTap: () {
                                            if (_recipientType ==
                                                'individual') {
                                              setState(() {
                                                _selectedUserIds = [
                                                  user.documentId
                                                ];
                                              });
                                            } else {
                                              setState(() {
                                                if (isSelected) {
                                                  _selectedUserIds
                                                      .remove(user.documentId);
                                                } else {
                                                  _selectedUserIds
                                                      .add(user.documentId);
                                                }
                                              });
                                            }
                                          },
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
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

  Widget _buildZoomCapacityForecastPanel() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('admin_notifications')
          .orderBy('createdAt', descending: true)
          .limit(25)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = (snapshot.data?.docs ?? [])
            .where((doc) {
              final data = doc.data();
              return data['type'] == 'zoom_hub_capacity_forecast' &&
                  data['resolved'] != true &&
                  data['open'] != false;
            })
            .take(3)
            .toList();

        if (docs.isEmpty) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xffFDBA74)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Color(0xffEA580C)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Zoom schedule risks',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xff111827),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Daily hub forecast found future classes that need review.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xff6B7280),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 98,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final problemCount = data['problemCount'] ?? 0;
                    final horizonEnd = data['horizonEnd'] ?? '';
                    final body = (data['body'] ?? 'Review Zoom schedule risk.')
                        .toString();

                    return SizedBox(
                      width: 340,
                      child: Material(
                        color: const Color(0xffFFF7ED),
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _showZoomForecastDetails(data),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$problemCount future Zoom risk${problemCount == 1 ? '' : 's'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xff9A3412),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Through $horizonEnd',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: const Color(0xff374151),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Expanded(
                                  child: Text(
                                    body,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: const Color(0xff6B7280),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildZoomGuardrailAttemptsPanel() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('admin_notifications')
          .orderBy('createdAt', descending: true)
          .limit(25)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = (snapshot.data?.docs ?? [])
            .where((doc) => doc.data()['type'] == 'zoom_hub_shift_guardrail')
            .take(5)
            .toList();

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xffFCA5A5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Color(0xffDC2626)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Blocked Zoom shift attempts',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xff111827),
                      ),
                    ),
                  ),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Review unsafe class attempts that were blocked before saving.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xff6B7280),
                ),
              ),
              const SizedBox(height: 12),
              if (snapshot.hasError)
                Text(
                  'Could not load blocked Zoom shift attempts.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xffDC2626),
                  ),
                )
              else if (docs.isEmpty)
                Text(
                  snapshot.connectionState == ConnectionState.waiting
                      ? 'Loading blocked attempts...'
                      : 'No blocked Zoom shift attempts yet.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xff6B7280),
                  ),
                )
              else
                SizedBox(
                  height: 92,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final data = docs[index].data();
                      final shiftAttempt =
                          (data['shiftAttempt'] as Map?) ?? const {};
                      final teacher = (shiftAttempt['teacherName'] ??
                              data['teacherName'] ??
                              'Unknown teacher')
                          .toString();
                      final className = (shiftAttempt['customName'] ??
                              shiftAttempt['subjectDisplayName'] ??
                              shiftAttempt['subjectName'] ??
                              'Zoom class')
                          .toString();
                      final actor = (data['attemptedByName'] ??
                              data['attemptedByEmail'] ??
                              data['attemptedByUid'] ??
                              'Unknown admin')
                          .toString();

                      return SizedBox(
                        width: 300,
                        child: Material(
                          color: const Color(0xffFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => _showZoomGuardrailAttemptDetails(data),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    className,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xff991B1B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$teacher • $actor',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: const Color(0xff374151),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _formatAttemptTimestamp(
                                      data['createdAt'] ?? data['created_at'],
                                    ),
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: const Color(0xff6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _formatAttemptTimestamp(dynamic raw) {
    DateTime? date;
    if (raw is Timestamp) {
      date = raw.toDate();
    } else if (raw is DateTime) {
      date = raw;
    }
    if (date == null) return 'Time unavailable';
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  String _formatAttemptValue(dynamic value) {
    if (value == null) return '';
    if (value is Timestamp) return _formatAttemptTimestamp(value);
    if (value is DateTime) return _formatAttemptTimestamp(value);
    if (value is Iterable) {
      return value
          .map(_formatAttemptValue)
          .where((item) => item.isNotEmpty)
          .join(', ');
    }
    if (value is Map) {
      return value.entries
          .map((entry) => '${entry.key}: ${_formatAttemptValue(entry.value)}')
          .join('\n');
    }
    return value.toString();
  }

  void _showZoomGuardrailAttemptDetails(Map<String, dynamic> data) {
    final shiftAttempt =
        Map<String, dynamic>.from((data['shiftAttempt'] as Map?) ?? const {});
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Blocked Zoom shift attempt'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: SelectionArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Attempted by: ${data['attemptedByName'] ?? ''}'),
                  Text('Email: ${data['attemptedByEmail'] ?? ''}'),
                  Text('Operation: ${data['operation'] ?? ''}'),
                  Text(
                      'When: ${_formatAttemptTimestamp(data['createdAt'] ?? data['created_at'])}'),
                  const SizedBox(height: 12),
                  Text(
                    'Warning shown',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                  Text(_formatAttemptValue(data['guardrailMessage'])),
                  const SizedBox(height: 12),
                  Text(
                    'Entered shift information',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  ...shiftAttempt.entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '${entry.key}: ${_formatAttemptValue(entry.value)}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
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

  void _showZoomForecastDetails(Map<String, dynamic> data) {
    final problems = (data['problems'] as List?) ?? const [];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zoom schedule risk forecast'),
        content: SizedBox(
          width: 680,
          child: SingleChildScrollView(
            child: SelectionArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      'When: ${_formatAttemptTimestamp(data['createdAt'] ?? data['created_at'])}'),
                  Text(
                      'Horizon: ${data['horizonStart'] ?? ''} to ${data['horizonEnd'] ?? ''}'),
                  Text(
                      'Problem count: ${data['problemCount'] ?? problems.length}'),
                  const SizedBox(height: 12),
                  Text(
                    'Summary',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                  Text(_formatAttemptValue(data['summary'])),
                  const SizedBox(height: 12),
                  Text(
                    'Problems',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (problems.isEmpty)
                    const Text('No problem details available.')
                  else
                    ...problems.asMap().entries.map((entry) {
                      final problem = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          '${entry.key + 1}. ${_formatAttemptValue(problem)}',
                        ),
                      );
                    }),
                ],
              ),
            ),
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

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return const Color(0xffEF4444);
      case 'teacher':
        return const Color(0xff3B82F6);
      case 'student':
        return const Color(0xff10B981);
      case 'parent':
        return const Color(0xffF59E0B);
      default:
        return const Color(0xff6B7280);
    }
  }

  String _getRoleName(String role) {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'teacher':
        return 'Teacher';
      case 'student':
        return 'Student';
      case 'parent':
        return 'Parent';
      default:
        return role;
    }
  }
}
