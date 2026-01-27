import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:csv/csv.dart';
import 'package:universal_html/html.dart' as html;

import 'core/constants/app_constants.dart';
import 'shared/widgets/header_widget.dart';
import 'core/models/employee_model.dart';
import 'utility_functions/export_helpers.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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

  int? numberOfUsers = 0;
  void getFirebaseData() async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    // Fetch the collection 'users'
    Future<QuerySnapshot<Map<String, dynamic>>> data =
        firestore.collection('users').get();

    // Use 'await' to get the data and then iterate over it
    data.then((querySnapshot) {
      for (var docSnapshot in querySnapshot.docs) {
        // Accessing the 'country_code' field in each document
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
    getFirebaseData();
    _tabController = TabController(length: 2, vsync: this);
    // _employeeDataSource = EmployeeDataSource(employees: []);
    _employeeDataSource = EmployeeDataSource(employees: _filteredEmployees);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // void _filterEmployees(String searchTerm) {
  //   setState(() {
  //     if (searchTerm.isEmpty) {
  //       _filteredEmployees = _allEmployees;
  //     } else {
  //       _filteredEmployees = _allEmployees.where((employee) {
  //         return employee.firstName
  //             .toLowerCase()
  //             .contains(searchTerm.toLowerCase());
  //       }).toList();
  //     }
  //     AppLogger.debug('sorted employes');
  //     for (var employee in _filteredEmployees) {
  //       AppLogger.debug("Employee is ${employee.firstName}");
  //     }

  //     _employeeDataSource!.updateDataSource(_filteredEmployees);
  //   });
  // }

  void _filterEmployees(String searchTerm) {
    setState(() {
      if (_allEmployees.isEmpty) {
        // If this is first load, don't filter yet
        return;
      }

      if (searchTerm.isEmpty) {
        _filteredEmployees = _allEmployees;
      } else {
        _filteredEmployees = _allEmployees.where((employee) {
          return employee.firstName
              .toLowerCase()
              .contains(searchTerm.toLowerCase());
        }).toList();
      }
      _employeeDataSource!.updateDataSource(_filteredEmployees);
    });
  }

  void _filterByUserType(String? userType) {
    // This method can be implemented later for filtering by user type
    // For now, it's just a placeholder to prevent linter errors
  }

  void _exportData() {
    AppLogger.debug('_exportData called. _allEmployees length: ${_allEmployees.length}');

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
                      AppLocalizations.of(context)!.roleUser,
                      style: openSansHebrewTextStyle.copyWith(fontSize: 24),
                    ),
                    const Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: UserCard(
                          userRole: null, // Will be updated from parent
                          userData: null, // Will be updated from parent
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
              onFilterChanged: _filterByUserType),
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
                    AppLogger.debug(
                        "Current connection state: ${snapshot.connectionState}");
                    AppLogger.debug("Has data: ${snapshot.hasData}");
                    AppLogger.error("Has error: ${snapshot.hasError}");

                    AppLogger.debug(
                        "Stream connection state: ${snapshot.connectionState}");
                    numberOfUsers = 3;
                    AppLogger.debug(snapshot.data?.docs[0].id);
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      AppLogger.debug('waiting');
                      // _allEmployees =
                      //     EmployeeDataSource.mapSnapshotToEmployeeList(
                      //         snapshot.data!);
                      // _filteredEmployees = _allEmployees;
                      // _employeeDataSource!.updateDataSource(_filteredEmployees);
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    } else if (snapshot.hasData) {
                      numberOfUsers = snapshot.data?.docs.length;
                      _allEmployees =
                          EmployeeDataSource.mapSnapshotToEmployeeList(
                              snapshot.data!);
                      _filteredEmployees = _allEmployees;
                      _employeeDataSource!.updateDataSource(_filteredEmployees);

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
                                  text: 'USERS (${numberOfUsers.toString()})',
                                ),
                                const Tab(text: AppLocalizations.of(context)!.admins1),
                              ],
                            ),
                          ),
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                SfDataGridTheme(
                                  data: const SfDataGridThemeData(
                                    headerColor: Color(0xffF8F8F8),
                                  ),
                                  child: SingleChildScrollView(
                                    physics: const ScrollPhysics(),
                                    scrollDirection: Axis.horizontal,
                                    child: SizedBox(
                                      width:
                                          1500, // Set a fixed width to enable horizontal scrolling
                                      child: SfDataGrid(
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
                                                AppLocalizations.of(context)!.userFirstName,
                                                style: openSansHebrewTextStyle
                                                    .copyWith(
                                                        color: const Color(
                                                            0xff3f4648),
                                                        fontWeight:
                                                            FontWeight.w500),
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
                                                AppLocalizations.of(context)!.userLastName,
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold),
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
                                                AppLocalizations.of(context)!.profileEmail,
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ),
                                          ),
                                          GridColumn(
                                            columnName: 'CountryCode',
                                            label: Container(
                                              padding:
                                                  const EdgeInsets.all(8.0),
                                              alignment: Alignment.center,
                                              child: Text(
                                                AppLocalizations.of(context)!.userCountryCode,
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
                                              child: Text(
                                                AppLocalizations.of(context)!.mobilePhone,
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
                                              child: Text(
                                                AppLocalizations.of(context)!.userUserType,
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
                                              child: Text(
                                                AppLocalizations.of(context)!.profileTitle,
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
                                              child: Text(
                                                AppLocalizations.of(context)!.employmentStartDate,
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
                                              child: Text(
                                                AppLocalizations.of(context)!.userKioskCode,
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
                                              child: Text(
                                                AppLocalizations.of(context)!.dateAdded,
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
                                              child: Text(
                                                AppLocalizations.of(context)!.lastLogin,
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const Center(
                                  child: Text(AppLocalizations.of(context)!.adminsTabContent),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    } else if (_filteredEmployees.isEmpty) {
                      _filteredEmployees = _allEmployees;
                      _employeeDataSource!.updateDataSource(_filteredEmployees);
                    }

                    return const Center(child: Text(AppLocalizations.of(context)!.noDataAvailable));
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
                          AppLocalizations.of(context)!.settingsSignOut,
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
                        AppLocalizations.of(context)!.account,
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
        child: Text(AppLocalizations.of(context)!.thisIsTheTaskscreenScreen),
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
        child: Text(AppLocalizations.of(context)!.thisIsTheTimeoffscreenScreen),
      ),
    );
  }
}
