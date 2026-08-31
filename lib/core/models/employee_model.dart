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
    this.studentCode = '',
    this.isAdminTeacher = false,
    this.isActive = true,
    this.aiTutorEnabled = false,
    this.tontineEnabled = false,
    this.useZoom = false,
    this.zoomHostAccount = '',
    this.secondaryRoles = const [],
    this.createdByUid = '',
    this.createdAt,
    this.deactivatedByUid = '',
    this.deactivatedAt,
    this.activatedByUid = '',
    this.activatedAt,
    this.parentName = '',
    this.teacherNames = '',
    this.weeklyHoursLabel = '',
    this.isAdultStudent = false,
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

  /// Student login/ID code (e.g. `first.last`) when available.
  final String studentCode;
  final String dateAdded;
  final String lastLogin;
  final String documentId; // Store Firestore document ID
  final bool isAdminTeacher;
  final bool isActive;
  final bool aiTutorEnabled;
  final bool tontineEnabled;
  final bool useZoom;
  final String zoomHostAccount;
  final List<String> secondaryRoles;
  final String createdByUid;
  final DateTime? createdAt;
  final String deactivatedByUid;
  final DateTime? deactivatedAt;
  final String activatedByUid;
  final DateTime? activatedAt;

  /// True when a student has been marked as an adult student (`is_adult_student`
  /// on the user doc); false/absent means the student is a minor.
  final bool isAdultStudent;

  /// Below fields are derived client-side (not stored on the user doc) to
  /// enrich the admin student grid: guardian display name, the name(s) of
  /// teacher(s) with a class this week, and total scheduled hours this week.
  final String parentName;
  final String teacherNames;
  final String weeklyHoursLabel;

  Employee copyWithScheduleInfo({
    String? parentName,
    String? teacherNames,
    String? weeklyHoursLabel,
  }) {
    return Employee(
      firstName: firstName,
      lastName: lastName,
      email: email,
      countryCode: countryCode,
      mobilePhone: mobilePhone,
      userType: userType,
      title: title,
      employmentStartDate: employmentStartDate,
      kioskCode: kioskCode,
      studentCode: studentCode,
      dateAdded: dateAdded,
      lastLogin: lastLogin,
      documentId: documentId,
      isAdminTeacher: isAdminTeacher,
      isActive: isActive,
      aiTutorEnabled: aiTutorEnabled,
      tontineEnabled: tontineEnabled,
      useZoom: useZoom,
      zoomHostAccount: zoomHostAccount,
      secondaryRoles: secondaryRoles,
      createdByUid: createdByUid,
      createdAt: createdAt,
      deactivatedByUid: deactivatedByUid,
      deactivatedAt: deactivatedAt,
      activatedByUid: activatedByUid,
      activatedAt: activatedAt,
      isAdultStudent: isAdultStudent,
      parentName: parentName ?? this.parentName,
      teacherNames: teacherNames ?? this.teacherNames,
      weeklyHoursLabel: weeklyHoursLabel ?? this.weeklyHoursLabel,
    );
  }
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

      String getStudentCode() {
        if (userType != 'student') return '';
        final raw =
            data['student_code'] ?? data['studentCode'] ?? data['student_id'];
        final code = raw == null ? '' : raw.toString().trim();
        if (code.isNotEmpty) return code;
        // Fallback so the UI can still disambiguate students with similar names.
        return getKioskCode();
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
        studentCode: getStudentCode(),
        dateAdded: formatTimestamp(data['date_added']),
        lastLogin: formatTimestamp(data['last_login']),
        documentId: doc.id, // Store the document ID
        isAdminTeacher: data['is_admin_teacher'] as bool? ?? false,
        isActive: data['is_active'] as bool? ??
            true, // Default to active if field doesn't exist
        aiTutorEnabled: data['ai_tutor_enabled'] as bool? ?? false,
        tontineEnabled: data['tontine_enabled'] as bool? ?? false,
        isAdultStudent: (data['is_adult_student'] ?? data['isAdultStudent']) ==
            true,
        useZoom: data['use_zoom'] as bool? ?? false,
        zoomHostAccount: (data['zoom_host_account'] ??
                data['zoomHostAccount'] ??
                data['zoom_host_email'] ??
                '')
            .toString(),
        secondaryRoles: List<String>.from(data['secondary_roles'] ?? []),
        createdByUid: (data['created_by_uid'] ??
                data['created_by'] ??
                data['createdBy'] ??
                data['created_by_admin_id'] ??
                '')
            .toString(),
        createdAt: _parseTimestamp(
          data['date_added'] ?? data['created_at'] ?? data['createdAt'],
        ),
        deactivatedByUid: (data['deactivated_by_uid'] ??
                data['archived_by_uid'] ??
                data['archivedByUid'] ??
                '')
            .toString(),
        deactivatedAt: _parseTimestamp(
          data['deactivated_at'] ?? data['archived_at'] ?? data['archivedAt'],
        ),
        activatedByUid: (data['activated_by_uid'] ??
                data['restored_by_uid'] ??
                data['restoredByUid'] ??
                '')
            .toString(),
        activatedAt: _parseTimestamp(
          data['activated_at'] ?? data['restored_at'] ?? data['restoredAt'],
        ),
      );
    }).toList();
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
