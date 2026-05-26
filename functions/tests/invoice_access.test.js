jest.mock('firebase-functions/v2/firestore', () => ({
  onDocumentWritten: (_path, fn) => fn,
}));

jest.mock('firebase-functions/v2/scheduler', () => ({
  onSchedule: (_schedule, fn) => fn,
}));

jest.mock('firebase-admin', () => {
  const firestoreFn = jest.fn();
  firestoreFn.FieldValue = {
    serverTimestamp: jest.fn(() => ({__type: 'serverTimestamp'})),
  };

  return {
    apps: [],
    initializeApp: jest.fn(),
    firestore: firestoreFn,
  };
});

const {
  _getEffectiveAccessCutoffDate,
  _recomputeStudentAccess,
} = require('../handlers/invoice_access');

const ts = (date) => ({toDate: () => date});

const docSnap = (id, data) => ({
  id,
  exists: data !== undefined,
  data: () => data,
});

const buildFirestore = ({invoices = {}, users = {}}) => {
  const writes = [];

  const collection = (name) => ({
    where: (field, op, value) => ({
      get: async () => {
        if (name === 'invoices' && field === 'parent_id' && op === '==') {
          return {
            docs: Object.entries(invoices)
              .filter(([, data]) => data.parent_id === value)
              .map(([id, data]) => docSnap(id, data)),
          };
        }

        if (name === 'users' && field === 'guardian_ids' && op === 'array-contains') {
          return {
            docs: Object.entries(users)
              .filter(([, data]) => (data.guardian_ids || []).includes(value))
              .map(([id, data]) => docSnap(id, data)),
          };
        }

        throw new Error(`Unexpected query: ${name}.${field} ${op} ${value}`);
      },
    }),
    doc: (id) => ({
      get: async () => docSnap(id, users[id]),
    }),
  });

  return {
    writes,
    collection,
    batch: () => ({
      set: (ref, data, options) => writes.push({ref, data, options}),
      commit: async () => {},
    }),
  };
};

describe('invoice access recompute', () => {
  test('uses due date plus one day when access cutoff is missing', () => {
    const dueDate = new Date('2026-01-10T12:00:00.000Z');

    expect(_getEffectiveAccessCutoffDate({due_date: ts(dueDate)}))
      .toEqual(new Date('2026-01-11T12:00:00.000Z'));
  });

  test('suspends invoice student when fallback due-date cutoff has passed', async () => {
    const db = buildFirestore({
      invoices: {
        inv1: {
          parent_id: 'parent_1',
          student_id: 'student_from_invoice',
          status: 'pending',
          total_amount: 100,
          paid_amount: 0,
          due_date: ts(new Date(Date.now() - 2 * 24 * 60 * 60 * 1000)),
        },
      },
      users: {
        parent_1: {children_ids: []},
        student_from_invoice: {user_type: 'Student'},
      },
    });

    await _recomputeStudentAccess(db, 'parent_1');

    expect(db.writes).toHaveLength(1);
    expect(db.writes[0].data.access_suspended).toBe(true);
  });

  test('suspends invoice student even when guardian links are missing', async () => {
    const db = buildFirestore({
      invoices: {
        inv1: {
          parent_id: 'parent_1',
          student_id: 'student_from_invoice',
          status: 'pending',
          total_amount: 100,
          paid_amount: 0,
          access_cutoff_date: ts(new Date(Date.now() - 60 * 1000)),
        },
      },
      users: {
        parent_1: {children_ids: []},
        student_from_invoice: {user_type: 'Student'},
      },
    });

    await _recomputeStudentAccess(db, 'parent_1');

    expect(db.writes).toHaveLength(1);
    expect(db.writes[0].ref).toEqual(
      expect.objectContaining({}),
    );
    expect(db.writes[0].data.access_suspended).toBe(true);
    expect(db.writes[0].options).toEqual({merge: true});
  });

  test('restores linked students when blocking invoice is paid', async () => {
    const db = buildFirestore({
      invoices: {
        inv1: {
          parent_id: 'parent_1',
          student_id: 'student_1',
          status: 'paid',
          total_amount: 100,
          paid_amount: 100,
          access_cutoff_date: ts(new Date(Date.now() - 60 * 1000)),
        },
      },
      users: {
        parent_1: {children_ids: ['student_1']},
        student_1: {guardian_ids: ['parent_1'], access_suspended: true},
      },
    });

    await _recomputeStudentAccess(db, 'parent_1');

    expect(db.writes).toHaveLength(1);
    expect(db.writes[0].data.access_suspended).toBe(false);
    expect(db.writes[0].options).toEqual({merge: true});
  });
});
