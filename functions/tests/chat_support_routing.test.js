const {__test: {supportRouting}} = require('../handlers/chat');

describe('Admin Support push routing', () => {
  test('a member writing in notifies the admins, not the virtual inbox id', () => {
    expect(supportRouting({participants: ['T1', 'admin_support'], senderId: 'T1'}))
      .toEqual({notify: 'admins', memberId: 'T1'});
  });

  test('any admin replying notifies the member, whichever admin it was', () => {
    expect(supportRouting({participants: ['admin_support', 'T1'], senderId: 'ADMIN_A'}))
      .toEqual({notify: 'member', memberId: 'T1'});
    expect(supportRouting({participants: ['admin_support', 'T1'], senderId: 'ADMIN_B'}))
      .toEqual({notify: 'member', memberId: 'T1'});
  });

  test('ordinary chats are not support routed', () => {
    expect(supportRouting({participants: ['A', 'B'], senderId: 'A'})).toBeNull();
    expect(supportRouting({participants: ['admin_support'], senderId: 'A'})).toBeNull();
    expect(supportRouting({participants: undefined, senderId: 'A'})).toBeNull();
  });
});
