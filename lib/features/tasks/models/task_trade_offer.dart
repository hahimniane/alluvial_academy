import 'package:cloud_firestore/cloud_firestore.dart';

import '../enums/task_enums.dart';

/// A leader's offer to hand one of their tasks to another leader.
///
/// It lives on the task document as four fields, written only while the task
/// is on offer: `offeredForTrade`, `offeredBy`, `offeredByName`, `offeredAt`.
/// A task without them is simply not offered, so existing tasks need nothing.
class TaskTradeOffer {
  static const String fieldOffered = 'offeredForTrade';
  static const String fieldOfferedBy = 'offeredBy';
  static const String fieldOfferedByName = 'offeredByName';
  static const String fieldOfferedAt = 'offeredAt';

  /// Uid of the leader who offered the task.
  final String offeredBy;
  final String offeredByName;
  final DateTime? offeredAt;

  const TaskTradeOffer({
    required this.offeredBy,
    this.offeredByName = '',
    this.offeredAt,
  });

  /// The offer written on a task document, or null when there is none.
  static TaskTradeOffer? fromTaskData(Map<String, dynamic>? data) {
    if (data == null || data[fieldOffered] != true) return null;
    final by = (data[fieldOfferedBy] ?? '').toString().trim();
    if (by.isEmpty) return null;
    final at = data[fieldOfferedAt];
    return TaskTradeOffer(
      offeredBy: by,
      offeredByName: (data[fieldOfferedByName] ?? '').toString().trim(),
      offeredAt: at is Timestamp ? at.toDate() : null,
    );
  }

  /// The fields that put a task on offer. [offeredAt] is the write time.
  static Map<String, dynamic> offerFields({
    required String uid,
    required String name,
    required Object offeredAt,
  }) {
    return {
      fieldOffered: true,
      fieldOfferedBy: uid,
      fieldOfferedByName: name,
      fieldOfferedAt: offeredAt,
    };
  }

  /// The fields that end an offer, given the value that removes a field.
  static Map<String, dynamic> clearedFields(Object deleteValue) {
    return {
      fieldOffered: deleteValue,
      fieldOfferedBy: deleteValue,
      fieldOfferedByName: deleteValue,
      fieldOfferedAt: deleteValue,
    };
  }
}

/// Everything trading needs to know about one task, read straight from its
/// document, plus who may do what with it.
class TaskTradeState {
  final String taskId;
  final List<String> assignedTo;
  final bool isDone;
  final bool isArchived;
  final bool isDraft;
  final TaskTradeOffer? _offer;

  const TaskTradeState({
    required this.taskId,
    required this.assignedTo,
    this.isDone = false,
    this.isArchived = false,
    this.isDraft = false,
    TaskTradeOffer? offer,
  }) : _offer = offer;

  factory TaskTradeState.fromTaskData(
    String taskId,
    Map<String, dynamic>? data,
  ) {
    final raw = data?['assignedTo'];
    final assignedTo = raw is List
        ? raw.map((e) => e.toString()).toList()
        : raw is String
            ? <String>[raw]
            : <String>[];
    return TaskTradeState(
      taskId: taskId,
      assignedTo: assignedTo,
      isDone: data?['status'] == TaskStatus.done.toString(),
      isArchived: data?['isArchived'] == true,
      isDraft: data?['isDraft'] == true,
      offer: TaskTradeOffer.fromTaskData(data),
    );
  }

  /// A finished, archived or draft task is not something to hand over.
  bool get isOpen => !isDone && !isArchived && !isDraft;

  /// The live offer, or null. An offer left on a task that has since been
  /// finished or archived no longer counts.
  TaskTradeOffer? get offer => isOpen ? _offer : null;

  bool get isOffered => offer != null;

  /// A leader assigned to an open task may offer it.
  bool canOffer({required String uid, required bool isLeader}) =>
      isLeader && isOpen && !isOffered && assignedTo.contains(uid);

  /// Only the leader who offered it takes the offer back.
  bool canWithdraw({required String uid, required bool isLeader}) =>
      isLeader && isOffered && offer!.offeredBy == uid;

  /// Any other leader may take an offered task.
  bool canTake({required String uid, required bool isLeader}) =>
      isLeader && isOffered && offer!.offeredBy != uid;

  /// Who is assigned once [takerUid] takes the task from [offererUid]: the
  /// taker stands where the offerer stood. When the taker is already on the
  /// task, the offerer is simply removed. Everyone else keeps their place.
  static List<String> assigneesAfterTakeOver({
    required List<String> assignedTo,
    required String offererUid,
    required String takerUid,
  }) {
    final takerAlreadyOn = assignedTo.contains(takerUid);
    final result = <String>[];
    for (final assignee in assignedTo) {
      if (assignee == offererUid && offererUid != takerUid) {
        if (!takerAlreadyOn && !result.contains(takerUid)) {
          result.add(takerUid);
        }
        continue;
      }
      if (!result.contains(assignee)) result.add(assignee);
    }
    // The offerer had already been taken off the task some other way.
    if (!result.contains(takerUid)) result.add(takerUid);
    return result;
  }

  /// The offered tasks a leader can take: on offer, open, and not their own
  /// offer. Earliest offer first.
  static List<TaskTradeState> takeableBy({
    required Iterable<TaskTradeState> states,
    required String uid,
  }) {
    final list =
        states.where((s) => s.canTake(uid: uid, isLeader: true)).toList()
          ..sort((a, b) {
            final at = a.offer!.offeredAt;
            final bt = b.offer!.offeredAt;
            if (at == null || bt == null) return at == null ? 1 : -1;
            return at.compareTo(bt);
          });
    return list;
  }
}
