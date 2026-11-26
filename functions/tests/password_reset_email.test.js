const mockAuth = {
  getUserByEmail: jest.fn(),
  generatePasswordResetLink: jest.fn(),
};
jest.mock('firebase-admin', () => ({auth: () => mockAuth}));
jest.mock('../services/email/senders', () => ({
  sendPasswordResetEmail: jest.fn(async () => ({success: true})),
  sendTestEmail: jest.fn(),
}));

const {sendCustomPasswordResetEmail} = require('../handlers/emails');
const {sendPasswordResetEmail} = require('../services/email/senders');

beforeEach(() => {
  jest.clearAllMocks();
  jest.spyOn(console, 'log').mockImplementation(() => {});
  jest.spyOn(console, 'error').mockImplementation(() => {});
});

test('an address with no account is answered not-found, and no link is made', async () => {
  mockAuth.getUserByEmail.mockRejectedValue(Object.assign(new Error('no user'), {code: 'auth/user-not-found'}));
  await expect(sendCustomPasswordResetEmail({data: {email: 'someone@gmai.com'}}))
    .rejects.toMatchObject({code: 'not-found'});
  expect(mockAuth.generatePasswordResetLink).not.toHaveBeenCalled();
  expect(sendPasswordResetEmail).not.toHaveBeenCalled();
});

test('a known address gets the email, and the link never reaches the logs', async () => {
  mockAuth.getUserByEmail.mockResolvedValue({uid: 'u1'});
  mockAuth.generatePasswordResetLink.mockResolvedValue('https://example.test/reset?oobCode=SECRET');
  await sendCustomPasswordResetEmail({data: {email: ' person@gmail.com ', displayName: 'P'}});
  expect(mockAuth.generatePasswordResetLink).toHaveBeenCalledWith('person@gmail.com');
  expect(sendPasswordResetEmail).toHaveBeenCalled();
  const logged = console.log.mock.calls.flat().join(' ');
  expect(logged).not.toContain('SECRET');
});
