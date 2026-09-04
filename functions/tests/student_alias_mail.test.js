const mockUsers = new Map();

jest.mock('firebase-admin', () => ({
  firestore: () => ({
    collection: () => ({
      where: (field, _op, value) => ({
        limit: () => ({
          get: async () => {
            const hit = mockUsers.get(`${field}:${value}`);
            return hit
              ? {empty: false, docs: [{data: () => hit}]}
              : {empty: true, docs: []};
          },
        }),
      }),
    }),
  }),
}));

const {isUndeliverableAddress, partitionRecipients} = require('../services/email/undeliverable');

const asStudent = (address) => mockUsers.set(`email:${address}`, {user_type: 'student'});
const asStaff = (address, type) => mockUsers.set(`email:${address}`, {user_type: type});

describe('mail to a student alias', () => {
  beforeEach(() => mockUsers.clear());

  test('a student alias at the school domain is undeliverable', async () => {
    asStudent('amdi1234@alluwaleducationhub.org');
    await expect(isUndeliverableAddress('amdi1234@alluwaleducationhub.org')).resolves.toBe(true);
  });

  test('a staff mailbox on the same domain still gets mail', async () => {
    asStaff('mariamcire@alluwaleducationhub.org', 'admin');
    asStaff('billing@alluwaleducationhub.org', 'teacher');
    await expect(isUndeliverableAddress('mariamcire@alluwaleducationhub.org')).resolves.toBe(false);
    await expect(isUndeliverableAddress('billing@alluwaleducationhub.org')).resolves.toBe(false);
  });

  test('an address on the domain with no user record is left alone', async () => {
    await expect(isUndeliverableAddress('support@alluwaleducationhub.org')).resolves.toBe(false);
  });

  test('a student with a real address elsewhere still gets mail', async () => {
    mockUsers.set('email:adult.student@gmail.com', {user_type: 'student'});
    await expect(isUndeliverableAddress('adult.student@gmail.com')).resolves.toBe(false);
  });

  test('the parent is kept when the student on the same invoice is dropped', async () => {
    asStudent('amdi1234@alluwaleducationhub.org');
    const result = await partitionRecipients([
      'parent@gmail.com',
      'amdi1234@alluwaleducationhub.org',
    ]);
    expect(result.deliverable).toEqual(['parent@gmail.com']);
    expect(result.dropped).toEqual(['amdi1234@alluwaleducationhub.org']);
  });

  test('a display-name recipient is matched on its address', async () => {
    asStudent('amdi1234@alluwaleducationhub.org');
    const result = await partitionRecipients('Amina Diallo <amdi1234@alluwaleducationhub.org>');
    expect(result.deliverable).toEqual([]);
    expect(result.dropped).toEqual(['amdi1234@alluwaleducationhub.org']);
  });

  test('a comma-separated list is split before checking', async () => {
    asStudent('amdi1234@alluwaleducationhub.org');
    const result = await partitionRecipients('parent@gmail.com, amdi1234@alluwaleducationhub.org');
    expect(result.deliverable).toEqual(['parent@gmail.com']);
  });

  test('no recipients at all is passed through untouched', async () => {
    await expect(partitionRecipients(undefined)).resolves.toEqual({deliverable: undefined, dropped: []});
  });
});
