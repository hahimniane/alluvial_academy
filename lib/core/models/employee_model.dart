import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:flutter/material.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

class Employee {
  Employee({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.countryCode,
    required this.mobilePhone,
    required this.userType,
    required this.title,
    required this.employmentStartDate,
    required this.kioskCode,
    required this.dateAdded,
    required this.lastLogin,
    required this.documentId, // Add document ID field
    this.isAdminTeacher = false,
    this.isActive = true,
  });

  final String firstName;
  final String lastName;
  final String email;
  final String countryCode;
  final String mobilePhone;
  final String userType;
  final String title;
  final String employmentStartDate;
  final String kioskCode;
  final String dateAdded;
  final String lastLogin;
  final String documentId; // Store Firestore document ID
  final bool isAdminTeacher;
  final bool isActive;
}

class EmployeeDataSource extends DataGridSource {
  EmployeeDataSource({required List<Employee> employees}) {
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
      ]);
    }).toList();
  }

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
      ]);
    }).toList();
    AppLogger.debug('the update method was called ');
    notifyListeners();
  }

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((dataGridCell) {
        return Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(8.0),
          child: Text(dataGridCell.value.toString()),
        );
      }).toList(),
    );
  }

  static List<Employee> mapSnapshotToEmployeeList(QuerySnapshot snapshot) {
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final userType = data['user_type'] ?? '';

      // Convert Timestamp to String for dates
      String formatTimestamp(dynamic timestamp) {
        if (timestamp is Timestamp) {
          return timestamp.toDate().toString();
        }
        if (timestamp == null) {
          return 'Never'; // Explicit indicator for users who never logged in
        }
        return timestamp.toString();
      }

      // For students, use document ID as kiosk code if kiosk_code is empty
      String getKioskCode() {
        final kioskCode = data['kiosk_code'] ?? '';
        if (userType == 'student' && kioskCode.isEmpty) {
          return doc.id; // Use document ID as student ID
        }
        return kioskCode;
      }

      return Employee(
        firstName: data['first_name'] ?? '',
        lastName: data['last_name'] ?? '',
        email: data['e-mail'] ?? '',
        countryCode: data['country_code'] ?? '',
        mobilePhone: data['phone_number'] ?? '',
        userType: userType,
        title: data['title'] ?? '',
        employmentStartDate: formatTimestamp(data['employment_start_date']),
        kioskCode: getKioskCode(),
        dateAdded: formatTimestamp(data['date_added']),
        lastLogin: formatTimestamp(data['last_login']),
        documentId: doc.id, // Store the document ID
        isAdminTeacher: data['is_admin_teacher'] as bool? ?? false,
        isActive: data['is_active'] as bool? ??
            true, // Default to active if field doesn't exist
      );
    }).toList();
  }
}
