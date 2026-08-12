jest.mock('firebase-admin', () => ({
  firestore: Object.assign(jest.fn(), {
    FieldValue: {
      serverTimestamp: jest.fn(() => 'SERVER_TIMESTAMP'),
    },
  }),
}));

jest.mock('firebase-functions/v2/firestore', () => ({
  onDocumentWrittenWithAuthContext: jest.fn((_, handler) => handler),
}));

const {
  classifyApplicationDecisions,
  classifyAuditDecisions,
  classifyEnrollmentDecisions,
  classifyFormResponseDecisions,
  classifyInvoiceDecisions,
  classifyNoShowDecisions,
  classifyShiftDecisions,
  classifyTaskDecisions,
  classifyTimesheetDecisions,
  classifyUserDecisions,
  classifySettingDecisions,
} = require('../handlers/decision_audits');
const {
  applyDecisionAuditWrites,
  buildDecisionAuditWrites,
  decisionAuditDocumentId,
  resolveDecisionActor,
} = require('../services/decision_audit');

describe('decision audit classification', () => {
  test('classifies user archive, restore, role, and delete decisions', () => {
    expect(
      classifyUserDecisions({is_active: true}, {is_active: false}),
    ).toEqual([{action: 'user.archived'}]);
    expect(
      classifyUserDecisions({is_active: false}, {is_active: true}),
    ).toEqual([{action: 'user.restored'}]);
    expect(
      classifyUserDecisions(
        {is_active: true, user_type: 'teacher'},
        {is_active: true, user_type: 'admin'},
      ),
    ).toEqual([
      {
        action: 'user.role_changed',
        metadata: {previous_role: 'teacher', new_role: 'admin'},
      },
    ]);
    expect(classifyUserDecisions({is_active: false}, null)).toEqual([
      {action: 'user.deleted'},
    ]);
  });

  test('does not audit ordinary user profile edits as critical decisions', () => {
    expect(
      classifyUserDecisions(
        {is_active: true, phone_number: '111'},
        {is_active: true, phone_number: '222'},
      ),
    ).toEqual([]);
  });

  test('classifies shift creation and simultaneous critical changes', () => {
    expect(classifyShiftDecisions(null, {status: 'scheduled'})).toEqual([
      {action: 'shift.created'},
    ]);
    expect(
      classifyShiftDecisions(
        {
          status: 'scheduled',
          is_published: false,
          teacher_id: 'teacher-1',
          shift_start: 1,
          shift_end: 2,
          student_ids: ['student-1'],
        },
        {
          status: 'cancelled',
          is_published: true,
          teacher_id: 'teacher-2',
          shift_start: 3,
          shift_end: 4,
          student_ids: ['student-1', 'student-2'],
        },
      ).map((event) => event.action),
    ).toEqual([
      'shift.cancelled',
      'shift.published',
      'shift.rescheduled',
      'shift.teacher_changed',
      'shift.students_changed',
    ]);
  });

  test('ignores runtime-only shift writes', () => {
    expect(
      classifyShiftDecisions(
        {status: 'active', whiteboard: {a: 1}},
        {status: 'active', whiteboard: {a: 2}},
      ),
    ).toEqual([]);
  });

  test('classifies invoice creation, payment status, and financial edits', () => {
    expect(classifyInvoiceDecisions(null, {status: 'pending'})).toEqual([
      {action: 'invoice.created'},
    ]);
    expect(
      classifyInvoiceDecisions(
        {
          status: 'pending',
          total_amount: 100,
          due_date: 1,
          access_cutoff_date: 2,
        },
        {
          status: 'paid',
          total_amount: 120,
          due_date: 3,
          access_cutoff_date: 4,
        },
      ).map((event) => event.action),
    ).toEqual([
      'invoice.paid',
      'invoice.amount_changed',
      'invoice.due_date_changed',
      'invoice.cutoff_changed',
    ]);
  });

  test('classifies timesheet approval, rejection, and payment decisions', () => {
    expect(
      classifyTimesheetDecisions(
        {status: 'pending', payment_amount: 80},
        {status: 'approved', payment_amount: 100},
      ).map((event) => event.action),
    ).toEqual(['timesheet.approved', 'timesheet.payment_changed']);
    expect(
      classifyTimesheetDecisions(
        {status: 'pending'},
        {status: 'rejected'},
      ),
    ).toEqual([{action: 'timesheet.rejected'}]);
  });

  test('classifies application and form review decisions', () => {
    expect(
      classifyApplicationDecisions(
        {status: 'pending'},
        {status: 'approved'},
      ),
    ).toEqual([{action: 'application.approved'}]);
    expect(
      classifyFormResponseDecisions(
        {reviewStatus: 'in review'},
        {reviewStatus: 'rejected'},
      ),
    ).toEqual([{action: 'form_response.rejected'}]);
  });

  test('classifies critical task changes without routine edits', () => {
    expect(
      classifyTaskDecisions(
        {
          title: 'A',
          status: 'TaskStatus.todo',
          assignedTo: ['user-1'],
          dueDate: 1,
        },
        {
          title: 'B',
          status: 'TaskStatus.done',
          assignedTo: ['user-2'],
          dueDate: 2,
        },
      ).map((event) => event.action),
    ).toEqual([
      'task.assignees_changed',
      'task.due_date_changed',
      'task.status_changed',
    ]);
  });

  test('classifies no-show review and reopen decisions', () => {
    expect(
      classifyNoShowDecisions(
        {status: 'pending'},
        {status: 'reviewed'},
      ),
    ).toEqual([{action: 'no_show.reviewed'}]);
    expect(
      classifyNoShowDecisions(
        {status: 'reviewed'},
        {status: 'pending'},
      ),
    ).toEqual([{action: 'no_show.reopened'}]);
  });

  test('classifies enrollment workflow and parent-link decisions', () => {
    expect(
      classifyEnrollmentDecisions(
        {metadata: {status: 'pending', parentId: 'parent-1'}},
        {metadata: {status: 'matched', parentId: 'parent-2'}},
      ).map((event) => event.action),
    ).toEqual(['enrollment.matched', 'enrollment.parent_link_changed']);
    expect(
      classifyEnrollmentDecisions(
        {metadata: {status: 'matched'}},
        {metadata: {status: 'archived'}},
      ),
    ).toEqual([{action: 'enrollment.archived'}]);
  });

  test('classifies audit reviews, compensation, and settings changes', () => {
    expect(
      classifyAuditDecisions(
        {status: 'pending', reviewChain: {}, ceoBonusMonthlyUsd: 0},
        {
          status: 'approved',
          reviewChain: {ceoReview: {status: 'approved'}},
          ceoBonusMonthlyUsd: 50,
        },
      ).map((event) => event.action),
    ).toEqual([
      'audit.status_changed',
      'audit.review_changed',
      'audit.compensation_changed',
    ]);
    expect(
      classifySettingDecisions(
        {feature_enabled: false, limit: 2},
        {feature_enabled: true, limit: 2},
      ),
    ).toEqual([
      {
        action: 'setting.changed',
        metadata: {changed_keys: ['feature_enabled']},
      },
    ]);
  });

  test('uses stable entity history document IDs', () => {
    expect(decisionAuditDocumentId('invoice', 'INV/2026')).toBe(
      'invoice__INV_2026',
    );
  });

  test('writes both entity history and the dedicated global ledger', () => {
    const refs = [];
    const makeDoc = (path) => ({
      path,
      collection: (name) => ({
        doc: (id) => makeDoc(`${path}/${name}/${id}`),
      }),
    });
    const db = {
      collection: (name) => ({
        doc: (id) => {
          const ref = makeDoc(`${name}/${id}`);
          refs.push(ref);
          return ref;
        },
      }),
    };
    const writer = {set: jest.fn()};
    const writes = buildDecisionAuditWrites({
      db,
      entityType: 'invoice',
      entityId: 'invoice-1',
      entityLabel: 'INV-1',
      action: 'invoice.created',
      actor: {uid: 'admin-1', name: 'Admin'},
      eventId: 'event-1',
    });

    applyDecisionAuditWrites(writer, writes);

    expect(writer.set).toHaveBeenCalledTimes(3);
    expect(writes.eventRef.path).toBe(
      'decision_audits/invoice__invoice-1/events/event-1',
    );
    expect(writes.globalEventRef.path).toMatch(
      /^decision_audit_events\/[a-f0-9]{64}$/,
    );
    expect(refs.map((ref) => ref.path)).toContain(
      writes.globalEventRef.path,
    );
    expect(writes.eventData.actor_kind).toBe('person');
  });

  test('turns service accounts into system automation', async () => {
    const actor = await resolveDecisionActor(
      {collection: jest.fn()},
      '123-compute@developer.gserviceaccount.com',
    );

    expect(actor).toEqual({
      uid: '',
      name: 'System automation',
      email: '',
      role: '',
      kind: 'system',
    });
  });

  test('prefers a real personal name over a phone-shaped profile name', async () => {
    const actorDocument = {
      exists: true,
      data: () => ({
        name: '+19292509698',
        first_name: 'Mamadou',
        last_name: 'Diallo',
        'e-mail': 'mamadou@example.com',
        user_type: 'admin',
      }),
    };
    const db = {
      collection: () => ({
        doc: () => ({get: jest.fn(async () => actorDocument)}),
      }),
    };

    const actor = await resolveDecisionActor(db, 'admin-1');

    expect(actor.name).toBe('Mamadou Diallo');
    expect(actor.kind).toBe('person');
  });
});
