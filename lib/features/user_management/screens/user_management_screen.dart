import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:csv/csv.dart';
import 'package:universal_html/html.dart' as html;

import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/header_widget.dart';
import '../../../core/models/employee_model.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  _UserManagementScreenState createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  EmployeeDataSource? _employeeDataSource;
  List<Employee> _allEmployees = [];
  List<Employee> _filteredEmployees = [];
  String _currentSearchTerm = '';
  String? _currentFilterType;

  int? numberOfUsers = 0;

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
    _employeeDataSource = EmployeeDataSource(employees: []);
  }

  @override
  void dispose() {
    _tabController.dispose();
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
    }

    // Update the filtered list
    _filteredEmployees = filtered;

    // Update the data source
    if (_employeeDataSource != null) {
      _employeeDataSource!.updateDataSource(_filteredEmployees);
    } else {
      print('ERROR: Data source is null!'); // Debug log
    }
  }

  void _updateEmployeeData(List<Employee> employees) {
    setState(() {
      _allEmployees = employees;
      numberOfUsers = employees.length;
      _applyFilters(); // Apply current filters to new data
    });
  }

  void _exportData() {
    List<List<String>> userData = [
      [
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
      ],
      ..._filteredEmployees.map((e) => [
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
    ];

    String csv = const ListToCsvConverter().convert(userData);

    final bytes = utf8.encode(csv);
    final blob = html.Blob([bytes]);

    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", "employees.csv")
      ..click();
    html.Url.revokeObjectUrl(url);
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
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: UserCard(
                          userRole: null,
                          userData: null,
                        ),
                      ),
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
                      // Check if we need to update the data
                      bool dataChanged =
                          _allEmployees.length != employees.length ||
                              _allEmployees.isEmpty ||
                              _employeeDataSource == null;

                      if (dataChanged) {
                        _updateEmployeeData(employees);
                      } else if (_allEmployees.isNotEmpty) {
                        // If data hasn't changed but we have employees, ensure current filters are applied
                        _applyFilters();
                      }
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
                              const Tab(
                                  text:
                                      'ADMINS (${0})'), // Will be updated dynamically
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
                                        ],
                                      ),
                              ),
                              // Admins Tab (placeholder)
                              const Center(
                                child:
                                    Text('Admin users will be displayed here'),
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

class UserCard extends StatefulWidget {
  final String? userRole;
  final Map<String, dynamic>? userData;

  const UserCard({super.key, this.userRole, this.userData});

  @override
  State<UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<UserCard> {
  String _getInitials() {
    if (widget.userData != null) {
      final firstName = widget.userData!['first_name'] ?? '';
      final lastName = widget.userData!['last_name'] ?? '';
      if (firstName.isNotEmpty && lastName.isNotEmpty) {
        return '${firstName[0]}${lastName[0]}'.toUpperCase();
      }
    }
    return 'U'; // Default fallback
  }

  String _getUserName() {
    if (widget.userData != null) {
      final firstName = widget.userData!['first_name'] ?? '';
      final lastName = widget.userData!['last_name'] ?? '';
      if (firstName.isNotEmpty || lastName.isNotEmpty) {
        return '$firstName $lastName'.trim();
      }
    }
    return 'User';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [],
          ),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getUserName(),
                    style: openSansHebrewTextStyle.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff2D3748),
                    ),
                  ),
                  if (widget.userRole != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getRoleColor(),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.userRole!.toUpperCase(),
                        style: openSansHebrewTextStyle.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: const Color(0xff04ABC1),
                child: Text(
                  _getInitials(),
                  style: openSansHebrewTextStyle.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'sign_out') {
                    await FirebaseAuth.instance.signOut();
                  }
                },
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem<String>(
                    value: 'sign_out',
                    child: Row(
                      children: [
                        const Icon(Icons.logout, size: 16, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(
                          'Sign Out',
                          style: openSansHebrewTextStyle.copyWith(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xff2998ff)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.manage_accounts,
                          size: 16, color: Color(0xff2998ff)),
                      const SizedBox(width: 4),
                      Text(
                        'Account',
                        style: openSansHebrewTextStyle.copyWith(
                          color: const Color(0xff2998ff),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down,
                          size: 16, color: Color(0xff2998ff)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getRoleColor() {
    switch (widget.userRole?.toLowerCase()) {
      case 'admin':
        return Colors.red;
      case 'teacher':
        return Colors.blue;
      case 'student':
        return Colors.green;
      case 'parent':
        return Colors.orange;
      default:
        return Colors.grey;
    }
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
