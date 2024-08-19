import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:csv/csv.dart';
import 'package:universal_html/html.dart' as html;

import 'const.dart';
import 'header_widget.dart';
import 'model/employee_model_class.dart';

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
      if (searchTerm.isEmpty) {
        _filteredEmployees = _allEmployees;
      } else {
        _filteredEmployees = _allEmployees.where((employee) {
          return employee.firstName
              .toLowerCase()
              .contains(searchTerm.toLowerCase());
        }).toList();
      }
      print('sorted employes');
      for (var employee in _filteredEmployees) {
        print("Employee is ${employee.firstName}");
      }

      _employeeDataSource!.updateDataSource(_filteredEmployees);
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
      ..._allEmployees.map((e) => [
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

    // Create a Blob
    final bytes = utf8.encode(csv);
    final blob = html.Blob([bytes]);

    // Create a link element
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
                      "User",
                      style: openSansHebrewTextStyle.copyWith(fontSize: 24),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: UserCard(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          HeaderWidget(
              onSearchChanged: _filterEmployees, onExport: _exportData),
          Expanded(
            flex: 11,
            child: Container(
              margin: const EdgeInsets.all(12),
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
                        "Stream connection state: ${snapshot.connectionState}");
                    numberOfUsers = 3;
                    print(snapshot.data?.docs[0].id);
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      print('waiting');
                      // _allEmployees =
                      //     EmployeeDataSource.mapSnapshotToEmployeeList(
                      //         snapshot.data!);
                      // _filteredEmployees = _allEmployees;
                      // _employeeDataSource!.updateDataSource(_filteredEmployees);
                      return const Center(child: Text("Waiting"));
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    if (snapshot.hasData) {
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
                                const Tab(text: 'ADMINS (1)'),
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
                                                'First Name',
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
                                              child: const Text(
                                                'Last Name',
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
                                              child: const Text(
                                                'Email',
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
                                                'Employment Start Date',
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
                                  ),
                                ),
                                const Center(
                                  child: Text('Admins tab content'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }
                    return const Center(child: Text('No data available'));
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

class UserCard extends StatelessWidget {
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
              CircleAvatar(
                backgroundColor: const Color(0xff04ABC1),
                child: Text(
                  'HN',
                  style: openSansHebrewTextStyle.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  // Handle button press
                },
                icon: const Icon(Icons.manage_accounts, size: 16),
                label: Text(
                  'Manage user details',
                  style: openSansHebrewTextStyle.copyWith(
                      color: const Color(0xff2998ff)),
                ),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Colors.blue),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FormScreen extends StatelessWidget {
  const FormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text("this is the FormScreen screen"),
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

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text("this is the ChatScreen screen"),
      ),
    );
  }
}

class JobSchedulingScreen extends StatelessWidget {
  const JobSchedulingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance.collection('users').get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Text("waiting");
              } else if (snapshot.connectionState == ConnectionState.done) {
                return Text("Done");
              } else if (snapshot.connectionState == ConnectionState.active) {
                return Text("active");
              }
              return Text("don't know what happened in the else ");
            }),
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
