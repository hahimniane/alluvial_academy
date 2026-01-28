import 'package:flutter/material.dart';
import '../../../core/models/user.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

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
          columns: [
            DataColumn(label: Text(AppLocalizations.of(context)!.userName)),
            DataColumn(label: Text(AppLocalizations.of(context)!.profileEmail)),
            DataColumn(label: Text(AppLocalizations.of(context)!.userRole)),
            DataColumn(label: Text(AppLocalizations.of(context)!.userStatus)),
            DataColumn(label: Text(AppLocalizations.of(context)!.timesheetActions)),
          ],
          rows: [], // Will be populated later with actual user data
        ),
      ),
    );
  }
}
