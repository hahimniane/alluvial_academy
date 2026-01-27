import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class UserSelectionDialog extends StatefulWidget {
  final List<String> selectedUserIds;
  final Function(List<String>) onUsersSelected;

  const UserSelectionDialog({
    super.key,
    required this.selectedUserIds,
    required this.onUsersSelected,
  });

  @override
  State<UserSelectionDialog> createState() => _UserSelectionDialogState();
}

class _UserSelectionDialogState extends State<UserSelectionDialog> {
  final _searchController = TextEditingController();
  bool _showCrossGroupSelection = false;
  List<String> _selectedUserIds = [];
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String _searchTerm = '';

  final List<Map<String, String>> _userRoles = [
    {'id': 'students', 'name': 'Students', 'icon': '🎓'},
    {'id': 'parents', 'name': 'Parents', 'icon': '👨‍👩‍👧‍👦'},
    {'id': 'teachers', 'name': 'Teachers', 'icon': '👩‍🏫'},
    {'id': 'admins', 'name': 'Admins', 'icon': '👨‍💼'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedUserIds = List<String>.from(widget.selectedUserIds);
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('status', isEqualTo: 'active')
          .get();

      setState(() {
        _users = usersSnapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  'email': doc.data()['email'] ?? '',
                  'firstName': doc.data()['first_name'] ?? '',
                  'lastName': doc.data()['last_name'] ?? '',
                  'role': doc.data()['role'] ?? '',
                })
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('Error loading users: $e');
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchTerm.isEmpty) return _users;
    final term = _searchTerm.toLowerCase();
    return _users.where((user) {
      final firstName = user['firstName'].toString().toLowerCase();
      final lastName = user['lastName'].toString().toLowerCase();
      final email = user['email'].toString().toLowerCase();
      return firstName.contains(term) ||
          lastName.contains(term) ||
          email.contains(term) ||
          '$firstName $lastName'.contains(term);
    }).toList();
  }

  void _toggleUserSelection(String userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }

  void _selectUserGroup(String roleId) {
    final usersInGroup = _users
        .where((u) => u['role'] == roleId)
        .map((u) => u['id'] as String)
        .toList();
    setState(() {
      _selectedUserIds = usersInGroup;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xff0386FF),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.selectUsers2,
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppLocalizations.of(context)!.filterFormResponsesByUser,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: Column(
                children: [
                  // Selection method
                  Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xffEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xffBFDBFE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.selectionMethod,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xff1E40AF),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Radio<bool>(
                              value: false,
                              groupValue: _showCrossGroupSelection,
                              onChanged: (value) {
                                setState(() {
                                  _showCrossGroupSelection = value!;
                                  _selectedUserIds.clear();
                                });
                              },
                              activeColor: const Color(0xff3B82F6),
                            ),
                            Flexible(
                              child: Text(
                                AppLocalizations.of(context)!.selectByUserGroupEG,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(0xff1E40AF),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Radio<bool>(
                              value: true,
                              groupValue: _showCrossGroupSelection,
                              onChanged: (value) {
                                setState(() {
                                  _showCrossGroupSelection = value!;
                                  _selectedUserIds.clear();
                                });
                              },
                              activeColor: const Color(0xff3B82F6),
                            ),
                            Flexible(
                              child: Text(
                                AppLocalizations.of(context)!.selectIndividualUsers,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(0xff1E40AF),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // User list
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xffE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _showCrossGroupSelection ? 'Users' : 'User Groups',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xff374151),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_showCrossGroupSelection) ...[
                            // Search
                            TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: AppLocalizations.of(context)!.userSearchUsers,
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _searchTerm = value;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                          ],
                          // User/group list
                          Expanded(
                            child: _isLoading
                                ? const Center(
                                    child: CircularProgressIndicator())
                                : _showCrossGroupSelection
                                    ? _buildUserList()
                                    : _buildGroupList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Actions
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Color(0xffE2E8F0)),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            AppLocalizations.of(context)!.commonCancel,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: const Color(0xff6B7280),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () {
                            widget.onUsersSelected(_selectedUserIds);
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff0386FF),
                            foregroundColor: Colors.white,
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.commonApply,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildUserList() {
    return ListView.builder(
      itemCount: _filteredUsers.length,
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        final isSelected = _selectedUserIds.contains(user['id']);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? const Color(0xff0386FF)
                  : const Color(0xffE2E8F0),
              width: isSelected ? 2 : 1,
            ),
            color: isSelected
                ? const Color(0xff0386FF).withOpacity(0.05)
                : Colors.white,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${user['firstName']} ${user['lastName']}'.trim(),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xff111827),
                      ),
                    ),
                    Text(
                      user['email'],
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xff6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              Checkbox(
                value: isSelected,
                onChanged: (value) => _toggleUserSelection(user['id']),
                activeColor: const Color(0xff0386FF),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGroupList() {
    return ListView.builder(
      itemCount: _userRoles.length,
      itemBuilder: (context, index) {
        final role = _userRoles[index];
        final usersInGroup =
            _users.where((u) => u['role'] == role['id']).toList();
        final allSelected =
            usersInGroup.every((u) => _selectedUserIds.contains(u['id']));

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: allSelected
                  ? const Color(0xff0386FF)
                  : const Color(0xffE2E8F0),
              width: allSelected ? 2 : 1,
            ),
            color: allSelected
                ? const Color(0xff0386FF).withOpacity(0.05)
                : Colors.white,
          ),
          child: Row(
            children: [
              Text(
                role['icon']!,
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role['name']!,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xff111827),
                      ),
                    ),
                    Text(
                      '${usersInGroup.length} users',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xff6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              Checkbox(
                value: allSelected,
                onChanged: (value) {
                  if (value == true) {
                    _selectUserGroup(role['id']!);
                  } else {
                    setState(() {
                      _selectedUserIds.removeWhere(
                          (id) => usersInGroup.any((u) => u['id'] == id));
                    });
                  }
                },
                activeColor: const Color(0xff0386FF),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
