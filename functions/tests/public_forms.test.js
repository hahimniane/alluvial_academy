jest.mock('firebase-functions/v2/https', () => ({
  ...jest.requireActual('firebase-functions/v2/https'),
  onCall: (_options, fn) => fn,
}));

const admin = require('firebase-admin');
const {createFakeFirestore, installOnAdmin, FakeTimestamp} = require('./helpers/fake_firestore');
const {getPublicForm, submitPublicFormResponse, _internals} = require('../handlers/public_forms');

const FIELDS = {
  q_name: {label: 'Child name', type: 'text', required: true, order: 2},
  q_intro: {label: 'About you', type: 'heading', order: 1},
  q_level: {label: 'Level', type: 'dropdown', options: ['Beginner', 'Advanced'], order: 3},
  q_more: {
    label: 'Details',
    type: 'long_text',
    order: 4,
    conditionalLogic: {dependsOnFieldId: 'q_level', condition: 'equals', expectedValue: 'Advanced', isVisible: true, extra: 'x'},
  },
  q_photo: {label: 'Photo', type: 'image_upload', order: 5},
};

function seed(extra = {}) {
  return {
    form_templates: {
      open: {name: 'Open Day Sign-up', description: 'Tell us about your child', isActive: true, public_link_enabled: true, frequency: 'onDemand', allowedRoles: ['parent'], fields: FIELDS, autoFillRules: [{fieldId: 'q_name'}]},
      closed: {name: 'Staff Survey', isActive: true, public_link_enabled: false, allowedRoles: ['teacher'], fields: FIELDS},
      old: {name: 'Renamed Later', isActive: false, version: 1, public_link_enabled: true, fields: FIELDS},
      newer: {name: 'Renamed Later', isActive: true, version: 2, fields: {q_name: FIELDS.q_name}},
      ...extra,
    },
  };
}

let db;
beforeEach(() => {
  db = createFakeFirestore(seed());
  installOnAdmin(admin, db);
});

const submit = (data) => submitPublicFormResponse({data: {id: 'open', name: 'Sample Parent', phone: '+224 620 00 00 00', responses: {q_name: 'Sample Child'}, ...data}});
const responses = () => Object.entries(db.store.form_responses || {});

describe('getPublicForm', () => {
  test('a form open to anyone returns its questions, nothing admin-only', async () => {
    const result = await getPublicForm({data: {id: 'open'}});
    expect(result).toMatchObject({found: true, available: true, id: 'open', title: 'Open Day Sign-up', description: 'Tell us about your child', audience: ['parent']});
    expect(result.fields.map((f) => f.id)).toEqual(['q_intro', 'q_name', 'q_level', 'q_more', 'q_photo']);
    expect(result.fields.find((f) => f.id === 'q_more').conditionalLogic).toEqual({dependsOnFieldId: 'q_level', condition: 'equals', expectedValue: 'Advanced', isVisible: true});
    expect(result).not.toHaveProperty('autoFillRules');
    expect(result).not.toHaveProperty('public_link_enabled');
  });

  test('a members-only form gives its title and no questions', async () => {
    const result = await getPublicForm({data: {id: 'closed'}});
    expect(result).toEqual({found: true, available: false, id: 'closed', title: 'Staff Survey', category: '', frequency: '', audience: ['teacher']});
  });

  test('a missing form is not found', async () => {
    await expect(getPublicForm({data: {id: 'gone'}})).resolves.toEqual({found: false, available: false});
  });

  test('a retired copy follows to the active copy with the same name, keeping the link open', async () => {
    const result = await getPublicForm({data: {id: 'old'}});
    expect(result).toMatchObject({found: true, available: true, id: 'newer'});
    expect(result.fields.map((f) => f.id)).toEqual(['q_name']);
  });

  test('a deactivated form with no active copy is not found', async () => {
    db.store.form_templates.newer.isActive = false;
    await expect(getPublicForm({data: {id: 'old'}})).resolves.toEqual({found: false, available: false});
  });

  test('a bad id is refused', async () => {
    await expect(getPublicForm({data: {id: 'a/b'}})).rejects.toMatchObject({code: 'invalid-argument'});
    await expect(getPublicForm({data: {}})).rejects.toMatchObject({code: 'invalid-argument'});
  });
});

describe('submitPublicFormResponse', () => {
  test('stores a response shaped like a signed-in one, tied to no account', async () => {
    const result = await submit({responses: {q_name: 'Sample Child', q_level: 'Advanced', q_more: 'Reads well'}});
    expect(result.success).toBe(true);
    const [[id, doc]] = responses();
    expect(id).toBe(result.id);
    expect(doc).toMatchObject({
      formId: 'open',
      templateId: 'open',
      formName: 'Open Day Sign-up',
      formTitle: 'Open Day Sign-up',
      formType: 'onDemand',
      frequency: 'onDemand',
      status: 'completed',
      public_submission: true,
      submitter_name: 'Sample Parent',
      submitter_phone: '+224 620 00 00 00',
      firstName: 'Sample',
      lastName: 'Parent',
      userEmail: null,
      responses: {q_name: 'Sample Child', q_level: 'Advanced', q_more: 'Reads well'},
    });
    expect(doc.userId).toMatch(/^public_link_[0-9a-f]{20}$/);
    expect(doc).not.toHaveProperty('submittedBy');
    expect(doc).not.toHaveProperty('teacherId');
    expect(doc.yearMonth).toMatch(/^\d{4}-\d{2}$/);
    expect(doc.submittedAt).toBeInstanceOf(FakeTimestamp);
  });

  test('the same number groups under one sender, however it is spaced', async () => {
    await submit({});
    await submit({phone: '+224620000000'});
    const [a, b] = responses().map(([, doc]) => doc.userId);
    expect(a).toBe(b);
  });

  test('a members-only or missing form takes no answers', async () => {
    await expect(submit({id: 'closed'})).rejects.toMatchObject({code: 'failed-precondition'});
    await expect(submit({id: 'gone'})).rejects.toMatchObject({code: 'failed-precondition'});
    expect(responses()).toHaveLength(0);
  });

  test('the switch is read again at send time', async () => {
    await getPublicForm({data: {id: 'open'}});
    db.store.form_templates.open.public_link_enabled = false;
    await expect(submit({})).rejects.toMatchObject({code: 'failed-precondition'});
  });

  test.each([
    ['a one-letter name', {name: 'A'}],
    ['a name over 100 characters', {name: 'x'.repeat(101)}],
    ['letters in the phone', {phone: '+224 abc 000'}],
    ['a phone too short', {phone: '12345'}],
    ['a phone too long', {phone: '1'.repeat(26)}],
  ])('refuses %s', async (_label, data) => {
    await expect(submit(data)).rejects.toMatchObject({code: 'invalid-argument'});
    expect(responses()).toHaveLength(0);
  });

  test.each([
    ['a question the form does not have', {q_other: 'x'}],
    ['a display block', {q_intro: 'x'}],
    ['a file question', {q_photo: 'https://example.test/a.png'}],
    ['an answer over 5000 characters', {q_name: 'x'.repeat(5001)}],
    ['an object answer', {q_name: {a: 1}}],
    ['a list with a non-text item', {q_level: ['ok', 3]}],
  ])('refuses %s', async (_label, answers) => {
    await expect(submit({responses: answers})).rejects.toMatchObject({code: 'invalid-argument'});
    expect(responses()).toHaveLength(0);
  });

  test('refuses an oversized payload', async () => {
    const big = {};
    for (let i = 0; i < 30; i += 1) big[`f${i}`] = {label: `Q${i}`, type: 'long_text', order: i};
    db.store.form_templates.open.fields = big;
    const answers = Object.fromEntries(Object.keys(big).map((key) => [key, 'x'.repeat(4000)]));
    await expect(submit({responses: answers})).rejects.toMatchObject({code: 'invalid-argument'});
  });

  test('caps answers per phone per form per day', async () => {
    for (let i = 0; i < _internals.LIMITS.perPhonePerDay; i += 1) await submit({});
    await expect(submit({})).rejects.toMatchObject({code: 'resource-exhausted'});
    expect(responses()).toHaveLength(_internals.LIMITS.perPhonePerDay);
    // Another sender is unaffected.
    await expect(submit({phone: '+1 555 123 4567'})).resolves.toMatchObject({success: true});
  });

  test('caps answers per form per day', async () => {
    const day = new Date().toISOString().slice(0, 10);
    db.store.public_form_submission_counts = {[`open_${day}`]: {count: _internals.LIMITS.perFormPerDay}};
    await expect(submit({})).rejects.toMatchObject({code: 'resource-exhausted'});
  });

  test('a retired linked copy files the answer on the active copy', async () => {
    await submit({id: 'old'});
    const [[, doc]] = responses();
    expect(doc.formId).toBe('newer');
  });
});
