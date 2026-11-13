const {
  isLeadershipDuty,
  isLeader,
  takeRefusal,
  offerRefusal,
  tradeEventFromChange,
  offerAudience,
} = require('../services/shifts/shift_trading');

const ts = (ms) => ({toDate: () => new Date(ms)});
const NOW = Date.UTC(2026, 10, 13, 12);

describe('who may take what', () => {
  const teacher = {user_type: 'teacher'};
  const adminUser = {user_type: 'admin'};
  const adminTeacher = {user_type: 'teacher', is_admin_teacher: true};
  const student = {user_type: 'student'};
  const klass = {shift_category: 'teaching'};
  const legacyClass = {};
  const duty = {shift_category: 'leadership'};
  const meeting = {shift_category: 'meeting'};

  test('a class with no category is a class', () => {
    expect(isLeadershipDuty(legacyClass)).toBe(false);
    expect(isLeadershipDuty(duty)).toBe(true);
    expect(isLeadershipDuty(meeting)).toBe(true);
  });

  test('a teacher takes a class', () => {
    expect(takeRefusal({shiftData: klass, userData: teacher})).toBeNull();
    expect(takeRefusal({shiftData: legacyClass, userData: adminUser})).toBeNull();
  });

  test('a student or parent can take nothing', () => {
    expect(takeRefusal({shiftData: klass, userData: student})).toMatch(/Only teachers/);
    expect(takeRefusal({shiftData: duty, userData: student})).toMatch(/Only leaders/);
    expect(takeRefusal({shiftData: klass, userData: null})).toMatch(/not found/);
  });

  test('a plain teacher cannot take a leadership duty', () => {
    expect(takeRefusal({shiftData: duty, userData: teacher, holdsLeadershipDuty: false})).toMatch(/Only leaders/);
    expect(takeRefusal({shiftData: meeting, userData: teacher})).toMatch(/Only leaders/);
  });

  test('leaders take leadership duties', () => {
    expect(takeRefusal({shiftData: duty, userData: adminUser})).toBeNull();
    expect(takeRefusal({shiftData: duty, userData: adminTeacher})).toBeNull();
    // A teacher who already hosts duties of their own is a leader.
    expect(takeRefusal({shiftData: duty, userData: teacher, holdsLeadershipDuty: true})).toBeNull();
    expect(isLeader(teacher, false)).toBe(false);
  });

  test('an inactive account takes nothing', () => {
    expect(takeRefusal({shiftData: klass, userData: {user_type: 'teacher', is_active: false}})).toMatch(/not active/);
  });
});

describe('what can be offered', () => {
  test('a future scheduled class can', () => {
    expect(offerRefusal({status: 'scheduled', shift_start: ts(NOW + 3600e3)}, NOW)).toBeNull();
  });
  test('a started, finished or cancelled class cannot', () => {
    expect(offerRefusal({status: 'scheduled', shift_start: ts(NOW - 60e3)}, NOW)).toMatch(/already started/);
    expect(offerRefusal({status: 'active', shift_start: ts(NOW + 3600e3)}, NOW)).toMatch(/has not started/);
    expect(offerRefusal({status: 'cancelled', shift_start: ts(NOW + 3600e3)}, NOW)).toMatch(/has not started/);
    expect(offerRefusal(null, NOW)).toMatch(/not found/);
  });
});

describe('the trade record', () => {
  const base = {teacher_id: 't1', teacher_name: 'Aisha', custom_name: 'Quran', shift_category: 'teaching'};

  test('offering by the teacher', () => {
    const event = tradeEventFromChange(base, {...base, is_published: true, published_by: 't1'});
    expect(event).toMatchObject({action: 'offered', actor_id: 't1', from_teacher_id: 't1', to_teacher_id: null});
  });

  test('offering by an admin names the admin as actor and the teacher as owner', () => {
    const event = tradeEventFromChange(base, {...base, is_published: true, published_by: 'adm'});
    expect(event).toMatchObject({action: 'offered', actor_id: 'adm', from_teacher_id: 't1'});
  });

  test('taking it back', () => {
    const offered = {...base, is_published: true, published_by: 't1'};
    const event = tradeEventFromChange(offered, {...base, is_published: false});
    expect(event).toMatchObject({action: 'withdrawn', actor_id: 't1', from_teacher_id: 't1'});
  });

  test('another teacher claiming it', () => {
    const offered = {...base, is_published: true, published_by: 't1'};
    const event = tradeEventFromChange(offered, {...base, is_published: false, teacher_id: 't2', teacher_name: 'Bilal'});
    expect(event).toMatchObject({action: 'claimed', actor_id: 't2', from_teacher_id: 't1', to_teacher_id: 't2', to_teacher_name: 'Bilal'});
  });

  test('an admin assigning it', () => {
    const offered = {...base, is_published: true, published_by: 't1'};
    const event = tradeEventFromChange(offered, {
      ...base, is_published: false, teacher_id: 't2', teacher_name: 'Bilal', shift_trade_assigned_by: 'adm',
    });
    expect(event).toMatchObject({action: 'assigned', actor_id: 'adm', to_teacher_id: 't2'});
  });

  test('an unrelated edit is not a trade', () => {
    expect(tradeEventFromChange(base, {...base, notes: 'x'})).toBeNull();
    expect(tradeEventFromChange({...base, is_published: true}, {...base, is_published: true, notes: 'x'})).toBeNull();
  });
});

describe('who hears about an offer', () => {
  const users = [
    {id: 't1', data: {user_type: 'teacher'}},
    {id: 't2', data: {user_type: 'teacher'}},
    {id: 't3', data: {user_type: 'teacher', is_active: false}},
    {id: 'at', data: {user_type: 'teacher', is_admin_teacher: true}},
    {id: 'adm', data: {user_type: 'admin'}},
    {id: 's1', data: {user_type: 'student'}},
  ];

  test('a class goes to active teachers, not its owner or the offerer', () => {
    const ids = offerAudience({shiftData: {shift_category: 'teaching'}, users, excludeUids: ['t1', 'adm']});
    expect(ids.sort()).toEqual(['at', 't2']);
  });

  test('a leadership duty goes only to leaders', () => {
    const ids = offerAudience({shiftData: {shift_category: 'leadership'}, users, excludeUids: ['adm']});
    expect(ids).toEqual(['at']);
  });
});
