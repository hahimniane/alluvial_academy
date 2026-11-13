import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/services/user_role_service.dart';
import '../../../core/utils/app_logger.dart';
import '../models/task_comment.dart';
import '../models/task_trade_offer.dart';

/// Why a task could not change hands.
enum TaskTradeFailure {
  /// The offer is gone: taken back, already taken, or the task was finished.
  noLongerOffered,

  /// The task is done, archived or a draft.
  notOpen,

  /// The person is not assigned to the task they tried to offer.
  notAssigned,

  /// The task no longer exists.
  notFound,
}

class TaskTradeException implements Exception {
  final TaskTradeFailure failure;
  const TaskTradeException(this.failure);

  @override
  String toString() => 'TaskTradeException(${failure.name})';
}

/// Leaders trading tasks: offer one, take the offer back, take someone
/// else's. Only admins can write tasks, so only they reach these.
class TaskTradeService {
  TaskTradeService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _tasks =>
      _firestore.collection('tasks');

  /// The trading state of one task, live.
  static Stream<TaskTradeState?> watchTask(String taskId) {
    return _tasks.doc(taskId).snapshots().map((snap) =>
        snap.exists ? TaskTradeState.fromTaskData(snap.id, snap.data()) : null);
  }

  /// The trading state of every offered task this person can read, keyed by
  /// task id. A leader reads all offered tasks; anyone else only those they
  /// are assigned to.
  static Stream<Map<String, TaskTradeState>> watchOffers({
    required bool isLeader,
  }) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(const {});

    // The non-leader query is the same one the task list already listens to,
    // so it costs no extra reads; the offer is picked out on the device.
    final Query<Map<String, dynamic>> query = isLeader
        ? _tasks.where(TaskTradeOffer.fieldOffered, isEqualTo: true)
        : _tasks.where('assignedTo', arrayContains: uid);

    return query.snapshots().map((snapshot) {
      final offers = <String, TaskTradeState>{};
      for (final doc in snapshot.docs) {
        final state = TaskTradeState.fromTaskData(doc.id, doc.data());
        if (state.isOffered) offers[doc.id] = state;
      }
      return offers;
    });
  }

  static Future<String> _myName(User user) async {
    try {
      final data = await UserRoleService.getCurrentUserData();
      final first = (data?['first_name'] ?? '').toString();
      final last = (data?['last_name'] ?? '').toString();
      final name = '$first $last'.trim();
      if (name.isNotEmpty) return name;
    } catch (e) {
      AppLogger.error('TaskTradeService: name lookup failed: $e');
    }
    return user.email ?? '';
  }

  static Future<String> _nameOf(String uid) async {
    try {
      final data = (await _firestore.collection('users').doc(uid).get()).data();
      final first = (data?['first_name'] ?? '').toString();
      final last = (data?['last_name'] ?? '').toString();
      return '$first $last'.trim();
    } catch (e) {
      AppLogger.error('TaskTradeService: name lookup failed: $e');
      return '';
    }
  }

  /// Puts a task I am assigned to on offer for another leader.
  static Future<void> offerTask(String taskId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Not signed in');
    final name = await _myName(user);
    final ref = _tasks.doc(taskId);

    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(ref);
      if (!snap.exists) {
        throw const TaskTradeException(TaskTradeFailure.notFound);
      }
      final state = TaskTradeState.fromTaskData(snap.id, snap.data());
      if (!state.isOpen) {
        throw const TaskTradeException(TaskTradeFailure.notOpen);
      }
      if (!state.assignedTo.contains(user.uid)) {
        throw const TaskTradeException(TaskTradeFailure.notAssigned);
      }
      if (state.isOffered) return;
      txn.update(
        ref,
        TaskTradeOffer.offerFields(
          uid: user.uid,
          name: name,
          offeredAt: FieldValue.serverTimestamp(),
        ),
      );
    });
  }

  /// Takes my own offer back; the task stays with me.
  static Future<void> withdrawOffer(String taskId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Not signed in');
    final ref = _tasks.doc(taskId);

    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(ref);
      if (!snap.exists) {
        throw const TaskTradeException(TaskTradeFailure.notFound);
      }
      final offer = TaskTradeOffer.fromTaskData(snap.data());
      // Already taken back, or taken by someone: nothing left to undo.
      if (offer == null || offer.offeredBy != user.uid) return;
      txn.update(ref, TaskTradeOffer.clearedFields(FieldValue.delete()));
    });
  }

  /// Takes a task another leader offered: I replace them among the
  /// assignees and the offer ends. Then a comment on the task records it;
  /// [commentFor] words that comment from my name and the offerer's.
  static Future<void> takeTask(
    String taskId, {
    required String Function(String takerName, String offererName) commentFor,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Not signed in');
    final myName = await _myName(user);
    final ref = _tasks.doc(taskId);

    final offererName = await _firestore.runTransaction<String>((txn) async {
      final snap = await txn.get(ref);
      if (!snap.exists) {
        throw const TaskTradeException(TaskTradeFailure.notFound);
      }
      final state = TaskTradeState.fromTaskData(snap.id, snap.data());
      final offer = state.offer;
      if (offer == null || offer.offeredBy == user.uid) {
        throw const TaskTradeException(TaskTradeFailure.noLongerOffered);
      }
      txn.update(ref, {
        'assignedTo': TaskTradeState.assigneesAfterTakeOver(
          assignedTo: state.assignedTo,
          offererUid: offer.offeredBy,
          takerUid: user.uid,
        ),
        ...TaskTradeOffer.clearedFields(FieldValue.delete()),
      });
      return offer.offeredByName.isNotEmpty
          ? offer.offeredByName
          : await _nameOf(offer.offeredBy);
    });

    // The task has changed hands; the comment is its record. If it cannot be
    // written the hand-over still stands.
    try {
      final comment = TaskComment(
        id: '',
        taskId: taskId,
        authorId: user.uid,
        authorName: myName,
        authorEmail: user.email ?? '',
        comment: commentFor(myName, offererName),
        createdAt: DateTime.now(),
      );
      await _firestore.collection('task_comments').add(comment.toFirestore());
    } catch (e) {
      AppLogger.error('TaskTradeService: hand-over comment failed: $e');
    }
  }
}
