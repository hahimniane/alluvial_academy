import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:google_fonts/google_fonts.dart';
import 'employee_model.dart';

class UserEmployeeDataSource extends DataGridSource {
  UserEmployeeDataSource({
    required List<Employee> employees,
    required this.onPromoteToAdmin,
    required this.onDeactivateUser,
    required this.onActivateUser,
    required this.onEditUser,
    required this.onDeleteUser,
    this.onViewCredentials,
  }) {
    _employees = employees.map<DataGridRow>((e) {
      return DataGridRow(cells: [
        DataGridCell<String>(columnName: 'FirstName', value: e.firstName),
        DataGridCell<String>(columnName: 'LastName', value: e.lastName),
        DataGridCell<String>(columnName: 'Email', value: e.email),
        DataGridCell<String>(columnName: 'CountryCode', value: e.countryCode),
        DataGridCell<String>(columnName: 'MobilePhone', value: e.mobilePhone),
        DataGridCell<String>(columnName: 'UserType', value: e.userType),
        DataGridCell<String>(columnName: 'Title', value: e.title),
        DataGridCell<String>(
            columnName: 'EmploymentStartDate', value: e.employmentStartDate),
        DataGridCell<String>(columnName: 'KioskCode', value: e.kioskCode),
        DataGridCell<String>(columnName: 'DateAdded', value: e.dateAdded),
        DataGridCell<String>(columnName: 'LastLogin', value: e.lastLogin),
        DataGridCell<Employee>(columnName: 'Actions', value: e),
      ]);
    }).toList();
  }

  final Function(Employee) onPromoteToAdmin;
  final Function(Employee) onDeactivateUser;
  final Function(Employee) onActivateUser;
  final Function(Employee) onEditUser;
  final Function(Employee) onDeleteUser;
  final Function(Employee)? onViewCredentials;

  List<DataGridRow> _employees = [];

  @override
  List<DataGridRow> get rows => _employees;

  void updateDataSource(List<Employee> employees) {
    _employees = employees.map<DataGridRow>((e) {
      return DataGridRow(cells: [
        DataGridCell<String>(columnName: 'FirstName', value: e.firstName),
        DataGridCell<String>(columnName: 'LastName', value: e.lastName),
        DataGridCell<String>(columnName: 'Email', value: e.email),
        DataGridCell<String>(columnName: 'CountryCode', value: e.countryCode),
        DataGridCell<String>(columnName: 'MobilePhone', value: e.mobilePhone),
        DataGridCell<String>(columnName: 'UserType', value: e.userType),
        DataGridCell<String>(columnName: 'Title', value: e.title),
        DataGridCell<String>(
            columnName: 'EmploymentStartDate', value: e.employmentStartDate),
        DataGridCell<String>(columnName: 'KioskCode', value: e.kioskCode),
        DataGridCell<String>(columnName: 'DateAdded', value: e.dateAdded),
        DataGridCell<String>(columnName: 'LastLogin', value: e.lastLogin),
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
                // View Credentials button - only for students
                if (employee.userType.toLowerCase() == 'student' && onViewCredentials != null)
                  _buildActionButton(
                    icon: Icons.key,
                    color: const Color(0xff06B6D4),
                    onTap: () => onViewCredentials!(employee),
                    tooltip: 'View Login Credentials',
                  ),
                // Edit button - always available for active users
                if (employee.isActive)
                  _buildActionButton(
                    icon: Icons.edit,
                    color: Colors.blue,
                    onTap: () => onEditUser(employee),
                    tooltip: 'Edit User',
                  ),
                if (employee.userType.toLowerCase() == 'teacher' &&
                    !employee.isAdminTeacher)
                  _buildActionButton(
                    icon: Icons.admin_panel_settings,
                    color: Colors.orange,
                    onTap: () => onPromoteToAdmin(employee),
                    tooltip: 'Promote to Admin-Teacher',
                  ),
                // Archive/Restore buttons
                if (employee.isActive)
                  _buildActionButton(
                    icon: Icons.archive,
                    color: Colors.orange,
                    onTap: () => onDeactivateUser(employee),
                    tooltip: 'Archive User',
                  ),
                if (!employee.isActive)
                  _buildActionButton(
                    icon: Icons.restore,
                    color: Colors.green,
                    onTap: () => onActivateUser(employee),
                    tooltip: 'Restore User',
                  ),
                // Permanent delete button - only for inactive users
                if (employee.isActive)
                  _buildActionButton(
                    icon: Icons.delete_outline,
                    color: Colors.red,
                    onTap: () => onDeleteUser(employee),
                    tooltip: 'Archive & Permanently Delete',
                    isDestructive: true,
                  ),
                if (!employee.isActive)
                  _buildActionButton(
                    icon: Icons.delete_forever,
                    color: Colors.red,
                    onTap: () => onDeleteUser(employee),
                    tooltip: 'Permanently Delete User',
                    isDestructive: true,
                  ),
                if (employee.userType.toLowerCase() == 'teacher' &&
                    employee.isAdminTeacher)
                  _buildActionButton(
                    icon: Icons.verified,
                    color: Colors.green,
                    onTap: () {}, // No action needed
                    tooltip: 'Already Admin-Teacher',
                  ),
              ],
            ),
          );
        } else if (dataGridCell.columnName == 'UserType') {
          final value = dataGridCell.value.toString();
          Color bgColor;
          Color textColor;

          switch (value.toLowerCase()) {
            case 'teacher':
              bgColor = Colors.blue.withOpacity(0.1);
              textColor = Colors.blue.shade700;
              break;
            case 'student':
              bgColor = Colors.green.withOpacity(0.1);
              textColor = Colors.green.shade700;
              break;
            case 'parent':
              bgColor = Colors.purple.withOpacity(0.1);
              textColor = Colors.purple.shade700;
              break;
            default:
              bgColor = Colors.grey.withOpacity(0.1);
              textColor = Colors.grey.shade700;
          }

          return Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.all(8.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
          );
        } else {
          final employee = row
              .getCells()
              .firstWhere((cell) => cell.columnName == 'Actions')
              .value as Employee;
          final isArchived = !employee.isActive;

          return Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isArchived)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Text(
                      'ARCHIVED',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    dataGridCell.value.toString(),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: isArchived
                          ? const Color(0xff9CA3AF)
                          : const Color(0xff374151),
                      decoration:
                          isArchived ? TextDecoration.lineThrough : null,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
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
