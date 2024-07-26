import 'package:flutter/material.dart';

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
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey,
      appBar: AppBar(
        elevation: 4,
        backgroundColor: Colors.white,
        title: const Text('Users'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'USERS (2)'),
            Tab(text: 'ADMINS (1)'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          UsersTab(),
          Center(child: Text('Admins tab content')),
          Center(child: Text('Archived tab content')),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        label: Text('Add users'),
        icon: Icon(Icons.add),
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
                icon: Icon(Icons.filter_list),
                label: Text('Filter'),
              ),
              Text('Users didn\'t log in yet',
                  style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: DataTable(
              columns: [
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
                DataRow(cells: [
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
                DataRow(cells: [
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
              Text('Get your team on board!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text(
                  'Take the first step of having everyone on the same page by inviting your first team members to join you.'),
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {},
                icon: Icon(Icons.add),
                label: Text('Add users'),
              ),
            ],
          ),
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
