import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:csv/csv.dart';
import 'package:universal_html/html.dart' as html;
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/header_widget.dart';
import '../../../core/models/employee_model.dart';
import '../../../core/models/admin_employee_datasource.dart';
import '../../../core/models/user_employee_datasource.dart';
import '../../../utility_functions/export_helpers.dart';
import '../../../core/services/user_role_service.dart';
import 'edit_user_screen.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  _UserManagementScreenState createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  UserEmployeeDataSource? _employeeDataSource;
  AdminEmployeeDataSource? _adminDataSource;

  StreamSubscription<QuerySnapshot>? _userStreamSubscription;
  bool _isLoading = true;

  List<Employee> _snapshotEmployees =
      []; // Holds the latest snapshot from Firestore
  List<Employee> _allEmployees = []; // Used for the 'Users' tab after filtering
  List<Employee> _adminUsers = []; // Used for the 'Admins' tab after filtering

  String _currentSearchTerm = '';
  String? _currentFilterType;
  String? _currentStatusFilter;
  String? _currentParentFilter; // For filtering by parent
  final Map<String, List<String>> _parentStudentMap =
      {}; // parent ID -> list of student IDs
  final Map<String, String> _studentParentMap =
      {}; // student ID -> parent ID (for display)

  int numberOfUsers = 0;
  int numberOfAdmins = 0;
  Timer? _debounceTimer;

  void getFirebaseData() async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    Future<QuerySnapshot<Map<String, dynamic>>> data =
        firestore.collection('users').get();

    data.then((querySnapshot) {
      for (var docSnapshot in querySnapshot.docs) {
        String? countryCode = docSnapshot.data()['country_code'];
        AppLogger.error('Country Code: $countryCode');
      }
    }).catchError((error) {
      AppLogger.error("Error fetching data: $error");
    });
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _employeeDataSource = UserEmployeeDataSource(
      employees: [],
      onPromoteToAdmin: _promoteToAdminTeacher,
      onDeactivateUser: _deactivateUser,
      onActivateUser: _activateUser,
      onEditUser: _editUser,
      onDeleteUser: _deleteUser,
    );
    _adminDataSource = AdminEmployeeDataSource(
      employees: [],
      onPromoteToAdmin: _promoteToAdminTeacher,
      onRevokeAdmin: _revokeAdminPrivileges,
      onDeactivateUser: _deactivateUser,
      onActivateUser: _activateUser,
      onEditUser: _editUser,
      onDeleteUser: _deleteUser,
    );

    _userStreamSubscription = FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        _snapshotEmployees =
            EmployeeDataSource.mapSnapshotToEmployeeList(snapshot);
        // Turn off loading indicator after first data load
        if (_isLoading) {
          setState(() {
            _isLoading = false;
          });
        }
        _loadParentStudentRelationships();
        _applyFilters();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _userStreamSubscription?.cancel();
    super.dispose();
  }

  void _filterEmployees(String searchTerm) {
    setState(() {
      _currentSearchTerm = searchTerm.toLowerCase();
      _applyFilters();
    });
  }

  void _filterByUserType(String? filterValue) {
    setState(() {
      // Reset filters
      _currentFilterType = null;
      _currentStatusFilter = null;
      _currentParentFilter = null;

      // Determine if it's a user type, status filter, or parent filter
      if (filterValue == 'active' ||
          filterValue == 'archived' ||
          filterValue == 'never_logged_in') {
        _currentStatusFilter = filterValue;
      } else if (filterValue?.startsWith('parent_') == true) {
        _currentParentFilter =
            filterValue?.substring(7); // Remove 'parent_' prefix
      // } else if (filterValue == 'shared_parents') {
      //   _currentStatusFilter = 'shared_parents';
      } else {
        _currentFilterType = filterValue;
      }

      _applyFilters();
    });
  }

  Future<void> _loadParentStudentRelationships() async {
    try {
      // Clear existing maps
      _parentStudentMap.clear();
      _studentParentMap.clear();

      // Query all students with guardian_ids
      final studentsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('user_type', isEqualTo: 'student')
          .get();

      for (var doc in studentsSnapshot.docs) {
        final data = doc.data();
        final studentId = doc.id;
        final studentEmail = data['e-mail'] as String?;
        final guardianIds = data['guardian_ids'] as List<dynamic>?;

        AppLogger.debug(
            'Student: ${data['first_name']} ${data['last_name']} (ID: $studentId, Email: $studentEmail)');
        AppLogger.debug('  Guardian IDs: $guardianIds');

        if (guardianIds != null && guardianIds.isNotEmpty) {
          // For each guardian, add this student to their list
          for (var guardianId in guardianIds) {
            final parentId = guardianId.toString();
            _parentStudentMap.putIfAbsent(parentId, () => []).add(studentId);

            // Store the first parent for display purposes
            if (!_studentParentMap.containsKey(studentId)) {
              _studentParentMap[studentId] = parentId;
            }
          }
        }
      }

      AppLogger.debug('=== Parent-Student Mapping Debug ===');
      _parentStudentMap.forEach((parentId, studentIds) {
        AppLogger.debug(
            'Parent $parentId has ${studentIds.length} students: $studentIds');
      });

      AppLogger.error(
          'Loaded parent-student relationships: ${_parentStudentMap.length} parents');
    } catch (e) {
      AppLogger.error('Error loading parent-student relationships: $e');
    }
  }


  void _applyFilters() {
    // Start with the full list from the snapshot (including archived users)
    List<Employee> allUsersFromSnapshot = List.from(_snapshotEmployees);
    List<Employee> regularUsers = allUsersFromSnapshot
        .where((emp) => emp.userType != 'admin' && !emp.isAdminTeacher)
        .toList();
    List<Employee> adminUsers = allUsersFromSnapshot
        .where((emp) => emp.userType == 'admin' || emp.isAdminTeacher)
        .toList();

    // Apply user type filter (only affects the 'Users' tab)
    if (_currentFilterType != null && _currentFilterType != 'all') {
      regularUsers = regularUsers
          .where((employee) =>
              employee.userType.toLowerCase() ==
              _currentFilterType!.toLowerCase())
          .toList();
    }

    // Apply status filter to both lists
    if (_currentStatusFilter != null) {
      switch (_currentStatusFilter) {
        case 'active':
          regularUsers = regularUsers.where((emp) => emp.isActive).toList();
          adminUsers = adminUsers.where((emp) => emp.isActive).toList();
          break;
        case 'archived':
          regularUsers = regularUsers.where((emp) => !emp.isActive).toList();
          adminUsers = adminUsers.where((emp) => !emp.isActive).toList();
          break;
        case 'never_logged_in':
          regularUsers =
              regularUsers.where((emp) => _hasNeverLoggedIn(emp)).toList();
          adminUsers =
              adminUsers.where((emp) => _hasNeverLoggedIn(emp)).toList();
          break;
        // case 'shared_parents':
        //   // Show only students who share parents with other students
        //   regularUsers = regularUsers.where((emp) {
        //     if (emp.userType != 'student') return false;
        //     
        //     // Find the parent of this student using their document ID
        //     final parentId = _studentParentMap[emp.documentId];
        //     if (parentId == null) return false;

        //     // Check if this parent has multiple students
        //     final studentList = _parentStudentMap[parentId] ?? [];
        //     return studentList.length > 1;
        //   }).toList();
        //   break;
      }
    }

    // Apply parent filter
    if (_currentParentFilter != null) {
      // Get all student IDs for this parent
      final studentIds = _parentStudentMap[_currentParentFilter] ?? [];
      regularUsers = regularUsers.where((emp) {
        if (emp.userType != 'student') return false;
        // Check if this student's document ID matches the parent's children
        return studentIds.contains(emp.documentId);
      }).toList();
    }

    // Apply search filter to both lists
    if (_currentSearchTerm.isNotEmpty) {
      regularUsers = regularUsers.where((employee) {
        return employee.firstName.toLowerCase().contains(_currentSearchTerm) ||
            employee.lastName.toLowerCase().contains(_currentSearchTerm) ||
            employee.email.toLowerCase().contains(_currentSearchTerm);
      }).toList();

      adminUsers = adminUsers.where((employee) {
        return employee.firstName.toLowerCase().contains(_currentSearchTerm) ||
            employee.lastName.toLowerCase().contains(_currentSearchTerm) ||
            employee.email.toLowerCase().contains(_currentSearchTerm);
      }).toList();
    }

    // Update the state with the filtered lists
    setState(() {
      _allEmployees = regularUsers;
      _adminUsers = adminUsers;
      _employeeDataSource?.updateDataSource(_allEmployees);
      _adminDataSource?.updateDataSource(_adminUsers);
    });
  }

  bool _hasNeverLoggedIn(Employee employee) {
    // Check if last login is empty, null, or a default placeholder value
    final lastLogin = employee.lastLogin.trim().toLowerCase();
    return lastLogin.isEmpty ||
        lastLogin == 'never' ||
        lastLogin == 'n/a' ||
        lastLogin == '-' ||
        lastLogin == 'null' ||
        lastLogin == 'none' ||
        // Handle Firestore null values that get converted to string representations
        lastLogin.contains('null') ||
        lastLogin.contains('1970-01-01') || // Unix epoch default
        // Handle cases where date conversion fails
        lastLogin.startsWith('instance of');
  }

  Future<void> _promoteToAdminTeacher(Employee employee) async {
    final confirmed = await _showPromotionDialog(employee);
    if (!confirmed) return;

    try {
      final success =
          await UserRoleService.promoteToAdminTeacher(employee.email);

      if (success) {
        _showSuccessSnackBar(
            '${employee.firstName} ${employee.lastName} has been promoted to Admin-Teacher!');
        _refreshData();
      } else {
        _showErrorSnackBar(
            'Failed to promote user. Only teachers can be promoted to admin-teacher role.');
      }
    } catch (e) {
      _showErrorSnackBar('Error promoting user: $e');
    }
  }

  Future<void> _revokeAdminPrivileges(Employee employee) async {
    final confirmed = await _showRevocationDialog(employee);
    if (!confirmed) return;

    try {
      final success =
          await UserRoleService.revokeAdminPrivileges(employee.email);

      if (success) {
        _showSuccessSnackBar(
            'Admin privileges revoked for ${employee.firstName} ${employee.lastName}');
        _refreshData();
      } else {
        _showErrorSnackBar('Failed to revoke admin privileges.');
      }
    } catch (e) {
      _showErrorSnackBar('Error revoking privileges: $e');
    }
  }

  Future<void> _deactivateUser(Employee employee) async {
    final confirmed = await _showDeactivationDialog(employee);
    if (!confirmed) return;

    try {
      final success = await UserRoleService.deactivateUser(employee.email);

      if (success) {
        _showSuccessSnackBar(
            '${employee.firstName} ${employee.lastName} has been archived');
        _refreshData();
      } else {
        _showErrorSnackBar('Failed to archive user.');
      }
    } catch (e) {
      _showErrorSnackBar('Error deactivating user: $e');
    }
  }

  Future<void> _activateUser(Employee employee) async {
    final confirmed = await _showActivationDialog(employee);
    if (!confirmed) return;

    try {
      final success = await UserRoleService.activateUser(employee.email);

      if (success) {
        _showSuccessSnackBar(
            '${employee.firstName} ${employee.lastName} has been restored');
        _refreshData();
      } else {
        _showErrorSnackBar('Failed to restore user.');
      }
    } catch (e) {
      _showErrorSnackBar('Error activating user: $e');
    }
  }

  /// Edit user functionality
  Future<void> _editUser(Employee employee) async {
    // Navigate to edit user screen with employee data
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditUserScreen(employee: employee),
      ),
    );

    // Refresh data if user was updated
    if (result == true) {
      _refreshData();
    }
  }

  /// Delete user permanently
  Future<void> _deleteUser(Employee employee) async {
    final confirmed = await _showDeleteConfirmationDialog(employee);
    if (!confirmed) return;

    try {
      final success = await UserRoleService.deleteUser(employee.email);

      if (success) {
        _showSuccessSnackBar(
            '${employee.firstName} ${employee.lastName} has been permanently deleted');
        _refreshData();
      } else {
        _showErrorSnackBar('Failed to delete user.');
      }
    } catch (e) {
      _showErrorSnackBar('Error deleting user: $e');
    }
  }

  Future<bool> _showDeleteConfirmationDialog(Employee employee) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.delete_forever, color: Colors.red, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Permanently Delete User',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This action cannot be undone!',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Are you sure you want to permanently delete this user?',
                  style: GoogleFonts.inter(fontSize: 16),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xffF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xffE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'User Details:',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Name: ${employee.firstName} ${employee.lastName}'),
                      Text('Email: ${employee.email}'),
                      Text('Role: ${employee.userType}'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'All associated data including timesheets, forms, and other records will be permanently removed.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xff6B7280),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(
                    color: const Color(0xff6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  'Delete Permanently',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _showPromotionDialog(Employee employee) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.admin_panel_settings, color: Colors.orange),
                const SizedBox(width: 8),
                Text('Promote to Admin-Teacher',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to promote ${employee.firstName} ${employee.lastName} to Admin-Teacher?',
                  style: GoogleFonts.inter(),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('This will give them:',
                          style:
                              GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('• Full admin privileges',
                          style: GoogleFonts.inter(fontSize: 12)),
                      Text(
                          '• Ability to switch between Admin and Teacher roles',
                          style: GoogleFonts.inter(fontSize: 12)),
                      Text('• Access to user management and system settings',
                          style: GoogleFonts.inter(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('Promote',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _showRevocationDialog(Employee employee) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.remove_moderator, color: Colors.red),
                const SizedBox(width: 8),
                Text('Revoke Admin Privileges',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to revoke admin privileges from ${employee.firstName} ${employee.lastName}?',
                  style: GoogleFonts.inter(),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('This will:',
                          style:
                              GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('• Remove admin privileges',
                          style: GoogleFonts.inter(fontSize: 12)),
                      Text('• Keep their teacher role intact',
                          style: GoogleFonts.inter(fontSize: 12)),
                      Text('• Remove access to admin functions',
                          style: GoogleFonts.inter(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child:
                    const Text('Revoke', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _showDeactivationDialog(Employee employee) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.delete_outline, color: Colors.red),
                const SizedBox(width: 8),
                Text('Archive User',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to archive ${employee.firstName} ${employee.lastName}?',
                  style: GoogleFonts.inter(),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('This will:',
                          style:
                              GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('• Archive their account (not permanently delete)',
                          style: GoogleFonts.inter(fontSize: 12)),
                      Text('• Remove access to the system',
                          style: GoogleFonts.inter(fontSize: 12)),
                      Text('• Preserve all their data safely',
                          style: GoogleFonts.inter(fontSize: 12)),
                      Text('• Allow restoration at any time',
                          style: GoogleFonts.inter(fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.blue.shade600, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No data will be permanently lost. You can restore this user later.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Archive User',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _showActivationDialog(Employee employee) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.restore, color: Colors.green),
                const SizedBox(width: 8),
                Text('Restore User',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to restore ${employee.firstName} ${employee.lastName}?',
                  style: GoogleFonts.inter(),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('This will:',
                          style:
                              GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('• Restore their account from archive',
                          style: GoogleFonts.inter(fontSize: 12)),
                      Text('• Re-enable access to the system',
                          style: GoogleFonts.inter(fontSize: 12)),
                      Text('• Allow them to log in again',
                          style: GoogleFonts.inter(fontSize: 12)),
                      Text('• Restore all their previous data',
                          style: GoogleFonts.inter(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Restore User',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _refreshData() {
    // Force rebuild by calling setState
    setState(() {});
  }

  Widget _buildAdminGrid() {
    return SfDataGrid(
      source: _adminDataSource!,
      columnWidthMode: ColumnWidthMode.fill,
      columns: <GridColumn>[
        GridColumn(
          columnName: 'FirstName',
          label: Container(
            padding: const EdgeInsets.all(8.0),
            alignment: Alignment.center,
            child: Text(
              'First Name',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: const Color(0xff3f4648),
              ),
            ),
          ),
        ),
        GridColumn(
          columnName: 'LastName',
          label: Container(
            padding: const EdgeInsets.all(8.0),
            alignment: Alignment.center,
            child: Text(
              'Last Name',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: const Color(0xff3f4648),
              ),
            ),
          ),
        ),
        GridColumn(
          columnName: 'Email',
          label: Container(
            padding: const EdgeInsets.all(8.0),
            alignment: Alignment.center,
            child: Text(
              'Email',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: const Color(0xff3f4648),
              ),
            ),
          ),
        ),
        GridColumn(
          columnName: 'UserType',
          label: Container(
            padding: const EdgeInsets.all(8.0),
            alignment: Alignment.center,
            child: Text(
              'Role Type',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: const Color(0xff3f4648),
              ),
            ),
          ),
        ),
        GridColumn(
          columnName: 'AdminType',
          label: Container(
            padding: const EdgeInsets.all(8.0),
            alignment: Alignment.center,
            child: Text(
              'Admin Type',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: const Color(0xff3f4648),
              ),
            ),
          ),
        ),
        GridColumn(
          columnName: 'Actions',
          label: Container(
            padding: const EdgeInsets.all(8.0),
            alignment: Alignment.center,
            child: Text(
              'Actions',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: const Color(0xff3f4648),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _exportData() {
    AppLogger.debug(
        '_exportData called. _filteredEmployees length: ${_allEmployees.length}');

    List<String> headers = [
      "First Name",
      "Last Name",
      "Email",
      "Country Code",
      "Mobile Phone",
      "User Type",
      "Title",
      "Employment Start Date",
      "Kiosk Code",
      "Date Added",
      "Last Login"
    ];

    List<List<String>> userData = _allEmployees
        .map((e) => [
              e.firstName,
              e.lastName,
              e.email,
              e.countryCode,
              e.mobilePhone,
              e.userType,
              e.title,
              e.employmentStartDate,
              e.kioskCode,
              e.dateAdded,
              e.lastLogin,
            ])
        .toList();

    AppLogger.debug('userData length: ${userData.length}');
    if (userData.isNotEmpty) {
      AppLogger.debug('First user data: ${userData[0]}');
    }

    ExportHelpers.showExportDialog(
      context,
      headers,
      userData,
      "employees",
    );
  }

  void _showParentSelectionDialog() async {
    // Get all parents
    final parentsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('user_type', isEqualTo: 'parent')
        .get();

    final parents = parentsSnapshot.docs
        .map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': '${data['first_name']} ${data['last_name']}',
            'email': data['e-mail'],
            'studentCount': _parentStudentMap[doc.id]?.length ?? 0,
          };
        })
        .where((parent) => parent['studentCount'] as int > 0)
        .toList();

    // Sort by student count (descending)
    parents.sort((a, b) =>
        (b['studentCount'] as int).compareTo(a['studentCount'] as int));

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 16,
        child: Container(
          width: 500,
          constraints: const BoxConstraints(maxHeight: 600),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                const Color(0xff9333EA).withOpacity(0.02),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Modern Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  gradient: LinearGradient(
                    colors: [
                      Color(0xff9333EA),
                      Color(0xff7C3AED),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.family_restroom,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Parent',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Choose a parent to view their students',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: parents.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No parents with students found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(16),
                        child: ListView.builder(
                          itemCount: parents.length,
                          itemBuilder: (context, index) {
                            final parent = parents[index];
                            final isSelected =
                                _currentParentFilter == parent['id'];

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xff9333EA)
                                      : Colors.grey.withOpacity(0.2),
                                  width: isSelected ? 2 : 1,
                                ),
                                color: isSelected
                                    ? const Color(0xff9333EA).withOpacity(0.05)
                                    : Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: isSelected
                                        ? const Color(0xff9333EA)
                                            .withOpacity(0.1)
                                        : Colors.black.withOpacity(0.02),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
                                    Navigator.pop(context);
                                    setState(() {
                                      _currentFilterType = null;
                                      _currentStatusFilter = null;
                                      _currentParentFilter =
                                          parent['id'].toString();
                                      _applyFilters();
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        // Avatar
                                        Container(
                                          width: 56,
                                          height: 56,
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xff9333EA),
                                                Color(0xff7C3AED),
                                              ],
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xff9333EA)
                                                    .withOpacity(0.3),
                                                blurRadius: 8,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: Text(
                                              parent['name']
                                                  .toString()[0]
                                                  .toUpperCase(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        // Info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                parent['name'].toString(),
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xff1F2937),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                parent['email'].toString(),
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Student count badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                const Color(0xff9333EA)
                                                    .withOpacity(0.1),
                                                const Color(0xff7C3AED)
                                                    .withOpacity(0.1),
                                              ],
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                              color: const Color(0xff9333EA)
                                                  .withOpacity(0.3),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.people,
                                                size: 16,
                                                color: Color(0xff9333EA),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '${parent['studentCount']}',
                                                style: const TextStyle(
                                                  color: Color(0xff9333EA),
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isSelected)
                                          const Padding(
                                            padding: EdgeInsets.only(left: 12),
                                            child: Icon(
                                              Icons.check_circle,
                                              color: Color(0xff9333EA),
                                              size: 24,
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
              ),
              // Bottom actions
              if (_currentParentFilter != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.grey.withOpacity(0.2)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {
                            _currentParentFilter = null;
                            _applyFilters();
                          });
                        },
                        icon: const Icon(Icons.clear, color: Colors.white),
                        label: const Text('Clear Filter'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff9333EA),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xffF1F1F1),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 5,
              ),
              child: Card(
                elevation: 3,
                color: Colors.white,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(
                        Icons.person,
                        color: Colors.blue,
                      ),
                    ),
                    Text(
                      "User Management",
                      style: openSansHebrewTextStyle.copyWith(fontSize: 24),
                    ),
                  ],
                ),
              ),
            ),
          ),
          HeaderWidget(
            onSearchChanged: _filterEmployees,
            onExport: _exportData,
            onFilterChanged: _filterByUserType,
            onShowNeverLoggedIn: () {
              setState(() {
                _currentFilterType = null;
                _currentStatusFilter = 'never_logged_in';
                _applyFilters();
              });
            },
            onSelectParent: _showParentSelectionDialog,
          ),
          Expanded(
            flex: 11,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Card(
                elevation: 4,
                color: Colors.white,
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TabBar(
                              labelStyle: const TextStyle(color: Colors.orange),
                              indicatorSize: TabBarIndicatorSize.tab,
                              controller: _tabController,
                              labelColor: Colors.blue,
                              unselectedLabelColor: Colors.black54,
                              indicator: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                              tabs: [
                                Tab(
                                  text: 'USERS (${_allEmployees.length})',
                                ),
                                Tab(
                                  text: 'ADMINS (${_adminUsers.length})',
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                // Users Tab
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  child: _employeeDataSource == null
                                      ? const Center(
                                          child: CircularProgressIndicator())
                                      : SfDataGrid(
                                          source: _employeeDataSource!,
                                          columnWidthMode: ColumnWidthMode.fill,
                                          columns: <GridColumn>[
                                            GridColumn(
                                              columnName: 'FirstName',
                                              label: Container(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                alignment: Alignment.center,
                                                child: Text(
                                                  'First Name',
                                                  style: GoogleFonts.inter(
                                                    color:
                                                        const Color(0xff3f4648),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            GridColumn(
                                              columnName: 'LastName',
                                              label: Container(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                alignment: Alignment.center,
                                                child: Text(
                                                  'Last Name',
                                                  style: openSansHebrewTextStyle
                                                      .copyWith(
                                                    color:
                                                        const Color(0xff3f4648),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            GridColumn(
                                              columnName: 'Email',
                                              label: Container(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                alignment: Alignment.center,
                                                child: Text(
                                                  'Email',
                                                  style: openSansHebrewTextStyle
                                                      .copyWith(
                                                    color:
                                                        const Color(0xff3f4648),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            GridColumn(
                                              columnName: 'CountryCode',
                                              label: Container(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                alignment: Alignment.center,
                                                child: const Text(
                                                  'Country Code',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                              ),
                                            ),
                                            GridColumn(
                                              columnName: 'MobilePhone',
                                              label: Container(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                alignment: Alignment.center,
                                                child: const Text(
                                                  'Mobile Phone',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                              ),
                                            ),
                                            GridColumn(
                                              columnName: 'UserType',
                                              label: Container(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                alignment: Alignment.center,
                                                child: const Text(
                                                  'User Type',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                              ),
                                            ),
                                            GridColumn(
                                              columnName: 'Title',
                                              label: Container(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                alignment: Alignment.center,
                                                child: const Text(
                                                  'Title',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                              ),
                                            ),
                                            GridColumn(
                                              columnName: 'EmploymentStartDate',
                                              label: Container(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                alignment: Alignment.center,
                                                child: const Text(
                                                  'Start Date',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                              ),
                                            ),
                                            GridColumn(
                                              columnName: 'KioskCode',
                                              label: Container(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                alignment: Alignment.center,
                                                child: const Text(
                                                  'Kiosk Code',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                              ),
                                            ),
                                            GridColumn(
                                              columnName: 'DateAdded',
                                              label: Container(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                alignment: Alignment.center,
                                                child: const Text(
                                                  'Date Added',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                              ),
                                            ),
                                            GridColumn(
                                              columnName: 'LastLogin',
                                              label: Container(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                alignment: Alignment.center,
                                                child: const Text(
                                                  'Last Login',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                              ),
                                            ),
                                            GridColumn(
                                              columnName: 'Actions',
                                              label: Container(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                alignment: Alignment.center,
                                                child: Text(
                                                  'Actions',
                                                  style: GoogleFonts.inter(
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        const Color(0xff3f4648),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                                // Admins Tab
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Header with role management info
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.info,
                                                color: Colors.blue),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Admin Role Management',
                                                    style: GoogleFonts.inter(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          Colors.blue.shade700,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Promote teachers to admin-teacher (dual role) or revoke admin privileges. Admin-teachers can switch between roles.',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 12,
                                                      color:
                                                          Colors.blue.shade600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 16),

                                      // Admin users grid
                                      Expanded(
                                        child: _adminDataSource == null
                                            ? const Center(
                                                child:
                                                    CircularProgressIndicator())
                                            : _adminUsers.isEmpty
                                                ? Center(
                                                    child: Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Icon(
                                                          Icons
                                                              .admin_panel_settings_outlined,
                                                          size: 64,
                                                          color: Colors
                                                              .grey.shade400,
                                                        ),
                                                        const SizedBox(
                                                            height: 16),
                                                        Text(
                                                          'No admin users found',
                                                          style:
                                                              GoogleFonts.inter(
                                                            fontSize: 18,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Colors
                                                                .grey.shade600,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 8),
                                                        Text(
                                                          'Promote teachers from the Users tab to create admin-teachers',
                                                          style:
                                                              GoogleFonts.inter(
                                                            fontSize: 14,
                                                            color: Colors
                                                                .grey.shade500,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  )
                                                : _buildAdminGrid(),
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
            ),
          ),
        ],
      ),
    );
  }
}

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text("this is the TaskScreen screen"),
      ),
    );
  }
}

class TimeOffScreen extends StatelessWidget {
  const TimeOffScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text("this is the timeoffScreen screen"),
      ),
    );
  }
}
