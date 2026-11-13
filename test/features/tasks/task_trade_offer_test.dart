import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alluwalacademyadmin/features/tasks/enums/task_enums.dart';
import 'package:alluwalacademyadmin/features/tasks/models/task_trade_offer.dart';

void main() {
  Map<String, dynamic> taskData({
    List<String> assignedTo = const ['amina'],
    TaskStatus status = TaskStatus.todo,
    bool archived = false,
    bool draft = false,
    String? offeredBy,
    DateTime? offeredAt,
  }) =>
      {
        'title': 'Call the parents',
        'assignedTo': assignedTo,
        'status': status.toString(),
        'isArchived': archived,
        'isDraft': draft,
        if (offeredBy != null) ...{
          'offeredForTrade': true,
          'offeredBy': offeredBy,
          'offeredByName': 'Amina Diallo',
          'offeredAt': Timestamp.fromDate(offeredAt ?? DateTime(2026, 11, 12)),
        },
      };

  group('reading a task document', () {
    test('a task written before trading existed is simply not offered', () {
      final state = TaskTradeState.fromTaskData('t', taskData());
      expect(state.isOffered, isFalse);
      expect(state.offer, isNull);
      expect(state.assignedTo, ['amina']);
    });

    test('an offered task carries who offered it and when', () {
      final state =
          TaskTradeState.fromTaskData('t', taskData(offeredBy: 'amina'));
      expect(state.isOffered, isTrue);
      expect(state.offer!.offeredBy, 'amina');
      expect(state.offer!.offeredByName, 'Amina Diallo');
      expect(state.offer!.offeredAt, DateTime(2026, 11, 12));
    });

    test('the old single-assignee format still reads', () {
      final state = TaskTradeState.fromTaskData(
          't', {'assignedTo': 'amina', 'status': 'TaskStatus.todo'});
      expect(state.assignedTo, ['amina']);
    });

    test('the flag without an offerer is not an offer', () {
      expect(TaskTradeOffer.fromTaskData({'offeredForTrade': true}), isNull);
      expect(TaskTradeOffer.fromTaskData(null), isNull);
    });

    test('an offer left on a finished or archived task no longer counts', () {
      expect(
        TaskTradeState.fromTaskData(
                't', taskData(offeredBy: 'amina', status: TaskStatus.done))
            .isOffered,
        isFalse,
      );
      expect(
        TaskTradeState.fromTaskData(
                't', taskData(offeredBy: 'amina', archived: true))
            .isOffered,
        isFalse,
      );
    });
  });

  group('who may do what', () {
    test('a leader assigned to an open task may offer it', () {
      final state = TaskTradeState.fromTaskData('t', taskData());
      expect(state.canOffer(uid: 'amina', isLeader: true), isTrue);
      expect(state.canOffer(uid: 'amina', isLeader: false), isFalse);
      expect(state.canOffer(uid: 'bilal', isLeader: true), isFalse);
    });

    test('done, archived and draft tasks cannot be offered', () {
      for (final data in [
        taskData(status: TaskStatus.done),
        taskData(archived: true),
        taskData(draft: true),
      ]) {
        expect(
          TaskTradeState.fromTaskData('t', data)
              .canOffer(uid: 'amina', isLeader: true),
          isFalse,
        );
      }
    });

    test('only the leader who offered takes the offer back', () {
      final state =
          TaskTradeState.fromTaskData('t', taskData(offeredBy: 'amina'));
      expect(state.canOffer(uid: 'amina', isLeader: true), isFalse);
      expect(state.canWithdraw(uid: 'amina', isLeader: true), isTrue);
      expect(state.canWithdraw(uid: 'bilal', isLeader: true), isFalse);
    });

    test('another leader may take it; the offerer and non-leaders may not', () {
      final state =
          TaskTradeState.fromTaskData('t', taskData(offeredBy: 'amina'));
      expect(state.canTake(uid: 'bilal', isLeader: true), isTrue);
      expect(state.canTake(uid: 'amina', isLeader: true), isFalse);
      expect(state.canTake(uid: 'bilal', isLeader: false), isFalse);
    });
  });

  group('assignees after a take-over', () {
    test('the taker stands where the offerer stood', () {
      expect(
        TaskTradeState.assigneesAfterTakeOver(
          assignedTo: ['x', 'amina', 'y'],
          offererUid: 'amina',
          takerUid: 'bilal',
        ),
        ['x', 'bilal', 'y'],
      );
    });

    test('a taker already on the task: the offerer is just removed', () {
      expect(
        TaskTradeState.assigneesAfterTakeOver(
          assignedTo: ['amina', 'bilal', 'y'],
          offererUid: 'amina',
          takerUid: 'bilal',
        ),
        ['bilal', 'y'],
      );
    });

    test('the only assignee hands the task over whole', () {
      expect(
        TaskTradeState.assigneesAfterTakeOver(
          assignedTo: ['amina'],
          offererUid: 'amina',
          takerUid: 'bilal',
        ),
        ['bilal'],
      );
    });

    test('an offerer already off the task: the taker is added', () {
      expect(
        TaskTradeState.assigneesAfterTakeOver(
          assignedTo: ['x'],
          offererUid: 'amina',
          takerUid: 'bilal',
        ),
        ['x', 'bilal'],
      );
    });

    test('never lists anyone twice', () {
      expect(
        TaskTradeState.assigneesAfterTakeOver(
          assignedTo: ['amina', 'x', 'amina', 'x'],
          offererUid: 'amina',
          takerUid: 'bilal',
        ),
        ['bilal', 'x'],
      );
    });
  });

  test('a leader sees the tasks others offered, earliest offer first', () {
    final states = [
      TaskTradeState.fromTaskData('late',
          taskData(offeredBy: 'amina', offeredAt: DateTime(2026, 11, 13))),
      TaskTradeState.fromTaskData('mine', taskData(offeredBy: 'bilal')),
      TaskTradeState.fromTaskData('not-offered', taskData()),
      TaskTradeState.fromTaskData(
          'done', taskData(offeredBy: 'amina', status: TaskStatus.done)),
      TaskTradeState.fromTaskData('early',
          taskData(offeredBy: 'amina', offeredAt: DateTime(2026, 11, 10))),
    ];
    expect(
      TaskTradeState.takeableBy(states: states, uid: 'bilal')
          .map((s) => s.taskId),
      ['early', 'late'],
    );
  });

  test('ending an offer clears all four fields', () {
    expect(TaskTradeOffer.clearedFields('gone').keys, [
      'offeredForTrade',
      'offeredBy',
      'offeredByName',
      'offeredAt',
    ]);
    expect(
      TaskTradeOffer.offerFields(uid: 'amina', name: 'Amina', offeredAt: 1),
      {
        'offeredForTrade': true,
        'offeredBy': 'amina',
        'offeredByName': 'Amina',
        'offeredAt': 1,
      },
    );
  });
}
