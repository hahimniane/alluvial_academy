import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/employee_model.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class MobileNotificationScreen extends StatefulWidget {
  const MobileNotificationScreen({super.key});

  @override
  State<MobileNotificationScreen> createState() => _MobileNotificationScreenState();
}

class _MobileNotificationScreenState extends State<MobileNotificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  String _recipientType = 'everyone'; // 'everyone', 'role', 'individual'
  String? _selectedRole; // 'teacher', 'student', 'parent', 'admin'
  List<String> _selectedUserIds = [];
  bool _isSending = false;

  // For user selection
  List<Employee> _allUsers = [];
  List<Employee> _filteredUsers = [];
  String _searchQuery = '';
  bool _isLoadingUsers = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
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

      users.sort((a, b) => '${a.firstName} ${a.lastName}'.compareTo('${b.firstName} ${b.lastName}'));

      setState(() {
        _allUsers = users;
        _filteredUsers = users;
        _isLoadingUsers = false;
      });
    } catch (e) {
      setState(() => _isLoadingUsers = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorLoadingUsersE)),
        );
      }
    }
  }


  Future<void> _sendNotification() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSending = true);

    try {
      // Check if user is authenticated
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      AppLogger.debug('Sending notification as user: ${currentUser.uid}');

      // Determine recipient IDs based on recipient type
      List<String> recipientIds = [];
      String actualRecipientType = _recipientType;

      if (_recipientType == 'everyone') {
        // Get all active users
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('is_active', isEqualTo: true)
            .get();
        recipientIds = snapshot.docs.map((doc) => doc.id).toList();
        actualRecipientType = 'selected'; // Use selected type with all IDs
      } else if (_recipientType == 'individual') {
        recipientIds = _selectedUserIds;
        actualRecipientType = 'selected';
      }

      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('sendAdminNotification');

      final result = await callable.call({
        'recipientType': actualRecipientType,
        'recipientRole': _selectedRole,
        'recipientIds': recipientIds,
        'notificationTitle': _titleController.text.trim(),
        'notificationBody': _bodyController.text.trim(),
        'sendEmail': false, // Simplified for mobile - no email option
        'adminId': currentUser.uid,
      });

      final data = result.data as Map<String, dynamic>;

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['message'] ??
                  AppLocalizations.of(context)!.notificationSentSuccess,
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Show results dialog
        if (data['results'] != null) {
          final results = data['results'] as Map<String, dynamic>;
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(AppLocalizations.of(context)!.notificationSent),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.of(context)!
                      .notificationRecipients(results['totalRecipients'])),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Text(AppLocalizations.of(context)!
                          .notificationSuccessCount(results['fcmSuccess'])),
                    ],
                  ),
                  if (results['fcmFailed'] > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.error, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Text(AppLocalizations.of(context)!
                            .notificationFailedCount(results['fcmFailed'])),
                      ],
                    ),
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
          _recipientType = 'everyone';
          _selectedRole = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.commonErrorWithDetails(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _showUserSelectionSheet() async {
    // Load users first if not already loaded
    if (_allUsers.isEmpty) {
      await _loadUsers();
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Title
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.selectUsers2,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_selectedUserIds.isNotEmpty)
                            Text(
                              '${_selectedUserIds.length} selected',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xff3B82F6),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                // Search bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.userSearchUsers,
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (query) {
                      setModalState(() {
                        _searchQuery = query.toLowerCase();
                        if (_searchQuery.isEmpty) {
                          _filteredUsers = _allUsers;
                        } else {
                          _filteredUsers = _allUsers.where((user) {
                            return user.firstName.toLowerCase().contains(_searchQuery) ||
                                user.lastName.toLowerCase().contains(_searchQuery) ||
                                user.email.toLowerCase().contains(_searchQuery);
                          }).toList();
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // User list
                Expanded(
                  child: _isLoadingUsers
                      ? Center(child: CircularProgressIndicator())
                      : _filteredUsers.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchQuery.isEmpty
                                        ? AppLocalizations.of(context)!.noUsersFound
                                        : AppLocalizations.of(context)!.noUsersMatchSearch,
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _filteredUsers.length,
                              itemBuilder: (context, index) {
                                if (index < 0 || index >= _filteredUsers.length) {
                                  return const SizedBox.shrink();
                                }
                                final user = _filteredUsers[index];
                                final isSelected = _selectedUserIds.contains(user.documentId);

                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: _getRoleColor(user.userType),
                                    child: Text(
                                      user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : '?',
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  title: Text(
                                    '${user.firstName} ${user.lastName}'.trim(),
                                    style: GoogleFonts.inter(fontSize: 14),
                                  ),
                                  subtitle: Text(
                                    '${user.email} • ${_getRoleName(user.userType)}',
                                    style: GoogleFonts.inter(fontSize: 12),
                                  ),
                                  trailing: Checkbox(
                                    value: isSelected,
                                    onChanged: (bool? value) {
                                      setModalState(() {
                                        if (value == true) {
                                          _selectedUserIds.add(user.documentId);
                                        } else {
                                          _selectedUserIds.remove(user.documentId);
                                        }
                                      });
                                    },
                                    activeColor: const Color(0xff3B82F6),
                                  ),
                                  onTap: () {
                                    setModalState(() {
                                      if (isSelected) {
                                        _selectedUserIds.remove(user.documentId);
                                      } else {
                                        _selectedUserIds.add(user.documentId);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                ),
                // Confirm button
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _selectedUserIds.isEmpty
                            ? null
                            : () {
                                setState(() {
                                  // Update parent state
                                });
                                Navigator.pop(context);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff3B82F6),
                          disabledBackgroundColor: Colors.grey[300],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          _selectedUserIds.isEmpty
                              ? AppLocalizations.of(context)!.notificationSelectAtLeastOneUser
                              : AppLocalizations.of(context)!
                                  .notificationConfirmSelected(_selectedUserIds.length),
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _selectedUserIds.isEmpty
                                ? Colors.grey[600]
                                : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.sendNotification,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quick send options
              Container(
                padding: const EdgeInsets.all(16),
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
                    Text(
                      AppLocalizations.of(context)!.sendTo2,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Recipient selection chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.people, size: 18),
                              const SizedBox(width: 4),
                              Text(AppLocalizations.of(context)!.everyone),
                            ],
                          ),
                          selected: _recipientType == 'everyone',
                          onSelected: (selected) {
                            setState(() {
                              _recipientType = 'everyone';
                              _selectedRole = null;
                              _selectedUserIds.clear();
                            });
                          },
                          selectedColor: const Color(0xff3B82F6),
                          labelStyle: TextStyle(
                            color: _recipientType == 'everyone' ? Colors.white : Colors.black,
                          ),
                        ),
                        ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.group, size: 18),
                              const SizedBox(width: 4),
                              Text(AppLocalizations.of(context)!.byRole),
                            ],
                          ),
                          selected: _recipientType == 'role',
                          onSelected: (selected) {
                            setState(() {
                              _recipientType = 'role';
                              _selectedUserIds.clear();
                            });
                          },
                          selectedColor: const Color(0xff3B82F6),
                          labelStyle: TextStyle(
                            color: _recipientType == 'role' ? Colors.white : Colors.black,
                          ),
                        ),
                        ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person, size: 18),
                              const SizedBox(width: 4),
                              Text(AppLocalizations.of(context)!.individual),
                            ],
                          ),
                          selected: _recipientType == 'individual',
                          onSelected: (selected) {
                            setState(() {
                              _recipientType = 'individual';
                              _selectedRole = null;
                            });
                          },
                          selectedColor: const Color(0xff3B82F6),
                          labelStyle: TextStyle(
                            color: _recipientType == 'individual' ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),

                    // Role selection dropdown (when role is selected)
                    if (_recipientType == 'role') ...[
                      SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedRole,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.selectRole,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        items: [
                          DropdownMenuItem(value: 'teacher', child: Text(AppLocalizations.of(context)!.allTeachers)),
                          DropdownMenuItem(value: 'student', child: Text(AppLocalizations.of(context)!.allStudents)),
                          DropdownMenuItem(value: 'parent', child: Text(AppLocalizations.of(context)!.allParents)),
                          DropdownMenuItem(value: 'admin', child: Text(AppLocalizations.of(context)!.allAdmins)),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedRole = value);
                        },
                        validator: (value) {
                          if (_recipientType == 'role' && value == null) {
                            return AppLocalizations.of(context)!.pleaseSelectARole;
                          }
                          return null;
                        },
                      ),
                    ],

                    // Individual user selection
                    if (_recipientType == 'individual') ...[
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: _showUserSelectionSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedUserIds.isEmpty
                                      ? AppLocalizations.of(context)!.tapToSelectUsers
                                      : _getSelectedUsersText(),
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: _selectedUserIds.isEmpty ? Colors.grey : Colors.black,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down),
                            ],
                          ),
                        ),
                      ),
                      if (_selectedUserIds.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _selectedUserIds.map((userId) {
                            final user = _allUsers.firstWhere(
                              (u) => u.documentId == userId,
                              orElse: () => Employee(
                                documentId: '',
                                email: '',
                                firstName: AppLocalizations.of(context)!.commonUnknown,
                                lastName: AppLocalizations.of(context)!.commonUser,
                                countryCode: '',
                                mobilePhone: '',
                                userType: '',
                                title: AppLocalizations.of(context)!.text2,
                                employmentStartDate: '',
                                kioskCode: '',
                                dateAdded: '',
                                lastLogin: '',
                                isActive: true,
                              ),
                            );
                            return Chip(
                              avatar: CircleAvatar(
                                backgroundColor: _getRoleColor(user.userType),
                                child: Text(
                                  user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : '?',
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ),
                              label: Text(
                                '${user.firstName} ${user.lastName}'.trim(),
                                style: GoogleFonts.inter(fontSize: 12),
                              ),
                              deleteIcon: const Icon(Icons.close, size: 18),
                              onDeleted: () {
                                setState(() {
                                  _selectedUserIds.remove(userId);
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Notification content
              Container(
                padding: const EdgeInsets.all(16),
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
                    Text(
                      AppLocalizations.of(context)!.notificationContent,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title field
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.profileTitle,
                        hintText: AppLocalizations.of(context)!.enterNotificationTitle,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return AppLocalizations.of(context)!.notificationEnterTitle;
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Message field
                    TextFormField(
                      controller: _bodyController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.message,
                        hintText: AppLocalizations.of(context)!.enterNotificationMessage,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                        alignLabelWithHint: true,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return AppLocalizations.of(context)!.notificationEnterMessage;
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Send button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSending ? null : _sendNotification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff3B82F6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: _isSending
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.send, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              AppLocalizations.of(context)!.sendNotification,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Info card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.notificationsWillBeSentInstantlyTo,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.blue[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getSelectedUsersText() {
    if (_selectedUserIds.isEmpty) return '';
    if (_selectedUserIds.length == 1) {
      final user = _allUsers.firstWhere(
        (u) => u.documentId == _selectedUserIds.first,
        orElse: () => Employee(
          documentId: '',
          email: '',
          firstName: AppLocalizations.of(context)!.commonUnknown,
          lastName: AppLocalizations.of(context)!.commonUser,
          countryCode: '',
          mobilePhone: '',
          userType: '',
          title: AppLocalizations.of(context)!.text2,
          employmentStartDate: '',
          kioskCode: '',
          dateAdded: '',
          lastLogin: '',
          isActive: true,
        ),
      );
      return '${user.firstName} ${user.lastName}'.trim();
    }
    return AppLocalizations.of(context)!.notificationUsersSelected(_selectedUserIds.length);
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
    final l10n = AppLocalizations.of(context)!;
    switch (role) {
      case 'admin':
        return l10n.roleAdmin;
      case 'teacher':
        return l10n.roleTeacher;
      case 'student':
        return l10n.roleStudent;
      case 'parent':
        return l10n.roleParent;
      default:
        return role;
    }
  }
}
