import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:google_fonts/google_fonts.dart';
import 'employee_model.dart';

class AdminEmployeeDataSource extends DataGridSource {
  AdminEmployeeDataSource({
    required List<Employee> employees,
    required this.onPromoteToAdmin,
    required this.onRevokeAdmin,
    required this.onDeactivateUser,
    required this.onActivateUser,
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
                if (employee.isAdminTeacher)
                  _buildActionButton(
                    icon: Icons.remove_moderator,
                    color: Colors.red,
                    onTap: () => onRevokeAdmin(employee),
                    tooltip: 'Revoke Admin Privileges',
                  ),
                if (employee.isActive)
                  _buildActionButton(
                    icon: Icons.block,
                    color: Colors.red,
                    onTap: () => onDeactivateUser(employee),
                    tooltip: 'Deactivate User',
                  ),
                if (!employee.isActive)
                  _buildActionButton(
                    icon: Icons.check_circle,
                    color: Colors.green,
                    onTap: () => onActivateUser(employee),
                    tooltip: 'Activate User',
                  ),
                if (!employee.isAdminTeacher)
                  _buildActionButton(
                    icon: Icons.admin_panel_settings,
                    color: Colors.blue,
                    onTap: () {}, // No action available for full admins
                    tooltip: 'Full Admin (No Actions)',
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
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(
              icon,
              size: 18,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
