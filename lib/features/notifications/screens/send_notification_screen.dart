import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/employee_model.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
      
      users.sort((a, b) => '${a.firstName} ${a.lastName}'.compareTo('${b.firstName} ${b.lastName}'));
      
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
        SnackBar(content: Text(AppLocalizations.of(context)!.errorLoadingUsersE)),
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
          final matchesSearch = _searchQuery.isEmpty ||
              user.firstName.toLowerCase().contains(_searchQuery) ||
              user.lastName.toLowerCase().contains(_searchQuery) ||
              user.email.toLowerCase().contains(_searchQuery);
          
          final matchesRole = _selectedRole == null || user.userType == _selectedRole;
          
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
          const SnackBar(content: Text(AppLocalizations.of(context)!.pleaseSelectAtLeastOneRecipient)),
        );
        return;
      }
    } else if (_recipientType == 'role' && _selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppLocalizations.of(context)!.pleaseSelectARole)),
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
              final userName = '${userData['first_name']} ${userData['last_name']}';
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
                  
                  AppLogger.info('  Token $i: ${token?.substring(0, 20)}... (platform: $platform, updated: $lastUpdated)');
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
            content: Text(data['message'] ?? 'Notifications sent successfully'),
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
                  Text('Total Recipients: ${results['totalRecipients']}'),
                  const SizedBox(height: 8),
                  Text(AppLocalizations.of(context)!.pushNotifications),
                  Text('  ✓ Success: ${results['fcmSuccess']}'),
                  Text('  ✗ Failed: ${results['fcmFailed']}'),
                  if (_sendEmail) ...[
                    const SizedBox(height: 8),
                    Text(AppLocalizations.of(context)!.emailNotifications),
                    Text('  ✓ Sent: ${results['emailsSent']}'),
                    Text('  ✗ Failed: ${results['emailsFailed']}'),
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
            content: Text(AppLocalizations.of(context)!.errorSendingNotificationE),
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
                          border: Border.all(color: const Color(0xffE5E7EB)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            RadioListTile<String>(
                              title: Text(
                                AppLocalizations.of(context)!.individualUser,
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
                                AppLocalizations.of(context)!.allUsersInRole,
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
                                AppLocalizations.of(context)!.selectedUsers,
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
                        const SizedBox(height: 16),
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
                            hintText: AppLocalizations.of(context)!.chooseARole,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xffE5E7EB)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xffE5E7EB)),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'teacher', child: Text(AppLocalizations.of(context)!.teachers2)),
                            DropdownMenuItem(value: 'student', child: Text(AppLocalizations.of(context)!.shiftStudents)),
                            DropdownMenuItem(value: 'parent', child: Text(AppLocalizations.of(context)!.parents)),
                            DropdownMenuItem(value: 'admin', child: Text(AppLocalizations.of(context)!.admins)),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedRole = value);
                          },
                          validator: (value) {
                            if (_recipientType == 'role' && value == null) {
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
                          hintText: AppLocalizations.of(context)!.enterNotificationTitle,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xffE5E7EB)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xffE5E7EB)),
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
                          hintText: AppLocalizations.of(context)!.enterNotificationMessage,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xffE5E7EB)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xffE5E7EB)),
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
                          AppLocalizations.of(context)!.alsoSendAsEmailNotification,
                          style: GoogleFonts.inter(fontSize: 14),
                        ),
                        subtitle: Text(
                          AppLocalizations.of(context)!.recipientsWillReceiveBothPushNotification,
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
                      
                      const SizedBox(height: 24),
                      
                      // Send Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSending ? null : _sendNotification,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff3B82F6),
                            padding: const EdgeInsets.symmetric(vertical: 16),
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
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  AppLocalizations.of(context)!.sendNotification,
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
                  margin: const EdgeInsets.only(top: 24, right: 24, bottom: 24),
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
                        _recipientType == 'individual' ? 'Select User' : 'Select Users',
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
                          hintText: AppLocalizations.of(context)!.userSearchUsers,
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xffE5E7EB)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xffE5E7EB)),
                          ),
                        ),
                        onChanged: _filterUsers,
                      ),
                      const SizedBox(height: 12),
                      
                      // Role Filter
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xffE5E7EB)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<String?>(
                          value: _selectedRole,
                          hint: Text(AppLocalizations.of(context)!.filterByRole),
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(value: null, child: Text(AppLocalizations.of(context)!.allRoles)),
                            DropdownMenuItem(value: 'teacher', child: Text(AppLocalizations.of(context)!.teachers2)),
                            DropdownMenuItem(value: 'student', child: Text(AppLocalizations.of(context)!.shiftStudents)),
                            DropdownMenuItem(value: 'parent', child: Text(AppLocalizations.of(context)!.parents)),
                            DropdownMenuItem(value: 'admin', child: Text(AppLocalizations.of(context)!.admins)),
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                            ? const Center(child: CircularProgressIndicator())
                            : ListView.builder(
                                itemCount: _filteredUsers.length,
                                itemBuilder: (context, index) {
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
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${user.email} • ${_getRoleName(user.userType)}',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: const Color(0xff6B7280),
                                      ),
                                    ),
                                    trailing: _recipientType == 'individual'
                                        ? Radio<String>(
                                            value: user.documentId,
                                            groupValue: _selectedUserIds.isNotEmpty ? _selectedUserIds.first : null,
                                            onChanged: (value) {
                                              setState(() {
                                                _selectedUserIds = [value!];
                                              });
                                            },
                                          )
                                        : Checkbox(
                                            value: isSelected,
                                            onChanged: (value) {
                                              setState(() {
                                                if (value ?? false) {
                                                  _selectedUserIds.add(user.documentId);
                                                } else {
                                                  _selectedUserIds.remove(user.documentId);
                                                }
                                              });
                                            },
                                          ),
                                    onTap: () {
                                      if (_recipientType == 'individual') {
                                        setState(() {
                                          _selectedUserIds = [user.documentId];
                                        });
                                      } else {
                                        setState(() {
                                          if (isSelected) {
                                            _selectedUserIds.remove(user.documentId);
                                          } else {
                                            _selectedUserIds.add(user.documentId);
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
