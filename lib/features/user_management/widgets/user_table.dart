import 'package:flutter/material.dart';
import '../../../core/models/user.dart';

class UserTable extends StatelessWidget {
  final List<AppUser> users;
  final Function(String)? onUserDelete;
  final Function(AppUser)? onUserEdit;

  const UserTable({
    super.key,
    required this.users,
    this.onUserDelete,
    this.onUserEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Email')),
            DataColumn(label: Text('Role')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions')),
          ],
          rows: const [], // Will be populated later with actual user data
        ),
      ),
    );
  }
}
