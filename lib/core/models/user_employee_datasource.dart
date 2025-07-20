import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:google_fonts/google_fonts.dart';
import 'employee_model.dart';

class UserEmployeeDataSource extends DataGridSource {
  UserEmployeeDataSource({
    required List<Employee> employees,
    required this.onPromoteToAdmin,
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (employee.userType.toLowerCase() == 'teacher') ...[
                  // Promote to admin button for teachers
                  Material(
                    elevation: 2,
                    borderRadius: BorderRadius.circular(6),
                    child: InkWell(
                      onTap: () => onPromoteToAdmin(employee),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.admin_panel_settings,
                              size: 14,
                              color: Colors.orange.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Promote',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // No action for non-teachers
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      'No Actions',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
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
