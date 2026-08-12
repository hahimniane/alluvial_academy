import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

class ClassParentContact {
  final String id;
  final String name;
  final String? phone;

  const ClassParentContact({
    required this.id,
    required this.name,
    this.phone,
  });

  factory ClassParentContact.fromUserData({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return ClassParentContact(
      id: id,
      name: ClassRosterContactParser.displayName(data, fallback: id),
      phone: ClassRosterContactParser.phoneNumber(data),
    );
  }
}

class ClassStudentContact {
  final String accountId;
  final String studentId;
  final String name;
  final List<ClassParentContact> parents;
  final bool parentLookupFailed;

  const ClassStudentContact({
    required this.accountId,
    required this.studentId,
    required this.name,
    required this.parents,
    this.parentLookupFailed = false,
  });

  factory ClassStudentContact.fromUserData({
    required String accountId,
    required Map<String, dynamic> data,
    required String fallbackName,
    required List<ClassParentContact> parents,
    bool parentLookupFailed = false,
  }) {
    return ClassStudentContact(
      accountId: accountId,
      studentId: ClassRosterContactParser.studentId(
        data,
        fallback: accountId,
      ),
      name: ClassRosterContactParser.displayName(
        data,
        fallback: fallbackName.isNotEmpty ? fallbackName : accountId,
      ),
      parents: parents,
      parentLookupFailed: parentLookupFailed,
    );
  }
}

class ClassRosterContactParser {
  const ClassRosterContactParser._();

  static String displayName(
    Map<String, dynamic> data, {
    required String fallback,
  }) {
    final first = _firstNonEmpty(data, const ['first_name', 'firstName']);
    final last = _firstNonEmpty(data, const ['last_name', 'lastName']);
    final fullName = '$first $last'.trim();
    if (fullName.isNotEmpty) return fullName;

    final storedName = _firstNonEmpty(
      data,
      const ['display_name', 'displayName', 'full_name', 'fullName', 'name'],
    );
    return storedName.isNotEmpty ? storedName : fallback;
  }

  static String studentId(
    Map<String, dynamic> data, {
    required String fallback,
  }) {
    final value = _firstNonEmpty(
      data,
      const ['student_code', 'studentCode', 'student_id', 'studentId'],
    );
    return value.isNotEmpty ? value : fallback;
  }

  static List<String> guardianIds(Map<String, dynamic> data) {
    final ids = <String>{};

    for (final key in const ['guardian_ids', 'guardianIds']) {
      final value = data[key];
      if (value is Iterable) {
        ids.addAll(value.map((item) => item.toString().trim()));
      }
    }

    for (final key in const [
      'guardian_id',
      'guardianId',
      'parent_id',
      'parentId',
    ]) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) ids.add(value);
    }

    ids.removeWhere((id) => id.isEmpty);
    return ids.toList();
  }

  static String? phoneNumber(Map<String, dynamic> data) {
    final value = _firstNonEmpty(
      data,
      const [
        'phone_number',
        'phoneNumber',
        'mobile_phone',
        'mobilePhone',
        'phone',
        'mobile',
        'telephone',
      ],
    );
    return value.isEmpty ? null : value;
  }

  static String _firstNonEmpty(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }
}

class ClassRosterContactService {
  ClassRosterContactService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<List<ClassStudentContact>> loadContacts({
    required List<String> studentIds,
    required List<String> studentNames,
  }) async {
    final contacts = <ClassStudentContact>[];
    final studentCount = studentIds.length > studentNames.length
        ? studentIds.length
        : studentNames.length;

    for (var index = 0; index < studentCount; index++) {
      final accountId =
          index < studentIds.length ? studentIds[index].trim() : '';
      final fallbackName =
          index < studentNames.length ? studentNames[index].trim() : '';

      if (accountId.isEmpty) {
        contacts.add(
          ClassStudentContact(
            accountId: '',
            studentId: '',
            name: fallbackName,
            parents: const [],
          ),
        );
        continue;
      }

      try {
        final studentDocument =
            await _firestore.collection('users').doc(accountId).get();
        final studentData = studentDocument.data() ?? <String, dynamic>{};
        final parentLookup = await _loadParents(accountId, studentData);

        contacts.add(
          ClassStudentContact.fromUserData(
            accountId: accountId,
            data: studentData,
            fallbackName: fallbackName,
            parents: parentLookup.parents,
            parentLookupFailed: parentLookup.failed,
          ),
        );
      } catch (error) {
        AppLogger.error(
          'ClassRosterContactService: failed to load student $accountId: '
          '$error',
        );
        contacts.add(
          ClassStudentContact(
            accountId: accountId,
            studentId: accountId,
            name: fallbackName.isNotEmpty ? fallbackName : accountId,
            parents: const [],
            parentLookupFailed: true,
          ),
        );
      }
    }

    return contacts;
  }

  Future<_ClassParentLookupResult> _loadParents(
    String studentId,
    Map<String, dynamic> studentData,
  ) async {
    final parentDocuments = <String, DocumentSnapshot<Map<String, dynamic>>>{};
    final unavailableParents = <ClassParentContact>[];
    final guardianIds = ClassRosterContactParser.guardianIds(studentData);
    var failed = false;

    for (final guardianId in guardianIds) {
      try {
        final document =
            await _firestore.collection('users').doc(guardianId).get();
        parentDocuments[guardianId] = document;
      } catch (error) {
        failed = true;
        AppLogger.error(
          'ClassRosterContactService: failed to load parent $guardianId: '
          '$error',
        );
        unavailableParents.add(
          ClassParentContact(id: guardianId, name: guardianId),
        );
      }
    }

    if (guardianIds.isEmpty) {
      for (final field in const ['children_ids', 'childrenIds']) {
        try {
          final snapshot = await _firestore
              .collection('users')
              .where(field, arrayContains: studentId)
              .get();
          for (final document in snapshot.docs) {
            parentDocuments[document.id] = document;
          }
        } catch (error) {
          failed = true;
          AppLogger.error(
            'ClassRosterContactService: failed reverse parent lookup for '
            '$studentId using $field: $error',
          );
        }
      }
    }

    final parents = <ClassParentContact>[...unavailableParents];
    for (final entry in parentDocuments.entries) {
      parents.add(
        ClassParentContact.fromUserData(
          id: entry.key,
          data: entry.value.data() ?? <String, dynamic>{},
        ),
      );
    }
    parents.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return _ClassParentLookupResult(parents: parents, failed: failed);
  }
}

class _ClassParentLookupResult {
  final List<ClassParentContact> parents;
  final bool failed;

  const _ClassParentLookupResult({
    required this.parents,
    required this.failed,
  });
}
