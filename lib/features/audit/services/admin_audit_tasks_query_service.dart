import 'package:cloud_firestore/cloud_firestore.dart';

import '../../tasks/models/task.dart';

/// Tasks touching an admin in a calendar month (same window as [AdminAuditService]).
class AdminAuditTasksQueryService {
  AdminAuditTasksQueryService._();

  static final _firestore = FirebaseFirestore.instance;

  static Future<List<Task>> loadTasksForAdminMonth({
    required String adminId,
    required String yearMonth,
  }) async {
    final monthStart = DateTime.parse('$yearMonth-01');
    final monthEnd = DateTime(monthStart.year, monthStart.month + 1);
    final snap = await _firestore
        .collection('tasks')
        .where('dueDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
        .where('dueDate', isLessThan: Timestamp.fromDate(monthEnd))
        .get();

    final out = <Task>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final assigned =
          (data['assignedTo'] as List<dynamic>?)?.cast<String>() ?? [];
      final createdBy = (data['createdBy'] as String?) ?? '';
      if (!assigned.contains(adminId) && createdBy != adminId) continue;
      try {
        out.add(Task.fromFirestore(doc));
      } catch (_) {
        // skip malformed
      }
    }
    out.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return out;
  }
}
