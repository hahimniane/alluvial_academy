import 'package:cloud_functions/cloud_functions.dart';

import '../utils/app_logger.dart';

enum ClassContactRelationship { parent, student, teacher }

class ClassContact {
  const ClassContact({
    required this.name,
    required this.relationship,
    required this.phone,
    required this.tel,
  });

  final String name;
  final ClassContactRelationship relationship;

  /// The number as shown to people.
  final String phone;

  /// The number as dialled: digits with an optional leading `+`.
  final String tel;

  Uri get telUri => Uri(scheme: 'tel', path: tel);

  static ClassContact? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final relationship = switch ('${raw['relationship'] ?? ''}'.trim()) {
      'parent' => ClassContactRelationship.parent,
      'student' => ClassContactRelationship.student,
      'teacher' => ClassContactRelationship.teacher,
      _ => null,
    };
    final tel = '${raw['tel'] ?? ''}'.trim().replaceAll(RegExp(r'[^\d+]'), '');
    if (relationship == null || tel.replaceAll(RegExp(r'\D'), '').length < 6) {
      return null;
    }
    final phone = '${raw['phone'] ?? ''}'.trim();
    return ClassContact(
      name: '${raw['name'] ?? ''}'.trim(),
      relationship: relationship,
      phone: phone.isEmpty ? tel : phone,
      tel: tel,
    );
  }
}

/// One student and the people to call about them: a teacher's view lists the
/// student's parents, a parent's view lists the child's teachers.
class ClassContactGroup {
  const ClassContactGroup({required this.studentName, required this.contacts});

  final String studentName;
  final List<ClassContact> contacts;

  static ClassContactGroup? fromMap(Object? raw) {
    if (raw is! Map) return null;
    return ClassContactGroup(
      studentName: '${raw['studentName'] ?? ''}'.trim(),
      contacts: _contacts(raw['contacts']),
    );
  }
}

List<ClassContact> _contacts(Object? raw) => raw is List
    ? raw.map(ClassContact.fromMap).whereType<ClassContact>().toList()
    : const [];

List<ClassContactGroup> _groups(Object? raw) => raw is List
    ? raw.map(ClassContactGroup.fromMap).whereType<ClassContactGroup>().toList()
    : const [];

class ClassContacts {
  const ClassContacts({
    this.students = const [],
    this.children = const [],
    this.teachers = const [],
  });

  /// For a teacher: each student taught, with that student's parents.
  final List<ClassContactGroup> students;

  /// For a parent: each child, with that child's teachers.
  final List<ClassContactGroup> children;

  /// For a student: their own teachers.
  final List<ClassContact> teachers;

  factory ClassContacts.fromMap(Object? raw) {
    if (raw is! Map) return const ClassContacts();
    return ClassContacts(
      students: _groups(raw['students']),
      children: _groups(raw['children']),
      teachers: _contacts(raw['teachers']),
    );
  }
}

/// Phone numbers of the people the signed-in user has classes with, from the
/// getClassContacts callable.
class ClassContactsService {
  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  /// Null when the numbers could not be loaded.
  static Future<ClassContacts?> load() async {
    try {
      final result = await _functions
          .httpsCallable('getClassContacts')
          .call(<String, dynamic>{});
      return ClassContacts.fromMap(result.data);
    } catch (e) {
      AppLogger.error('ClassContactsService: could not load contacts: $e');
      return null;
    }
  }
}
