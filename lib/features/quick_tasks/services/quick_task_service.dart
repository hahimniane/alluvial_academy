import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/quick_task.dart';

class QuickTaskService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _collection = 'quick_tasks';

  Stream<List<QuickTask>> streamTasksForUser(String userId) {
    return _db
        .collection(_collection)
        .where('assignees', arrayContains: userId)
        .orderBy('due_date')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => QuickTask.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<QuickTask>> streamCreatedTasks(String adminId) {
    return _db
        .collection(_collection)
        .where('created_by', isEqualTo: adminId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => QuickTask.fromMap(d.data(), d.id)).toList());
  }

  Future<void> createTask(QuickTask task) async {
    await _db.collection(_collection).add(task.toMap());
  }

  Future<void> markCompleted(String taskId, bool value) async {
    await _db
        .collection(_collection)
        .doc(taskId)
        .update({'is_completed': value});
  }
}
