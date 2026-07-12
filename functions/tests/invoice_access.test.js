jest.mock('firebase-functions/v2/firestore', () => ({
  onDocumentWritten: (_path, fn) => fn,
}));

jest.mock('firebase-functions/v2/scheduler', () => ({
  onSchedule: (_schedule, fn) => fn,
}));

jest.mock('firebase-functions/v2/https', () => {
  class HttpsError extends Error {
    constructor(code, message, details) {
      super(message);
      this.code = code;
      this.details = details;
    }
  }
  return { HttpsError };
});

jest.mock('firebase-admin', () => {
  const firestoreFn = jest.fn();
  firestoreFn.FieldValue = {
    serverTimestamp: jest.fn(() => ({__type: 'serverTimestamp'})),
  };
  firestoreFn.Timestamp = {
    now: jest.fn(() => ({toDate: () => new Date()})),
    fromDate: jest.fn((date) => ({toDate: () => date})),
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
  extendStudentAccessCutoff,
} = require('../handlers/invoice_access');
const admin = require('firebase-admin');

const ts = (date) => ({toDate: () => date});

const docSnap = (id, data) => ({
  id,
  exists: data !== undefined,
  data: () => data,
});

const buildFirestore = ({invoices = {}, users = {}}) => {
  const writes = [];
  const collections = {invoices, users};

  const applySet = (name, id, data, options) => {
    const current = collections[name][id] || {};
    collections[name][id] = options && options.merge
      ? {...current, ...data}
      : {...data};
  };

  const refFor = (name, id) => ({
    id,
    collectionName: name,
    get: async () => docSnap(id, collections[name][id]),
  });

  const queryDoc = (name, id, data) =>
    Object.assign(docSnap(id, data), {ref: refFor(name, id)});

  const collection = (name) => ({
    where: (field, op, value) => ({
      get: async () => {
        if (op === '==') {
          return {
            docs: Object.entries(collections[name] || {})
              .filter(([, data]) => data[field] === value)
              .map(([id, data]) => queryDoc(name, id, data)),
          };
        }

        if (op === 'array-contains') {
          return {
            docs: Object.entries(collections[name] || {})
              .filter(([, data]) => (data[field] || []).includes(value))
              .map(([id, data]) => queryDoc(name, id, data)),
          };
        }

        throw new Error(`Unexpected query: ${name}.${field} ${op} ${value}`);
      },
    }),
    doc: (id) => refFor(name, id),
  });

  return {
    writes,
    collection,
    batch: () => ({
      set: (ref, data, options) => {
        writes.push({ref, data, options});
        applySet(ref.collectionName, ref.id, data, options);
      },
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

  test('extends blocking parent invoices and recomputes access', async () => {
    const extendTo = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
    const db = buildFirestore({
      invoices: {
        inv1: {
          parent_id: 'parent_1',
          student_id: 'student_1',
          status: 'pending',
          total_amount: 100,
          paid_amount: 0,
          access_cutoff_date: ts(new Date(Date.now() - 60 * 1000)),
        },
        inv2: {
          parentId: 'parent_1',
          studentId: 'student_1',
          status: 'pending',
          totalAmount: 100,
          paidAmount: 0,
          accessCutoffDate: ts(new Date(Date.now() - 60 * 1000)),
        },
        inv3: {
          parent_id: 'parent_1',
          student_id: 'student_1',
          status: 'paid',
          total_amount: 100,
          paid_amount: 100,
          access_cutoff_date: ts(new Date(Date.now() - 60 * 1000)),
        },
      },
      users: {
        admin_uid: {user_type: 'super_admin'},
        parent_1: {children_ids: ['student_1']},
        student_1: {guardian_ids: ['parent_1'], access_suspended: true},
      },
    });
    admin.firestore.mockReturnValue(db);

    const result = await extendStudentAccessCutoff({
      auth: {uid: 'admin_uid'},
      data: {
        parentId: 'parent_1',
        scope: 'parent',
        extendTo: extendTo.toISOString(),
      },
    });

    expect(result.updatedInvoices).toBe(2);
    expect(db.writes.some((write) =>
      write.ref.id === 'student_1' &&
      write.data.access_suspended === false
    )).toBe(true);
  });
});
