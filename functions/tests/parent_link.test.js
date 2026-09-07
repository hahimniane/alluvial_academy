const {parentAccountDecision, displayName} = require('../utils/parent_link');

test('a parent account, or one with no role yet, can be linked', () => {
  expect(parentAccountDecision({user_type: 'parent'})).toEqual({canLink: true, role: 'parent'});
  expect(parentAccountDecision({})).toEqual({canLink: true, role: ''});
  expect(parentAccountDecision(null).canLink).toBe(true);
  expect(parentAccountDecision({role: 'Guardian'}).canLink).toBe(true);
});

test('staff and students are refused unless parent is a secondary role', () => {
  expect(parentAccountDecision({user_type: 'admin'})).toEqual({canLink: false, role: 'admin'});
  expect(parentAccountDecision({user_type: 'teacher', secondary_roles: ['Parent']}).canLink).toBe(true);
  expect(parentAccountDecision({user_type: 'student'}).canLink).toBe(false);
});

test('display name drops blanks', () => {
  expect(displayName({first_name: ' Fatou ', last_name: ''})).toBe('Fatou');
  expect(displayName(undefined)).toBe('');
});
