import 'package:flutter/material.dart';

import 'const.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text("this is the feed screen"),
      ),
    );
  }
}

class UserManagementScreen extends StatefulWidget {
  @override
  _UserManagementScreenState createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xffF1F1F1),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                // color: Colors.white,
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
                            child: UserCard())),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 11,
            child: Container(
              margin: EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                // border: Border.all(color: Colors.brown),
              ),
              // color: Colors.purple,
              child: Card(
                elevation: 4,
                color: Colors.white,
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        // border: Border.all(color: Colors.brown),
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
                        tabs: const [
                          Tab(text: 'USERS (2)'),
                          Tab(text: 'ADMINS (1)'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: const [
                          // UsersTab(),
                          DataTableExample(),
                          Center(
                            child: Text('Admins tab content'),
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

class UserCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
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
                icon: Icon(Icons.manage_accounts, size: 16),
                label: Text(
                  'Manage user details',
                  style: openSansHebrewTextStyle.copyWith(
                      color: Color(0xff2998ff)),
                ),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  backgroundColor: Colors.white,
                  side: BorderSide(color: Colors.blue),
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

class UsersTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.filter_list),
                label: const Text('Filter'),
              ),
              const Text('Users didn\'t log in yet',
                  style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: DataTable(
              columns: const [
                DataColumn(label: Text('First name')),
                DataColumn(label: Text('Last name')),
                DataColumn(label: Text('Title')),
                DataColumn(label: Text('Employment Start Date')),
                DataColumn(label: Text('Team')),
                DataColumn(label: Text('Department')),
                DataColumn(label: Text('Kiosk code')),
                DataColumn(label: Text('Date added')),
                DataColumn(label: Text('Last login')),
              ],
              rows: [
                const DataRow(cells: [
                  DataCell(Row(
                    children: [
                      CircleAvatar(child: Text('HN')),
                      SizedBox(width: 8),
                      Text('Hassimiou'),
                    ],
                  )),
                  DataCell(Text('Niane')),
                  DataCell(Text('Founder')),
                  DataCell(Text('07/19/2024')),
                  DataCell(Text('')),
                  DataCell(Text('')),
                  DataCell(Text('6677')),
                  DataCell(Text('07/19/2024')),
                  DataCell(Text('07/25/2024')),
                ]),
                const DataRow(cells: [
                  DataCell(Row(
                    children: [
                      CircleAvatar(child: Text('SB')),
                      SizedBox(width: 8),
                      Text('Sulaiman'),
                    ],
                  )),
                  DataCell(Text('Barry')),
                  DataCell(Text('')),
                  DataCell(Text('')),
                  DataCell(Text('')),
                  DataCell(Text('')),
                  DataCell(Text('8368')),
                  DataCell(Text('07/19/2024')),
                  DataCell(Text('Never logged in')),
                ]),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Text('Get your team on board!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                  'Take the first step of having everyone on the same page by inviting your first team members to join you.'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: const Text('Add users'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class DataTableExample extends StatelessWidget {
  const DataTableExample({super.key});

  @override
  Widget build(BuildContext context) {
    return DataTable(
      columns: const <DataColumn>[
        DataColumn(
          label: Expanded(
            child: Text(
              'First Name',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
        ),
        DataColumn(
          label: Expanded(
            child: Text(
              'Last Name',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
        ),
        DataColumn(
          label: Expanded(
            child: Text(
              'Role',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
        ),
      ],
      rows: const <DataRow>[
        DataRow(
          cells: <DataCell>[
            DataCell(Text('Sarah')),
            DataCell(Text('Oslow')),
            DataCell(Text('Student')),
          ],
        ),
        DataRow(
          cells: <DataCell>[
            DataCell(Text('Janine')),
            DataCell(Text('Yamal')),
            DataCell(Text('Professor')),
          ],
        ),
        DataRow(
          cells: <DataCell>[
            DataCell(Text('William')),
            DataCell(Text('Jenkins')),
            DataCell(Text('Associate Professor')),
          ],
        ),
      ],
    );
  }
}

class FormScreen extends StatelessWidget {
  const FormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text("this is the FomScreen screen"),
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

class TimeClockScreen extends StatelessWidget {
  const TimeClockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text("this is the TimeClockScreen screen"),
      ),
    );
  }
}

class JobSchedulingScreen extends StatelessWidget {
  const JobSchedulingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text("this is the JobScheduling screen"),
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
