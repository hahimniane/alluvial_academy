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
  List<Employee> _allEmployees = [];
  List<Employee> _filteredEmployees = [];
  List<Employee> _adminUsers = [];
  List<Employee> _filteredAdmins = [];
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
    getFirebaseData();
    _tabController = TabController(length: 2, vsync: this);
    _employeeDataSource = UserEmployeeDataSource(
      employees: [],
      onPromoteToAdmin: _promoteToAdminTeacher,
    );
    _adminDataSource = AdminEmployeeDataSource(
      employees: [],
      onPromoteToAdmin: _promoteToAdminTeacher,
      onRevokeAdmin: _revokeAdminPrivileges,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _debounceTimer?.cancel();
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
    List<Employee> filtered = _allEmployees;
    List<Employee> adminFiltered = _adminUsers;

    // Apply user type filter
    if (_currentFilterType != null && _currentFilterType != 'all') {
      filtered = filtered.where((employee) {
        return employee.userType.toLowerCase() ==
            _currentFilterType!.toLowerCase();
      }).toList();
    }

    // Apply search filter
    if (_currentSearchTerm.isNotEmpty) {
      filtered = filtered.where((employee) {
        return employee.firstName.toLowerCase().contains(_currentSearchTerm) ||
            employee.lastName.toLowerCase().contains(_currentSearchTerm) ||
            employee.email.toLowerCase().contains(_currentSearchTerm) ||
            employee.userType.toLowerCase().contains(_currentSearchTerm);
      }).toList();

      adminFiltered = adminFiltered.where((employee) {
        return employee.firstName.toLowerCase().contains(_currentSearchTerm) ||
            employee.lastName.toLowerCase().contains(_currentSearchTerm) ||
            employee.email.toLowerCase().contains(_currentSearchTerm) ||
            employee.userType.toLowerCase().contains(_currentSearchTerm);
      }).toList();
    }

    // Update the filtered lists
    _filteredEmployees = filtered;
    _filteredAdmins = adminFiltered;

    // Update the data sources
    if (_employeeDataSource != null) {
      _employeeDataSource!.updateDataSource(_filteredEmployees);
    }
    if (_adminDataSource != null) {
      _adminDataSource!.updateDataSource(_filteredAdmins);
    }
  }

  void _updateEmployeeData(List<Employee> employees) {
    // Separate admin and regular users
    final newAllEmployees = employees
        .where((emp) => emp.userType != 'admin' && !emp.isAdminTeacher)
        .toList();
    final newAdminUsers = employees
        .where((emp) => emp.userType == 'admin' || emp.isAdminTeacher)
        .toList();

    final newNumberOfUsers = newAllEmployees.length;
    final newNumberOfAdmins = newAdminUsers.length;

    // Only update state if there are actual changes
    bool shouldUpdate = _allEmployees.length != newAllEmployees.length ||
        _adminUsers.length != newAdminUsers.length ||
        numberOfUsers != newNumberOfUsers ||
        numberOfAdmins != newNumberOfAdmins;

    if (shouldUpdate) {
      setState(() {
        _allEmployees = newAllEmployees;
        _adminUsers = newAdminUsers;
        numberOfUsers = newNumberOfUsers;
        numberOfAdmins = newNumberOfAdmins;

        // Initialize data sources if needed
        if (_employeeDataSource == null) {
          _employeeDataSource = UserEmployeeDataSource(
            employees: _allEmployees,
            onPromoteToAdmin: _promoteToAdminTeacher,
          );
        }
        if (_adminDataSource == null) {
          _adminDataSource = AdminEmployeeDataSource(
            employees: _adminUsers,
            onPromoteToAdmin: _promoteToAdminTeacher,
            onRevokeAdmin: _revokeAdminPrivileges,
          );
        }

        _applyFilters(); // Apply current filters to new data
      });
    } else {
      // Data hasn't changed, but update the data sources with fresh data
      _employeeDataSource?.updateDataSource(_allEmployees);
      _adminDataSource?.updateDataSource(_adminUsers);
    }
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

  void _debouncedUpdateEmployeeData(List<Employee> employees) {
    // Cancel any existing timer
    _debounceTimer?.cancel();

    // Set a new timer with a short delay
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      // Check if we need to update the data
      bool dataChanged = _allEmployees.length != employees.length ||
          _employeeDataSource == null ||
          _adminDataSource == null;

      // Only check for actual content changes if lengths are the same
      if (!dataChanged && _allEmployees.isNotEmpty) {
        // Check if the actual data content has changed
        for (int i = 0; i < employees.length && i < _allEmployees.length; i++) {
          if (employees[i].email != _allEmployees[i].email ||
              employees[i].userType != _allEmployees[i].userType ||
              employees[i].isAdminTeacher != _allEmployees[i].isAdminTeacher) {
            dataChanged = true;
            break;
          }
        }
      }

      if (dataChanged) {
        _updateEmployeeData(employees);
      }
    });
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
        '_exportData called. _filteredEmployees length: ${_filteredEmployees.length}');

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

    List<List<String>> userData = _filteredEmployees
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
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .snapshots(),
                  builder: (context, snapshot) {
                    print(
                        "Current connection state: ${snapshot.connectionState}");
                    print("Has data: ${snapshot.hasData}");
                    print("Has error: ${snapshot.hasError}");

                    // Debug: Print the actual number of documents and their IDs
                    if (snapshot.hasData) {
                      print("Documents count: ${snapshot.data!.docs.length}");
                      print(
                          "Document IDs: ${snapshot.data!.docs.map((doc) => doc.id).toList()}");
                      print(
                          "First 3 documents data: ${snapshot.data!.docs.take(3).map((doc) => doc.data()).toList()}");
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      print('waiting');
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('No users found'));
                    }

                    // Process the data
                    final employees =
                        EmployeeDataSource.mapSnapshotToEmployeeList(
                            snapshot.data!);

                    // Update the employee data (this will trigger filtering)
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _debouncedUpdateEmployeeData(employees);
                    });

                    return Column(
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
                                text: 'USERS (${_filteredEmployees.length})',
                              ),
                              Tab(
                                text: 'ADMINS (${_filteredAdmins.length})',
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
                                          : _filteredAdmins.isEmpty
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
                    );
                  },
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
