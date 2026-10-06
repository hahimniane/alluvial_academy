jest.mock('firebase-functions/v2/firestore', () => ({
  onDocumentCreated: (_path, fn) => fn,
}));
jest.mock('firebase-functions/v2/scheduler', () => ({
  onSchedule: (...args) => args[args.length - 1],
}));
jest.mock('../services/email/senders', () => ({
  sendInvoiceCreatedEmail: jest.fn(async () => true),
  sendPaymentConfirmationEmail: jest.fn(async () => true),
}));

const {_findDuplicateActivePlan} = require('../handlers/payments');

// A plan that bills one student, described the way the generator stores it.
const planFor = (studentIds, extra = {}) => ({
  total_amount: 68,
  currency: 'USD',
  interval: 'monthly',
  base_items: studentIds.map((id) => ({
    description: `Tuition - ${id}`,
    student_id: id,
  })),
  ...extra,
});

describe('_findDuplicateActivePlan', () => {
  test('flags an existing plan for the identical single student', () => {
    const clash = _findDuplicateActivePlan({
      studentIds: ['stu_1'],
      existingPlans: [planFor(['stu_1'], {total_amount: 68})],
    });
    expect(clash).not.toBeNull();
    expect(clash.total_amount).toBe(68);
  });

  test('flags a duplicate even when the amount differs', () => {
    // Same enrollment, mistyped price: still a duplicate plan, not a new one.
    const clash = _findDuplicateActivePlan({
      studentIds: ['stu_1'],
      existingPlans: [planFor(['stu_1'], {total_amount: 106.8})],
    });
    expect(clash).not.toBeNull();
  });

  test('matches on the exact student set regardless of order', () => {
    const clash = _findDuplicateActivePlan({
      studentIds: ['stu_b', 'stu_a'],
      existingPlans: [planFor(['stu_a', 'stu_b'])],
    });
    expect(clash).not.toBeNull();
  });

  test('does NOT flag a different single student', () => {
    const clash = _findDuplicateActivePlan({
      studentIds: ['stu_2'],
      existingPlans: [planFor(['stu_1'])],
    });
    expect(clash).toBeNull();
  });

  test('does NOT flag a superset/subset of the same family', () => {
    // One child vs. both children are different enrollments.
    expect(
      _findDuplicateActivePlan({
        studentIds: ['stu_1'],
        existingPlans: [planFor(['stu_1', 'stu_2'])],
      })
    ).toBeNull();
    expect(
      _findDuplicateActivePlan({
        studentIds: ['stu_1', 'stu_2'],
        existingPlans: [planFor(['stu_1'])],
      })
    ).toBeNull();
  });

  test('falls back to plan.student_id when base_items is absent', () => {
    const clash = _findDuplicateActivePlan({
      studentIds: ['stu_1'],
      existingPlans: [{total_amount: 50, student_id: 'stu_1'}],
    });
    expect(clash).not.toBeNull();
  });

  test('empty incoming student set never clashes', () => {
    expect(
      _findDuplicateActivePlan({
        studentIds: [],
        existingPlans: [planFor(['stu_1'])],
      })
    ).toBeNull();
  });

  test('no existing plans means no clash', () => {
    expect(
      _findDuplicateActivePlan({studentIds: ['stu_1'], existingPlans: []})
    ).toBeNull();
  });

  test('picks the matching plan out of several', () => {
    const clash = _findDuplicateActivePlan({
      studentIds: ['stu_2'],
      existingPlans: [
        planFor(['stu_1']),
        planFor(['stu_3']),
        planFor(['stu_2'], {total_amount: 99}),
      ],
    });
    expect(clash).not.toBeNull();
    expect(clash.total_amount).toBe(99);
  });
});
