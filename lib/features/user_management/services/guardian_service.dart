import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

/// A single parent/guardian linked to a student.
class GuardianLink {
  final String id;
  final String name;
  final String? email;
  final String? phone;

  const GuardianLink({
    required this.id,
    required this.name,
    this.email,
    this.phone,
  });
}

/// A single student linked to a parent/guardian.
class ParentStudentLink {
  final String id;
  final String name;
  final String? email;
  final String? studentCode;
  final bool isAdultStudent;

  const ParentStudentLink({
    required this.id,
    required this.name,
    this.email,
    this.studentCode,
    this.isAdultStudent = false,
  });
}

/// Admin-side reads and mutations for the parent ⇄ student relationship.
///
/// Linking is performed server-side by `inviteParentForEnrollment`. Unlinking
/// goes through the `unlinkGuardianFromStudent` callable so the two-sided
/// `guardian_ids` / `children_ids` edges, enrollment metadata, and the audit
/// trail all stay consistent.
class GuardianService {
  static FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  static String _displayName(Map<String, dynamic> data, String fallback) {
    final first = (data['first_name'] ?? '').toString().trim();
    final last = (data['last_name'] ?? '').toString().trim();
    final name = ('$first $last').trim();
    final displayName =
        (data['displayName'] ?? data['name'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;
    if (displayName.isNotEmpty) return displayName;
    return fallback;
  }

  /// The parents currently linked to [studentUid].
  static Future<List<GuardianLink>> getStudentGuardians(
      String studentUid) async {
    final studentDoc =
        await _firestore.collection('users').doc(studentUid).get();
    if (!studentDoc.exists) return const [];

    final data = studentDoc.data() ?? {};
    final guardianIds = <String>{
      ...((data['guardian_ids'] as List?)?.map((e) => e.toString()) ?? []),
      ...((data['guardianIds'] as List?)?.map((e) => e.toString()) ?? []),
    }.where((id) => id.trim().isNotEmpty).toList();

    if (guardianIds.isEmpty) return const [];

    final guardians = <GuardianLink>[];
    for (final id in guardianIds) {
      try {
        final parentDoc = await _firestore.collection('users').doc(id).get();
        final parent = parentDoc.data() ?? {};
        guardians.add(GuardianLink(
          id: id,
          name: _displayName(parent, id),
          email: (parent['e-mail'] ?? parent['email'])?.toString(),
          phone: (parent['phone_number'] ?? parent['phone'])?.toString(),
        ));
      } catch (e) {
        AppLogger.error('GuardianService: failed to load guardian $id: $e');
        guardians.add(GuardianLink(id: id, name: id));
      }
    }

    guardians
        .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return guardians;
  }

  /// The students currently linked to [parentUid].
  static Future<List<ParentStudentLink>> getParentStudents(
      String parentUid) async {
    final parentDoc = await _firestore.collection('users').doc(parentUid).get();
    final studentIds = <String>{};

    if (parentDoc.exists) {
      final parent = parentDoc.data() ?? {};
      studentIds.addAll(
        ((parent['children_ids'] as List?)?.map((e) => e.toString()) ?? []),
      );
      studentIds.addAll(
        ((parent['childrenIds'] as List?)?.map((e) => e.toString()) ?? []),
      );
    }

    try {
      final byGuardian = await _firestore
          .collection('users')
          .where('guardian_ids', arrayContains: parentUid)
          .get();
      studentIds.addAll(byGuardian.docs.map((doc) => doc.id));
    } catch (e) {
      AppLogger.error(
          'GuardianService: failed to query students for parent $parentUid: $e');
    }

    final cleanIds = studentIds.where((id) => id.trim().isNotEmpty).toList();
    if (cleanIds.isEmpty) return const [];

    final students = <ParentStudentLink>[];
    for (final id in cleanIds) {
      try {
        final studentDoc = await _firestore.collection('users').doc(id).get();
        final student = studentDoc.data() ?? {};
        students.add(ParentStudentLink(
          id: id,
          name: _displayName(student, id),
          email: (student['e-mail'] ?? student['email'])?.toString(),
          studentCode: (student['student_code'] ??
                  student['studentCode'] ??
                  student['student_id'])
              ?.toString(),
          isAdultStudent: student['is_adult_student'] == true,
        ));
      } catch (e) {
        AppLogger.error('GuardianService: failed to load student $id: $e');
        students.add(ParentStudentLink(id: id, name: id));
      }
    }

    students
        .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return students;
  }

  /// Sever the link between [parentUid] and [studentUid]. [reason] is optional
  /// and stored in the audit trail.
  static Future<void> unlinkGuardian({
    required String studentUid,
    required String parentUid,
    String? reason,
    bool convertStudentToAdult = false,
  }) async {
    final callable =
        FirebaseFunctions.instance.httpsCallable('unlinkGuardianFromStudent');
    await callable.call<Map<String, dynamic>>({
      'studentUid': studentUid,
      'parentUid': parentUid,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      if (convertStudentToAdult) 'convertStudentToAdult': true,
    });
  }
}
