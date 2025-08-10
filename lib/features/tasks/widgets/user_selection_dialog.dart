import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class UserSelectionDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<Map<String, dynamic>> availableUsers;
  final List<String> selectedUserIds;
  final bool allowMultiple;
  final Function(List<String>) onUsersSelected;

  const UserSelectionDialog({
    super.key,
    required this.title,
    required this.subtitle,
    required this.availableUsers,
    required this.selectedUserIds,
    required this.allowMultiple,
    required this.onUsersSelected,
  });

  @override
  State<UserSelectionDialog> createState() => _UserSelectionDialogState();
}

class _UserSelectionDialogState extends State<UserSelectionDialog> {
  final _searchController = TextEditingController();
  String _searchTerm = '';
  late List<String> _tempSelectedUserIds;

  @override
  void initState() {
    super.initState();
    _tempSelectedUserIds = List.from(widget.selectedUserIds);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchTerm.isEmpty) return widget.availableUsers;
    final term = _searchTerm.toLowerCase();
    return widget.availableUsers.where((user) {
      final name = user['name'].toString().toLowerCase();
      final email = user['email'].toString().toLowerCase();
      return name.contains(term) || email.contains(term);
    }).toList();
  }

  void _toggleUser(String userId) {
    setState(() {
      if (widget.allowMultiple) {
        if (_tempSelectedUserIds.contains(userId)) {
          _tempSelectedUserIds.remove(userId);
        } else {
          _tempSelectedUserIds.add(userId);
        }
      } else {
        _tempSelectedUserIds = [userId];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
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
                          widget.title,
                          style: GoogleFonts.openSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.subtitle,
                          style: GoogleFonts.openSans(
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
            // Search
            Padding(
              padding: const EdgeInsets.all(24),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search users by name or email...',
                  hintStyle: GoogleFonts.openSans(
                    color: const Color(0xffA0AEC0),
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xff718096),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xffE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xffE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xff0386FF), width: 2),
                  ),
                  filled: true,
                  fillColor: const Color(0xffF7FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchTerm = value;
                  });
                },
              ),
            ),
            // User List
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                child: _filteredUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _searchTerm.isNotEmpty ? Icons.search_off : Icons.people_outline,
                              size: 48,
                              color: const Color(0xff718096),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchTerm.isNotEmpty
                                  ? 'No users found matching "$_searchTerm"'
                                  : 'No users available',
                              style: GoogleFonts.openSans(
                                fontSize: 16,
                                color: const Color(0xff718096),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          final isSelected = _tempSelectedUserIds.contains(user['id']);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => _toggleUser(user['id']),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
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
                                      CircleAvatar(
                                        backgroundColor: const Color(0xff0386FF).withOpacity(0.1),
                                        child: Text(
                                          user['name'].isNotEmpty
                                              ? user['name'][0].toUpperCase()
                                              : 'U',
                                          style: GoogleFonts.openSans(
                                            color: const Color(0xff0386FF),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              user['name'],
                                              style: GoogleFonts.openSans(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                                color: const Color(0xff2D3748),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              user['email'],
                                              style: GoogleFonts.openSans(
                                                fontSize: 14,
                                                color: const Color(0xff718096),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(
                                          widget.allowMultiple 
                                              ? Icons.check_circle
                                              : Icons.radio_button_checked,
                                          color: const Color(0xff0386FF),
                                          size: 24,
                                        )
                                      else
                                        Icon(
                                          widget.allowMultiple 
                                              ? Icons.check_circle_outline
                                              : Icons.radio_button_unchecked,
                                          color: const Color(0xff718096),
                                          size: 24,
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
            ),
            // Footer
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xffE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  if (widget.allowMultiple) ...[
                    Text(
                      '${_tempSelectedUserIds.length} selected',
                      style: GoogleFonts.openSans(
                        fontSize: 14,
                        color: const Color(0xff718096),
                      ),
                    ),
                    const Spacer(),
                  ] else ...[
                    const Spacer(),
                  ],
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.openSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xff718096),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _tempSelectedUserIds.isNotEmpty
                        ? () {
                            widget.onUsersSelected(_tempSelectedUserIds);
                            Navigator.of(context).pop();
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff0386FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      widget.allowMultiple ? 'Select Users' : 'Select User',
                      style: GoogleFonts.openSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
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
}