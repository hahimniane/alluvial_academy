import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:google_fonts/google_fonts.dart';
import 'employee_model.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class AdminEmployeeDataSource extends DataGridSource {
  AdminEmployeeDataSource({
    required List<Employee> employees,
    required this.onPromoteToAdmin,
    required this.onRevokeAdmin,
    required this.onDeactivateUser,
    required this.onActivateUser,
    required this.onEditUser,
    required this.onDeleteUser,
    required this.context,
  }) {
    _employees = employees.map<DataGridRow>((e) {
      return DataGridRow(cells: [
        DataGridCell<String>(columnName: 'FirstName', value: e.firstName),
        DataGridCell<String>(columnName: 'LastName', value: e.lastName),
        DataGridCell<String>(columnName: 'Email', value: e.email),
        DataGridCell<String>(columnName: 'UserType', value: e.userType),
        DataGridCell<String>(
            columnName: 'AdminType',
            value: e.isAdminTeacher ? 'Admin-Teacher' : 'Full Admin'),
        DataGridCell<Employee>(columnName: 'Actions', value: e),
      ]);
    }).toList();
  }

  final Function(Employee) onPromoteToAdmin;
  final Function(Employee) onRevokeAdmin;
  final Function(Employee) onDeactivateUser;
  final Function(Employee) onActivateUser;
  final Function(Employee) onEditUser;
  final Function(Employee) onDeleteUser;
  final BuildContext context;

  List<DataGridRow> _employees = [];

  @override
  List<DataGridRow> get rows => _employees;

  void updateDataSource(List<Employee> employees) {
    _employees = employees.map<DataGridRow>((e) {
      return DataGridRow(cells: [
        DataGridCell<String>(columnName: 'FirstName', value: e.firstName),
        DataGridCell<String>(columnName: 'LastName', value: e.lastName),
        DataGridCell<String>(columnName: 'Email', value: e.email),
        DataGridCell<String>(columnName: 'UserType', value: e.userType),
        DataGridCell<String>(
            columnName: 'AdminType',
            value: e.isAdminTeacher ? 'Admin-Teacher' : 'Full Admin'),
        DataGridCell<Employee>(columnName: 'Actions', value: e),
      ]);
    }).toList();
    notifyListeners();
  }

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((dataGridCell) {
        if (dataGridCell.columnName == 'Actions') {
          final employee = dataGridCell.value as Employee;
          return Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.all(8.0),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 4.0,
              runSpacing: 4.0,
              children: [
                // Edit button - always available for active users
                if (employee.isActive)
                  _buildActionButton(
                    icon: Icons.edit,
                    color: Colors.blue,
                    onTap: () => onEditUser(employee),
                    tooltip: AppLocalizations.of(context)!.userEditUser,
                  ),
                if (employee.isAdminTeacher)
                  _buildActionButton(
                    icon: Icons.remove_moderator,
                    color: Colors.red,
                    onTap: () => onRevokeAdmin(employee),
                    tooltip: AppLocalizations.of(context)!.revokeAdminPrivileges,
                  ),
                // Archive/Restore buttons
                if (employee.isActive)
                  _buildActionButton(
                    icon: Icons.archive,
                    color: Colors.orange,
                    onTap: () => onDeactivateUser(employee),
                    tooltip: AppLocalizations.of(context)!.archiveUser,
                  ),
                if (!employee.isActive)
                  _buildActionButton(
                    icon: Icons.restore,
                    color: Colors.green,
                    onTap: () => onActivateUser(employee),
                    tooltip: AppLocalizations.of(context)!.restoreUser,
                  ),
                if (employee.isActive)
                  _buildActionButton(
                    icon: Icons.delete_outline,
                    color: Colors.red,
                    onTap: () => onDeleteUser(employee),
                    tooltip: AppLocalizations.of(context)!.archivePermanentlyDelete,
                    isDestructive: true,
                  ),
                if (!employee.isActive)
                  _buildActionButton(
                    icon: Icons.delete_forever,
                    color: Colors.red,
                    onTap: () => onDeleteUser(employee),
                    tooltip: AppLocalizations.of(context)!.permanentlyDeleteUser,
                    isDestructive: true,
                  ),
                if (!employee.isAdminTeacher)
                  _buildActionButton(
                    icon: Icons.admin_panel_settings,
                    color: Colors.grey,
                    onTap: () {}, // No action available for full admins
                    tooltip: AppLocalizations.of(context)!.fullAdmin,
                  ),
              ],
            ),
          );
        } else if (dataGridCell.columnName == 'AdminType') {
          final value = dataGridCell.value.toString();
          final isAdminTeacher = value == 'Admin-Teacher';

          return Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.all(8.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isAdminTeacher
                    ? Colors.orange.withOpacity(0.1)
                    : Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isAdminTeacher
                      ? Colors.orange.shade700
                      : Colors.blue.shade700,
                ),
              ),
            ),
          );
        } else {
          return Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.all(8.0),
            child: Text(
              dataGridCell.value.toString(),
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xff374151),
              ),
            ),
          );
        }
      }).toList(),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
    bool isDestructive = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isDestructive
            ? Colors.red.withOpacity(0.05)
            : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDestructive
                    ? Colors.red.withOpacity(0.4)
                    : color.withOpacity(0.3),
                width: isDestructive ? 1.5 : 1,
              ),
            ),
            child: Icon(
              icon,
              size: isDestructive ? 20 : 18,
              color: isDestructive ? Colors.red.shade600 : color,
            ),
          ),
        ),
      ),
    );
  }
}
