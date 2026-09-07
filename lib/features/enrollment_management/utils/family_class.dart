/// Applications that are one class.
///
/// "Exclusive family class" means only this family's children, taught
/// together. Enrollment writes one document per student, so a family class
/// arrives as several documents describing a single class. They join only
/// when they came from the same submission (`metadata.parentLinkId`), name
/// the same subject, and both say the class is exclusive to the family —
/// siblings enrolled separately, or in different programs, stay separate.
///
/// Mirrors `apps/web/src/lib/familyGroups.ts`.
const String familyClassType = 'Exclusive Family Class';

/// The grouping key for an enrollment document's data, or null when the
/// document is a class of its own.
String? familyClassKey(Map<String, dynamic> data) {
  final program = (data['program'] as Map?) ?? const {};
  final classType = (program['classType'] ?? data['classType'] ?? '').toString();
  if (classType != familyClassType) return null;
  final metadata = (data['metadata'] as Map?) ?? const {};
  final link = (metadata['parentLinkId'] ?? data['parentLinkId'] ?? '').toString().trim();
  if (link.isEmpty) return null;
  final subject = (data['subject'] ?? '').toString().trim().toLowerCase();
  return '$link::$subject';
}

/// One child of a family class, as the matched card works with it.
class FamilyMember {
  final String enrollmentId;
  final String name;
  String uid;
  FamilyMember({required this.enrollmentId, required this.name, required this.uid});
}

/// "test 1 and test 2", "a, b and c".
String listNames(Iterable<String> names) {
  final clean = names.map((n) => n.trim()).where((n) => n.isNotEmpty).toList();
  if (clean.isEmpty) return '';
  if (clean.length == 1) return clean.first;
  return '${clean.sublist(0, clean.length - 1).join(', ')} and ${clean.last}';
}
