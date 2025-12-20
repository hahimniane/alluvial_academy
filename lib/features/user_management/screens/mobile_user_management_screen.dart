import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/employee_model.dart';

class MobileUserManagementScreen extends StatefulWidget {
  const MobileUserManagementScreen({super.key});

  @override
  State<MobileUserManagementScreen> createState() => _MobileUserManagementScreenState();
}

class _MobileUserManagementScreenState extends State<MobileUserManagementScreen> {
  List<Employee> _users = [];
  List<Employee> _filteredUsers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedRoleFilter;
  bool? _activeFilter;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
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
        _users = users;
        _filteredUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading users: $e')),
        );
      }
    }
  }

  void _filterUsers() {
    setState(() {
      _filteredUsers = _users.where((user) {
        // Search query filter
        final matchesSearch = _searchQuery.isEmpty ||
            user.firstName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            user.lastName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            user.email.toLowerCase().contains(_searchQuery.toLowerCase());

        // Role filter
        final matchesRole = _selectedRoleFilter == null || user.userType == _selectedRoleFilter;

        // Active status filter
        final matchesActive = _activeFilter == null || user.isActive == _activeFilter;

        return matchesSearch && matchesRole && matchesActive;
      }).toList();
    });
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Filter Users',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),

              // Role filter
              Text(
                'Role',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: _selectedRoleFilter == null,
                    onSelected: (selected) {
                      setModalState(() => _selectedRoleFilter = null);
                      setState(() => _selectedRoleFilter = null);
                      _filterUsers();
                    },
                  ),
                  FilterChip(
                    label: const Text('Admin'),
                    selected: _selectedRoleFilter == 'admin',
                    onSelected: (selected) {
                      setModalState(() => _selectedRoleFilter = selected ? 'admin' : null);
                      setState(() => _selectedRoleFilter = selected ? 'admin' : null);
                      _filterUsers();
                    },
                  ),
                  FilterChip(
                    label: const Text('Teacher'),
                    selected: _selectedRoleFilter == 'teacher',
                    onSelected: (selected) {
                      setModalState(() => _selectedRoleFilter = selected ? 'teacher' : null);
                      setState(() => _selectedRoleFilter = selected ? 'teacher' : null);
                      _filterUsers();
                    },
                  ),
                  FilterChip(
                    label: const Text('Student'),
                    selected: _selectedRoleFilter == 'student',
                    onSelected: (selected) {
                      setModalState(() => _selectedRoleFilter = selected ? 'student' : null);
                      setState(() => _selectedRoleFilter = selected ? 'student' : null);
                      _filterUsers();
                    },
                  ),
                  FilterChip(
                    label: const Text('Parent'),
                    selected: _selectedRoleFilter == 'parent',
                    onSelected: (selected) {
                      setModalState(() => _selectedRoleFilter = selected ? 'parent' : null);
                      setState(() => _selectedRoleFilter = selected ? 'parent' : null);
                      _filterUsers();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Status filter
              Text(
                'Status',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: _activeFilter == null,
                    onSelected: (selected) {
                      setModalState(() => _activeFilter = null);
                      setState(() => _activeFilter = null);
                      _filterUsers();
                    },
                  ),
                  FilterChip(
                    label: const Text('Active'),
                    selected: _activeFilter == true,
                    onSelected: (selected) {
                      setModalState(() => _activeFilter = selected ? true : null);
                      setState(() => _activeFilter = selected ? true : null);
                      _filterUsers();
                    },
                  ),
                  FilterChip(
                    label: const Text('Inactive'),
                    selected: _activeFilter == false,
                    onSelected: (selected) {
                      setModalState(() => _activeFilter = selected ? false : null);
                      setState(() => _activeFilter = selected ? false : null);
                      _filterUsers();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setModalState(() {
                          _selectedRoleFilter = null;
                          _activeFilter = null;
                        });
                        setState(() {
                          _selectedRoleFilter = null;
                          _activeFilter = null;
                          _filterUsers();
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xff3B82F6)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Reset',
                        style: TextStyle(color: Color(0xff3B82F6)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _filterUsers();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff3B82F6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Apply Filters',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUserActions(Employee user) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // User info header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _getRoleColor(user.userType),
                    child: Text(
                      user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${user.firstName} ${user.lastName}'.trim(),
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          user.email,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Actions
            ListTile(
              leading: Icon(
                user.isActive ? Icons.block : Icons.check_circle,
                color: user.isActive ? Colors.orange : Colors.green,
              ),
              title: Text(user.isActive ? 'Deactivate User' : 'Activate User'),
              onTap: () async {
                Navigator.pop(context);
                await _toggleUserStatus(user);
              },
            ),
            if (user.userType != 'admin')
              ListTile(
                leading: const Icon(Icons.admin_panel_settings, color: Colors.blue),
                title: const Text('Promote to Admin'),
                onTap: () async {
                  Navigator.pop(context);
                  await _promoteToAdmin(user);
                },
              ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.grey),
              title: const Text('Edit User'),
              onTap: () {
                Navigator.pop(context);
                _showEditUserDialog(user);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete User'),
              onTap: () async {
                Navigator.pop(context);
                await _deleteUser(user);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleUserStatus(Employee user) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.documentId)
          .update({'is_active': !user.isActive});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(user.isActive ? 'User deactivated' : 'User activated'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _loadUsers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _promoteToAdmin(Employee user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Promote to Admin'),
        content: Text('Are you sure you want to promote ${user.firstName} ${user.lastName} to admin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff3B82F6)),
            child: const Text('Promote', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.documentId)
            .update({'user_type': 'admin'});

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User promoted to admin'),
              backgroundColor: Colors.green,
            ),
          );
        }
        _loadUsers();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error promoting user: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteUser(Employee user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to permanently delete ${user.firstName} ${user.lastName}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.documentId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
        _loadUsers();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting user: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showEditUserDialog(Employee user) {
    final firstNameController = TextEditingController(text: user.firstName);
    final lastNameController = TextEditingController(text: user.lastName);
    final phoneController = TextEditingController(text: user.mobilePhone);
    String selectedRole = user.userType;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit User'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: firstNameController,
                decoration: const InputDecoration(
                  labelText: 'First Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Last Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
                  DropdownMenuItem(value: 'student', child: Text('Student')),
                  DropdownMenuItem(value: 'parent', child: Text('Parent')),
                ],
                onChanged: (value) {
                  selectedRole = value!;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.documentId)
                    .update({
                  'first_name': firstNameController.text,
                  'last_name': lastNameController.text,
                  'phone_number': phoneController.text,
                  'user_type': selectedRole,
                });
                if (context.mounted) Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('User updated successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
                _loadUsers();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error updating user: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff3B82F6)),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        title: Text(
          'User Management',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.filter_list),
                if (_selectedRoleFilter != null || _activeFilter != null)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _showFilterOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
                _filterUsers();
              },
            ),
          ),

          // User stats
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filteredUsers.length} users',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                if (_filteredUsers.isNotEmpty)
                  Text(
                    '${_filteredUsers.where((u) => u.isActive).length} active',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.green,
                    ),
                  ),
              ],
            ),
          ),

          // User list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No users found',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadUsers,
                        child: ListView.builder(
                          itemCount: _filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = _filteredUsers[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: ListTile(
                                leading: Stack(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: _getRoleColor(user.userType),
                                      child: Text(
                                        user.firstName.isNotEmpty
                                            ? user.firstName[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    if (!user.isActive)
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: Colors.grey,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                title: Text(
                                  '${user.firstName} ${user.lastName}'.trim(),
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.email,
                                      style: GoogleFonts.inter(fontSize: 12),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getRoleColor(user.userType).withAlpha(25),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            _getRoleName(user.userType),
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              color: _getRoleColor(user.userType),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        if (!user.isActive) ...[
                                          const SizedBox(width: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.withAlpha(25),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'Inactive',
                                              style: GoogleFonts.inter(
                                                fontSize: 10,
                                                color: Colors.grey,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.more_vert),
                                  onPressed: () => _showUserActions(user),
                                ),
                                onTap: () => _showUserActions(user),
                              ),
                            );
                          },
                        ),
                      ),
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
