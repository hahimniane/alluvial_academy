'use strict';

/**
 * The pushes around a trade. Until 2026-11-13 the offer push crashed on an
 * undefined `db` before sending anything, so nobody was ever told a class was
 * on offer; these run the real handler code so that cannot come back.
 */

jest.mock('../services/notifications/fcm', () => ({
  sendFCMNotificationToTeacher: jest.fn(() => Promise.resolve({success: true})),
  sendFCMNotificationToStudent: jest.fn(() => Promise.resolve({success: true})),
  sendClassRemindersToStudents: jest.fn(),
  formatDateInTimezone: jest.fn(() => 'Nov 14, 3:00 PM'),
  getUserTimezone: jest.fn(() => Promise.resolve('America/New_York')),
}));

const admin = require('firebase-admin');
const fcm = require('../services/notifications/fcm');
const {__test__} = require('../handlers/shifts');

const userDocs = [
  {id: 't1', data: () => ({user_type: 'teacher'})},
  {id: 't2', data: () => ({user_type: 'teacher'})},
  {id: 'adm', data: () => ({user_type: 'admin'})},
  {id: 's1', data: () => ({user_type: 'student'})},
];

let added;
beforeEach(() => {
  jest.clearAllMocks();
  added = [];
  admin.firestore.FieldValue = {serverTimestamp: () => 'server-time', delete: () => 'delete'};
  const db = admin.firestore();
  db.get.mockImplementation(() => Promise.resolve({docs: userDocs}));
  db.add = jest.fn((doc) => {
    added.push(doc);
    return Promise.resolve({id: 'trade1'});
  });
});

const sentTo = () => fcm.sendFCMNotificationToTeacher.mock.calls.map((call) => call[0]).sort();

describe('offering', () => {
  test('a class offered by its teacher reaches the other teachers', async () => {
    await __test__.notifyTeachersOfPublishedShiftOffer({
      shiftId: 'sh1',
      shiftData: {teacher_id: 't1', custom_name: 'Quran', shift_category: 'teaching'},
      publishedByUid: 't1',
    });
    // The real query filters to teachers; the mock returns everyone, and the
    // audience rule still keeps only teachers.
    expect(sentTo()).toEqual(['t2']);
  });

  test('a class offered by an admin also tells its teacher', async () => {
    await __test__.notifyTeachersOfPublishedShiftOffer({
      shiftId: 'sh1',
      shiftData: {teacher_id: 't1', custom_name: 'Quran'},
      publishedByUid: 'adm',
    });
    expect(sentTo()).toEqual(['t1', 't2']);
    const ownerCall = fcm.sendFCMNotificationToTeacher.mock.calls.find((call) => call[0] === 't1');
    expect(ownerCall[1].title).toMatch(/Your class was offered/);
  });

  test('a leadership duty reaches leaders only', async () => {
    await __test__.notifyTeachersOfPublishedShiftOffer({
      shiftId: 'sh2',
      shiftData: {teacher_id: 'lead1', custom_name: 'Hosting', shift_category: 'leadership'},
      publishedByUid: 'lead1',
    });
    expect(sentTo()).toEqual(['adm']);
  });
});

describe('the trade record', () => {
  const event = {
    action: 'claimed',
    actor_id: 't2',
    from_teacher_id: 't1',
    from_teacher_name: 'Aisha',
    to_teacher_id: 't2',
    to_teacher_name: 'Bilal',
    shift_name: 'Quran',
    shift_start: {toDate: () => new Date('2026-11-14T20:00:00Z')},
  };

  test('a claim is recorded and the teacher who offered is told', async () => {
    await __test__.recordShiftTradeEvent({shiftId: 'sh1', event});
    expect(added).toHaveLength(1);
    expect(added[0]).toMatchObject({shift_id: 'sh1', action: 'claimed', to_teacher_id: 't2'});
    expect(sentTo()).toEqual(['t1']);
    expect(fcm.sendFCMNotificationToTeacher.mock.calls[0][1].body).toMatch(/Bilal will take Quran on Nov 14/);
  });

  test('an admin assignment also tells the new teacher', async () => {
    await __test__.recordShiftTradeEvent({shiftId: 'sh1', event: {...event, action: 'assigned', actor_id: 'adm'}});
    expect(sentTo()).toEqual(['t1', 't2']);
  });

  test('offering and taking back are recorded without a hand-over push', async () => {
    await __test__.recordShiftTradeEvent({shiftId: 'sh1', event: {...event, action: 'withdrawn'}});
    expect(added).toHaveLength(1);
    expect(fcm.sendFCMNotificationToTeacher).not.toHaveBeenCalled();
  });
});
