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

  List<Employee> _snapshotEmployees = []; // Holds the latest snapshot from Firestore
  List<Employee> _allEmployees = []; // Used for the 'Users' tab after filtering
  List<Employee> _adminUsers = []; // Used for the 'Admins' tab after filtering

  String _currentSearchTerm = '';
  String? _currentFilterType;

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
        print('Country Code: $countryCode');
      }
    }).catchError((error) {
      print("Error fetching data: $error");
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
    );
    _adminDataSource = AdminEmployeeDataSource(
      employees: [],
      onPromoteToAdmin: _promoteToAdminTeacher,
      onRevokeAdmin: _revokeAdminPrivileges,
      onDeactivateUser: _deactivateUser,
      onActivateUser: _activateUser,
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

  void _filterByUserType(String? userType) {
    setState(() {
      _currentFilterType = userType;
      _applyFilters();
    });
  }

  void _applyFilters() {
    // Start with the full list from the snapshot
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
              employee.userType.toLowerCase() == _currentFilterType!.toLowerCase())
          .toList();
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
            '${employee.firstName} ${employee.lastName} has been deactivated');
        _refreshData();
      } else {
        _showErrorSnackBar('Failed to deactivate user.');
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
            '${employee.firstName} ${employee.lastName} has been activated');
        _refreshData();
      } else {
        _showErrorSnackBar('Failed to activate user.');
      }
    } catch (e) {
      _showErrorSnackBar('Error activating user: $e');
    }
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
                const Icon(Icons.block, color: Colors.red),
                const SizedBox(width: 8),
                Text('Deactivate User',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to deactivate ${employee.firstName} ${employee.lastName}?',
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
                      Text('• Disable their account',
                          style: GoogleFonts.inter(fontSize: 12)),
                      Text('• Remove access to the system',
                          style: GoogleFonts.inter(fontSize: 12)),
                      Text('• Keep their data for future reference',
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
                    const Text('Deactivate', style: TextStyle(color: Colors.white)),
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
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Text('Activate User',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to activate ${employee.firstName} ${employee.lastName}?',
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
                      Text('• Re-enable their account',
                          style: GoogleFonts.inter(fontSize: 12)),
                      Text('• Restore access to the system',
                          style: GoogleFonts.inter(fontSize: 12)),
                      Text('• Allow them to log in again',
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
                child:
                    const Text('Activate', style: TextStyle(color: Colors.white)),
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
    print(
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

    print('userData length: ${userData.length}');
    if (userData.isNotEmpty) {
      print('First user data: ${userData[0]}');
    }

    ExportHelpers.showExportDialog(
      context,
      headers,
      userData,
      "employees",
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
                              labelStyle:
                                  const TextStyle(color: Colors.orange),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header with role management info
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
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
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.blue.shade700,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Promote teachers to admin-teacher (dual role) or revoke admin privileges. Admin-teachers can switch between roles.',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 12,
                                                    color: Colors.blue.shade600,
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
                                                      const SizedBox(height: 8),
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
