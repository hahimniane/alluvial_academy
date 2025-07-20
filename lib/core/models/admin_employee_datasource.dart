import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:google_fonts/google_fonts.dart';
import 'employee_model.dart';

class AdminEmployeeDataSource extends DataGridSource {
  AdminEmployeeDataSource({
    required List<Employee> employees,
    required this.onPromoteToAdmin,
    required this.onRevokeAdmin,
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (employee.isAdminTeacher) ...[
                  // Revoke admin button for admin-teachers
                  Material(
                    elevation: 2,
                    borderRadius: BorderRadius.circular(6),
                    child: InkWell(
                      onTap: () => onRevokeAdmin(employee),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.remove_moderator,
                              size: 14,
                              color: Colors.red.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Revoke',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // Full admin - no actions available
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.admin_panel_settings,
                          size: 14,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Full Admin',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
}
